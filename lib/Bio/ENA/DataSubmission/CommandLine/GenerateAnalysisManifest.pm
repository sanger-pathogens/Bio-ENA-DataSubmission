package Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest;

# ABSTRACT: module for generation of manifest files for ENA genome update

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest;
	

=head1 METHODS



=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;
use File::Slurp;

use Path::Find;
use Path::Find::Lanes;
use Path::Find::Filter;

use Getopt::Long qw(GetOptionsFromArray);
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::Spreadsheet;
use Bio::ENA::DataSubmission::FindData;
use List::MoreUtils qw(uniq);

has 'args'             => ( is => 'ro', isa => 'ArrayRef', required => 1 );

has 'type'             => ( is => 'rw', isa => 'Str',      required => 0 );
has 'id'               => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'          => ( is => 'rw', isa => 'Str',      required => 0, default => 'analysis_manifest.xls' );
has 'manifest_data'    => ( is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1 );
has 'empty'            => ( is => 'rw', isa => 'Bool',     required => 0, default => 0 );
has 'pubmed_id'        => ( is => 'rw', isa => 'Str',      required => 0, default => '' );
has 'help'             => ( is => 'rw', isa => 'Bool',     required => 0 );
has '_current_date'    => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has '_analysis_center' => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has '_show_errors'     => ( is => 'rw', isa => 'Bool',     required => 0, default => 1 );

has 'config_file' => ( is => 'rw', isa => 'Str',      required => 0, default    => '/software/pathogen/etc/ena_data_submission.conf');

sub _build__current_date {
	my $self = shift;
	print "Building current_date!\n";

	my @timestamp = localtime(time);
	my $day  = sprintf( "%04d-%02d-%02d", $timestamp[5]+1900, $timestamp[4]+1, $timestamp[3] );
	return $day;
}

sub _build__analysis_center {
	return 'SC';
}

sub BUILD {
	my ( $self ) = @_;

	my ( $type, $id, $outfile, $empty, $pubmed_id, $no_errors, $help,$config_file );
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		't|type=s'      => \$type,
		'i|id=s'        => \$id,
		'o|outfile=s'   => \$outfile,
		'empty'         => \$empty,
		'p|pubmed_id=s' => \$pubmed_id,
		'no_errors'     => \$no_errors,
		'h|help'      => \$help,
		'c|config_file=s' => \$config_file
	);

	$self->type($type)               if ( defined $type );
	$self->id($id)                   if ( defined $id );
	$self->outfile($outfile)         if ( defined $outfile );
	$self->empty($empty)             if ( defined $empty );
	$self->pubmed_id($pubmed_id)     if ( defined $pubmed_id );
	$self->_show_errors(!$no_errors) if ( defined $no_errors );
	$self->help($help)               if ( defined $help );
	
	$self->config_file($config_file) if ( defined $config_file );
	( -e $self->config_file ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find config file\n" );
	$self->_populate_attributes_from_config_file;
}

sub _populate_attributes_from_config_file
{
  my ($self) = @_;
  my $file_contents = read_file($self->config_file);
  my $config_values = eval($file_contents);
}

sub check_inputs{
    my $self = shift; 
    return(
        ($self->type
          && ( $self->type eq 'study'
            || $self->type eq 'lane'
            || $self->type eq 'file'
            || $self->type eq 'sample' )
          && $self->id)
          || $self->empty
          && !$self->help
    );
}

