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

use_ok('Bio::ENA::DataSubmission::CommandLine::ValidateEMBL');

my ($obj, @args);

#--------------------------#
# Check validation         #
#--------------------------#


# validate bad embl file
@args = ('t/data/expected_single_feature.embl');
ok($obj = Bio::ENA::DataSubmission::CommandLine::ValidateEMBL->new(args => \@args, jar_path => 'data/embl-client.jar'), 'initialise valid obj');
is $obj->run, 1, 'Invalid EMBL file';
ok(-e 'VAL_SUMMARY.txt', 'File created - VAL_SUMMARY');
ok(-e 'VAL_REPORTS.txt', 'File created - VAL_REPORTS');
ok(-e 'VAL_INFO.txt',    'File created - VAL_INFO');
ok(-e 'VAL_FIXES.txt',   'File created - VAL_FIXES');
ok(-e 'VAL_ERROR.txt',   'File created - VAL_ERROR');

unlink('VAL_SUMMARY.txt');
unlink('VAL_REPORTS.txt');
unlink('VAL_INFO.txt');
unlink('VAL_FIXES.txt');
unlink('VAL_ERROR.txt');

remove_tree($tmp);
done_testing();
