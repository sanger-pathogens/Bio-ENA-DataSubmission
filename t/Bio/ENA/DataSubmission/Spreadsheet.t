#!/usr/bin/env perl
BEGIN { unshift( @INC, './lib' ) }

BEGIN {
    use Test::Most;
	use Test::Output;
	use Test::Exception;
}

use Moose;
use File::Temp;
use File::Slurp;
use File::Path qw( remove_tree);

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::Spreadsheet');

my $obj;

# test reading
$obj = Bio::ENA::DataSubmission::Spreadsheet->new( infile => 't/data/test.xls');
is_deeply $obj->parse,
	[['name', 'age'], ['Carla', '27'], ['Becca', '22']],
	'Correct parsed file structure';

# test writing
my $data = [['name', 'age'], ['Carla', '27'], ['Becca', '22']];
Bio::ENA::DataSubmission::Spreadsheet->new( data => $data, outfile => "$tmp/test.xls")->write_xls;
is(
	read_file('t/data/test.xls'),
	read_file("$tmp/test.xls"),
	'spreadsheet file correct'
);

# test appending
my $data = [['Carla', '27'], ['Becca', '22']];
Bio::ENA::DataSubmission::Spreadsheet->new( data => $data, infile => "t/data/header.xls", outfile => "$tmp/append_test.xls")->write_xls;
is(
	read_file('t/data/test.xls'),
	read_file("$tmp/append_test.xls"),
	'spreadsheet file correct'
);

remove_tree($tmp);
done_testing();