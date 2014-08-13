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

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 0 );
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
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid output file path';

#--------------#
# test methods #
#--------------#

@args = ('--test', '-f', 't/data/update_manifest.xls', '-o', "$tmp/update_report.xls");
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( 
	args => \@args,
	_output_dest  => $tmp, 
	_data_root    => './data', 
	_email_to     => 'cc21@sanger.ac.uk',
	_timestamp    => 'testtime',
	_current_user => 'testuser'
);

# sample XML updating
ok( $obj->_updated_xml, 'XML update successful' );
ok( -e "$tmp/samples_testtime.xml", 'XML exists' );
ok(
	compare( 't/data/updated.xml', "$tmp/samples_testtime.xml" ) == 0,
	'Updated XML file correct'
);

# submission XML generation
ok( $obj->_generate_submission, 'Sumission XML generated successfully' );
ok( -e "$tmp/submission_testtime.xml", 'XML exists' );
ok(
	compare( 't/data/submission.xml', "$tmp/submission_testtime.xml" ) == 0,
	'Submission XML correct'
);

# Validation with XSD

# 1. validate correct XMLs
ok( $obj->_validate_with_xsd, 'Validation successful' );

# 2. validate with incorrect sample XML
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( 
	args => \@args,
	_output_dest    => 't/data/bad_sample/', 
	_data_root      => './data', 
	_email_to       => 'cc21@sanger.ac.uk', 
	_sample_xml     => 'samples.xml', 
	_submission_xml => 'submission.xml'
);
throws_ok {$obj->_validate_with_xsd} 'Bio::ENA::DataSubmission::Exception::ValidationFail', 'Validation failed correctly';

# 3. validate with incorrect submission XML
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( 
	args => \@args,
	_output_dest    => 't/data/bad_submission/',
	_data_root      => './data', 
	_email_to       => 'cc21@sanger.ac.uk',
	_sample_xml     => 'samples.xml', 
	_submission_xml => 'submission.xml'
);
throws_ok {$obj->_validate_with_xsd} 'Bio::ENA::DataSubmission::Exception::ValidationFail', 'Validation failed correctly';

#remove_tree($tmp);
done_testing();

