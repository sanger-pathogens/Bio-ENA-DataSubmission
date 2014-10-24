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

use_ok('Bio::ENA::DataSubmission::CommandLine::CompareMetadata');

my ($obj, @args);

#----------------------#
# test illegal options #
#----------------------#

@args = ( '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::CompareMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';

@args = ( '-o', 't/data/fakefile.txt', '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::CompareMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

@args = ('-f', 'not/a/file', '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::CompareMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid input file path';

@args = ('-f', 't/data/compare_manifest.xls', '-o', 'not/a/file', '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::CompareMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::CannotWriteFile', 'dies with invalid output file path';


#--------------#
# test methods #
#--------------#

@args = ('-f', 't/data/compare_manifest.xls', '-o', "$tmp/comparison_report.xls", '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::CompareMetadata->new( args => \@args );

# compare metadata
my %data1 = (
	tax_id           => '1496',
	scientific_name  => '[Clostridium] difficile',
	common_name      => 'Clostridium difficile',
	sample_title     => '[Clostridium] difficile',
	collection_date  => '2007',
	country          => 'USA: AZ',
	specific_host    => 'Free living',
	isolation_source => 'Food',
	strain           => '2007223'
);
$data1{'sample_accession'} = "ERS001491";
$data1{'sanger_sample_name'} = "2007223";
my %data2 = %data1;
$data2{'tax_id'} = '1111';
$data2{'specific_host'} = 'Human';

my @exp = ( 
	['ERS001491', '2007223', 'specific_host', 'Free living', 'Human'],
	['ERS001491', '2007223', 'tax_id', '1496', '1111']
);
my @got = $obj->_compare_metadata(\%data1, \%data2);
is_deeply \@exp, \@got, 'Correct fields identified as incongruous';

# test reporting
my @errors = @exp;
ok( $obj->_report(\@errors), 'Report write ok' );
ok( -e "$tmp/comparison_report.xls", 'Report exists' );
is_deeply( diff_xls('t/data/comparison_report.xls', "$tmp/comparison_report.xls"), 'Report correct' );


# test reporting without any errors
@args = ('-f', 't/data/compare_manifest.xls', '-o', "$tmp/comparison_report2.xls", '-c', 't/data/test_ena_data_submission.conf');
$obj = Bio::ENA::DataSubmission::CommandLine::CompareMetadata->new( args => \@args );

my @no_errors;
ok( $obj->_report(\@no_errors), 'Report write ok' );
ok( -e "$tmp/comparison_report2.xls", 'Report exists' );
is_deeply( diff_xls('t/data/comparison_report2.xls', "$tmp/comparison_report2.xls"), 'Report correct' );

remove_tree($tmp);
done_testing();

sub diff_xls {
	my ($x1, $x2) = @_;
	my $x1_data = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $x1 )->parse;
	my $x2_data = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $x2 )->parse;
	return ( $x1_data, $x2_data );
}