#!/usr/bin/env perl

BEGIN {
    use strict;
    use warnings;
    use Test::Most;
    use Test::Exception;
    use Test::MockObject;
}


use File::Temp;
use File::Temp qw(tempfile tempdir);
use File::Path qw(remove_tree);
use File::Copy qw(copy);

use_ok('Bio::ENA::DataSubmission::AnalysisSubmissionPreparation');

my @temp_dirs_to_clean = ();
my (undef, $filename) = tempfile(CLEANUP => 1);
my $temp_output_dir_global = File::Temp->newdir(CLEANUP => 1);
my $temp_output_dir_name_global = $temp_output_dir_global->dirname();
push @temp_dirs_to_clean, $temp_output_dir_name_global;
my %full_args = (
    manifest_spreadsheet => [],
    output_dir           => $temp_output_dir_name_global,
    gff_converter        => build_mock_gff_converter(),
);


# Test fasta assemblies without chromosome list
{
    my $temp_output_dir_name = create_temp_dir();
    # file
    my $expected = <<EXPECTED;
STUDY ERP001039
SAMPLE ERS311560
ASSEMBLYNAME 10660_2#13
ASSEMBLY_TYPE clone or isolate
COVERAGE 52
PROGRAM velvet
PLATFORM SLX
MOLECULETYPE genomic DNA
FASTA $temp_output_dir_name/10660_2#13.fasta.gz
EXPECTED
    my $expected2 = <<EXPECTED;
STUDY ERP001039
SAMPLE ERS311393
ASSEMBLYNAME 10665_2#81
ASSEMBLY_TYPE clone or isolate
COVERAGE 54
PROGRAM velvet
PLATFORM SLX
MOLECULETYPE genomic DNA
FASTA $temp_output_dir_name/10665_2#81.fasta.gz
EXPECTED

    my $args = { %full_args };
    $args->{output_dir} = $temp_output_dir_name;
    $args->{manifest_spreadsheet} = _to_spreadsheet_manifest(
        [ "10660_2#13", "FALSE", 52, "velvet", "SLX", "0", "t/data/analysis_submission/testfile1.fa", "scaffold_fasta", "Assembly of Mycobacterium abscessus", "Assembly of Mycobacterium abscessus", "ERP001039", "ERS311560", "ERR363472", "SC", "current_date", "current_date", "im_a_paper", "36809", "Mycobacterium abscessus" ],
        [ "10665_2#81", "FALSE", "54", "velvet", "SLX", "0", "t/data/analysis_submission/testfile2.fa", "scaffold_fasta", "Assembly of Mycobacterium abscessus", "Assembly of Mycobacterium abscessus", "ERP001039", "ERS311393", "ERR369155", "SC", "current_date", "current_date", "im_a_paper", "36809", "Mycobacterium abscessus" ]
    );
    my $obj = Bio::ENA::DataSubmission::AnalysisSubmissionPreparation->new(%$args);
    my @actual_data_for_submission = $obj->prepare_for_submission();
    is_deeply \@actual_data_for_submission, [ [$temp_output_dir_name . "/10660_2#13.manifest", "SC"], [$temp_output_dir_name . "/10665_2#81.manifest", "SC"] ], 'Manifest generated';
    my @actual_manifest_content = map {$_->get_content()} @{$obj->manifest_for_submission};
    is_deeply \@actual_manifest_content, [ $expected, $expected2 ], 'Correct file data';
    ok(-e $temp_output_dir_name . "/10660_2#13.manifest", 'manifest file for 10660_2#13 exists');
    ok(-e $temp_output_dir_name . "/10660_2#13.fasta.gz", 'compressed fasta file for 10660_2#13 exists');
    ok(-e $temp_output_dir_name . "/10665_2#81.manifest", 'manifest file for 10665_2#81 exists');
    ok(-e $temp_output_dir_name . "/10665_2#81.fasta.gz", 'compressed fasta file for 10665_2#81 exists');
    ok(-e $temp_output_dir_name . "/submission_spreadsheet.xls", 'submission spreadsheet exists');

}


