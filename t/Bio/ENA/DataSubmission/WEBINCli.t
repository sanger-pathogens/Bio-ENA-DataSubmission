#!/usr/bin/env perl

BEGIN { unshift( @INC, './lib' ) }

BEGIN {
    use Test::Most;
    use Test::Output;
    use Test::Exception;
}

use Moose;
use File::Temp qw(tempfile tempdir);
use Data::Dumper;
use File::Path qw(remove_tree);

my $temp_input_dir = File::Temp->newdir(CLEANUP => 1 );
my $temp_input_dir_name = $temp_input_dir->dirname();
my $temp_output_dir = File::Temp->newdir(CLEANUP => 1 );
my $temp_output_dir_name = $temp_output_dir->dirname();
my($fh, $filename) = tempfile(CLEANUP => 1);
my($manifest_file, $manifest_filename) = tempfile(CLEANUP => 1);
my $temp_dir = File::Temp->newdir(CLEANUP => 1 );
my $temp_dir_name = $temp_dir->dirname();
my($unreadable_manifest_handle, $unreadable_manifest) = tempfile(CLEANUP => 1);
chmod 0333, ($unreadable_manifest);
use constant WEB_IN_CLIENT_JAR => "WEB_IN_CLIENT_JAR";
use constant A_PROXY_HOST => "A_HOST";
use constant A_PROXY_PORT => 1010;
use constant A_USER => "A_USER";
use constant A_PASSWORD => "A_PASSWORD";

my %full_args = (
    http_proxy_host => A_PROXY_HOST,
    http_proxy_port => A_PROXY_PORT,
    username => A_USER,
    password => A_PASSWORD,
    jar_path => WEB_IN_CLIENT_JAR,
    input_dir => $temp_input_dir_name,
    output_dir => $temp_output_dir_name,
    manifest => $manifest_filename,
);

#Mock the system function by capturing it's input
my $system_call_args;
use Test::Mock::Cmd 'system' => sub { $system_call_args = \@_ };




# Test the module can be used
{

    use_ok('Bio::ENA::DataSubmission::WEBINCli');
}

#Test the system call is made properly
{

    my ($under_test) = Bio::ENA::DataSubmission::WEBINCli->new(%full_args);
    $under_test->run();
    my $expected = ["java", "-Dhttp.proxyHost=A_HOST", "-Dhttp.proxyPort=1010", "-jar", WEB_IN_CLIENT_JAR, "-username",
        A_USER, "-password", A_PASSWORD, "-inputDir", $temp_input_dir_name, "-outputDir", $temp_output_dir_name,
        "-manifest", $manifest_filename, "-context", "genome", "-validate", "-submit"];
    is_deeply($system_call_args, $expected, 'run() calls system() with correct arguments');
}

#Test can change the context
{

    my $args = {%full_args};
    $args->{'context'} = 'a_context';
    my ($under_test) = Bio::ENA::DataSubmission::WEBINCli->new(%$args);
    $under_test->run();
    my $expected = ["java", "-Dhttp.proxyHost=A_HOST", "-Dhttp.proxyPort=1010", "-jar", WEB_IN_CLIENT_JAR, "-username",
        A_USER, "-password", A_PASSWORD, "-inputDir", $temp_input_dir_name, "-outputDir", $temp_output_dir_name,
        "-manifest", $manifest_filename, "-context", "a_context", "-validate", "-submit"];
    is_deeply($system_call_args, $expected, 'run() calls system() with correct arguments');
}

#Test can change the test mode
{

    my $args = {%full_args};
    $args->{'test'} = 1;
    my ($under_test) = Bio::ENA::DataSubmission::WEBINCli->new(%$args);
    $under_test->run();
    my $expected = ["java", "-Dhttp.proxyHost=A_HOST", "-Dhttp.proxyPort=1010", "-jar", WEB_IN_CLIENT_JAR, "-username",
        A_USER, "-password", A_PASSWORD, "-inputDir", $temp_input_dir_name, "-outputDir", $temp_output_dir_name,
        "-manifest", $manifest_filename, "-context", "genome", "-test", "-validate", "-submit"];
    is_deeply($system_call_args, $expected, 'run() calls system() with correct arguments');
}

