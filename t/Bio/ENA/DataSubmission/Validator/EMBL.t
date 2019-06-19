#!/usr/bin/env perl

BEGIN {
    use Test::Most;
    use Test::Output;
    use Test::Exception;
}

use Moose;
use constant EMBL_CLIENT_JAR => "EMBL_CLIENT_JAR";
use constant A_FILE => "A_FILE";
use constant ANOTHER_FILE => "ANOTHER_FILE";

#Mock the system function by capturing it's input
my $system_call_args;
use Test::Mock::Cmd 'system' => sub { $system_call_args = \@_ };

# Test the module can be used
{

    use_ok('Bio::ENA::DataSubmission::Validator::EMBL');
}

# Test the system call is made properly if one file
{

    my ($under_test);

    my @files = [A_FILE];
    $under_test = Bio::ENA::DataSubmission::Validator::EMBL->new(
        jar_path => EMBL_CLIENT_JAR,
        embl_files   => @files
    );

    $under_test->validate();
    my $expected = ["java -classpath " . EMBL_CLIENT_JAR . " uk.ac.ebi.embl.api.validation.EnaValidator -r " . A_FILE];
    is_deeply($system_call_args, $expected, 'validate() calls system() with correct args for single file');
}


# Test the system call is made properly with multiple files
{

    my ($under_test);

    my @files = [A_FILE, ANOTHER_FILE];
    $under_test = Bio::ENA::DataSubmission::Validator::EMBL->new(
        jar_path => EMBL_CLIENT_JAR,
        embl_files   => @files
    );

    $under_test->validate();
    my $expected = ["java -classpath " . EMBL_CLIENT_JAR . " uk.ac.ebi.embl.api.validation.EnaValidator -r " . A_FILE . " " . ANOTHER_FILE];
    is_deeply($system_call_args, $expected, 'validate() calls system() with correct args for multiple files');
}

done_testing();
