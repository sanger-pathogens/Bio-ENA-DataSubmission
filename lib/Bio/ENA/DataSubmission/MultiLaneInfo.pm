package Bio::ENA::DataSubmission::MultiLaneInfo;

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
use Try::Tiny;

use Path2::Find;
use Path2::Find::Lanes;
use Path2::Find::Filter;

use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::FindData;
use Bio::ENA::DataSubmission::LaneInfo;


#inputs
has 'file_type' => (is => 'rw', isa => 'Str', required => 1);
has 'assembly_directories' => (is => 'rw', isa => 'Maybe[ArrayRef]');
has 'annotation_directories' => (is => 'rw', isa => 'Maybe[ArrayRef]');
has 'finder' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::FindData', required => 1);
has 'vrtrack' => (is => 'ro', isa => 'VRTrack::VRTrack', required => 1);
has 'lane' => (is => 'ro', isa => 'VRTrack::Lane', required => 1);

has 'paths' => (is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_build_paths');
has 'lane_infos' => (is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_build_lane_infos');

sub _build_paths {
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
    my $lane_filter = Path2::Find::Filter->new(
        lanes           => [ $self->lane ],
        filetype        => $filetype,
        type_extensions => \%type_extensions,
        root            => $self->finder->_root,
        pathtrack       => $self->vrtrack,
        subdirectories  => $directory,
    );
    my @results;
    foreach my $matching_lane ($lane_filter->filter) {
        push @results, $matching_lane->{path};
    }
    return \@results;
}

sub _build_lane_infos {
    my ($self) = @_;
    my @results;
    foreach my $path (@{$self->paths}) {
        if (defined($path)) {
            push @results, Bio::ENA::DataSubmission::LaneInfo->new(
                file_type              => $self->file_type,
                vrtrack                => $self->vrtrack,
                lane                   => $self->lane,
                path                   => $path

            );
        }
    }
    if (scalar @results == 0) {
        push @results, Bio::ENA::DataSubmission::LaneInfo->new(
            file_type              => $self->file_type,
            vrtrack                => $self->vrtrack,
            lane                   => $self->lane,
            path                   => undef

        );
    }
    return \@results;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
