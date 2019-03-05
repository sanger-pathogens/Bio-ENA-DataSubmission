package Bio::ENA::DataSubmission::LaneInfo;

# ABSTRACT: module to isolate GenerateAnalysisManifest from vr and pathfind codebase

=head1 NAME

Bio::ENA::DataSubmission::LaneInfo

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

use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::FindData;


#inputs
has 'file_type' => (is => 'rw', isa => 'Str', required => 1);
has 'assembly_directories' => (is => 'rw', isa => 'Maybe[ArrayRef]');
has 'annotation_directories' => (is => 'rw', isa => 'Maybe[ArrayRef]');
has 'finder' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::FindData', required => 1);
has 'vrtrack' => (is => 'ro', isa => 'VRTrack::VRTrack', required => 1);
has 'lane' => (is => 'ro', isa => 'VRTrack::Lane', required => 1);

#calculated
has 'lane_name' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_lane_name');
has 'seq_tech_name' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_seq_tech_name');
has 'study_name' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_study_name');
has 'species_name' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_species_name');
has 'taxid' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_taxid');
has 'sample_name' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_sample_name');
has 'run' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_run');
has 'coverage' => (is => 'ro', isa => 'Int', lazy => 1, builder => '_build_coverage');
has 'program' => (is => 'ro', isa => 'Int', lazy => 1, builder => '_build_program');
has 'path' => (is => 'ro', isa => 'String', lazy => 1, builder => '_build_path');
has 'type' => (is => 'ro', isa => 'String', lazy => 1, builder => '_build_type');
has 'description' => (is => 'ro', isa => 'String', lazy => 1, builder => '_build_description');

#vrtrack injected codebase
has 'seq_tech' => (is => 'ro', isa => 'VRTrack::Seq_tech', required => 1);
has 'study' => (is => 'ro', isa => 'VRTrack::Study', required => 1);
has 'species' => (is => 'ro', isa => 'Maybe[VRTrack::Species]', required => 0);
has 'sample' => (is => 'ro', isa => 'VRTrack::Sample', required => 1);

around BUILDARGS => sub {
    my ($orig, $class, %args) = @_;
    my ($vrtrack) = $args{'vrtrack'};
    my ($lane) = $args{'lane'};

    my ($library) = VRTrack::Library->new($vrtrack, $lane->library_id);
    my ($seq_tech) = VRTrack::Seq_tech->new($vrtrack, $library->seq_tech_id) if defined $library;
    my ($sample) = VRTrack::Sample->new($vrtrack, $library->sample_id) if defined $library;
    my ($project) = VRTrack::Project->new($vrtrack, $sample->project_id) if defined $sample;
    my ($study) = VRTrack::Study->new($vrtrack, $project->study_id) if defined $project;
    my ($individual) = VRTrack::Individual->new($vrtrack, $sample->individual_id) if defined $sample;
    my ($species) = VRTrack::Species->new($vrtrack, $individual->species_id) if defined $individual;

    $args{'library'} = $library;
    $args{'seq_tech'} = $seq_tech;
    $args{'sample'} = $sample;
    $args{'project'} = $project;
    $args{'study'} = $study;
    $args{'individual'} = $individual;
    $args{'species'} = $species;

    $class->$orig(%args);
};

sub _build_lane_name {
    my ($self) = @_;

    return $self->lane->name;
}

sub _build_seq_tech_name {
    my ($self) = @_;

    return $self->seq_tech->name;
}

sub _build_study_name {
    my ($self) = @_;

    return $self->study->acc;
}

sub _build_species_name {
    my ($self) = @_;
    return defined($self->species) ? $species->name : '';
}

sub _build_taxid {
    my ($self) = @_;
    return defined($self->species) ? $species->taxon_id : '';
}

sub _build_sample_name {
    my ($self) = @_;

    return $self->sample->individual->acc;
}

sub _build_run {
    return defined($lane->acc) ? $lane->acc : '';
}


sub _build_type {
    my ($self) = @_;
    return ($self->file_type eq "assembly") ? 'scaffold_fasta' : 'scaffold_flatfile';
}

sub _build_coverage {
    my ($self) = @_;
    return ($self->file_type eq "assembly") ? $self->_calculate_coverage() : 100;
}

sub _build_program {
    my ($self) = @_;
    return ($self->file_type eq "assembly") ? $self->_get_assembly_program() : 'Prokka';
}

sub _build_path {
    my ($self) = @_;
    my (%type_extensions, $directory, $filetype);
    if ($self->file_type eq "assembly") {

        %type_extensions = (assembly => 'contigs.fa');
        $directory = $self->assembly_directories;
        $filetype = 'assembly';
    }
    else {

        %type_extensions = (gff => '*.gff');
        $directory = $self->annotation_directories;
        $filetype = 'gff';
    }
    my $lane_filter = Path::Find::Filter->new(
        lanes           => [ $self->lane ],
        filetype        => $filetype,
        type_extensions => \%type_extensions,
        root            => $self->finder->_root,
        pathtrack       => $self->vrtrack,
        subdirectories  => $directory,
    );
    my @matching_lanes = $lane_filter->filter;
    return defined $matching_lanes[0] ? $matching_lanes[0]->{path} : undef;
}

sub _build_description {
    my ($self) = @_;

    return ($self->file_type eq "assembly" ? "Assembly of " : "Annotated assembly of ") . $self->species_name;
}

sub _calculate_coverage {
    my ($self) = @_;

    open(my $fh, '<', $self->path . '.stats');
    my $line = <$fh>;
    $line = <$fh>;
    $line =~ /sum = (\d+)/;
    my $assembly = int($1);
    my $coverage = int($self->lane->raw_bases / $assembly);
    return $coverage;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
