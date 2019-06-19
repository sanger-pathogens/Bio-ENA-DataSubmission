#!/usr/bin/env perl

BEGIN {
    use strict;
    use warnings;
    use Test::Most;
    use Test::Output;
    use Test::Exception;
    use Test::MockObject;
}


use File::Temp;
use File::Temp qw(tempfile tempdir);
use File::Path qw(remove_tree);

use constant A_STUDY => "A_STUDY";
use constant A_SAMPLE => "A_SAMPLE";
use constant A_STUDY_PRIMARY_ID => "A_STUDY_PRIMARY_ID";
use constant A_SAMPLE_PRIMARY_ID => "A_SAMPLE_PRIMARY_ID";
use constant A_LOCUS_TAG => "A_LOCUS_TAG";
use constant ANOTHER_STUDY => "ANOTHER_STUDY";
use constant ANOTHER_SAMPLE => "ANOTHER_SAMPLE";
use constant ANOTHER_STUDY_PRIMARY_ID => "ANOTHER_STUDY_PRIMARY_ID";
use constant ANOTHER_SAMPLE_PRIMARY_ID => "ANOTHER_SAMPLE_PRIMARY_ID";
use constant ANOTHER_LOCUS_TAG => "ANOTHER_LOCUS_TAG";

subtest "Can use the package", sub {
    use_ok('Bio::ENA::DataSubmission::SpreadsheetEnricher');
};

subtest "Can convert the ids", sub {

    my $converter = Test::MockObject->new();
    $converter->set_isa('Bio::ENA::DataSubmission::AccessionConverter');
    $converter->mock('convert_secondary_project_accession_to_primary' => sub {
        my (undef, $accession) = @_;

        return $accession eq A_STUDY ? A_STUDY_PRIMARY_ID : ($accession eq ANOTHER_STUDY ? ANOTHER_STUDY_PRIMARY_ID : undef);
    });
    $converter->mock('convert_secondary_sample_accession_to_biosample' => sub {
        my (undef, $accession) = @_;
        return $accession eq A_SAMPLE ? A_SAMPLE_PRIMARY_ID : ($accession eq ANOTHER_SAMPLE ? ANOTHER_SAMPLE_PRIMARY_ID : undef);
    });

    my ($self, $manifest_spreadsheet) = @_;
    foreach my $row (@{$manifest_spreadsheet}) {
        $row->{original_study} = $row->{study};
        $row->{original_sample} = $row->{sample};
        $row->{study} = $self->converter->convert_secondary_project_accession_to_primary($row->{study});
        $row->{sample} = $self->converter->convert_secondary_sample_accession_to_biosample($row->{sample});
    }

    my $spreadsheet = [ a_base_sheet(), {
        study     => ANOTHER_STUDY,
        sample    => ANOTHER_SAMPLE,
        locus_tag => ANOTHER_LOCUS_TAG,
    } ];
    my $under_test = Bio::ENA::DataSubmission::SpreadsheetEnricher->new({ converter => $converter });
    $under_test->enrich($spreadsheet);
    is_deeply($spreadsheet, [
        {
            study              => A_STUDY_PRIMARY_ID,
            sample             => A_SAMPLE_PRIMARY_ID,
            locus_tag          => A_LOCUS_TAG,
            original_locus_tag => A_LOCUS_TAG,
            original_study     => A_STUDY,
            original_sample    => A_SAMPLE,
        },
        {
            study              => ANOTHER_STUDY_PRIMARY_ID,
            sample             => ANOTHER_SAMPLE_PRIMARY_ID,
            locus_tag          => ANOTHER_LOCUS_TAG,
            original_locus_tag => ANOTHER_LOCUS_TAG,
            original_study     => ANOTHER_STUDY,
            original_sample    => ANOTHER_SAMPLE,
        }
    ], "converted accession as expected");

};

subtest "Should conserve provided locus tag", sub {

    my $sheet = a_base_sheet();
    my $under_test = Bio::ENA::DataSubmission::SpreadsheetEnricher->new({ converter => identity_converter() });
    $under_test->enrich([ $sheet ]);
    is_deeply($sheet, {
        study              => A_STUDY,
        sample             => A_SAMPLE,
        locus_tag          => A_LOCUS_TAG,
        original_locus_tag => A_LOCUS_TAG,
        original_study     => A_STUDY,
        original_sample    => A_SAMPLE,
    }, "conserve provided locus tag");

};

subtest "Should replace locus tag with sample if undefined", sub {

    my $sheet = a_base_sheet();
    $sheet->{locus_tag} = undef;
    my $under_test = Bio::ENA::DataSubmission::SpreadsheetEnricher->new({ converter => identity_converter() });
    $under_test->enrich([ $sheet ]);
    is_deeply($sheet, {
        study              => A_STUDY,
        sample             => A_SAMPLE,
        locus_tag          => A_SAMPLE,
        original_locus_tag => undef,
        original_study     => A_STUDY,
        original_sample    => A_SAMPLE,
    }, "conserve provided locus tag");

};

subtest "Should replace locus tag with sample if blank", sub {

    my $sheet = a_base_sheet();
    $sheet->{locus_tag} = "";
    my $under_test = Bio::ENA::DataSubmission::SpreadsheetEnricher->new({ converter => identity_converter() });
    $under_test->enrich([ $sheet ]);
    is_deeply($sheet, {
        study              => A_STUDY,
        sample             => A_SAMPLE,
        locus_tag          => A_SAMPLE,
        original_locus_tag => "",
        original_study     => A_STUDY,
        original_sample    => A_SAMPLE,
    }, "conserve provided locus tag");

};

sub a_base_sheet {
    return {
        study     => A_STUDY,
        sample    => A_SAMPLE,
        locus_tag => A_LOCUS_TAG
    };

}

sub identity_converter {
    my $converter = Test::MockObject->new();
    $converter->set_isa('Bio::ENA::DataSubmission::AccessionConverter');
    $converter->mock('convert_secondary_project_accession_to_primary' => sub {
        my (undef, $accession) = @_;

        return $accession;
    });
    $converter->mock('convert_secondary_sample_accession_to_biosample' => sub {
        my (undef, $accession) = @_;
        return $accession;
    });

    return $converter;
}

done_testing();

