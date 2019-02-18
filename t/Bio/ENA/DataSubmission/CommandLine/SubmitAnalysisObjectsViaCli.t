#!/usr/bin/env perl

#TODO find a way to compare objects
BEGIN {unshift(@INC, './lib')}

BEGIN {
    use Test::Most;
    use Test::Mock::Class ':all';

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
};
mock_class 'Bio::ENA::DataSubmission::ConfigReader' => 'Bio::ENA::DataSubmission::ConfigReader::Mock';
my $mock_config_reader = Bio::ENA::DataSubmission::ConfigReader::Mock->new;
$mock_config_reader->mock_return(get_config => $config, args => []);
my ($manifest_file, $manifest_filename) = tempfile(CLEANUP => 1);
my $temp_input_dir = File::Temp->newdir(CLEANUP => 1 );
my $temp_input_dir_name = $temp_input_dir->dirname();
my $temp_output_dir = File::Temp->newdir(CLEANUP => 1 );
my $temp_output_dir_name = $temp_output_dir->dirname();

my %full_args = (
    config_reader => $mock_config_reader,
    manifest      => $manifest_filename,
    input_dir     => $temp_input_dir_name,
    output_dir    => $temp_output_dir_name,
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
        args => [ '-f', $manifest_filename, '-i', $temp_input_dir_name, '-o', $temp_output_dir_name, '-c', 't/data/test_ena_data_submission.conf' ],
    };
    can_build_cli_based_on_input($args);
}
# Test can suppress validation using command line parameters
{
    my $args = {
        args => [ '-f', $manifest_filename, '-i', $temp_input_dir_name, '-o', $temp_output_dir_name, '-c', 't/data/test_ena_data_submission.conf', '--no_validate' ]
    };
    can_suppress_validation($args);
}

# Test can suppress validation using direct arguments
{
    my $args = { %full_args };
    $args->{validate} = 0;
    can_suppress_validation($args);
}

# Test can override test using command line args
{
    my $args = {
        args => [ '-f', $manifest_filename, '-i', $temp_input_dir_name, '-o', $temp_output_dir_name, '-c', 't/data/test_ena_data_submission.conf', '--test' ]
    };
    can_override_test($args);
}

# Test can override test uing direct input
{
    my $args = { %full_args };
    $args->{test} = 1;
    can_override_test($args);
}

# Test can change the context using command line args
{

    my $args = {
        args => ['-f', $manifest_filename, '-i', $temp_input_dir_name, '-o', $temp_output_dir_name, '-c', 't/data/test_ena_data_submission.conf', '-t', 'another context']
    };
    can_change_the_context($args);
}

# Test can change the context using direct input
{

    my $args = { %full_args };
    $args->{context} = 'another context';
    can_change_the_context($args);

}

