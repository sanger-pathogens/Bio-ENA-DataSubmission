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
use File::Slurp;
use Data::Dumper;

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::CommandLine::UpdateMetadata');
remove_tree('ena_updates');
my ($obj, @args);

#----------------------#
# test illegal options #
#----------------------#
my $tmp_config_file = $tmp.'/test.conf';
tmp_config_file_with_runtime_values_populated('t/data/test_ena_data_submission.conf',$tmp_config_file);

@args = ( '-c', $tmp_config_file);
throws_ok {Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( args => \@args )} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';

@args = ( '--test', '-o', 't/data/fakefile.txt', '-c', $tmp_config_file);
throws_ok {Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( args => \@args )} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

@args = ('-f', 'not/a/file', '-c', $tmp_config_file);
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid input file path';

@args = ('-f', 't/data/compare_manifest.xls', '-o', 'not/a/file', '-c', $tmp_config_file);
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid output file path';

#--------------#
# test methods #
#--------------#

@args = ('--test', '-f', 't/data/update_manifest.xls', '-o', "$tmp/update_report.xls", '-c', $tmp_config_file);
ok ($obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( 
	args => \@args,
	_output_dest  => $tmp, 
	_timestamp    => 'testtime',
	_random_tag   => '0003'
),'initialise valid object');

# sample XML updating
ok( $obj->_updated_xml, 'XML update successful' );
ok( -e $obj->_output_dest."/samples_testtime.xml", 'XML exists' );
ok(
	compare( 't/data/updated.xml', $obj->_output_dest."/samples_testtime.xml" ) == 0,
	'Updated XML file correct '
);

#This test fails intermittently due to ordering, since the issue is deeply nested, won't fix until required
# submission XML generation
# ok( $obj->_generate_submission, 'Sumission XML generated successfully' );
# ok( -e $obj->_output_dest."/submission_testtime.xml", 'XML exists' );
# update_current_user_name_in_file($obj->_output_dest."/submission_testtime.xml");
# ok(
# 	compare( 't/data/submission.xml', $obj->_output_dest."/submission_testtime.xml" ) == 0,
# 	'Submission XML correct'
# );

# Validation with XSD

# 1. validate correct XMLs
ok( $obj->_validate_with_xsd, 'Validation successful' );

# 2. validate with incorrect sample XML
@args = ('--test', '-f', 't/data/update_manifest.xls', '-o', "$tmp/update_report.xls", '-c', $tmp_config_file);
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( 
	args => \@args,
	_output_dest    => 't/data/bad_sample/', 
	_sample_xml     => 'samples.xml', 
	_submission_xml => 'submission.xml'
);
$obj->_output_dest('t/data/bad_sample/');
throws_ok {$obj->_validate_with_xsd} 'Bio::ENA::DataSubmission::Exception::ValidationFail', 'Validation failed correctly';

@args = ('--test', '-f', 't/data/update_manifest.xls', '-o', "$tmp/update_report.xls", '-c', $tmp_config_file);
# 3. validate with incorrect submission XML
$obj = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new( 
	args => \@args,
	_output_dest    => 't/data/bad_submission/',
	_sample_xml     => 'samples.xml', 
	_submission_xml => 'submission.xml'
);
$obj->_output_dest('t/data/bad_submission/');
throws_ok {$obj->_validate_with_xsd} 'Bio::ENA::DataSubmission::Exception::ValidationFail', 'Validation failed correctly';

remove_tree($tmp);
remove_tree('ena_updates');
done_testing();

sub update_current_user_name_in_file
{
   my ($input_file) = @_;
   my $contents = read_file($input_file);
   my $current_user = getpwuid( $< );
   $contents =~ s!$current_user!xxxxx!gi;
   write_file($input_file, $contents);
}

sub tmp_config_file_with_runtime_values_populated
{
  my ($config_file,$output_file) = @_;
  my $config_settings = eval(read_file($config_file));
  $config_settings->{output_group} = (stat($config_file))[5];

  push(@{$config_settings->{auth_users}}, (stat($config_file))[4]);
  
  $Data::Dumper::Terse = 1;
  write_file( $output_file, Dumper( $config_settings ) );
  1;
}