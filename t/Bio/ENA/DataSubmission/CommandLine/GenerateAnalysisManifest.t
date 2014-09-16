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

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest');

my ( @args, $obj, @exp );

#----------------------#
# test illegal options #
#----------------------#

@args = ();
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';

@args = ('-t');
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';

@args = ('-t', 'rex');
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';

@args = ('-i');
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';

@args = ('-i', 'pod');
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';

@args = ('-t', 'rex', '-i', '10665_2#81');
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies with invalid arguments';

@args = ('-t', 'file', '-i', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid arguments';

@args = ('-t', 'lane', '-i', '10665_2#81', '-o', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid arguments';


#--------------#
# test methods #
#--------------#

# check correct ERS numbers, sample names, supplier names

# lane
@exp = ( ['', 'FALSE', '52.42', '', 'SLX', '0', '', '', '', '', 'ERP001039', 'ERS311560', 'ERR363472', 'SC', 'current_date', 'current_date', ''] );
@args = ( '-t', 'lane', '-i', '10660_2#13', '-o', "$tmp/manifest.xls" );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args, _current_date => 'current_date' );
ok( $obj->run, 'Manifest generated' );
is_deeply $obj->manifest_data, \@exp, 'Correct lane data';

# file
@exp = ( 
	['', 'FALSE', '52.42', '', 'SLX', '0', '', '', '', '', 'ERP001039', 'ERS311560', 'ERR363472', 'SC', 'current_date', 'current_date', ''], 
	['', 'FALSE', '54.31', '', 'SLX', '0', '', '', '', '', 'ERP001039', 'ERS311393', 'ERR369155', 'SC', 'current_date', 'current_date', ''],
	['', 'FALSE', '81.50', '', 'SLX', '0', '', '', '', '', 'ERP001039', 'ERS311489', 'ERR369164', 'SC', 'current_date', 'current_date', ''],
        ['', 'FALSE', 'Not Found', '', 'SLX', '0', '', '', '', '', 'Not Found', 'Not Found', '11111_1#1', 'SC', 'current_date', 'current_date', '']
);
@args = ( '-t', 'file', '-i', 't/data/lanes.txt', '-o', "$tmp/manifest.xls" );
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args, _current_date => 'current_date' );
ok( $obj->run, 'Manifest generated' );
is_deeply $obj->manifest_data, \@exp, 'Correct file data';


# check spreadsheet
@args = ( '-t', 'file', '-i', 't/data/lanes.txt', '-o', "$tmp/manifest.xls", '-p', 'im_a_paper');
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args, _current_date => 'current_date' );
ok( $obj->run, 'Manifest generated' );
is_deeply( 
	diff_xls('t/data/exp_analysis_manifest.xls', "$tmp/manifest.xls" ),
	'Manifest file correct'
);

# check empty spreadsheet
@args = ("--empty", '-o', "$tmp/empty.xls");
$obj = Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest->new( args => \@args );
ok( $obj->run, 'Manifest generated' );
is_deeply $obj->manifest_data, [[]], 'Empty data correct';
is_deeply( 
	diff_xls('t/data/empty_analysis_manifest.xls', "$tmp/empty.xls" ),
	'Empty manifest file correct'
);

remove_tree($tmp);
done_testing();

sub diff_xls {
	my ($x1, $x2) = @_;
	my $x1_data = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $x1 )->parse;
	my $x2_data = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $x2 )->parse;

	return ( $x1_data, $x2_data );
}
