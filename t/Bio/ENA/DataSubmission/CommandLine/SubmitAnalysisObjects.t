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
use Data::Dumper;

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects');

my ($obj, @args);

#----------------------#
# test illegal options #
#----------------------#

@args = ( '-c', 't/data/test_ena_data_submission.conf');
throws_ok {Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects->new( args => \@args )} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';

@args = (  '-o', 't/data/fakefile.txt', '-c', 't/data/test_ena_data_submission.conf');
throws_ok {Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects->new( args => \@args )} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

@args = ('-f', 'not/a/file', '-c', 't/data/test_ena_data_submission.conf');
throws_ok {Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects->new( args => \@args )} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid input file path';

@args = ('-f', 't/data/compare_manifest.xls', '-o', 'not/a/file', '-c', 't/data/test_ena_data_submission.conf');
throws_ok {Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects->new( args => \@args )} 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid output file path';

#--------------#
# test methods #
#--------------#

@args = ( '-f', 't/data/analysis_submission_manifest.xls', '-o', "$tmp/analysis_submission_report.xls", '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects->new( 
	args         => \@args,
	_checksum    => 'im_a_checksum',
	_output_dest => $tmp,
);

# sample XML updating
ok( $obj->_update_analysis_xml, 'XML update successful' );
ok( -e $obj->_output_dest."/analysis_2014-01-01.xml", 'XML exists analysis_2014-01-01.xml' );
ok(
	compare( 't/data/analysis_updated.xml', $obj->_output_dest."/analysis_2014-01-01.xml" ) == 0,
	'Updated XML file correct'
);

# test release date comparison
ok( !$obj->_later_than_today( '2000-01-01' ), 'Date comparison correct' );
ok(  $obj->_later_than_today( '2050-01-01' ), 'Date comparison correct');
remove_tree($obj->_output_dest);


@args = ( '-f', 't/data/analysis_submission_manifest.xls', '-o', "$tmp/analysis_submission_report.xls", '-c', 't/data/test_ena_data_submission.conf');
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
ok( $obj->_generate_submissions( ), 'Submission XMLs generated successfully' );
ok( -e $obj->_output_dest."/submission_2014-01-01.xml", 'XML exists submission_2014-01-01.xml' );
ok( -e $obj->_output_dest."/submission_2050-01-01.xml", 'XML exists submission_2050-01-01.xml' );
ok(
	compare( 't/data/analysis_submission1.xml',  $obj->_output_dest."/submission_2014-01-01.xml" ) == 0,
	'Submission XML correct'
);
ok(
	compare( 't/data/analysis_submission2.xml',  $obj->_output_dest."/submission_2050-01-01.xml" ) == 0,
	'Submission XML correct'
);

# test full run

#remove_tree($obj->_output_dest);
remove_tree($tmp);
done_testing();