sub can_build_cli_based_on_input {
    my ($args) = @_;

    my ($under_test) = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new(%$args);
    my $cli = $under_test->{_webincli};
    is($cli->http_proxy_host, 'http://wwwcache.sanger.ac.uk', 'http_proxy_host is populated correctly');
    is($cli->http_proxy_port, 3128, 'http_proxy_port is populated correctly');
    is($cli->username, 'user', 'username is populated correctly');
    is($cli->password, 'pass', 'password is populated correctly');
    is($cli->jar_path, 't/bin/webin-cli-1.6.0.jar', 'jar_path is populated correctly');
    is($cli->manifest, $manifest_filename, 'manifest is populated correctly');
    is($cli->input_dir, $temp_input_dir_name, 'manifest is populated correctly');
    is($cli->output_dir, $temp_output_dir_name, 'manifest is populated correctly');
    is($cli->context, 'genome', 'context is populated correctly');
    is($cli->test, 0, 'test is populated correctly');
    is($cli->validate, 1, 'validate is populated correctly');
    is($cli->submit, 1, 'submit is populated correctly');
}
sub can_suppress_validation {
    my ($args) = @_;

    my ($under_test) = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new(%$args);
    my $cli = $under_test->{_webincli};
    is($cli->http_proxy_host, 'http://wwwcache.sanger.ac.uk', 'http_proxy_host is populated correctly');
    is($cli->http_proxy_port, 3128, 'http_proxy_port is populated correctly');
    is($cli->username, 'user', 'username is populated correctly');
    is($cli->password, 'pass', 'password is populated correctly');
    is($cli->jar_path, 't/bin/webin-cli-1.6.0.jar', 'jar_path is populated correctly');
    is($cli->manifest, $manifest_filename, 'manifest is populated correctly');
    is($cli->input_dir, $temp_input_dir_name, 'manifest is populated correctly');
    is($cli->output_dir, $temp_output_dir_name, 'manifest is populated correctly');
    is($cli->context, 'genome', 'context is populated correctly');
    is($cli->test, 0, 'test is populated correctly');
    is($cli->validate, 0, 'validate is populated correctly');
    is($cli->submit, 1, 'submit is populated correctly');
}
sub can_change_the_context {
    my ($args) = @_;

    my ($under_test) = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new(%$args);
    my $cli = $under_test->{_webincli};
    is($cli->http_proxy_host, 'http://wwwcache.sanger.ac.uk', 'http_proxy_host is populated correctly');
    is($cli->http_proxy_port, 3128, 'http_proxy_port is populated correctly');
    is($cli->username, 'user', 'username is populated correctly');
    is($cli->password, 'pass', 'password is populated correctly');
    is($cli->jar_path, 't/bin/webin-cli-1.6.0.jar', 'jar_path is populated correctly');
    is($cli->manifest, $manifest_filename, 'manifest is populated correctly');
    is($cli->input_dir, $temp_input_dir_name, 'manifest is populated correctly');
    is($cli->output_dir, $temp_output_dir_name, 'manifest is populated correctly');
    is($cli->context, 'another context', 'context is populated correctly');
    is($cli->test, 0, 'test is populated correctly');
    is($cli->validate, 1, 'validate is populated correctly');
    is($cli->submit, 1, 'submit is populated correctly');

}
sub can_override_test {
    my ($args) = @_;

    my ($under_test) = Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new(%$args);
    my $cli = $under_test->{_webincli};
    is($cli->http_proxy_host, 'http://wwwcache.sanger.ac.uk', 'http_proxy_host is populated correctly');
    is($cli->http_proxy_port, 3128, 'http_proxy_port is populated correctly');
    is($cli->username, 'user', 'username is populated correctly');
    is($cli->password, 'pass', 'password is populated correctly');
    is($cli->jar_path, 't/bin/webin-cli-1.6.0.jar', 'jar_path is populated correctly');
    is($cli->manifest, $manifest_filename, 'manifest is populated correctly');
    is($cli->input_dir, $temp_input_dir_name, 'manifest is populated correctly');
    is($cli->output_dir, $temp_output_dir_name, 'manifest is populated correctly');
    is($cli->context, 'genome', 'context is populated correctly');
    is($cli->test, 1, 'test is populated correctly');
    is($cli->validate, 1, 'validate is populated correctly');
    is($cli->submit, 1, 'submit is populated correctly');

}
sub test_mandatory_args {
    my ($input) = @_;
    my $args_with_missing_required_arg = { %full_args };
    delete $args_with_missing_required_arg->{$input};
    throws_ok {Bio::ENA::DataSubmission::WEBINCli->new(%$args_with_missing_required_arg)} 'Moose::Exception::AttributeIsRequired', "dies if mandatory arg $input is missing";
}

# Check mandatory arguments
{
    my (@mandatory_args) = ('input_dir', 'output_dir', 'manifest');

    foreach (@mandatory_args) {
        test_mandatory_args($_);
    }

}



remove_tree($temp_input_dir_name, $temp_output_dir_name, $manifest_filename, );
done_testing();

no Moose;


