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
use Data::Dumper;


my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::CommandLine::ValidateManifest');

my ($obj, @args);

#----------------------#
# test illegal options #
#----------------------#

@args = ();
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';

@args = ('--edit', '-r', 't/data/fakefile.txt');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

@args = ('-f', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid input file path';

@args = ('-f', 't/data/manifest_bad.xls', '-r', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid output file path';


#--------------------------#
# Check validation reports #
#--------------------------#

# validate good spreadsheet
@args = ('-f', 't/data/manifest_good.xls', '-r', "$tmp/pass.txt");
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new( args => \@args );
is $obj->run, 1, 'perfect spreadsheet passed';
is(
	read_file('t/data/validator_pass.txt'),
	read_file("$tmp/pass.txt"),
	'validation report correct'
);

# validate bad spreadsheet
@args = ('-f', 't/data/manifest_bad.xls', '-r', "$tmp/fail.txt");
$obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new( args => \@args );
is $obj->run, 0, 'bad spreadsheet failed';
is(
	read_file('t/data/validator_fail.txt'),
	read_file("$tmp/fail.txt"),
	'validation report correct'
);

# # validate and edit bad spreadsheet
# @args = ('-f', 't/data/manifest_bad.xls', '-r', "$tmp/pass.txt", '--edit', '-o', "$tmp/edited_manifest.xls");
# $obj = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new( args => \@args );
# is $obj->run, 0, 'bad spreadsheet failed';
# is(
# 	read_file('t/data/validator_fail.txt'),
# 	read_file("$tmp/fail.txt"),
# 	'validation report correct'
# );
# is(
# 	read_file('t/data/edited_manifest.xls'),
# 	read_file("$tmp/edited_manifest.xls"),
# 	'manifest edited correctly'
# );

remove_tree($tmp);
done_testing();