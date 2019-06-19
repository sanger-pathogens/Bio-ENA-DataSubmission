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

use_ok('Bio::ENA::DataSubmission::XML');

my ($obj);

#-----------------#
# test validation #
#-----------------#

# sanity checks

$obj = Bio::ENA::DataSubmission::XML->new(dataroot => 'data');
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_good.xml',dataroot => 'data');
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without XSD input';

$obj = Bio::ENA::DataSubmission::XML->new( xsd => 'data/sample.xsd',dataroot => 'data');
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_good.xml', xsd => 'not/a/file.xsd' ,dataroot => 'data');
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid XSD path';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 'not/a/file.xml', xsd => 'data/sample.xsd' ,dataroot => 'data');
throws_ok {$obj->validate} 'Bio::ENA::DataSubmission::Exception::FileNotFound', 'dies with invalid XML path';

# validation checks

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_bad.xml', xsd => 'data/sample.xsd' ,dataroot => 'data');
is $obj->validate, 0, 'Bad XML failed';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/validation_good.xml', xsd => 'data/sample.xsd' ,dataroot => 'data');
is $obj->validate, 1, 'Good XML passed';

#-----------------#
# test XML update #
#-----------------#

# sanity checks

ok($obj = Bio::ENA::DataSubmission::XML->new(dataroot => 'data'), 'initialise xml obj');
throws_ok {$obj->update_sample} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without sample input';

my %sample_sample;
throws_ok {$obj->update_sample( \%sample_sample )} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without sample input';


# update checks
# Checked via UpdateMetadata.t

#-----------------#
# test XML parser #
#-----------------#

# sanity checks

$obj = Bio::ENA::DataSubmission::XML->new(dataroot => 'data');
throws_ok {$obj->parse_from_file} 'Bio::ENA::DataSubmission::Exception::InvalidInput', 'dies without file input';

$obj = Bio::ENA::DataSubmission::XML->new( xml => 'not/a/file.xml',dataroot => 'data' );
throws_ok {$obj->parse_from_file} 'Bio::ENA::DataSubmission::Exception::CannotReadFile', 'dies with invalid XML path';

# file parser checks

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/update.xml',dataroot => 'data' );
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

$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/update.xml', ena_base_path => 't/data/',dataroot => 'data' );
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

# update_sample to check does it remove 'Strain'
$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/update.xml', ena_base_path => 't/data/',dataroot => 'data' );
ok( my $updated_xml = $obj->update_sample({'sample_accession' => 'ERS486637', 'anothertag' => 'ABC', 'strain' => 'lowercase strain'}), 'Remove strain');
validate($updated_xml->{SAMPLE_ATTRIBUTES}, [{'SAMPLE_ATTRIBUTE' => [
    {
        'VALUE' => [{}],
        'TAG' => ['Sample Description']
    },
    {
        'VALUE' => ['lowercase strain'],
        'TAG' => ['strain']
    },
    {
        'VALUE' => ['ABC'],
        'TAG' => ['anothertag']
    }]
}], 'Check Strain has been removed but lowercase strain kept');


sub sort_hash {
    my $to_sort = shift;
    for my $hashref (@$to_sort) {
        my $array_to_sort = $hashref->{SAMPLE_ATTRIBUTE};
        my @sorted = sort @$array_to_sort;
        $hashref->{SAMPLE_ATTRIBUTE} = \@sorted;
    }
}

# update_sample to check does it remove EXTERNAL_ID and ENA-BASE-COUNT and ENA-SPOT-COUNT
$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/update.xml', ena_base_path => 't/data/',dataroot => 'data' );
ok( $updated_xml = $obj->update_sample({'sample_accession' => 'ERS023435', 'anothertag' => 'ABC', 'strain' => 'lowercase strain'}), 'Remove injected values');

is_deeply($updated_xml->{IDENTIFIERS},
[
          {
            'SUBMITTER_ID' => [
                              {
                                'namespace' => 'SC',
                                'content' => '7494-sc-2011-02-15-1079060'
                              }
                            ],
            'PRIMARY_ID' => [
                            'ERS023435'
                          ]
          }
        ]
        , 'Check external id has been removed');
