#!/usr/bin/env perl

BEGIN {unshift(@INC, './lib')}

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
        'webin_host'                 => 'example.com',
        'webin_cli_jar'              => 't/bin/webin-cli-1.6.0.jar',
        'ena_login_string'           => 'xxxxx',
        'ena_dropbox_submission_url' => 'https://example.com/',
        'ena_base_path'              => 't/data/',
        'pubmed_url_base'            => 't/data/',
        'taxon_lookup_service'       => 't/data/',
        'data_root'                  => 'data',
        'output_root'                => 'ena_updates/',
        'auth_users'                 => [ 'root', 'pathpipe', 'maa', 'ap13', 'os7','pathdb', 'vagrant', 'travis'],
        'email_to'                   => 'ap13@sanger.ac.uk',
        'schema'                     => 'ERC000028',
        'output_group'               => 'some_group_thats_changed_as_tests_are_run',
        'proxy'                      => 'http://wwwcache.sanger.ac.uk:3128',
        'embl_jar_path'              => 't/bin/embl-client.jar',
        'assembly_directories'       => [ '/velvet_assembly', '/spades_assembly', '/iva_assembly', '/pacbio_assembly' ],
        'annotation_directories'     => [ '/velvet_assembly/annotation', '/spades_assembly/annotation', '/iva_assembly/annotation', '/pacbio_assembly/annotation' ],
        'jvm'                        => 'customjava',
    };
    my ($under_test) = Bio::ENA::DataSubmission::ConfigReader->new(config_file => 't/data/test_ena_data_submission.conf');
    my $actual = $under_test->get_config();
    is_deeply($actual, $expected, 'read() returns the expected hash');
}


done_testing();

