#!/usr/bin/env perl


BEGIN {
    use strict;
    use warnings;
    use Test::Most;
}


# Test the module can be used
{

    use_ok('Bio::ENA::DataSubmission::ConfigReader');
}

#Test can load a file
{

    my $expected = {
        'webin_user'                 => 'user',
        'webin_pass'                 => 'pass',
        'ena_base_path'              => 't/data/',
        'pubmed_url_base'            => 't/data/',
        'taxon_lookup_service'       => 't/data/',
        'output_root'                => 'ena_updates/',
        'auth_users'                 => [ 'root', 'pathpipe', 'maa', 'ap13', 'os7','pathdb', 'vagrant', 'travis'],
        'email_to'                   => 'ap13@sanger.ac.uk',
        'output_group'               => 'some_group_thats_changed_as_tests_are_run',
        'proxy'                      => 'http://wwwcache.sanger.ac.uk:3128',
        'embl_jar_path'              => 't/bin/embl-client.jar',
        'assembly_directories'       => [ '/velvet_assembly', '/spades_assembly', '/iva_assembly', '/pacbio_assembly' ],
        'annotation_directories'     => [ '/velvet_assembly/annotation', '/spades_assembly/annotation', '/iva_assembly/annotation', '/pacbio_assembly/annotation' ],
    };
    my ($under_test) = Bio::ENA::DataSubmission::ConfigReader->new(config_file => 't/data/test_ena_data_submission.conf');
    my $actual = $under_test->get_config();
    is_deeply($actual, $expected, 'read() returns the expected hash');
}


done_testing();

