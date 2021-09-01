package Bio::ENA::DataSubmission::AccessionConverter;

# ABSTRACT: module for converting accession

=head1 NAME

Bio::ENA::DataSubmission::AccessionConverter

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;

use Bio::ENA::DataSubmission::XML;

has 'ena_base_path' => (is => 'ro', isa => 'Str', required => 1);

sub convert_secondary_project_accession_to_primary {
    my ($self, $accession) = @_;

    if (defined($accession) && $accession =~ /ERP/) {
        my $xml = Bio::ENA::DataSubmission::XML->new(url => $self->ena_base_path . "$accession", ena_base_path => $self->ena_base_path)->parse_from_url;
        if (defined($xml) &&
            defined($xml->{STUDY}) &&
            defined($xml->{STUDY}->[0]) &&
            defined($xml->{STUDY}->[0]->{IDENTIFIERS}) &&
            defined($xml->{STUDY}->[0]->{IDENTIFIERS}->[0]) &&
            defined($xml->{STUDY}->[0]->{IDENTIFIERS}->[0]->{SECONDARY_ID}) &&
            defined($xml->{STUDY}->[0]->{IDENTIFIERS}->[0]->{SECONDARY_ID}->[0])) {
            return $xml->{STUDY}->[0]->{IDENTIFIERS}->[0]->{SECONDARY_ID}->[0];
        }
    }
    return $accession;
}

sub convert_secondary_sample_accession_to_biosample {
    my ($self, $accession) = @_;
    if (defined($accession) && $accession =~ /ERS/) {
        my $xml = Bio::ENA::DataSubmission::XML->new(url => $self->ena_base_path . "$accession", ena_base_path => $self->ena_base_path)->parse_from_url;
        if (defined($xml) &&
            defined($xml->{SAMPLE}) &&
            defined($xml->{SAMPLE}->[0]) &&
            defined($xml->{SAMPLE}->[0]->{IDENTIFIERS}) &&
            defined($xml->{SAMPLE}->[0]->{IDENTIFIERS}->[0]) &&
            defined($xml->{SAMPLE}->[0]->{IDENTIFIERS}->[0]->{EXTERNAL_ID}) &&
            defined($xml->{SAMPLE}->[0]->{IDENTIFIERS}->[0]->{EXTERNAL_ID}->[0]) &&
            defined($xml->{SAMPLE}->[0]->{IDENTIFIERS}->[0]->{EXTERNAL_ID}->[0]->{content})) {
            return $xml->{SAMPLE}->[0]->{IDENTIFIERS}->[0]->{EXTERNAL_ID}->[0]->{content};
        }
    }
    return $accession;
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;
