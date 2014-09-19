package Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects;

# ABSTRACT: module for submitting genome assemblies with metadata

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects

=head1 SYNOPSIS

	1. validate manifest, die if not met
	2. Place files in ENA dropbox via FTP
	3. generate analysis XML
	4. generate submission XML
	5. validate XMLs with XSDs
	6. submit all files for each submission via ENA REST API
	7. wait for confirmation XML
	8. generate report

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;
use Getopt::Long qw(GetOptionsFromArray);
use Data::Dumper;
use File::Copy qw(copy);
use File::Path qw(make_path);
use Cwd 'abs_path';

use lib "/software/pathogen/internal/prod/lib";
use lib '../lib';
use lib './lib';
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::CommandLine::ValidateManifest;
use Email::MIME;
use Email::Sender::Simple qw(sendmail);

has 'args'            => ( is => 'ro', isa => 'ArrayRef', required => 1 );

has '_output_root'    => ( is => 'rw', isa => 'Str',      required => 0, default => '/nfs/pathogen/ena_updates/' );
has '_output_dest'    => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has 'analysis_type'   => ( is => 'rw', isa => 'Str',      required => 0, default => 'sequence_assembly' );
has 'manifest'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'         => ( is => 'rw', isa => 'Str',      required => 0 );
has 'test'            => ( is => 'rw', isa => 'Bool',     required => 0 );
has 'help'            => ( is => 'rw', isa => 'Bool',     required => 0 );
has '_current_user'   => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has '_auth_users'     => ( is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1 );
has 'no_validate'     => ( is => 'rw', isa => 'Bool',     required => 0, default => 0 );
has '_timestamp'      => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has '_manifest_data'  => ( is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1 );

sub _build__output_dest{
	my $self = shift;
	my $dir = abs_path($self->_output_root);

	my $user      = $self->_current_user;
	my $timestamp = $self->_timestamp;
	$dir .= '/' . $user . '_' . $timestamp;

	my $mode = 0774;
	make_path( $dir, {
		owner => $self->_current_user,
		group => 'pathsub',
		mode  => $mode
	}) or Bio::ENA::DataSubmission::Exception::CannotCreateDirectory->throw( error => "Cannot create directory $dir" );
	chmod $mode, $dir; # sets correct permissions - make_path not working properly

	return $dir;
}

sub _build__current_user {
	my $self = shift;
	return getpwuid( $< );
}

sub _build__auth_users {
	my $self = shift;

	my $dir = $self->_output_root;
	open( my $users, '<', "$dir/approved_users" );
	my @u;
	while( my $line = <$users> ){
		my @parts = split('\t', $line);
		push(@u, $parts[0]) if defined( $parts[0] );
	}
	return \@u;
}

sub _build__timestamp {
	my @timestamp = localtime(time);
	my $day  = sprintf("%04d-%02d-%02d", $timestamp[5]+1900,$timestamp[4]+1,$timestamp[3]);
	my $time = sprintf("%02d-%02d", $timestamp[2], $timestamp[1]);

	return $day . '_' . $time;
}

sub _build__manifest_data {
	my $self = shift;

	my $manifest_handler = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $self->manifest );
	return $manifest_handler->parse_manifest;
}

sub BUILD {
	my ( $self ) = @_;

	my ( $file, $outfile, $test, $analysis_type, $no_validate, $help );
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		'f|file=s'    => \$file,
		'o|outfile=s' => \$outfile,
		'test'        => \$test,
		't|type'      => \$analysis_type,
		'no_validate' => \$no_validate,
		'h|help'      => \$help
	);

	$self->manifest($file)               if ( defined $file );
	$self->outfile($outfile)             if ( defined $outfile );
	$self->test($test)                   if ( defined $test );
	$self->analysis_type($analysis_type) if ( defined $analysis_type );
	$self->no_validate($no_validate)     if ( defined $no_validate );
	$self->help($help)                   if ( defined $help );
}

sub run {
	my $self = shift;

	my $manifest = $self->manifest;
	my $outfile  = $self->outfile;

	# sanity checks
	$self->_check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	$self->_check_user or Bio::ENA::DataSubmission::Exception::UnauthorisedUser->throw( error => "You are not on the approved list of users for this script\n" );
	( -e $manifest ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find $manifest\n" );
	( -r $manifest ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $manifest\n" );
	$outfile = "$manifest.report.xls" unless( defined( $outfile ) );
	$self->outfile($outfile);
	system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" ) if ( defined $outfile );

	# first, validate the manifest
	unless( $self->no_validate ){
		my @args = ( '-f', $manifest, '-r', $outfile );
		my $validator = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new( args => \@args );
		Bio::ENA::DataSubmission::Exception::ValidationFail->throw("Manifest $manifest did not pass validation. See $outfile for report\n") if( $validator->run == 0 ); # manifest failed validation
	}

	# Place files in ENA dropbox via FTP
	my $files = $self->_parse_filelist;
	my $uploader = Bio::ENA::DataSubmission::FTP->new( files => $files );
	$uploader->upload or Bio::ENA::DataSubmission::Exception::FTPError->throw( error => $uploader->error );

	# generate analysis XML
	$self->_update_analysis_xml;

	# generate submission XML
	

	# validate XMLs with XSDs
	
	# submit all files for each submission via ENA REST API

	# get confirmation XML

	# generate report

}

sub _parse_filelist {
	my $self = shift;
	my @manifest = @{ $self->_manifest_data };

	my @filelist;
	for my $row ( @manifest ) {
		push( @filelist, $row->[6] );
	}
	return \@filelist;
}

sub _update_analysis_xml {
	my $self     = shift;
	my $test     = $self->test;
	my $dest     = $self->_output_dest;
	my $manifest = $self->manifest;
	my $analysis = $self->_analysis_xml;

	# parse manifest and loop
	my $manifest_handler = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $manifest );
	my @manifest = @{ $manifest_handler->parse_manifest };
	my @updated_data;
	foreach my $row (@manifest){
		my $analysis_xml = Bio::ENA::DataSubmission::XML->new()->update_analysis( $row );
		push( @updated_data, $analysis_xml );
	}
	my %new_xml = ( 'ANALYSIS' => \@updated_samples );
	Bio::ENA::DataSubmission::XML->new( data => \%new_xml, outfile => "$dest/$analysis", root => 'ANALYSIS_SET' )->write;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;