#!/usr/bin/env perl

BEGIN {unshift(@INC, './lib')}

BEGIN {
    use Test::Most;
    use Test::MockObject;

}

use Moose;
use Bio::ENA::DataSubmission::ConfigReader;
use File::Temp qw(tempfile);
use File::Path qw(remove_tree);

# General mocking
my $config = {
    'webin_user'    => 'user',
    'webin_pass'    => 'pass',
    'webin_cli_jar' => 't/bin/webin-cli-1.6.0.jar',
    'proxy'         => 'http://wwwcache.sanger.ac.uk:3128',
    'jvm'           => 'customjava',
};
my ($manifest_file, $manifest_filename) = tempfile(CLEANUP => 1);
my $temp_output_dir = File::Temp->newdir(CLEANUP => 1);
my $temp_output_dir_name = $temp_output_dir->dirname();
use constant A_CONFIG_FILE => 't/data/test_ena_data_submission.conf';

my %full_args = (
    config_file => A_CONFIG_FILE,
    spreadsheet => $manifest_filename,
    output_dir  => $temp_output_dir_name,
    context     => 'genome',
    test        => 0,
    validate    => 1,
    submit      => 1,
);


# Test the module can be used
{

    use_ok('Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli');
}

# Test CLI is build correctly using direct args
{

    can_build_cli_based_on_input(\%full_args);
}

# Test CLI is build correctly using command line arguments
{
    my $args = {
        args => [ '-f', $manifest_filename, '-o', $temp_output_dir_name, '--config_file', 't/data/test_ena_data_submission.conf' ],
    };
    can_build_cli_based_on_input($args);
}

# Test can suppress validation using command line parameters
{
    my $args = {
        args => [ '-f', $manifest_filename, '-o', $temp_output_dir_name, '--config_file', 't/data/test_ena_data_submission.conf', '--no_validate' ]
    };
    can_suppress_validation($args);
}

# Test can suppress submission using command line parameters
{
    my $args = {
        args => [ '-f', $manifest_filename, '-o', $temp_output_dir_name, '--config_file', 't/data/test_ena_data_submission.conf', '--no_submit' ]
    };
    can_suppress_submission($args);
}

# Test can override test using command line args
{
    my $args = {
        args => [ '-f', $manifest_filename, '-o', $temp_output_dir_name, '--config_file', 't/data/test_ena_data_submission.conf', '--test' ]
    };
    can_override_test($args);
}

# Test can change the context using command line args
{

    my $args = {
        args => [ '-f', $manifest_filename, '-o', $temp_output_dir_name, '--config_file', 't/data/test_ena_data_submission.conf', '-c', 'another context' ]
    };
    can_change_the_context($args);
}

#Test delegation of run method to the assembler
{
    my $container = Test::MockObject->new();
    $container->set_isa('Bio::ENA::DataSubmission::AnalysisSubmission');
    $container->set_true('run');
    my $construction_args = { %full_args };
    $construction_args->{container} = $container;
    my ($under_test) = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new(%$construction_args);

    $under_test->run();
    my ($name, $args) = $container->next_call();
    is($name, "run", "run was called");
    is_deeply($args, [ $container ], "run was run with correct arguments");
    is($container->next_call(), undef, "run was called only once");
}


sub can_build_cli_based_on_input {
    my ($args) = @_;

    my ($under_test) = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new(%$args);
    my $container = $under_test->container;
    is($container->config_file, A_CONFIG_FILE, 'config_file is populated correctly');
    is($container->spreadsheet, $manifest_filename, 'spreadsheet is populated correctly');
    is($container->reference_dir, $temp_output_dir_name, 'reference_dir is populated correctly');
    is($container->context, 'genome', 'context is populated correctly');
    is($container->test, 0, 'test is populated correctly');
    is($container->validate, 1, 'validate is populated correctly');
    is($container->submit, 1, 'submit is populated correctly');
}

sub can_suppress_submission {
    my ($args) = @_;

    my ($under_test) = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new(%$args);
    my $container = $under_test->container;
    is($container->config_file, A_CONFIG_FILE, 'config_file is populated correctly');
    is($container->spreadsheet, $manifest_filename, 'spreadsheet is populated correctly');
    is($container->reference_dir, $temp_output_dir_name, 'reference_dir is populated correctly');
    is($container->context, 'genome', 'context is populated correctly');
    is($container->test, 0, 'test is populated correctly');
    is($container->validate, 1, 'validate is populated correctly');
    is($container->submit, 0, 'submit is populated correctly');
}

sub can_suppress_validation {
    my ($args) = @_;

    my ($under_test) = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new(%$args);
    my $container = $under_test->container;
    is($container->config_file, A_CONFIG_FILE, 'config_file is populated correctly');
    is($container->spreadsheet, $manifest_filename, 'spreadsheet is populated correctly');
    is($container->reference_dir, $temp_output_dir_name, 'reference_dir is populated correctly');
    is($container->context, 'genome', 'context is populated correctly');
    is($container->test, 0, 'test is populated correctly');
    is($container->validate, 0, 'validate is populated correctly');
    is($container->submit, 1, 'submit is populated correctly');
}

sub can_change_the_context {
    my ($args) = @_;

    my ($under_test) = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new(%$args);
    my $container = $under_test->container;
    is($container->config_file, A_CONFIG_FILE, 'config_file is populated correctly');
    is($container->spreadsheet, $manifest_filename, 'spreadsheet is populated correctly');
    is($container->reference_dir, $temp_output_dir_name, 'reference_dir is populated correctly');
    is($container->context, 'another context', 'context is populated correctly');
    is($container->test, 0, 'test is populated correctly');
    is($container->validate, 1, 'validate is populated correctly');
    is($container->submit, 1, 'submit is populated correctly');
}
sub can_override_test {
    my ($args) = @_;


    my ($under_test) = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new(%$args);
    my $container = $under_test->container;
    is($container->config_file, A_CONFIG_FILE, 'config_file is populated correctly');
    is($container->spreadsheet, $manifest_filename, 'spreadsheet is populated correctly');
    is($container->reference_dir, $temp_output_dir_name, 'reference_dir is populated correctly');
    is($container->context, 'genome', 'context is populated correctly');
    is($container->test, 1, 'test is populated correctly');
    is($container->validate, 1, 'validate is populated correctly');
    is($container->submit, 1, 'submit is populated correctly');
}

sub test_mandatory_args {
    my ($input) = @_;
    my $args_with_missing_required_arg = { %full_args };
    delete $args_with_missing_required_arg->{$input};
    throws_ok {Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new(%$args_with_missing_required_arg)} 'Moose::Exception::AttributeIsRequired', "dies if mandatory arg $input is missing";
}

# Check mandatory arguments
{
    my (@mandatory_args) = ('output_dir', 'spreadsheet', 'validate', 'test', 'context', 'submit');

    foreach (@mandatory_args) {
        test_mandatory_args($_);
    }

}



remove_tree($temp_output_dir_name, $manifest_filename,);
done_testing();

no Moose;


