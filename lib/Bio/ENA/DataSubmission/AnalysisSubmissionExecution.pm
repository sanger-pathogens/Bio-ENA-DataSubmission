package Bio::ENA::DataSubmission::AnalysisSubmissionExecution;

# ABSTRACT: module for submitting genome assemblies with metadata using the web-in cli

=head1 NAME

Bio::ENA::DataSubmission::AnalysisSubmissionExecution

=head1 SYNOPSIS

Creates and run an instance of Bio::ENA::DataSubmission::WEBINCli based on config file and parameters provided

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use Moose;
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::WEBINCli;

has 'jar_path' => (is => 'ro', isa => 'Str', required => 1);
has 'username' => (is => 'ro', isa => 'Str', required => 1);
has 'password' => (is => 'ro', isa => 'Str', required => 1);
has 'http_proxy_host' => (is => 'ro', isa => 'Str', required => 1);
has 'http_proxy_port' => (is => 'ro', isa => 'Int', required => 1);
has 'context' => (is => 'ro', isa => 'Str', required => 1);
has 'input_dir' => (is => 'ro', isa => 'Str', required => 1);
has 'output_dir' => (is => 'ro', isa => 'Str', required => 1);
has 'test' => (is => 'ro', isa => 'Bool', required => 1);
has 'validate' => (is => 'ro', isa => 'Bool', required => 1);
has 'submit' => (is => 'ro', isa => 'Bool', required => 1);
has 'jvm' => (is => 'ro', isa => 'Str', required => 1);

#webincli_factory is used for mock injection
has 'webincli_factory' => (is => 'ro', isa => 'CodeRef', required => 0, default => sub {
 return sub {
     my %hash = @_;
     return Bio::ENA::DataSubmission::WEBINCli->new(%hash);
 }
});

sub run {
    my ($self, $submission_data) = @_;

    for my $single_submission_data (@$submission_data) {
        my ($manifest, $centerName) = @$single_submission_data;
        my $webincli = $self->webincli_factory->(
            http_proxy_host => $self->http_proxy_host,
            http_proxy_port => $self->http_proxy_port,
            username        => $self->{username},
            password        => $self->{password},
            jar_path        => $self->{jar_path},
            input_dir       => $self->input_dir,
            output_dir      => $self->output_dir,
            manifest        => $manifest,
            center_name     => $centerName,
            validate        => $self->validate,
            test            => $self->test,
            context         => $self->context,
            jvm             => $self->{jvm},
            submit          => $self->submit,
        );
        $webincli->run();
    }

}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
