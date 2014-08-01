#!/usr/bin/env perl
BEGIN { unshift( @INC, './lib' ) }

BEGIN {
    use Test::Most;
	use Test::Output;
	use Test::Exception;
}

use Moose;
use File::Temp;
use File::Compare;
use Cwd;
use File::Path qw( remove_tree);

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 0 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::Spreadsheet');

my ($obj, $data);

# test reading
$obj = Bio::ENA::DataSubmission::Spreadsheet->new( infile => 't/data/test.xls');
is_deeply $obj->parse,
	[['name', 'age'], ['Carla', '27'], ['Becca', '22']],
	'Correct parsed file structure';

# test writing
$data = [['name', 'age'], ['Carla', '27'], ['Becca', '22']];
Bio::ENA::DataSubmission::Spreadsheet->new( data => $data, outfile => "$tmp/test.xls")->write_xls;
is_deeply( 
	diff_xls('t/data/test.xls', "$tmp/test.xls" ),
	'spreadsheet file correct'
);

# test writing with manifest header
$data = [['Carla', '27'], ['Becca', '22']];
Bio::ENA::DataSubmission::Spreadsheet->new( data => $data, outfile => "$tmp/header_test.xls", add_manifest_header => 1)->write_xls;
is_deeply( 
	diff_xls('t/data/header_test.xls', "$tmp/header_test.xls" ),
	'spreadsheet file correct'
);

remove_tree($tmp);
done_testing();

sub diff_xls {
	my ($x1, $x2) = @_;
	my $x1_data = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $x1 )->parse;
	my $x2_data = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $x2 )->parse;
	return ( $x1_data, $x2_data );
}