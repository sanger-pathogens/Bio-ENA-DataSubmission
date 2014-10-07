#!/usr/bin/env perl
BEGIN { unshift( @INC, './lib' ) }

BEGIN {
    use Test::Most;
	use Test::Output;
	use Test::Exception;
}

use Moose;
use File::Compare;
use File::Path qw( remove_tree);
use Cwd;
use File::Temp;

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects');

my ($obj, @args);

#----------------------#
# test illegal options #
#----------------------#

@args = ();
$obj = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';

@args = ( '--test', '-o', 't/data/fakefile.txt');
$obj = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

@args = ('-f', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid input file path';

@args = ('-f', 't/data/compare_manifest.xls', '-o', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid output file path';

#--------------#
# test methods #
#--------------#

@args = ('--test', '-f', 't/data/analysis_submission_manifest.xls', '-o', "$tmp/analysis_submission_report.xls");
$obj = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects->new( 
	args         => \@args,
	_checksum    => 'im_a_checksum',
	_output_dest => $tmp,
);

# sample XML updating
ok( $obj->_update_analysis_xml, 'XML update successful' );
ok( -e "$tmp/analysis_2014-10-01.xml", 'XML exists' );
ok(
	compare( 't/data/analysis_updated.xml', "$tmp/analysis_2014-10-01.xml" ) == 0,
	'Updated XML file correct'
);

# test release date comparison
ok( !$obj->_later_than_today( '2000-01-01' ), 'Date comparison correct' );
ok(  $obj->_later_than_today( '2050-01-01' ), 'Date comparison correct');

# submission XML generation
# test with different release dates!
$obj = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects->new( 
	args          => \@args,
	_current_user => 'testuser',
	_timestamp    => 'testtime',
	_output_dest  => $tmp,
	_no_upload    => 1,
	_no_validate  => 1
);
my $files = { '2014-01-01' => "$tmp/analysis_A.xml", '2050-01-01' => "$tmp/analysis_B.xml" };
ok( $obj->_generate_submissions( $files ), 'Submission XMLs generated successfully' );
ok( -e "$tmp/submission_2014-01-01.xml", 'XML exists' );
ok( -e "$tmp/submission_2050-01-01.xml", 'XML exists' );
ok(
	compare( 't/data/analysis_submission1.xml', "$tmp/submission_2014-01-01.xml" ) == 0,
	'Submission XML correct'
);
ok(
	compare( 't/data/analysis_submission2.xml', "$tmp/submission_2050-01-01.xml" ) == 0,
	'Submission XML correct'
);

# test full run


remove_tree($tmp);
done_testing();