#Test can switch off validation
{

    my $args = {%full_args};
    $args->{'validate'} = 0;
    my ($under_test) = Bio::ENA::DataSubmission::WEBINCli->new(%$args);
    $under_test->run();
    my $expected = ["java", "-Dhttp.proxyHost=A_HOST", "-Dhttp.proxyPort=1010", "-jar", WEB_IN_CLIENT_JAR, "-username",
        A_USER, "-password", A_PASSWORD, "-inputDir", $temp_input_dir_name, "-outputDir", $temp_output_dir_name,
        "-manifest", $manifest_filename, "-context", "genome", "-submit"];
    is_deeply($system_call_args, $expected, 'run() calls system() with correct arguments');
}

#Test can switch off submission
{

    my $args = {%full_args};
    $args->{'submit'} = 0;
    my ($under_test) = Bio::ENA::DataSubmission::WEBINCli->new(%$args);
    $under_test->run();
    my $expected = ["java", "-Dhttp.proxyHost=A_HOST", "-Dhttp.proxyPort=1010", "-jar", WEB_IN_CLIENT_JAR, "-username",
        A_USER, "-password", A_PASSWORD, "-inputDir", $temp_input_dir_name, "-outputDir", $temp_output_dir_name,
        "-manifest", $manifest_filename, "-context", "genome", "-validate"];
    is_deeply($system_call_args, $expected, 'run() calls system() with correct arguments');
}


sub test_mandatory_args {
    my ($input) = @_;
    my $args_with_missing_required_arg = {%full_args};
    delete $args_with_missing_required_arg->{$input};
    throws_ok {Bio::ENA::DataSubmission::WEBINCli->new(%$args_with_missing_required_arg)} 'Moose::Exception::AttributeIsRequired', "dies if mandatory arg $input is missing";
}

# Check mandatory arguments
{
    my (@mandatory_args) = ('input_dir','output_dir','manifest', 'http_proxy_host', 'http_proxy_port', 'username',
        'password');

    foreach (@mandatory_args) {
        test_mandatory_args($_);
    }

}

# Fail non integer proxy port
{
    my $args = {%full_args};
    $args->{"http_proxy_port"} = 13.3;
    throws_ok {Bio::ENA::DataSubmission::WEBINCli->new(%$args)} 'Moose::Exception::ValidationFailedForInlineTypeConstraint', "dies if http_proxy_port is not an int";
}


sub test_directory_missing {
    my ($input) = @_;
    my $args = {%full_args};
    $args->{$input} = 'Not/An/Existing/Directory';
    my $under_test = Bio::ENA::DataSubmission::WEBINCli->new(%$args);
    throws_ok {$under_test->run()} 'Bio::ENA::DataSubmission::Exception::DirectoryNotFound', "dies if $input is not found";
}

sub test_directory_not_a_directory {
    my ($input) = @_;
    my $args = {%full_args};
    $args->{$input} = $filename;
    my $under_test = Bio::ENA::DataSubmission::WEBINCli->new(%$args);
    throws_ok {$under_test->run()} 'Bio::ENA::DataSubmission::Exception::DirectoryNotFound', "dies if $input is a file and not a dir";
}


# Check directories validation
{
    my (@dir_args) = ('input_dir','output_dir');
    foreach (@dir_args) {
        test_directory_missing($_);
        test_directory_not_a_directory($_);
    }

}

# Check manifest validation when missing
{
    my $args = {%full_args};
    $args->{'manifest'} = 'Not/An/Existing/File';
    my $under_test = Bio::ENA::DataSubmission::WEBINCli->new(%$args);
    throws_ok {$under_test->run()} 'Bio::ENA::DataSubmission::Exception::FileNotFound', "dies if manifest is not found";

}

# Check manifest validation when not a file
{
    my $args = {%full_args};
    $args->{'manifest'} = $temp_dir_name;
    my $under_test = Bio::ENA::DataSubmission::WEBINCli->new(%$args);
    throws_ok {$under_test->run()} 'Bio::ENA::DataSubmission::Exception::CannotReadFile', "dies if manifest is not a readable file";

}

# Check manifest validation when file is not readable
{
    my $args = {%full_args};
    $args->{'manifest'} = $unreadable_manifest;
    my $under_test = Bio::ENA::DataSubmission::WEBINCli->new(%$args);
    throws_ok {$under_test->run()} 'Bio::ENA::DataSubmission::Exception::CannotReadFile', "dies if manifest is not a readable file";

}

remove_tree($temp_input_dir_name, $temp_output_dir_name, $filename, $manifest_filename, $temp_dir_name, $unreadable_manifest);
done_testing();

no Moose;
