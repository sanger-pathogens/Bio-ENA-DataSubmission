package Bio::ENA::DataSubmission::AnalysisSubmissionCoordinator;

# ABSTRACT: module for submitting genome assemblies with metadata using the web-in cli

=head1 NAME

Bio::ENA::DataSubmission::AnalysisSubmissionCoordinator

=head1 SYNOPSIS

Coordinate the submission of analysis by first preparing the data and then submitting

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use Moose;
use Bio::ENA::DataSubmission::AnalysisSubmissionPreparation;
use Bio::ENA::DataSubmission::AnalysisSubmissionExecution;

has 'data_generator' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::AnalysisSubmissionPreparation', required => 1);
has 'submitter' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::AnalysisSubmissionExecution', required => 1);


sub run {
    my $self = shift;
    my @submission_data = $self->data_generator->prepare_for_submission();
    $self->submitter->run(@submission_data);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;