sub run {
	my ($self) = @_;

	my $outfile = $self->outfile;

	# sanity checks
	$self->check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	if ( defined $self->type && $self->type eq 'file' ){
		my $id = $self->id;
		( -e $id ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "File $id does not exist\n" );
		( -r $id ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $id\n" );
	}
	system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" ) if ( defined $outfile );

	my $header = [
		'name*', 'partial*', 'coverage*', 'program*', 'platform*', 'minimum_gap',
		'file*', 'file_type*', 'title', 'description*', 'study*', 'sample*', 'run',
		'analysis_center', 'analysis_date', 'release_date', 'pubmed_id'									
	];

	# write data to spreadsheet
	my $data = $self->manifest_data;
	my $manifest = Bio::ENA::DataSubmission::Spreadsheet->new(
		data                => $data,
		outfile             => $outfile,
		_header             => $header,
		add_manifest_header => 1
	);
	$manifest->write_xls;

	1;
}

sub _build_manifest_data {
	my $self = shift;

	return [[]] if ( $self->empty );

	my $finder = Bio::ENA::DataSubmission::FindData->new(
		type => $self->type,
		id   => $self->id
	);
	my %data = %{ $finder->find };

	my @manifest;
	for my $k ( @{ $data{key_order} } ){
		push( @manifest, $self->_manifest_row( $finder, $data{$k}, $k ) );
	}
	return \@manifest;
}

sub _manifest_row{
	my ($self, $f, $lane, $k) = @_;

	my @row = ('', 'FALSE', 'not found', '', 'SLX', '0', '', '', '', '', 'not found', 'not found', 'not found', $self->_analysis_center, $self->_current_date, $self->_current_date, $self->pubmed_id);
	@row = $self->_error_row(\@row) if ( $self->_show_errors );
	unless ( defined $lane ) {
	    $row[12] = $k;
	    return \@row;
	}

	$row[2]  = $self->_get_coverage( $f, $lane );
	$row[4]  = $self->_get_seq_tech_from_lane( $f->_vrtrack, $lane );
	$row[10] = $self->_get_study_from_lane( $f->_vrtrack, $lane );
	$row[11] = $self->_get_sample_from_lane( $f->_vrtrack, $lane );
	$row[12] = $self->_get_run_from_lane( $lane );

	return \@row;
}

sub _error_row {
	my ($self, $row) = @_;

	my @new_row;
	for my $cell ( @{ $row } ){
		$cell =~ s/not found/not found!!/;
		push( @new_row, $cell );
	}
	return @new_row;
}

sub _get_seq_tech_from_lane {
	my ($self, $vrtrack, $lane) = @_;

	return "SLX"; # remove if any other seq tech is ever added to DB

	my ( $library, $seq_tech );

	$library  = VRTrack::Library->new( $vrtrack, $lane->library_id );
	$seq_tech = VRTrack::Seq_tech->new( $vrtrack, $library->seq_tech_id );

	return $seq_tech->name;
}

sub _get_study_from_lane {
	my ( $self, $vrtrack, $lane ) = @_;
	my ( $library, $sample, $project, $study );

	$library = VRTrack::Library->new( $vrtrack, $lane->library_id );
    $sample  = VRTrack::Sample->new( $vrtrack, $library->sample_id ) if defined $library;
    $project = VRTrack::Project->new( $vrtrack, $sample->project_id ) if defined $sample;
    $study   = VRTrack::Study->new( $vrtrack, $project->study_id ) if defined $project; 

    return $study->acc;
}

sub _get_sample_from_lane {
    my ( $self, $vrtrack, $lane ) = @_;
    my ( $library, $sample );

    $library = VRTrack::Library->new( $vrtrack, $lane->library_id );
    $sample = VRTrack::Sample->new( $vrtrack, $library->sample_id )
      if defined $library;

    return $sample->individual->acc;
}

sub _get_run_from_lane {
	my ( $self, $lane ) = @_;
	return $lane->acc;
}

sub _get_coverage {
	my ( $self, $finder, $lane ) = @_;

	my $yield = $lane->raw_bases;

	my @sub_directories = ( '/velvet_assembly', '/spades_assembly', '/iva_assembly' );
	my %type_extensions = ( ass_stats => 'contigs.fa.stats' );
	my $lane_filter = Path::Find::Filter->new(
            lanes           => [$lane],
            filetype        => 'ass_stats',
            type_extensions => \%type_extensions,
            root            => $finder->_root,
            pathtrack       => $finder->_vrtrack,
            subdirectories  => \@sub_directories,
    );
    my @matching_lanes = $lane_filter->filter;
    return undef unless defined $matching_lanes[0];

    open(my $fh, '<', $matching_lanes[0]->{path});
    my $line = <$fh>;
    $line = <$fh>;
    $line =~ /sum = (\d+)/;
    my $assembly = int($1);
    my $coverage = $yield/$assembly;
	return sprintf( "%.2f", $coverage );
}

sub usage_text {
	return <<USAGE;
Usage: validate_sample_manifest [options]

	-t|type       lane|study|file|sample
	-i|id         lane ID|study ID|file of lanes|file of samples|sample ID
	-o|outfile    path for output manifest
	--empty       generate empty manifest
	-p|pubmed_id  pubmed ID associated with analysis
	-h|help       this help message

USAGE
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;
