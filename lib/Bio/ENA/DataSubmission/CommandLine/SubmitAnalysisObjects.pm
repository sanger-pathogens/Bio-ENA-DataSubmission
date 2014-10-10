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
use File::Basename;
use File::Copy qw(copy);
use File::Path qw(make_path);
use Cwd 'abs_path';

use Bio::ENA::DataSubmission;
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest;
use Bio::ENA::DataSubmission::XML;
use DateTime;
use Digest::MD5 qw(md5_hex);
use File::Slurp;

has 'args'            => ( is => 'ro', isa => 'ArrayRef', required => 1 );

has '_output_root'    => ( is => 'rw', isa => 'Str',      required => 0, default => '/nfs/pathogen/ena_updates/' );
has '_output_dest'    => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has 'analysis_type'   => ( is => 'rw', isa => 'Str',      required => 0, default => 'sequence_assembly' );
has 'manifest'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'         => ( is => 'rw', isa => 'Str',      required => 0 );
has 'test'            => ( is => 'rw', isa => 'Bool',     required => 0, default => 0 );
has 'help'            => ( is => 'rw', isa => 'Bool',     required => 0 );
has '_current_user'   => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has 'auth_users'      => ( is => 'rw', isa => 'ArrayRef', required => 0,  default => sub{['root']} );
has 'no_validate'     => ( is => 'rw', isa => 'Bool',     required => 0, default => 0 );
has '_no_upload'      => ( is => 'rw', isa => 'Bool',     required => 0, default => 0 );
has '_timestamp'      => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has '_manifest_data'  => ( is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1 );
#has '_data_root'      => ( is => 'rw', isa => 'Str',      required => 0, default => '/software/pathogen/projects/Bio-ENA-DataSubmission/data/' );
has '_data_root'      => ( is => 'rw', isa => 'Str',      required => 0, default => '/Users/cc21/Development/repos/Bio-ENA-DataSubmission/data' );
has '_server_dest'    => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has '_release_dates'  => ( is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1 );

sub _build__output_dest{
	my $self = shift;
	my $dir = abs_path($self->_output_root);

	my $user      = $self->_current_user;
	my $timestamp = $self->_timestamp;
	$dir .= '/' . $user . '_' . $timestamp;

	make_path( $dir );
	# my $mode = 0774;
	# make_path( $dir, {
	# 	owner => $self->_current_user,
	# 	group => 'pathsub',
	# 	mode  => $mode
	# }) or Bio::ENA::DataSubmission::Exception::CannotCreateDirectory->throw( error => "Cannot create directory $dir" );
	# chmod $mode, $dir; # sets correct permissions - make_path not working properly

	return $dir;
}

sub _build__release_dates {
	my $self = shift;
	my @manifest = @{ $self->_manifest_data };

	my @dates;
	for my $row ( @manifest ) {
		push( @dates, $row->[15] ) if ( defined $row->[15] );
	}
	return \@dates;
}

sub _build__current_user {
	my $self = shift;
	return getpwuid( $< );
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

sub _build__server_dest {
	my $self = shift;

	return '/' . $self->analysis_type . '/' . $self->_current_user . '_' . $self->_timestamp;
}

sub BUILD {
	my $self = shift;

	my ( 
		$file, $outfile, $test, $analysis_type,
		$no_validate, $no_upload, $help 
	);
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

sub _check_inputs {
	my $self = shift;

	return (
		$self->manifest && !$self->help
	);
}

sub _check_user {
	my $self = shift;

	return 1;
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
		my $validator = Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest->new( args => \@args );
		Bio::ENA::DataSubmission::Exception::ValidationFail->throw("Manifest $manifest did not pass validation. See $outfile for report\n") if( $validator->run == 0 ); # manifest failed validation
	}

	# Place files in ENA dropbox via FTP
	unless( defined $self->_no_upload ){
		my $files = $self->_parse_filelist;
		my $dest  = $self->_server_dest; 
		my $uploader = Bio::ENA::DataSubmission::FTP->new( files => $files, destination => $dest );
		$uploader->upload or Bio::ENA::DataSubmission::Exception::FTPError->throw( error => $uploader->error );
	}

	# generate analysis XML
	$self->_update_analysis_xml;

	# generate submission XML
	$self->_generate_submissions;

	# validate XMLs with XSDs
	$self->_validate_with_xsd;
	
	# submit all files for each submission via ENA REST API
	$self->_submit;

	# generate report from XML receipts
	$self->_report;

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

	# parse manifest and loop
	my $manifest_handler = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $manifest );
	my @manifest = @{ $manifest_handler->parse_manifest };
	my %updated_data;
	foreach my $row (@manifest){
		$row->{checksum} = md5_hex( read_file( $row->{file} ) ); # add MD5 checksum
		$row->{file} = $self->_server_path( $row->{file} ); # change file path from local to server
		my $analysis_xml = Bio::ENA::DataSubmission::XML->new()->update_analysis( $row );
		my $release_date = $row->{release_date};
		# split data based on release dates. release date set in submission XML
		$updated_data{$release_date} = [] unless ( defined $updated_data{$release_date} );
		push( @{ $updated_data{$release_date} }, $analysis_xml );
	}

	my @release_dates;
	for my $k ( keys %updated_data ){
		my %new_xml = ( 'ANALYSIS' => $updated_data{$k} );
		my $outfile = $self->_analysis_xml( $k );
		Bio::ENA::DataSubmission::XML->new( data => \%new_xml, outfile => $outfile )->write_analysis;
		push( @release_dates, $k );
	}
	$self->_release_dates( \@release_dates );
}

