#!/usr/bin/env perl
BEGIN {unshift(@INC, './lib')}

BEGIN {
    use Test::Most;
    use Test::Output;
    use Test::Exception;
}

use Moose;
use File::Temp;
use Bio::ENA::DataSubmission::Spreadsheet;
use File::Compare;
use File::Path qw(remove_tree);
use Cwd;

my @temp_directories = ();

subtest "Can use the package", sub {
    use_ok('Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest');
};

subtest "No arguments provided", sub {
    my @args = ('-c', 't/data/test_ena_data_submission.conf');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';
};

subtest "Invalid type, missing input", sub {
    my @args = ('-t', 'rex', '-c', 't/data/test_ena_data_submission.conf');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';
};

subtest "Missing output", sub {
    my @args = ('-i', 'pod', '-c', 't/data/test_ena_data_submission.conf');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';
};
subtest "Invalid type", sub {
    my @args = ('-t', 'rex', '-i', '10665_2#81', '-c', 't/data/test_ena_data_submission.conf');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';
};
subtest "Input file does not exist", sub {
    my @args = ('-t', 'file', '-i', 'not/a/file', '-c', 't/data/test_ena_data_submission.conf');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid arguments';
};
subtest "Output file cannot be written to", sub {
    my @args = ('-t', 'lane', '-i', '10665_2#81', '-o', 'not/a/file', '-c', 't/data/test_ena_data_submission.conf');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid arguments';
};

subtest "Input is a lane", sub {
    check_nfs_dependencies();
    using_temp_dir(sub {
        my ($tmp) = @_;
        my @exp = ([ '10660_2#13',
            'FALSE',
            '52',
            'velvet',
            'SLX',
            '0',
            '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/abscessus/TRACKING/2047/2047STDY5552273/SLX/8020157/10660_2#13/velvet_assembly/contigs.fa',
            'scaffold_fasta',
            'Assembly of Mycobacterium abscessus',
            'Assembly of Mycobacterium abscessus',
            'ERP001039',
            'ERS311560',
            'ERR363472',
            'SC',
            'current_date',
            'current_date',
            '',
            '36809',
            'Mycobacterium abscessus',
            ''
        ]);

        my @args = ('-t', 'lane', '-i', '10660_2#13', '-o', "$tmp/manifest.xls", '-c', 't/data/test_ena_data_submission.conf');
        my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new(args => \@args, _current_date => 'current_date');
        ok($obj->run, 'Manifest generated');
        is_deeply $obj->manifest_data, \@exp, 'Correct lane data';
    });
};

subtest "Input is a file", sub {
    check_nfs_dependencies();
    using_temp_dir(sub {
        my ($tmp) = @_;
        my @exp = (
            [ '10660_2#13', 'FALSE', '52', 'velvet', 'SLX', '0', '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/abscessus/TRACKING/2047/2047STDY5552273/SLX/8020157/10660_2#13/velvet_assembly/contigs.fa', 'scaffold_fasta', 'Assembly of Mycobacterium abscessus', 'Assembly of Mycobacterium abscessus', 'ERP001039', 'ERS311560', 'ERR363472', 'SC', 'current_date', 'current_date', '', '36809', 'Mycobacterium abscessus', '' ],
            [ '10665_2#81', 'FALSE', '54', 'velvet', 'SLX', '0', '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/abscessus/TRACKING/2047/2047STDY5552104/SLX/7939790/10665_2#81/velvet_assembly/contigs.fa', 'scaffold_fasta', 'Assembly of Mycobacterium abscessus', 'Assembly of Mycobacterium abscessus', 'ERP001039', 'ERS311393', 'ERR369155', 'SC', 'current_date', 'current_date', '', '36809', 'Mycobacterium abscessus', '' ],
            [ '10665_2#90', 'FALSE', '81', 'velvet', 'SLX', '0', '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/abscessus/TRACKING/2047/2047STDY5552201/SLX/7939803/10665_2#90/velvet_assembly/contigs.fa', 'scaffold_fasta', 'Assembly of Mycobacterium abscessus', 'Assembly of Mycobacterium abscessus', 'ERP001039', 'ERS311489', 'ERR369164', 'SC', 'current_date', 'current_date', '', '36809', 'Mycobacterium abscessus', '' ],
            [ '', 'FALSE', 'not found', '', 'SLX', '0', '', '', '', '', 'not found', 'not found', '11111_1#1', 'SC', 'current_date', 'current_date', '', '', '', '' ]
        );
        my @args = ('-t', 'file', '-i', 't/data/lanes.txt', '-o', "$tmp/manifest.xls", '-c', 't/data/test_ena_data_submission.conf');
        my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new(args => \@args, _current_date => 'current_date');
        ok($obj->run, 'Manifest generated');
        is_deeply $obj->manifest_data, \@exp, 'Correct file data';
    });
};

