#!/usr/bin/env perl

BEGIN {
    use strict;
    use warnings;
    use Test::Most;
    use Test::MockObject;

}

use File::Temp;
use File::Path qw(remove_tree);

my $temp_reference_dir = File::Temp->newdir(CLEANUP => 1);
my $temp_reference_dir_name = $temp_reference_dir->dirname();

# Test the module can be used
{

    use_ok('Bio::ENA::DataSubmission::AnalysisSubmission');
}

#Test construction
{
    my $expected_config = {
        'webin_user'                 => 'user',
        'webin_pass'                 => 'pass',
        'ena_base_path'              => 't/data/',
        'pubmed_url_base'            => 't/data/',
        'taxon_lookup_service'       => 't/data/',
        'output_root'                => 'ena_updates/',
        'auth_users'                 => [ 'root', 'pathpipe', 'maa', 'ap13', 'os7', 'pathdb', 'vagrant', 'travis' ],
        'email_to'                   => 'ap13@sanger.ac.uk',
        'output_group'               => 'some_group_thats_changed_as_tests_are_run',
        'proxy'                      => 'http://wwwcache.sanger.ac.uk:3128',
        'embl_jar_path'              => 't/bin/embl-client.jar',
        'assembly_directories'       => [ '/velvet_assembly', '/spades_assembly', '/iva_assembly', '/pacbio_assembly' ],
        'annotation_directories'     => [ '/velvet_assembly/annotation', '/spades_assembly/annotation', '/iva_assembly/annotation', '/pacbio_assembly/annotation' ],
    };

    my $under_test = Bio::ENA::DataSubmission::AnalysisSubmission->new(
        config_file   => 't/data/test_ena_data_submission.conf',
        spreadsheet   => 't/data/exp_analysis_manifest.xls',
        reference_dir => $temp_reference_dir_name,
        current_user  => 'current_user',
        timestamp     => 'timestamp',
        validate      => 1,
        test          => 1,
        context       => 1,
        submit        => 1,
        jar_path      => 'some_path_to_jar',
    );
    is_deeply($under_test->config, $expected_config, "Config");
    is_deeply($under_test->proxy, [ "wwwcache.sanger.ac.uk", "3128" ], "Proxy");
    is_deeply($under_test->manifest_spreadsheet, [ {
        name               => "10660_2#13",
        locus_tag          => "SAMEA1968765",
        original_locus_tag => undef,
        coverage           => 52,
        partial            => 'FALSE',
        program            => 'velvet',
        platform           => 'SLX',
        minimum_gap        => 0,
        analysis_center    => 'SC',
        analysis_date      => 'current_date',
        release_date       => 'current_date',
        pubmed_id          => 'im_a_paper',
        tax_id             => '36809',
        common_name        => 'Mycobacterium abscessus',
        file_type          => 'scaffold_fasta',
        title              => 'Assembly of Mycobacterium abscessus',
        description        => 'Assembly of Mycobacterium abscessus',
        file               => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/abscessus/TRACKING/2047/2047STDY5552273/SLX/8020157/10660_2#13/velvet_assembly/contigs.fa',
        study              => 'PRJEB2779',
        original_study     => 'ERP001039',
        original_sample    => 'ERS311560',
        sample             => 'SAMEA1968765',
        run                => 'ERR363472',
    }, {
        name               => "10665_2#81",
        locus_tag          => "SAMEA2156862",
        original_locus_tag => undef,
        coverage           => 54,
        partial            => 'FALSE',
        program            => 'velvet',
        platform           => 'SLX',
        minimum_gap        => 0,
        analysis_center    => 'SC',
        analysis_date      => 'current_date',
        release_date       => 'current_date',
        pubmed_id          => 'im_a_paper',
        tax_id             => '36809',
        common_name        => 'Mycobacterium abscessus',
        file_type          => 'scaffold_fasta',
        title              => 'Assembly of Mycobacterium abscessus',
        description        => 'Assembly of Mycobacterium abscessus',
        file               => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/abscessus/TRACKING/2047/2047STDY5552104/SLX/7939790/10665_2#81/velvet_assembly/contigs.fa',
        study              => 'PRJEB2779',
        original_study     => 'ERP001039',
        original_sample    => 'ERS311393',
        sample             => 'SAMEA2156862',
        run                => 'ERR369155',
    }, {
        name               => "10665_2#90",
        locus_tag          => "SAMEA2144703",
        original_locus_tag => undef,
        coverage           => 81,
        partial            => 'FALSE',
        program            => 'velvet',
        platform           => 'SLX',
        minimum_gap        => 0,
        analysis_center    => 'SC',
        analysis_date      => 'current_date',
        release_date       => 'current_date',
        pubmed_id          => 'im_a_paper',
        tax_id             => '36809',
        common_name        => 'Mycobacterium abscessus',
        file_type          => 'scaffold_fasta',
        title              => 'Assembly of Mycobacterium abscessus',
        description        => 'Assembly of Mycobacterium abscessus',
        file               => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/abscessus/TRACKING/2047/2047STDY5552201/SLX/7939803/10665_2#90/velvet_assembly/contigs.fa',
        study              => 'PRJEB2779',
        sample             => 'SAMEA2144703',
        original_study     => 'ERP001039',
        original_sample    => 'ERS311489',
        run                => 'ERR369164',
    } ], "Manifest spreadsheet content");

    is($under_test->input_dir, "$temp_reference_dir_name/current_user_timestamp/input");
    is($under_test->output_dir, "$temp_reference_dir_name/current_user_timestamp/output");

    isa_ok($under_test->accession_converter, 'Bio::ENA::DataSubmission::AccessionConverter', "accession converter type");
    is($under_test->accession_converter->ena_base_path, 't/data/', "accession converter ena base path");

    isa_ok($under_test->spreadsheet_converter, 'Bio::ENA::DataSubmission::SpreadsheetEnricher', "spreadsheet accession converter type");
    is($under_test->spreadsheet_converter->converter, $under_test->accession_converter, "spreadsheet accession converter accession converter");

    isa_ok($under_test->gff_converter, 'Bio::ENA::DataSubmission::GffConverter');
    isa_ok($under_test->analysis_submission_coordinator, 'Bio::ENA::DataSubmission::AnalysisSubmissionCoordinator', "Analysis submission coordinator type");
    is($under_test->analysis_submission_coordinator->data_generator, $under_test->data_generator, "Coordinator data generator");
    is($under_test->analysis_submission_coordinator->submitter, $under_test->submitter, "Coordinator submitter");

    isa_ok($under_test->data_generator, 'Bio::ENA::DataSubmission::AnalysisSubmissionPreparation', "Data generator type");
    is($under_test->data_generator->manifest_spreadsheet, $under_test->manifest_spreadsheet, "Data generator manifest spreadsheet");
    is($under_test->data_generator->output_dir, $under_test->input_dir, "Data generator input dir");
    is($under_test->data_generator->gff_converter, $under_test->gff_converter, "Data generator gff converter");

    isa_ok($under_test->submitter, 'Bio::ENA::DataSubmission::AnalysisSubmissionExecution', "Submitter type");
    is($under_test->submitter->username, 'user', "Submitter username");
    is($under_test->submitter->password, 'pass', "Submitter password");
    is($under_test->submitter->jar_path, 'some_path_to_jar', "Submitter jar_path");
    is($under_test->submitter->jvm, 'java', "Submitter jvm");
    is($under_test->submitter->http_proxy_host, 'wwwcache.sanger.ac.uk', "Submitter http_proxy_host");
    is($under_test->submitter->http_proxy_port, '3128', "Submitter http_proxy_port");
    is($under_test->submitter->submit, '1', "Submitter submit");
    is($under_test->submitter->context, '1', "Submitter context");
    is($under_test->submitter->input_dir, "$temp_reference_dir_name/current_user_timestamp/input", "Submitter input_dir");
    is($under_test->submitter->output_dir, "$temp_reference_dir_name/current_user_timestamp/output", "Submitter output_dir");
    is($under_test->submitter->validate, '1', "Submitter validate");
    is($under_test->submitter->test, '1', "Submitter test");
}

#Test delegation of run method to the coordinator
{
    my $coordinator = Test::MockObject->new();
    $coordinator->set_isa('Bio::ENA::DataSubmission::AnalysisSubmissionCoordinator');
    $coordinator->set_true('run');

    my $under_test = Bio::ENA::DataSubmission::AnalysisSubmission->new(
        config_file                     => 't/data/test_ena_data_submission.conf',
        spreadsheet                     => 't/data/exp_analysis_manifest.xls',
        reference_dir                   => $temp_reference_dir_name,
        current_user                    => 'current_user',
        timestamp                       => 'timestamp',
        validate                        => 1,
        test                            => 1,
        context                         => 1,
        submit                          => 1,
        analysis_submission_coordinator => $coordinator,
    );
    $under_test->run();
    my ($name, $args) = $coordinator->next_call();
    is($name, "run", "run was called");
    is_deeply($args, [ $coordinator ], "run was run with correct arguments");
    is($coordinator->next_call(), undef, "run was called only once");
}

remove_tree($temp_reference_dir_name);

done_testing();