sub _server_path {
	my ( $self, $local ) = @_;
	my $s_dest = $self->_server_dest;

	my ( $filename, $directories, $suffix ) = fileparse( $local );
	return "$s_dest/$filename";
}

sub _analysis_xml {
	my ( $self, $id ) = @_;
	my $dest = $self->_output_dest;

	return "$dest/analysis_$id.xml";
}

sub _submission_xml {
	my ( $self, $id ) = @_;
	my $dest = $self->_output_dest;

	return "$dest/submission_$id.xml";
}

sub _receipt_xml {
	my ( $self, $id ) = @_;
	my $dest = $self->_output_dest;

	return "$dest/receipt_$id.xml";
}

sub _generate_submissions {
	my $self = shift;
	my @dates    = @{ $self->_release_dates }; 

	my $sub_template = Bio::ENA::DataSubmission::XML->new( xml => $self->_data_root . "/submission.xml" )->parse_from_file;	

	for my $date ( @dates ){
		my ( $filename, $directories, $suffix ) = fileparse( $self->_analysis_xml( $date ), ('.xml') );
		my $file = "$filename$suffix"; # remove directories

		my @actions = ( { ADD => [ { source => $file, schema => 'analysis' } ] } );
		if ( $self->_later_than_today( $date ) ){
			# hold until release date
			push( @actions, { HOLD => [ { HoldUntilDate => $date } ] } );
		}
		else {
			# release immediately
			push( @actions, { RELEASE => [ {} ] } );
		}

		# construct XML data structure
		my $sub_template = { 
			ACTIONS     => [{ ACTION => \@actions }],
			alias       => $self->_current_user . '_' . $self->_timestamp . "_release_$date",
			center_name => 'SC'
		};
		
		# write to file
		my $outfile = $self->_submission_xml( $date );
		Bio::ENA::DataSubmission::XML->new( data => $sub_template, outfile =>  $outfile )->write_submission;
	}
	return 1;
}

sub _later_than_today {
	my ( $self, $date ) = @_;

	chomp $date;
	my @date_data = split( '-', $date );
	my $release_date = DateTime->new( 
		year  => $date_data[0], 
		month => $date_data[1], 
		day   => $date_data[2] 
	);
	my $today = DateTime->today;

	my $diff = $release_date->subtract_datetime( $today );

	return 1 if ( $diff->{months} > 0 || $diff->{days} > 0 );
	return 0;
}

sub _validate_with_xsd {
	my $self = shift;
	my $dest = $self->_output_dest;
	my $xsd_root = $self->_data_root;

	for my $date ( @{ $self->_release_dates } ){
		my $analysis_xml = $self->_analysis_xml( $date );
		my $sample_validator = Bio::ENA::DataSubmission::XML->new( xml => $analysis_xml, xsd => "$xsd_root/analysis.xsd" );
		Bio::ENA::DataSubmission::Exception::ValidationFail->throw( error => "Validation of updated sample XML failed. Errors:\n" . $sample_validator->validation_report . "\n" ) unless ( $sample_validator->validate );

		my $submission_xml = $self->_submission_xml( $date );
		my $submission_validator = Bio::ENA::DataSubmission::XML->new( xml => $submission_xml, xsd => "$xsd_root/submission.xsd" );
		Bio::ENA::DataSubmission::Exception::ValidationFail->throw( error => "Validation of submission XML failed. Errors:\n" . $submission_validator->validation_report . "\n" ) unless ( $submission_validator->validate );
	}

	return 1;
}

sub _submit {
	my $self = shift;

	for my $date ( @{ $self->_release_dates } ){
		my $sub_obj = Bio::ENA::DataSubmission->new(
			submission => $self->_submission_xml( $date ),
			analysis   => $self->_analysis_xml( $date ),
			receipt    => $self->_receipt_xml( $date ),
			test       => $self->test
		);
		#$sub_obj->submit;
		print $sub_obj->_submission_cmd . "\n";
	}
}

sub _report {
	my $self = shift;

	# parse and store all required info from receipt XMLs
	my %receipts;
	for my $date ( @{ $self->_release_dates } ){
		my $receipt = $self->_receipt_xml( $date );
		$receipts{$date} = $self->_parse_receipt( $receipt );
	}

	# loop through manifest and match to receipt
	my @report = ( ['name', 'success', 'errors'] );
	my @manifest = @{ $self->_manifest_data };
	for my $row ( @manifest ) {
		my $release = $row->[15];
		push( @report, [ $row->[0], $receipts{$release}->{success}, $receipts{$release}->{errors} ] );
	}

	## write report to spreadsheet
	my $report_xls = Bio::ENA::DataSubmission::Spreadsheet->new(
		data                => $data,
		outfile             => $self->outfile,
	);
	$report_xls->write_xls;
}

sub _parse_receipt {
	my ( $self, $receipt ) = @_;

	my $xml = Bio::ENA::DataSubmission::XML->new( xml => $receipt )->parse_from_file;
	return {
		success => $xml->{success},
		errors  => join( ';', @{ $xml->{MESSAGES}->[0]->{ERROR} } )
	};
}

sub usage_text {
	return <<USAGE;
Usage: submit_analysis_objects [options]

	-f|file    
	-o|outfile     Output file for report ( .xls format )
	-t|type        Default = sequence_assembly
	--no_validate  Do not run manifest validation step
	-h|help'       This help message

USAGE
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;