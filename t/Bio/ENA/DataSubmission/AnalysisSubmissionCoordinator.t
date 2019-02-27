#!/usr/bin/env perl
BEGIN {unshift(@INC, './lib')}

BEGIN {
    use strict;
    use warnings;
    use Test::Most;
    use Test::MockObject;
}

use File::Path qw(remove_tree);
use constant A_CENTER_NAME => "A_CENTER_NAME";
use constant ANOTHER_CENTER_NAME => "ANOTHER_CENTER_NAME";
use constant A_FILE => "A_FILE";
use constant ANOTHER_FILE => "ANOTHER_FILE";

use_ok('Bio::ENA::DataSubmission::AnalysisSubmissionCoordinator');

#test
{
    my @submitted_data = ([A_FILE, A_CENTER_NAME], [ANOTHER_FILE, ANOTHER_CENTER_NAME]);
    my $data_generator = create_mock_data_generator(@submitted_data);
    my $submitter = create_mock_submitter();
    my $under_test = Bio::ENA::DataSubmission::AnalysisSubmissionCoordinator->new(
        submitter      => $submitter,
        data_generator => => $data_generator,
    );

    $under_test->run();

    validate_call_to_submitter($submitter, [[A_FILE, A_CENTER_NAME], [ANOTHER_FILE, ANOTHER_CENTER_NAME]]);
}

sub validate_call_to_submitter {
    my ($submitter, $expected) = @_;
    my ($name, $args) = $submitter->next_call();
    is($name, "run", "run was called");
    is_deeply($args, [$submitter, $expected], "run was run with correct arguments");
    is($submitter->next_call(), undef, "run was called only once");

}
sub create_mock_submitter {
    my $submitter = Test::MockObject->new();
    $submitter->set_isa('Bio::ENA::DataSubmission::AnalysisSubmissionExecution');
    $submitter->set_true('run');
    return $submitter;
}

sub create_mock_data_generator {
    my @submitted_data = @_;
    my $data_generator = Test::MockObject->new();
    $data_generator->set_isa('Bio::ENA::DataSubmission::AnalysisSubmissionPreparation');
    $data_generator->mock('prepare_for_submission' => sub {
        return @submitted_data;
    });
    return $data_generator;
}

done_testing();