validate($updated_xml->{SAMPLE_ATTRIBUTES},
[
          {
            'SAMPLE_ATTRIBUTE' => [
                                    {
                                      'VALUE' => [
                                                 {}
                                               ],
                                      'TAG' => [
                                                 'Sample Description'
                                               ]
                                    },
                                    {
                                      'VALUE' => [
                                                 '2003-07-01'
                                               ],
                                      'TAG' => [
                                                 'collection_date'
                                               ]
                                    },
                                    {
                                      'VALUE' => [
                                                 'human'
                                               ],
                                      'TAG' => [
                                                 'specific_host'
                                               ]
                                    },
                                    {
                                      'VALUE' => [
                                                 'sputum'
                                               ],
                                      'TAG' => [
                                                 'isolation_source'
                                               ]
                                    },
                                    {
                                      'VALUE' => [
                                                   'lowercase strain'
                                                 ],
                                      'TAG' => [
                                                 'strain'
                                               ]
                                    },
                                    {
                                      'VALUE' => [
                                                   'ABC'
                                                 ],
                                      'TAG' => [
                                                 'anothertag'
                                               ]
                                    }
                                  ]
          }
        ]
        , 'Check ena spot and ena base count have been removed');



# update_sample to check does it remove duplicated sample attributes inserted by ENA
$obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/update.xml', ena_base_path => 't/data/',dataroot => 'data' );
ok( $updated_xml = $obj->update_sample({'sample_accession' => 'ERS092760','strain' => 'lowercase strain'}), 'Remove injected values');

validate($updated_xml->{SAMPLE_ATTRIBUTES},
[
          {
            'SAMPLE_ATTRIBUTE' => [
                                    {
                                      'VALUE' => [
                                                 'ST8'
                                               ],
                                      'TAG' => [
                                                 'serovar'
                                               ]
                                    },
                                    {
                                      'VALUE' => [
                                                   'lowercase strain'
                                                 ],
                                      'TAG' => [
                                                 'strain'
                                               ]
                                    },
                                    {
                                      'VALUE' => [
                                                 '1350789'
                                               ],
                                      'TAG' => [
                                                 'anonymized_name'
                                               ]
                                    }
                                  ]
          }
        ]
        , 'Check duplicated inserted tags have been removed');

for my $country (('not available: not collected','not available: restricted access','not available: to be reported later','not applicable','obscured','temporarily obscured'))
{

  # update sample should remove countries that are not available
  $obj = Bio::ENA::DataSubmission::XML->new( xml => 't/data/update.xml', ena_base_path => 't/data/',dataroot => 'data' );
  ok( $updated_xml = $obj->update_sample({'sample_accession' => 'ERS092760','country' =>  $country}), 'Remove country '. $country);
    validate($updated_xml->{SAMPLE_ATTRIBUTES},
  [
            {
              'SAMPLE_ATTRIBUTE' => [
                                      {
                                        'VALUE' => [
                                                   'ST8'
                                                 ],
                                        'TAG' => [
                                                   'serovar'
                                                 ]
                                      },
									  {
                                      'VALUE' => [
                                                 'USFL003'
                                               ],
                                      'TAG' => [
                                                 'strain'
                                               ]
                                    },
                                      {
                                        'VALUE' => [
                                                   '1350789'
                                                 ],
                                        'TAG' => [
                                                   'anonymized_name'
                                                 ]
                                      }
                                    ]
            }
          ]
          , 'check not available country removed');
}


sub validate {
    my($expected, $actual, $description) = @_;
    _sort_hash($expected);
    _sort_hash($actual);

    is_deeply($expected, $actual, $description);

}

sub _sort_hash {
    my $to_sort = shift;
    for my $hashref (@$to_sort) {
        my $array_to_sort = $hashref->{SAMPLE_ATTRIBUTE};
        my @sorted = sort {$a->{TAG}[0] cmp $b->{TAG}[0]} @$array_to_sort;
        $hashref->{SAMPLE_ATTRIBUTE} = \@sorted;
    }
}




remove_tree($tmp);
done_testing();