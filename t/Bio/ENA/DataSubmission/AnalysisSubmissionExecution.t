#!/usr/bin/env perl
BEGIN {unshift(@INC, './lib')}

BEGIN {
    use strict;
    use warnings;
    use Test::Most;
    use Test::Output;
    use Test::Exception;
    use Test::MockObject;
}


use File::Temp;
use File::Temp qw(tempfile tempdir);
use File::Path qw(remove_tree);

my $temp_input_dir = File::Temp->newdir(CLEANUP => 1);
my $temp_input_dir_name = $temp_input_dir->dirname();
my $temp_output_dir = File::Temp->newdir(CLEANUP => 1);
my $temp_output_dir_name = $temp_output_dir->dirname();

use constant WEB_IN_CLIENT_JAR => "WEB_IN_CLIENT_JAR";
use constant A_PROXY_HOST => "A_HOST";
use constant A_PROXY_PORT => 1010;
use constant A_USER => "A_USER";
use constant A_PASSWORD => "A_PASSWORD";
use constant A_JVM_PATH => "PATH/TO/JVM";
use constant A_CONTEXT => "A_CONTEXT";
use constant A_CENTER_NAME => "A_CENTER_NAME";
use constant ANOTHER_CENTER_NAME => "ANOTHER_CENTER_NAME";
use constant A_FILE => "A_FILE";
use constant ANOTHER_FILE => "ANOTHER_FILE";
my @captured_input = ();
my @register_mocks = ();
my %full_args = (
    jar_path         => WEB_IN_CLIENT_JAR,
    username         => A_USER,
    password         => A_PASSWORD,
    http_proxy_host  => A_PROXY_HOST,
    http_proxy_port  => A_PROXY_PORT,
    context          => A_CONTEXT,
    input_dir        => $temp_input_dir_name,
    output_dir       => $temp_output_dir_name,
    test             => 1,
    validate         => 1,
    submit           => 1,
    jvm              => A_JVM_PATH,
    webincli_factory => sub {
        my %hash = @_;
        push @captured_input, \%hash;
        my $mock = Test::MockObject->new();
        $mock->set_true('run');
        push @register_mocks, $mock;
        return $mock;

    }
);

use_ok('Bio::ENA::DataSubmission::AnalysisSubmissionExecution');

#Test
{

    my ($under_test) = Bio::ENA::DataSubmission::AnalysisSubmissionExecution->new(%full_args);
    $under_test->run([ [ A_FILE, A_CENTER_NAME ], [ ANOTHER_FILE, ANOTHER_CENTER_NAME ] ]);
    is_deeply \@captured_input, [ {
        center_name     => A_CENTER_NAME,
        context         => A_CONTEXT,
        http_proxy_host => A_PROXY_HOST,
        http_proxy_port => A_PROXY_PORT,
        input_dir       => $temp_input_dir_name,
        jar_path        => WEB_IN_CLIENT_JAR,
        jvm             => A_JVM_PATH,
        manifest        => A_FILE,
        output_dir      => $temp_output_dir_name,
        password        => A_PASSWORD,
        submit          => 1,
        test            => 1,
        username        => A_USER,
        validate        => 1,

    }, {
        center_name     => ANOTHER_CENTER_NAME,
        context         => A_CONTEXT,
        http_proxy_host => A_PROXY_HOST,
        http_proxy_port => A_PROXY_PORT,
        input_dir       => $temp_input_dir_name,
        jar_path        => WEB_IN_CLIENT_JAR,
        jvm             => A_JVM_PATH,
        manifest        => ANOTHER_FILE,
        output_dir      => $temp_output_dir_name,
        password        => A_PASSWORD,
        submit          => 1,
        test            => 1,
        username        => A_USER,
        validate        => 1,

    } ], 'Webin cli initialized correctly';

    is(scalar @register_mocks, 2, "the cli was called twice");
    for my $mock (@register_mocks) {
        my ($name, $args) = $mock->next_call();
        is($name, "run", "run was called");
        is_deeply($args, [$mock], "run has no arguments");
        is($mock->next_call(), undef, "run was called only once");
    }
}

remove_tree($temp_input_dir_name, $temp_output_dir_name);

done_testing();

