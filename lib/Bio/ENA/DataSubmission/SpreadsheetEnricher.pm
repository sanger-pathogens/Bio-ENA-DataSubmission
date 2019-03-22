package Bio::ENA::DataSubmission::SpreadsheetEnricher;

# ABSTRACT: Enriches the analysis spreasheet before submission

=head1 NAME

Bio::ENA::DataSubmission::SpreadsheetEnricher

=head1 SYNOPSIS

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;
use Bio::ENA::DataSubmission::AccessionConverter;

has 'converter' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::AccessionConverter', required => 1);


sub enrich {
    my ($self, $manifest_spreadsheet) = @_;
    foreach my $row (@{$manifest_spreadsheet}) {
        $self->_convert_accession($row);
        $self->_determine_locus_tag($row);
    }
}

sub _convert_accession {
    my ($self, $row) = @_;
    $row->{original_study} = $row->{study};
    $row->{study} = $self->converter->convert_secondary_project_accession_to_primary($row->{study});
    $row->{original_sample} = $row->{sample};
    $row->{sample} = $self->converter->convert_secondary_sample_accession_to_biosample($row->{sample});
}


sub _determine_locus_tag {
    my ($self, $row) = @_;
    $row->{original_locus_tag} = $row->{locus_tag};

    my ($locus_tag) = _non_empty($row->{locus_tag});

    if (!defined($locus_tag)) {
        $locus_tag = _non_empty($row->{sample});
    }

    $row->{locus_tag} = $locus_tag;
}


sub _non_empty {
    my ($string) = @_;

    return (defined($string) && $string ne "") ? $string : undef;
}



__PACKAGE__->meta->make_immutable;
no Moose;
1;