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

$obj = Bio::ENA::DataSubmission::XML->new( xsd => 'data/sample.xsd');
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_good.xml', xsd => 'not/a/file.xsd' );
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid XSD path';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 'not/a/file.xml', xsd => 'data/sample.xsd' );
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid XML path';

# validation checks

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_bad.xml', xsd => 'data/sample.xsd' );
is $obj->validate, 0, 'Bad XML failed';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_good.xml', xsd => 'data/sample.xsd' );
is $obj->validate, 1, 'Good XML passed';

#-----------------#
# test XML update #
#-----------------#

# sanity checks

ok($obj = Bio::ENA::DataSubmission::XML->new(), 'initialise xml obj');
throws_ok {$obj->update_sample} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without sample input';

my %sample_sample;
throws_ok {$obj->update_sample( \%sample_sample )} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without sample input';


# update checks
# Checked via UpdateMetadata.t

#-----------------#
# test XML parser #
#-----------------#

# sanity checks

$obj = Bio::ENA::DataSubmission::XML->new();
throws_ok {$obj->parse_from_file} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 'not/a/file.xml' );
throws_ok {$obj->parse_from_file} 'Bio::ENA::DataSubmission::Exception::CannotReadFile', 'dies with invalid XML path';

# file parser checks

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/update.xml' );
my $exp = 
{
          'SUBMISSION' => [
                          {
                            'ACTIONS' => [
                                         {
                                           'ACTION' => [
                                                       {
                                                         'MODIFY' => [
                                                                     {
                                                                       'source' => 'samples.xml',
                                                                       'schema' => 'sample'
                                                                     }
                                                                   ]
                                                       }
                                                     ]
                                         }
                                       ],
                            'alias' => 'ReleaseSubmissionUpdate'
                          }
                        ]
        };
is_deeply $obj->parse_from_file, $exp, 'XML parsed successfully';

# URL parser checks

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/update.xml', _ena_base_path => 't/data/' );
# Metadata parsing test
my %exp = (
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
is_deeply $obj->parse_xml_metadata('ERS001491'), \%exp, 'XML parsed correctly';

remove_tree($tmp);
done_testing();