# Test fasta assemblies with chromosome list
{
    my $temp_output_dir_name = create_temp_dir();
    # file
    my $expected = <<EXPECTED;
STUDY ERP001039
SAMPLE ERS311560
ASSEMBLYNAME test_genome_1
ASSEMBLY_TYPE clone or isolate
COVERAGE 52
PROGRAM velvet
PLATFORM SLX
MOLECULETYPE genomic DNA
FASTA $temp_output_dir_name/test_genome_1.fasta.gz
CHROMOSOME_LIST $temp_output_dir_name/test_genome_1.chromosome_list.gz
EXPECTED
    my $expected2 = <<EXPECTED;
STUDY ERP001039
SAMPLE ERS311489
ASSEMBLYNAME test_genome_2
ASSEMBLY_TYPE clone or isolate
COVERAGE 81
PROGRAM velvet
PLATFORM SLX
MOLECULETYPE genomic DNA
FASTA $temp_output_dir_name/test_genome_2.fasta.gz
CHROMOSOME_LIST $temp_output_dir_name/test_genome_2.chromosome_list.gz
EXPECTED


    my $args = { %full_args };
    $args->{output_dir} = $temp_output_dir_name;
    $args->{manifest_spreadsheet} = _to_spreadsheet_manifest(
        [ "test_genome_1", "FALSE", "52", "velvet", "SLX", "0", "t/data/analysis_submission/testfile1.fa", "chromosome_fasta", "Assembly of Stap A", "Assembly of Stap A", "ERP001039", "ERS311560", "ERR363472", "SC", "01/09/2014", "01/01/2014", "111111", "1234", "Stap A" ],
        [ "test_genome_2", "TRUE", "81", "velvet", "SLX", "0", "t/data/analysis_submission/testfile2.fa", "chromosome_fasta", "Assembly of Ecoli", "Assembly of Ecoli", "ERP001039", "ERS311489", "ERR369164", "SC", "01/09/2014", "01/01/2050", "111111", "1234", "Ecoli" ]
    );
    my $obj = Bio::ENA::DataSubmission::AnalysisSubmissionPreparation->new(%$args);
    my @actual_data_for_submission = $obj->prepare_for_submission();
    is_deeply \@actual_data_for_submission, [ [$temp_output_dir_name . "/test_genome_1.manifest", "SC"], [$temp_output_dir_name . "/test_genome_2.manifest", "SC"] ], 'Manifest generated';
    my @actual_manifest_content = map {$_->get_content()} @{$obj->manifest_for_submission};
    is_deeply \@actual_manifest_content, [ $expected, $expected2 ], 'Correct file data';
    ok(-e $temp_output_dir_name . "/test_genome_1.manifest", 'manifest file for test_genome_1 exists');
    ok(-e $temp_output_dir_name . "/test_genome_1.fasta.gz", 'compressed fasta file for test_genome_1 exists');
    ok(-e $temp_output_dir_name . "/test_genome_1.chromosome_list.gz", 'compressed chromosome list file for test_genome_1 exists');
    ok(-e $temp_output_dir_name . "/test_genome_2.manifest", 'manifest file for test_genome_2 exists');
    ok(-e $temp_output_dir_name . "/test_genome_2.fasta.gz", 'compressed fasta file for test_genome_2 exists');
    ok(-e $temp_output_dir_name . "/test_genome_2.chromosome_list.gz", 'compressed chromosome list file for test_genome_2 exists');
    ok(-e $temp_output_dir_name . "/submission_spreadsheet.xls", 'submission spreadsheet exists');
}


