#!/usr/bin/env perl

BEGIN {
    use Test::Most;
	use Test::Output;
	use Test::Exception;
}

use Moose;
use File::Slurp;
use File::Path qw( remove_tree);
use Cwd;
use File::Temp;
use Data::Dumper;


my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::CommandLine::ValidateManifest');

my ($obj, @args);

#----------------------#
# test illegal options #
#----------------------#

@args = ( '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new(args => \@args, valid_countries_file => 'data/valid_countries.txt');
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';

@args = ('--edit', '-r', 't/data/fakefile.txt', '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new(args => \@args, valid_countries_file => 'data/valid_countries.txt');
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

@args = ('-f', 'not/a/file', '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new(args => \@args, valid_countries_file => 'data/valid_countries.txt');
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid input file path';

@args = ('-f', 't/data/manifest_bad.xls', '-r', 'not/a/file', '-o', "$tmp/manifest_bad.xls.edit.xls", '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new(args => \@args, valid_countries_file => 'data/valid_countries.txt');
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid output file path';


#--------------------------#
# Check validation reports #
#--------------------------#

# validate good spreadsheet
@args = ('-f', 't/data/manifest_good.xls', '-r', "$tmp/pass.txt", '-o', "$tmp/manifest_good.xls.edit.xls", '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new(args => \@args, valid_countries_file => 'data/valid_countries.txt');
is $obj->run, 1, 'perfect spreadsheet passed';
is(
	read_file('t/data/validator_pass.txt'),
	read_file("$tmp/pass.txt"),
	'validation report correct'
);

# validate bad spreadsheet
@args = ('-f', 't/data/manifest_bad.xls', '-r', "$tmp/fail.txt", '-o', "$tmp/manifest_bad.xls.edit.xls", '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new(args => \@args, valid_countries_file => 'data/valid_countries.txt');
is $obj->run, 0, 'bad spreadsheet failed';
is(
	read_file('t/data/validator_fail.txt'),
	read_file("$tmp/fail.txt"),
    'validation report correct for fail'
);

# validate bad spreadsheet
@args = ('-f', 't/data/Sample_manifest_for_154_Kp_assemblies.xls', '-r', "$tmp/fail2.txt", '-o', "$tmp/manifest_bad.xls.edit2.xls", '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new(args => \@args, valid_countries_file => 'data/valid_countries.txt');
is $obj->run, 0, 'bad spreadsheet failed';
is(
    read_file('t/data/validator_fail2.txt'),
    read_file("$tmp/fail2.txt"),
    'validation report correct for missing accession number'
);

remove_tree($tmp);
done_testing();