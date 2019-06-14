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

use Path2::Find;
use Path2::Find::Lanes;
use Path2::Find::Filter;

use Getopt::Long qw(GetOptionsFromArray);
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::Spreadsheet;
use Bio::ENA::DataSubmission::FindData;
use Bio::ENA::DataSubmission::LaneInfo;
use List::MoreUtils qw(uniq);

has 'args' => (is => 'ro', isa => 'ArrayRef', required => 1);

has 'type' => (is => 'rw', isa => 'Str', required => 0);
has 'id' => (is => 'rw', isa => 'Str', required => 0);
has 'outfile' => (is => 'rw', isa => 'Str', required => 0, default => 'analysis_manifest.xls');
has 'manifest_data' => (is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1);
has 'empty' => (is => 'rw', isa => 'Bool', required => 0, default => 0);
has 'pubmed_id' => (is => 'rw', isa => 'Str', required => 0, default => '');
has 'help' => (is => 'rw', isa => 'Bool', required => 0);
has '_current_date' => (is => 'rw', isa => 'Str', required => 0, lazy_build => 1);
has '_analysis_center' => (is => 'rw', isa => 'Str', required => 0, lazy_build => 1);
has '_show_errors' => (is => 'rw', isa => 'Bool', required => 0, default => 1);

has 'file_type' => (is => 'rw', isa => 'Str', required => 0, default => 'assembly');
has 'assembly_directories' => (is => 'rw', isa => 'Maybe[ArrayRef]');
has 'annotation_directories' => (is => 'rw', isa => 'Maybe[ArrayRef]');
has 'config_file' => (is => 'rw', isa => 'Maybe[Str]', required => 0, default => $ENV{'ENA_SUBMISSIONS_CONFIG'});


#used for mocking
has 'laneinfo_factory' => (is => 'ro', isa => 'CodeRef', required => 0, default => sub {
    return sub {
        my %hash = @_;
        return Bio::ENA::DataSubmission::LaneInfo->new(%hash);
    }
});


sub _build__current_date {

    my @timestamp = localtime(time);
    my $day = sprintf("%04d-%02d-%02d", $timestamp[5] + 1900, $timestamp[4] + 1, $timestamp[3]);
    return $day;
}

sub _build__analysis_center {
    return 'SC';
}

sub BUILD {
    my ($self) = @_;

    my ($type, $id, $outfile, $empty, $pubmed_id, $no_errors, $help, $config_file, $file_type);
    my $args = $self->args;

    GetOptionsFromArray(
        $args,
        't|type=s'        => \$type,
        'i|id=s'          => \$id,
        'o|outfile=s'     => \$outfile,
        'empty'           => \$empty,
        'p|pubmed_id=s'   => \$pubmed_id,
        'no_errors'       => \$no_errors,
        'h|help'          => \$help,
        'c|config_file=s' => \$config_file,
        'a|file_type=s'   => \$file_type
    );

    $self->type($type) if (defined $type);
    $self->id($id) if (defined $id);
    $self->outfile($outfile) if (defined $outfile);
    $self->empty($empty) if (defined $empty);
    $self->pubmed_id($pubmed_id) if (defined $pubmed_id);
    $self->_show_errors(!$no_errors) if (defined $no_errors);
    $self->help($help) if (defined $help);
    $self->file_type($file_type) if (defined $file_type);

    $self->config_file($config_file) if (defined $config_file);
    (defined($self->config_file) && -e $self->config_file) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw(error => "Cannot find config file\n");
    $self->_populate_attributes_from_config_file;
}

sub _populate_attributes_from_config_file {
    my ($self) = @_;
    my $file_contents = read_file($self->config_file);
    my $config_values = eval($file_contents);

    $self->assembly_directories($config_values->{assembly_directories});
    $self->annotation_directories($config_values->{annotation_directories});
}

sub check_inputs {
    my $self = shift;
    return(
        ($self->type
            && ($self->type eq 'study'
            || $self->type eq 'lane'
            || $self->type eq 'file'
            || $self->type eq 'sample')
            && $self->id)
            || $self->empty
            && !$self->help
    );
}

sub _check_can_write {
    my (undef, $outfile) = @_;
    open(FILE, ">", $outfile) or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" );
    close(FILE);
}

sub run {
    my ($self) = @_;

    my $outfile = $self->outfile;

    # sanity checks
    $self->check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw(error => $self->usage_text);
    if (defined $self->type && $self->type eq 'file') {
        my $id = $self->id;
        (-e $id) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw(error => "File $id does not exist\n");
        (-r $id) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw(error => "Cannot read $id\n");
    }
    $self->_check_can_write($outfile);

    my $header = [
        'name*', 'partial*', 'coverage*', 'program*', 'platform*', 'minimum_gap',
        'file*', 'file_type*', 'title', 'description*', 'study*', 'sample*', 'run',
        'analysis_center', 'analysis_date', 'release_date', 'pubmed_id', 'tax_id', 'common_name', 'locus_tag'
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
    print "Created manifest file:\t" . $self->outfile . "\n";

    1;
}

sub _build_manifest_data {
    my ($self) = @_;

    return [ [] ] if ($self->empty);

    my $manifest = Bio::ENA::DataSubmission::FindData->map($self->type, $self->id, $self->file_type, 'lane', sub {
        my($finder, $id, $data) = @_;
        my ($lane) = (!defined $data) ? undef : $self->laneinfo_factory->(
            file_type              => $self->file_type,
            assembly_directories   => $self->assembly_directories,
            annotation_directories => $self->annotation_directories,
            finder                 => $finder,
            vrtrack                => $finder->_vrtrack,
            lane                   => $data,
        );

        return $self->_manifest_row($lane, $id);
    });
    return $manifest;
}

sub _manifest_row {
    my ($self, $lane, $k) = @_;

    my @row = ('', 'FALSE', 'not found', '', 'SLX', '0', '', '', '', '', 'not found', 'not found', $k, $self->_analysis_center, $self->_current_date, $self->_current_date, $self->pubmed_id, '', '', '');
    @row = $self->_error_row(\@row) if ($self->_show_errors);
    unless (defined $lane) {
        return \@row;
    }

    $row[0] = $lane->lane_name;
    $row[2] = $lane->coverage;
    $row[3] = $lane->program;
    $row[4] = $lane->seq_tech_name;
    $row[6] = $lane->path;
    $row[7] = $lane->type;
    $row[8] = $lane->description;
    $row[9] = $lane->description;
    $row[10] = $lane->study_name;
    $row[11] = $lane->sample_name;
    $row[12] = $lane->run;
    $row[18] = $lane->species_name;
    $row[17] = $lane->taxid;
    return \@row;
}

sub _error_row {
    my (undef, $row) = @_;

    my @new_row;
    for my $cell (@{$row}) {
        $cell =~ s/not found/not found!!/;
        push(@new_row, $cell);
    }
    return @new_row;
}

sub usage_text {
    return <<USAGE;
Usage: generate_analysis_manifest [options]

	-t|type          lane|study|file|sample
	-i|id            lane ID|study ID|file of lanes|file of samples|sample ID
	-o|outfile       path for output manifest
	--empty          generate empty manifest
	-p|pubmed_id     pubmed ID associated with analysis
	-a|file_type     [assembly|annotation] defaults to assembly
	-h|help          this help message

USAGE
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;
