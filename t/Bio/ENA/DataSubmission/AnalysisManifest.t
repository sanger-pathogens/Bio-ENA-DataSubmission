#!/usr/bin/env perl

BEGIN {unshift(@INC, './lib')}

BEGIN {
    use strict;
    use warnings;
    use Test::Most;
}


# Test the module can be used
{

    use_ok('Bio::ENA::DataSubmission::AnalysisManifest');
}

#Test can populate flat file and chromosome list
{
    my $expected = <<EXPECTED;
STUDY ERP005928
SAMPLE ERS1324143
ASSEMBLYNAME 50624_G01-3
ASSEMBLY_TYPE clone or isolate
COVERAGE 100
PROGRAM HGAP, Circlator, Prokka
PLATFORM PacBio
MOLECULETYPE genomic DNA
FLATFILE 50624_G01.embl.gz
CHROMOSOME_LIST 50624_G01.chromosome_list.gz
EXPECTED

    my ($under_test) = Bio::ENA::DataSubmission::AnalysisManifest->new(
        study          => "ERP005928",
        sample         => "ERS1324143",
        assembly_name  => "50624_G01-3",
        assembly_type  => "clone or isolate",
        coverage       => 100,
        program        => "HGAP, Circlator, Prokka",
        platform       => "PacBio",
        molecule_type  => "genomic DNA",
        flat_file      => "50624_G01.embl.gz",
        chromosom_list => "50624_G01.chromosome_list.gz",
    );

    my $actual = $under_test->get_content();
    is($actual, $expected, 'get_content() returns the expected get_content');
}

#Test can populate fasta file
{
    my $expected = <<EXPECTED;
STUDY ERP005928
SAMPLE ERS1324143
ASSEMBLYNAME 50624_G01-3
ASSEMBLY_TYPE clone or isolate
COVERAGE 100
PROGRAM HGAP, Circlator, Prokka
PLATFORM PacBio
MOLECULETYPE genomic DNA
FASTA 50624_G01.fasta.gz
EXPECTED

    my ($under_test) = Bio::ENA::DataSubmission::AnalysisManifest->new(
        study         => "ERP005928",
        sample        => "ERS1324143",
        assembly_name => "50624_G01-3",
        assembly_type => "clone or isolate",
        coverage      => 100,
        program       => "HGAP, Circlator, Prokka",
        platform      => "PacBio",
        molecule_type => "genomic DNA",
        fasta         => "50624_G01.fasta.gz",
    );

    my $actual = $under_test->get_content();
    is($actual, $expected, 'get_content() returns the expected get_content');
}


done_testing();