subtest "Input is a file with spreadsheet validation", sub {
    check_nfs_dependencies();
    using_temp_dir(sub {
        my ($tmp) = @_;
        my @args = ('-t', 'file', '-i', 't/data/lanes.txt', '-o', "$tmp/manifest.xls", '-p', 'im_a_paper', '-c', 't/data/test_ena_data_submission.conf');
        my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new(args => \@args, _current_date => 'current_date');
        ok($obj->run, 'Manifest generated');
        is_deeply(
            diff_xls('t/data/exp_analysis_manifest.xls', "$tmp/manifest.xls"),
            'Manifest file correct'
        );
    });
};

subtest "generate empty spreadsheet", sub {
    check_nfs_dependencies();
    using_temp_dir(sub {
        my ($tmp) = @_;
        my @args = ("--empty", '-o', "$tmp/empty.xls", '-c', 't/data/test_ena_data_submission.conf');
        my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new(args => \@args);
        ok($obj->run, 'Manifest generated');
        is_deeply $obj->manifest_data, [ [] ], 'Empty data correct';
        is_deeply(
            diff_xls('t/data/empty_analysis_manifest.xls', "$tmp/empty.xls"),
            'Empty manifest file correct'
        );
    });
};

subtest "file with annotation", sub {
    check_nfs_dependencies();
    using_temp_dir(sub {
        my ($tmp) = @_;
        my @exp = (
            [ '10660_2#13', 'FALSE', '100', 'Prokka', 'SLX', '0', '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/abscessus/TRACKING/2047/2047STDY5552273/SLX/8020157/10660_2#13/velvet_assembly/annotation/10660_2#13.gff', 'scaffold_flatfile', 'Annotated assembly of Mycobacterium abscessus', 'Annotated assembly of Mycobacterium abscessus', 'ERP001039', 'ERS311560', 'ERR363472', 'SC', 'current_date', 'current_date', '', '36809', 'Mycobacterium abscessus', '' ],
            [ '10665_2#81', 'FALSE', '100', 'Prokka', 'SLX', '0', '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/abscessus/TRACKING/2047/2047STDY5552104/SLX/7939790/10665_2#81/velvet_assembly/annotation/10665_2#81.gff', 'scaffold_flatfile', 'Annotated assembly of Mycobacterium abscessus', 'Annotated assembly of Mycobacterium abscessus', 'ERP001039', 'ERS311393', 'ERR369155', 'SC', 'current_date', 'current_date', '', '36809', 'Mycobacterium abscessus', '' ],
            [ '10665_2#90', 'FALSE', '100', 'Prokka', 'SLX', '0', '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/abscessus/TRACKING/2047/2047STDY5552201/SLX/7939803/10665_2#90/velvet_assembly/annotation/10665_2#90.gff', 'scaffold_flatfile', 'Annotated assembly of Mycobacterium abscessus', 'Annotated assembly of Mycobacterium abscessus', 'ERP001039', 'ERS311489', 'ERR369164', 'SC', 'current_date', 'current_date', '', '36809', 'Mycobacterium abscessus', '' ],
            [ '', 'FALSE', 'not found', '', 'SLX', '0', '', '', '', '', 'not found', 'not found', '11111_1#1', 'SC', 'current_date', 'current_date', '', '', '', '' ]
        );
        my @args = ('-t', 'file', '-i', 't/data/lanes.txt', '-o', "$tmp/manifest.xls", '-a', 'annotation', '-c', 't/data/test_ena_data_submission.conf');
        my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new(args => \@args, _current_date => 'current_date');
        ok($obj->run, 'Manifest generated for annotation data');
        is_deeply $obj->manifest_data, \@exp, 'Correct file data';
    });
};

remove_tree(@temp_directories);
done_testing();

sub diff_xls {
    my ($x1, $x2) = @_;
    my $x1_data = Bio::ENA::DataSubmission::Spreadsheet->new(infile => $x1)->parse;
    my $x2_data = Bio::ENA::DataSubmission::Spreadsheet->new(infile => $x2)->parse;

    return($x1_data, $x2_data);
}

sub using_temp_dir {
    my ($closure) = @_;
    my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1);
    my $tmp = $temp_directory_obj->dirname();
    push @temp_directories, $tmp;
    $closure->($tmp);
}

sub check_nfs_dependencies {
    plan( skip_all => 'Dependency on path /software missing' ) unless ( -e "/software" );
}