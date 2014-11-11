#!/usr/bin/env perl
BEGIN { unshift( @INC, './lib' ) }

BEGIN {
    use Test::Most;
    use Test::Output;
    use Test::Exception;
}

use Moose;
use File::Temp;
use Bio::ENA::DataSubmission::Spreadsheet;
use File::Compare;
use File::Path qw( remove_tree);
use Cwd;

my $temp_directory_obj = File::Temp->newdir( DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::CommandLine::GenerateManifest');

my ( @args, $obj, @exp_ers );

#----------------------#
# test illegal options #
#----------------------#

@args = ( '-c', 't/data/test_ena_data_submission.conf' );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );
throws_ok { $obj->run } 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';

@args = ( '-t', 'rex', '-c', 't/data/test_ena_data_submission.conf' );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );
throws_ok { $obj->run } 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';

@args = ( '-i', 'pod', '-c', 't/data/test_ena_data_submission.conf' );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );
throws_ok { $obj->run } 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';

@args = ( '-t', 'rex', '-i', '10665_2#81', '-c', 't/data/test_ena_data_submission.conf' );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );
throws_ok { $obj->run } 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';

@args = ( '-t', 'file', '-i', 'not/a/file', '-c', 't/data/test_ena_data_submission.conf' );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );
throws_ok { $obj->run } 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid arguments';

@args = ( '-t', 'lane', '-i', '10665_2#81', '-o', 'not/a/file', '-c', 't/data/test_ena_data_submission.conf' );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );
throws_ok { $obj->run } 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid arguments';

#--------------#
# test methods #
#--------------#

# check correct ERS numbers, sample names, supplier names

# lane
@exp_ers = (
    [
        'ERS311393', '2047STDY5552104', 'RVI551', 'ERS311393', '36809', 'Mycobacterium abscessus', 'Mycobacterium abscessus', '1648513', '10665_2#81', '', '', '', '', '', 'NA', 'NA', 'NA', 'NA', '', 'NA', '', '', '', '', '', '2047STDY5552104', '', '', 'NA'
    ]
);
@args = ( '-t', 'lane', '-i', '10665_2#81', '-o', "$tmp/manifest.xls", '-c', 't/data/test_ena_data_submission.conf' );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );
ok( $obj->run, 'Manifest generated' );
is_deeply $obj->sample_data, \@exp_ers, 'Correct lane ERS';

# file
@exp_ers = (
    [
        'ERS311560', '2047STDY5552273', 'UNC718', 'ERS311560', '36809', 'Mycobacterium abscessus', 'Mycobacterium abscessus', '1648682', '10660_2#13', '', '', '', '', '', 'NA', 'NA', 'NA', 'NA', '', 'NA', '', '', '', '', '', '2047STDY5552273', '', '', 'NA'
    ],
    [
        'ERS311393', '2047STDY5552104', 'RVI551', 'ERS311393', '36809', 'Mycobacterium abscessus', 'Mycobacterium abscessus', '1648513', '10665_2#81', '', '', '', '', '', 'NA', 'NA', 'NA', 'NA', '', 'NA', '', '', '', '', '', '2047STDY5552104', '', '', 'NA'
    ],
    [
        'ERS311489', '2047STDY5552201', 'UNC647', 'ERS311489', '36809', 'Mycobacterium abscessus', 'Mycobacterium abscessus', '1648610', '10665_2#90', '', '', '', '', '', 'NA', 'NA', 'NA', 'NA', '', 'NA', '', '', '', '', '', '2047STDY5552201', '', '', 'NA'
    ],
    [ '11111_1#1', 'not found', 'not found' ]
);
@args = ( '-t', 'file', '-i', 't/data/lanes.txt', '-o', "$tmp/manifest.xls", '--no_errors', '-c', 't/data/test_ena_data_submission.conf' );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );
ok( $obj->run );
is_deeply $obj->sample_data, \@exp_ers, 'Correct file ERSs';

# check spreadsheet
@args = ( '-t', 'file', '-i', 't/data/lanes.txt', '-o', "$tmp/manifest.xls", '-c', 't/data/test_ena_data_submission.conf' );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );
ok( $obj->run, 'Manifest generated' );
is_deeply( diff_xls( 't/data/exp_manifest.xls', "$tmp/manifest.xls" ), 'Manifest file correct' );

remove_tree($tmp);
done_testing();

sub diff_xls {
    my ( $x1, $x2 ) = @_;
    my $x1_data = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $x1 )->parse;
    my $x2_data = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $x2 )->parse;

    return ( $x1_data, $x2_data );
}
