package Bio::ENA::DataSubmission::GffConverter;

# ABSTRACT: module used to convert from gff to embl

=head1 NAME

Bio::ENA::DataSubmission::GffConverter

=head1 METHODS



=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;

sub convert {
    my ($self, $locus_tag, $chromosome_list_file, $output_file, $input_file, $common_name, $tax_id, $study, $description) = @_;

    my @cmd = ("gff3_to_embl");
    if (defined $locus_tag) {
        push @cmd, "--locus_tag", $locus_tag;
    }
    if (defined $chromosome_list_file) {
        push @cmd, "--chromosome_list", $chromosome_list_file;
    }
    push @cmd, "--output_filename", $output_file, $common_name, $tax_id, $study, $description, $input_file;
    print "Executing \"" . join("\" \"", @cmd) . "\"\n";
    system(@cmd);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
