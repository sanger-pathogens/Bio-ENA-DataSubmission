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
use File::Slurp;
use File::Path qw( remove_tree);

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();


use_ok('Bio::ENA::DataSubmission::CommandLine::GenerateManifest');

# check correct ERS numbers, sample names
my ( $obj, @args, @exp_ers );

# lane
@exp_ers = ( ['ERS311393', '2047STDY5552104', 'RVI551'] );
@args = ( '-t', 'lane', '-i', '10665_2#81' );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );
is $obj->sample_data, \@exp_ers, 'Correct lane ERS';

# file
@exp_ers = ( ['ERS311560', '2047STDY5552273', 'UNC718'], ['ERS311393', '2047STDY5552104', 'RVI551'], ['ERS311489', '2047STDY5552201', 'UNC647']);
@args = ( '-t', 'file', '-i', 't/data/lanes.txt' );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );
is $obj->sample_data, \@exp_ers, 'Correct file ERSs';


# check spreadsheet
@args = ( '-t', 'file', '-i', 't/data/lanes.txt' '-o', "$tmp/manifest.xls");
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateManifest->new( args => \@args );

#my $exp_xls = Bio::ENA::DataSubmission::Spreadsheet->new( file => 't/data/exp_manifest.xls')->parse;
#my $got_xls = Bio::ENA::DataSubmission::Spreadsheet->new( file => "$tmp/manifest.xls")->parse;
#is_deeply $got_xls, $exp_xls, 'Spreadsheet is correct';

is(
	read_file('t/data/exp_manifest.xls'),
	read_file("$tmp/manifest.xls"),
	'Manifest file correct'
);

remove_tree($tmp);
done_testing();
