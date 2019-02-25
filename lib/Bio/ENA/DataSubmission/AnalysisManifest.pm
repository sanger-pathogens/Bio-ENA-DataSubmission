package Bio::ENA::DataSubmission::AnalysisManifest;

# ABSTRACT: The analysis manifest

=head1 NAME

Bio::ENA::DataSubmission::AnalysisManifest

=head1 SYNOPSIS

Reads a config file and returns the corresponding hash

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use Moose;
use File::Slurp qw(read_file);
use constant SEPARATOR => " ";
use constant LINE_SEPARATOR => "\n";

has 'study' => (is => 'ro', isa => 'Str', required => 1);
has 'sample' => (is => 'ro', isa => 'Str', required => 1);
has 'assembly_name' => (is => 'ro', isa => 'Str', required => 1);
has 'assembly_type' => (is => 'ro', isa => 'Str', required => 1);
has 'coverage' => (is => 'ro', isa => 'Int', required => 1); #TODO Validate the type
has 'program' => (is => 'ro', isa => 'Str', required => 1);
has 'platform' => (is => 'ro', isa => 'Str', required => 1);
has 'molecule_type' => (is => 'ro', isa => 'Str', required => 1);
has 'flat_file' => (is => 'ro', isa => 'Maybe[Str]', required => 0);
has 'fasta' => (is => 'ro', isa => 'Maybe[Str]', required => 0);
has 'chromosom_list' => (is => 'ro', isa => 'Maybe[Str]', required => 0);

sub get_content {
    my ($self) = @_;
    my $file_contents = to_line2("STUDY", $self->study) .
        $self->to_line("SAMPLE", $self->sample) .
        $self->to_line("ASSEMBLYNAME", $self->assembly_name) .
        $self->to_line("ASSEMBLY_TYPE", $self->assembly_type) .
        $self->to_line("COVERAGE", $self->coverage) .
        $self->to_line("PROGRAM", $self->program) .
        $self->to_line("PLATFORM", $self->platform) .
        $self->to_line("MOLECULETYPE", $self->molecule_type);
    $file_contents = $file_contents . $self->to_line("FLATFILE", $self->flat_file) if defined($self->flat_file);
    $file_contents = $file_contents . $self->to_line("FASTA", $self->fasta) if defined($self->fasta);
    $file_contents = $file_contents . $self->to_line("CHROMOSOME_LIST", $self->chromosom_list) if defined($self->chromosom_list);

    return $file_contents;
}

sub to_line {
    my ($self, $header, $content) = @_;

    return $header . SEPARATOR . $content . LINE_SEPARATOR;

}

sub to_line2 {
    my ($header, $content) = @_;

    return $header . SEPARATOR . $content . LINE_SEPARATOR;

}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
