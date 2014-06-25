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

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

use_ok('Bio::ENA::DataSubmission::CommandLine::CompareMetadata');

my ($obj, @args);

#----------------------#
# test illegal options #
#----------------------#

@args = ();
$obj = Bio::ENA::DataSubmission::CommandLine::CompareMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without arguments';

@args = ( '-o', 't/data/fakefile.txt');
$obj = Bio::ENA::DataSubmission::CommandLine::CompareMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

@args = ('-f', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::CompareMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid input file path';

@args = ('-f', 't/data/compare_manifest.xls', '-o', 'not/a/file');
$obj = Bio::ENA::DataSubmission::CommandLine::CompareMetadata->new( args => \@args );
throws_ok {$obj->run} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid output file path';


#--------------#
# test methods #
#--------------#

@args = ('-f', 't/data/compare_manifest.xls', '-o', "$tmp/comparison_report.xls");
$obj = Bio::ENA::DataSubmission::CommandLine::CompareMetadata->new( args => \@args );

# test parsing of XML
my %exp = (
	sample_accession => 'ERS001491',
	sample_alias     => '2007223-sc-2010-05-07-2811',
	tax_id           => '1496',
	scientific_name  => '[Clostridium] difficile',
	common_name      => 'Clostridium difficile',
	sample_title     => '[Clostridium] difficile',
	collection_date  => '2007',
	country          => 'USA: AZ',
	host             => 'Free living',
	isolation_source => 'Food',
	strain           => '2007223'
);
is_deeply $obj->_xml_data('ERS001491'), \%exp, 'XML parsed correctly';

# compare metadata
my %data1 = %exp;
my %data2 = %data1;
$data2['tax_id'] = '1111';
$data2['host'] = 'Human';
my @exp = ( 
	['ERS001491', '2007223', 'tax_id', '1111', '1496'],
	['ERS001491', '2007223', 'host', 'Human', 'Free living']
);
is_deeply \@exp, $obj->_compare_metadata(\%data1, \%data2), 'Correct fields identified as incongruous';

# test reporting
my @errors = @exp;
ok( $obj->_report, 'Report write ok' );
ok( -e "$tmp/comparison_report.xls", 'Report exists' );
is(
	read_file("$tmp/comparison_report.xls"),
	read_file('t/data/comparison_report.xls'),
	'Report correct'
);


remove_tree($tmp);
done_testing();

sub parse_csv{
	my $filename = shift;

	my @data;
	open(FH, $filename);
	while ( my $line = <FH> ){
		chomp $line;
		my @parts = split(",", $line);
		push(@data, \@parts);
	}
	return \@data;
}