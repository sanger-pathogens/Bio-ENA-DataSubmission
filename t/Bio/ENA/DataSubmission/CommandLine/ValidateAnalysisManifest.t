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
use Cwd;
use File::Temp;

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest');

my ($obj, @args);

#----------------------#
# test illegal options #
#----------------------#

@args = ();
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';

@args = ('--edit', '-r', 't/data/fakefile.txt');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

@args = ('-f', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid input file path';

@args = ('-f', 't/data/manifest_bad.xls', '-r', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid output file path';


#--------------------------#
# Check validation reports #
#--------------------------#

# validate good spreadsheet
@args = ('-f', 't/data/analysis_manifest_good.xls', '-r', "$tmp/pass.txt");
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest->new( args => \@args );
is $obj->run, 1, 'perfect spreadsheet passed';
is(
	read_file('t/data/analysis_validator_pass.txt'),
	read_file("$tmp/pass.txt"),
	'validation report correct'
);

# validate bad spreadsheet
@args = ('-f', 't/data/analysis_manifest_bad.xls', '-r', "$tmp/fail.txt");
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest->new( args => \@args );
is $obj->run, 0, 'bad spreadsheet failed';
is(
	read_file('t/data/analysis_validator_fail.txt'),
	read_file("$tmp/fail.txt"),
	'validation report correct'
);

remove_tree($tmp);
done_testing();