#!/usr/bin/env perl
BEGIN {unshift(@INC, './lib')}

BEGIN {
    use Test::Most;
    use Test::Output;
    use Test::Exception;
}

package Bio::ENA::DataSubmission::MockGffConverter;
use Moose;
use File::Copy qw(copy);
use Bio::ENA::DataSubmission::GffConverter;

extends 'Bio::ENA::DataSubmission::GffConverter';

override 'convert' => sub {
    my ($self, $locus_tag, $chromosome_list_file, $output_file, $input_file, $common_name, $tax_id, $study, $description) = @_;
    copy($input_file, $output_file) or die 1;
    if (defined($chromosome_list_file)) {
        copy($input_file, $chromosome_list_file) or die 1;
    }
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;
