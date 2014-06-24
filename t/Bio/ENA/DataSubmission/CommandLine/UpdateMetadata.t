#!/usr/bin/env perl
BEGIN { unshift( @INC, './lib' ) }

BEGIN {
    use Test::Most;
	use Test::Output;
	use Test::Exception;
}

use Moose;
use File::Slurp;
use File::Path qw( remove_tree);

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::CommandLine::UpdateMetadata');

my @args = ('--test', '-f', 't/data/update_manifest.xls', '-o', "$tmp/update_report.xls");
my $obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( args => \@args, _xml_dest => $tmp );

# test update of XML
ok( $obj->_update_xmls, 'XML update successful' );
ok ( -e "$tmp/ERS001491.xls" );
is(
	read_file("$tmp/ERS001491.xls"),
	read_file('t/data/ERS001491.xls'),
	'ERS001491 XML correct'
);
ok ( -e "$tmp/ERS002783.xls" );
is(
	read_file("$tmp/ERS002783.xls"),
	read_file('t/data/ERS002783.xls'),
	'ERS002783 XML correct'
);

# test 


remove_tree($tmp);
done_testing();