# Test annotated assemblies with chromosome list
{
    my $temp_output_dir_name = create_temp_dir();
    my $expected = <<EXPECTED;
STUDY ERP001039
SAMPLE ERS311560
ASSEMBLYNAME test_genome_1
ASSEMBLY_TYPE clone or isolate
COVERAGE 52
PROGRAM velvet
PLATFORM SLX
MOLECULETYPE genomic DNA
FLATFILE $temp_output_dir_name/test_genome_1.embl.gz
CHROMOSOME_LIST $temp_output_dir_name/test_genome_1.chromosome_list.gz
EXPECTED
    my $expected2 = <<EXPECTED;
STUDY ERP001039
SAMPLE ERS311489
ASSEMBLYNAME test_genome_2
ASSEMBLY_TYPE clone or isolate
COVERAGE 81
PROGRAM velvet
PLATFORM SLX
MOLECULETYPE genomic DNA
FLATFILE $temp_output_dir_name/test_genome_2.embl.gz
CHROMOSOME_LIST $temp_output_dir_name/test_genome_2.chromosome_list.gz
EXPECTED
    my $args = { %full_args };
    $args->{output_dir} = $temp_output_dir_name;
    $args->{manifest_spreadsheet} = _to_spreadsheet_manifest(
        [ "test_genome_1", "FALSE", "52", "velvet", "SLX", "0", "t/data/analysis_submission/testfile1.gff", "chromosome_flatfile", "Assembly of test genome 1", "We assembled stuff", "ERP001039", "ERS311560", "ERR363472", "SC", "01/09/2014", "01/01/2014", "111111", "1234", "Stap A", "ABC123" ],
        [ "test_genome_2", "TRUE", "81", "velvet", "SLX", "0", "t/data/analysis_submission/testfile2.gff", "chromosome_flatfile", "Assembly of test genome 2", "Assembly of stuff", "ERP001039", "ERS311489", "ERR369164", "SC", "01/09/2014", "01/01/2050", "111111", "1234", "Ecoli" ]
    );

    my $obj = Bio::ENA::DataSubmission::AnalysisSubmissionPreparation->new(%$args);
    my @actual_data_for_submission = $obj->prepare_for_submission();
    is_deeply \@actual_data_for_submission, [ [$temp_output_dir_name . "/test_genome_1.manifest", "SC"], [$temp_output_dir_name . "/test_genome_2.manifest", "SC"] ], 'Manifest generated';
    my @actual_manifest_content = map {$_->get_content()} @{$obj->manifest_for_submission};
    is_deeply \@actual_manifest_content, [ $expected, $expected2 ], 'Correct file data';
    ok(-e $temp_output_dir_name . "/test_genome_1.manifest", 'manifest file for test_genome_1 exists');
    ok(-e $temp_output_dir_name . "/test_genome_1.embl.gz", 'compressed embl file for test_genome_1 exists');
    ok(-e $temp_output_dir_name . "/test_genome_1.chromosome_list.gz", 'compressed chromosome list file for test_genome_1 exists');
    ok(-e $temp_output_dir_name . "/test_genome_2.manifest", 'manifest file for test_genome_2 exists');
    ok(-e $temp_output_dir_name . "/test_genome_2.embl.gz", 'compressed embl file for test_genome_2 exists');
    ok(-e $temp_output_dir_name . "/test_genome_2.chromosome_list.gz", 'compressed chromosome list file for test_genome_2 exists');
    ok(-e $temp_output_dir_name . "/submission_spreadsheet.xls", 'submission spreadsheet exists');
}


# Test annotated assemblies without chromosome list
{
    my $temp_output_dir_name = create_temp_dir();
    my $expected = <<EXPECTED;
STUDY ERP001039
SAMPLE ERS311560
ASSEMBLYNAME 10660_2#13
ASSEMBLY_TYPE clone or isolate
COVERAGE 100
PROGRAM Prokka
PLATFORM SLX
MOLECULETYPE genomic DNA
FLATFILE $temp_output_dir_name/10660_2#13.embl.gz
EXPECTED
    my $expected2 = <<EXPECTED;
STUDY ERP001039
SAMPLE ERS311393
ASSEMBLYNAME 10665_2#81
ASSEMBLY_TYPE clone or isolate
COVERAGE 100
PROGRAM Prokka
PLATFORM SLX
MOLECULETYPE genomic DNA
FLATFILE $temp_output_dir_name/10665_2#81.embl.gz
EXPECTED

    my $args = { %full_args };
    $args->{output_dir} = $temp_output_dir_name;
    $args->{manifest_spreadsheet} = _to_spreadsheet_manifest(
        [ "10660_2#13", "FALSE", "100", "Prokka", "SLX", "0", "t/data/analysis_submission/testfile1.gff", "scaffold_flatfile", "Annotated assembly of Mycobacterium abscessus", "Annotated assembly of Mycobacterium abscessus", "ERP001039", "ERS311560", "ERR363472", "SC", "current_date", "current_date", "im_a_paper", "36809", "Mycobacterium abscessus" ],
        [ "10665_2#81", "FALSE", "100", "Prokka", "SLX", "0", "t/data/analysis_submission/testfile2.gff", "scaffold_flatfile", "Annotated assembly of Mycobacterium abscessus", "Annotated assembly of Mycobacterium abscessus", "ERP001039", "ERS311393", "ERR369155", "SC", "current_date", "current_date", "im_a_paper", "36809", "Mycobacterium abscessus" ]
    );
    my $obj = Bio::ENA::DataSubmission::AnalysisSubmissionPreparation->new(%$args);
    my @actual_data_for_submission = $obj->prepare_for_submission();
    is_deeply \@actual_data_for_submission, [ [$temp_output_dir_name . "/10660_2#13.manifest", "SC"], [$temp_output_dir_name . "/10665_2#81.manifest", "SC"] ], 'Manifest generated';
    my @actual_manifest_content = map {$_->get_content()} @{$obj->manifest_for_submission};
    is_deeply \@actual_manifest_content, [ $expected, $expected2 ], 'Correct file data';
    ok(-e $temp_output_dir_name . "/10660_2#13.manifest", 'manifest file for 10660_2#13 exists');
    ok(-e $temp_output_dir_name . "/10660_2#13.embl.gz", 'compressed embl file for 10660_2#13 exists');
    ok(-e $temp_output_dir_name . "/10665_2#81.manifest", 'manifest file for 10665_2#81 exists');
    ok(-e $temp_output_dir_name . "/10665_2#81.embl.gz", 'compressed embl file for 10665_2#81 exists');
    ok(-e $temp_output_dir_name . "/submission_spreadsheet.xls", 'submission spreadsheet exists');
}

