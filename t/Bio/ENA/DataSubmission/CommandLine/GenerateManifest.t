#!/usr/bin/env perl

BEGIN {
    use Test::Most;
    use Test::Output;
    use Test::Exception;
    use Test::More;
}

use Moose;
use File::Temp;
use Bio::ENA::DataSubmission::Spreadsheet;
use File::Compare;
use File::Path qw( remove_tree);
use Cwd;


my @temp_directories = ();

subtest "Can use the package", sub {
    use_ok('Bio::ENA::DataSubmission::CommandLine::GenerateManifest');
};

subtest "Dies without arguments", sub {
    my @args = ();
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';
};

subtest "Dies with invalid type", sub {
    my @args = ('-t', 'rex');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';
};

subtest "Dies if type and output are missing", sub {
    my @args = ('-i', 'pod');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';
};

subtest "Dies if type invalid and output are missing", sub {
    my @args = ('-t', 'rex', '-i', '10665_2#81');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';
};

subtest "Dies if input file does not exist", sub {
    my @args = ('-t', 'file', '-i', 'not/a/file');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid arguments';
};

subtest "Dies if output file cannot be written to", sub {
    my @args = ('-t', 'lane', '-i', '10665_2#81', '-o', 'not/a/file');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid arguments';
};

subtest "Dies if invalid file id type", sub {
    my @args = ('-t', 'lane', '--file_id_type', 'wrong', '-i', '10665_2#81', '-o', 'out.xls');
    my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new(args => \@args);
    throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';
};

subtest "Input is a lane", sub {
    check_nfs_dependencies();

    using_temp_dir(sub {
        my ($tmp) = @_;
        my @exp_ers = (
            [
                'ERS311393', '2047STDY5552104', 'RVI551', '', '36809', 'Mycobacterium abscessus', 'Mycobacterium abscessus', '1648513', '10665_2#81', '', '', '', '', '', '1800/2014', '', '', 'NA', '', 'NA', '', '', '', '', '', '2047STDY5552104', '', '', 'NA'
            ]
        );
        my @args = ('-t', 'lane', '-i', '10665_2#81', '-o', "$tmp/manifest.xls");
        my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new(args => \@args);
        ok($obj->run, 'Manifest generated');
        is_deeply $obj->sample_data, \@exp_ers, 'Correct lane ERS';
    });
};

subtest "Input is a file of lanes", sub {
    check_nfs_dependencies();

    using_temp_dir(sub {
        my ($tmp) = @_;
        my @exp_ers = (
            [
                'ERS311560', '2047STDY5552273', 'UNC718', '', '36809', 'Mycobacterium abscessus', 'Mycobacterium abscessus', '1648682', '10660_2#13', '', '', '', '', '', '1800/2014', '', '', 'NA', '', 'NA', '', '', '', '', '', '2047STDY5552273', '', '', 'NA'
            ],
            [
                'ERS311393', '2047STDY5552104', 'RVI551', '', '36809', 'Mycobacterium abscessus', 'Mycobacterium abscessus', '1648513', '10665_2#81', '', '', '', '', '', '1800/2014', '', '', 'NA', '', 'NA', '', '', '', '', '', '2047STDY5552104', '', '', 'NA'
            ],
            [
                'ERS311489', '2047STDY5552201', 'UNC647', '', '36809', 'Mycobacterium abscessus', 'Mycobacterium abscessus', '1648610', '10665_2#90', '', '', '', '', '', '1800/2014', '', '', 'NA', '', 'NA', '', '', '', '', '', '2047STDY5552201', '', '', 'NA'
            ],
            [ '11111_1#1', 'not found', 'not found' ]
        );
        my @args = ('-t', 'file', '-i', 't/data/lanes.txt', '-o', "$tmp/manifest.xls", '--no_errors');
        my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new(args => \@args);
        ok($obj->run, '"run" successful');
        is_deeply $obj->sample_data, \@exp_ers, 'Correct file ERSs with lane IDs';
    });
};

subtest "Input is a file of samples", sub {
    check_nfs_dependencies();
    using_temp_dir(sub {
        my ($tmp) = @_;
        my @exp_ers = (
            [ 'ERS044413', 'EQUI0200', '', '', 1336, 'Streptococcus equi', 'Streptococcus equi', 1252837, '6903_8#56', '', '', '', '', '', '1800/2014', '', '', 'NA', '', 'NA', '', '', '', '', '', 'EQUI0200', '', '', 'NA' ],
            [ 'ERS044414', 'EQUI0201', '', '', 1336, 'Streptococcus equi', 'Streptococcus equi', 1252838, '6903_8#57', '', '', '', '', '', '1800/2014', '', '', 'NA', '', 'NA', '', '', '', '', '', 'EQUI0201', '', '', 'NA' ],
            [ 'ERS044415', 'EQUI0202', '', '', 1336, 'Streptococcus equi', 'Streptococcus equi', 1252839, '6903_8#58', '', '', '', '', '', '1800/2014', '', '', 'NA', '', 'NA', '', '', '', '', '', 'EQUI0202', '', '', 'NA' ],
            [ 'ERS044416', 'EQUI0203', '', '', 1336, 'Streptococcus equi', 'Streptococcus equi', 1252840, '6903_8#59', '', '', '', '', '', '1800/2014', '', '', 'NA', '', 'NA', '', '', '', '', '', 'EQUI0203', '', '', 'NA' ],
            [ 'ERS044417', 'EQUI0204', '', '', 1336, 'Streptococcus equi', 'Streptococcus equi', 1252841, '6903_8#60', '', '', '', '', '', '1800/2014', '', '', 'NA', '', 'NA', '', '', '', '', '', 'EQUI0204', '', '', 'NA' ],
            [ 'ERS044418', 'EQUI0205', '', '', 1336, 'Streptococcus equi', 'Streptococcus equi', 1252842, '6903_8#61', '', '', '', '', '', '1800/2014', '', '', 'NA', '', 'NA', '', '', '', '', '', 'EQUI0205', '', '', 'NA' ],
            [ 'ERS000000', 'not found', 'not found' ]
        );
        my @args = (
            '-t', 'file',
            '-i', 't/data/generate_manifest_samples.txt',
            '-o', "$tmp/manifest.xls",
            '--file_id_type', 'sample',
            '--no_errors',
            '-c', 't/data/test_ena_data_submission.conf'
        );

        my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new(args => \@args);

        ok($obj->run, '"run" successful');
        is_deeply $obj->sample_data, \@exp_ers, 'Correct file ERSs with sample IDs';
    });
};

subtest "Input is a file of lanes with spreadsheet validation", sub {
    check_nfs_dependencies();
    using_temp_dir(sub {
        my ($tmp) = @_;

        my @args = ('-t', 'file', '-i', 't/data/lanes.txt', '-o', "$tmp/manifest.xls");
        my $obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new(args => \@args);
        ok($obj->run, 'Manifest generated');
        is_deeply(diff_xls('t/data/exp_manifest.xls', "$tmp/manifest.xls"), 'Manifest file correct');
    });
};

remove_tree(@temp_directories);
done_testing();

sub diff_xls {
    my ( $x1, $x2 ) = @_;
    my $x1_data = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $x1 )->parse;
    my $x2_data = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $x2 )->parse;

    return ( $x1_data, $x2_data );
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