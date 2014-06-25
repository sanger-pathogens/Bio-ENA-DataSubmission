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

my ($obj, @args);

#----------------------#
# test illegal options #
#----------------------#

@args = ();
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';

@args = ( '--test', '-o', 't/data/fakefile.txt');
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

@args = ('-f', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid input file path';

@args = ('-f', 't/data/compare_manifest.xls', '-o', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid output file path';

#--------------#
# test methods #
#--------------#

@args = ('--test', '-f', 't/data/update_manifest.xls', '-o', "$tmp/update_report.xls");
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( args => \@args, _xml_dest => $tmp );

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

# test generation of submission XML
ok( $obj->generate_submission, 'Submission XML generation successful');
ok( -e "$tmp/submission.xml");
is(
	read_file("$tmp/submission.xml"),
	read_file('t/data/submission.xml'),
	'Submission XML correct'
);

remove_tree($tmp);
done_testing();