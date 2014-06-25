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

use_ok('Bio::ENA::DataSubmission::XML');

my ($obj, @args);

#-----------------#
# test validation #
#-----------------#

# sanity checks

$obj = Bio::ENA::DataSubmission::XML->new();
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_good.xml');
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without XSD input';

$obj = Bio::ENA::DataSubmission::XML->new( xsd => 'data/study.xsd');
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_good.xml', xsd => 'not/a/file.xsd' );
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid XSD path';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 'not/a/file.xml', xsd => 'data/study.xsd' );
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid XML path';

# validation checks

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_bad.xml', xsd => 'data/study.xsd' );
is $obj->validate, 0, 'Bad XML failed';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_good.xml', xsd => 'data/study.xsd' );
is $obj->validate, 1, 'Good XML passed';

#-----------------#
# test XML update #
#-----------------#

# sanity checks

$obj = Bio::ENA::DataSubmission::XML->new();
throws_ok {$obj->update} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_good.xml');
throws_ok {$obj->update} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without update data input';

$obj = Bio::ENA::DataSubmission::XML->new( data => { test => 1 } );
throws_ok {$obj->update} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 'not/a/file.xml', data => { test => 1 } );
throws_ok {$obj->update} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid XML path';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/update.xml', data => { test => 1 } );
throws_ok {$obj->update} 'Bio::ENA::DataSubmission::Exception::TagNotFound', 'dies with invalid data keys';

# update checks

my %data = (
	country => "UK: Cambridgeshire",
	strain => "s1234"
);
$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/update.xml', data => \%data, outfile => "$tmp/updated.xml" );
ok( $obj->update, 'Update successful' );
ok( -e "$tmp/updated.xml", 'Updated XML exists' );
is(
	read_file('t/data/updated.xml'),
	read_file("$tmp/updated.xml"),
	'Updated XML correct'
);

#-----------------#
# test XML parser #
#-----------------#

# sanity checks

$obj = Bio::ENA::DataSubmission::XML->new();
throws_ok {$obj->parse} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 'not/a/file.xml' );
throws_ok {$obj->parse} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid XML path';

# parser checks

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/update.xml' );
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
is_deeply $obj->parse, \%exp, 'XML parsed successfully';

remove_tree($tmp);
done_testing();