sub test_mandatory_args {
    my ($input) = @_;
    my $args_with_missing_required_arg = { %full_args };
    delete $args_with_missing_required_arg->{$input};
    throws_ok {Bio::ENA::DataSubmission::AnalysisSubmissionPreparation->new(%$args_with_missing_required_arg)} 'Moose::Exception::AttributeIsRequired', "dies if mandatory arg $input is missing";
}

# Check mandatory arguments
{
    my (@mandatory_args) = ('manifest_spreadsheet', 'output_dir');

    foreach (@mandatory_args) {
        test_mandatory_args($_);
    }

}


# Check directories validation
{
    my (@dir_args) = ('output_dir');
    foreach (@dir_args) {
        test_directory_missing($_);
        test_directory_not_a_directory($_);
    }

}

sub _to_spreadsheet_manifest {

    my @values = @_;
    my $result = [];
    my $header = [
        'name', 'partial', 'coverage', 'program', 'platform', 'minimum_gap',
        'file', 'file_type', 'title', 'description', 'study', 'sample', 'run',
        'analysis_center', 'analysis_date', 'release_date', 'pubmed_id', 'tax_id', 'common_name', 'locus_tag'
    ];

    for my $row (@values) {
        my %hash;
        @hash{@$header} = @$row;
        push @$result, \%hash;
    }

    return $result;
}

sub test_directory_missing {
    my ($input) = @_;
    my $args = { %full_args };
    $args->{$input} = 'Not/An/Existing/Directory';
    throws_ok {Bio::ENA::DataSubmission::AnalysisSubmissionPreparation->new(%$args)} 'Bio::ENA::DataSubmission::Exception::DirectoryNotFound', "dies if $input is not found";
}

sub test_directory_not_a_directory {
    my ($input) = @_;
    my $args = { %full_args };
    $args->{$input} = $filename;
    throws_ok {Bio::ENA::DataSubmission::AnalysisSubmissionPreparation->new(%$args)} 'Bio::ENA::DataSubmission::Exception::DirectoryNotFound', "dies if $input is a file and not a dir";
}

sub create_temp_dir {
    my $temp_output_dir = File::Temp->newdir(CLEANUP => 0);
    my $temp_output_dir_name = $temp_output_dir->dirname();
    push @temp_dirs_to_clean, $temp_output_dir_name;
    return $temp_output_dir_name;

}

sub build_mock_gff_converter {
    my $mock_gff_converter = Test::MockObject->new();
    $mock_gff_converter->set_isa('Bio::ENA::DataSubmission::GffConverter');
    $mock_gff_converter->mock('convert' => sub {
        my (undef, undef, $chromosome_list_file, $output_file, $input_file, undef, undef, undef, undef) = @_;
        copy($input_file, $output_file) or die 1;
        if (defined($chromosome_list_file)) {
            copy($input_file, $chromosome_list_file) or die 1;
        }});
    return $mock_gff_converter;
}

remove_tree(@temp_dirs_to_clean);

done_testing();


no Moose;
