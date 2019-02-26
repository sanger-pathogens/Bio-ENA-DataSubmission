package Bio::ENA::DataSubmission::AnalysisSubmission;

# ABSTRACT: module for submitting genome assemblies with metadata using the web-in cli

=head1 NAME

Bio::ENA::DataSubmission::AnalysisSubmission

=head1 SYNOPSIS

Create all the necessary components to run the analysis submission.  Serves as a container and to help follows IoC principles

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use Moose;
use Getopt::Long qw(GetOptionsFromArray);
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::AnalysisSubmissionPreparation;
use Bio::ENA::DataSubmission::AnalysisSubmissionExecution;
use Bio::ENA::DataSubmission::AnalysisSubmissionCoordinator;
use Bio::ENA::DataSubmission::GffConverter;

use Bio::ENA::DataSubmission::ConfigReader;

has 'config_file' => (is => 'ro', isa => 'Str', required => 1);
has 'spreadsheet' => (is => 'ro', isa => 'Str', required => 1);
has 'input_dir' => (is => 'ro', isa => 'Str', required => 1);
has 'output_dir' => (is => 'ro', isa => 'Str', required => 1);
has 'validate' => (is => 'ro', isa => 'Bool', required => 1);
has 'test' => (is => 'ro', isa => 'Bool', required => 1);
has 'context' => (is => 'ro', isa => 'Str', required => 1);
has 'submit' => (is => 'ro', isa => 'Str', required => 1);

has 'gff_converter' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::GffConverter', lazy => 1, builder => '_build_gff_converter');
has 'config' => (is => 'ro', isa => 'HashRef', lazy => 1, builder => '_build_config');
has 'analysis_submission_coordinator' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::AnalysisSubmissionCoordinator', lazy => 1, builder => '_build_analysis_submission_coordinator');
has 'data_generator' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::AnalysisSubmissionPreparation', lazy => 1, builder => '_build_data_generator');
has 'submitter' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::AnalysisSubmissionExecution', lazy => 1, builder => '_build_submitter');
has 'proxy' => (is => 'ro', isa => 'ArrayRef', , lazy => 1, builder => '_build_proxy');
has 'manifest_spreadsheet' => (is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_build_manifest_spreadsheet');


#TODO add all validation/ fail fast stuff...

sub run {
    my ($self) = @_;
    $self->analysis_submission_coordinator->run();
}

sub _build_gff_converter {
    return Bio::ENA::DataSubmission::GffConverter->new();
}

sub _build_config {
    my ($self) = @_;
    my $reader = Bio::ENA::DataSubmission::ConfigReader->new(config_file => $self->config_file);
    return $reader->get_config();
}

sub _build_analysis_submission_coordinator {
    my ($self) = @_;
    return Bio::ENA::DataSubmission::AnalysisSubmissionCoordinator->new(data_generator => $self->data_generator, submitter => $self->submitter);

}

sub _build_data_generator {
    my ($self) = @_;
    return Bio::ENA::DataSubmission::AnalysisSubmissionPreparation->new(
        manifest_spreadsheet => $self->manifest_spreadsheet,
        output_dir           => $self->input_dir,
        gff_converter        => $self->gff_converter,
    );
}

sub _build_manifest_spreadsheet {
    my ($self) = @_;
    my $manifest_handler = Bio::ENA::DataSubmission::Spreadsheet->new(infile => $self->spreadsheet);
    return $manifest_handler->parse_manifest;
}


sub _build_submitter {
    my ($self) = @_;
    my ($host, $port) = @{$self->proxy};

    return Bio::ENA::DataSubmission::AnalysisSubmissionExecution->new(
        username        => $self->config->{webin_user},
        password        => $self->config->{webin_pass},
        jar_path        => $self->config->{webin_cli_jar},
        jvm             => $self->config->{jvm},
        http_proxy_host => $host,
        http_proxy_port => $port,
        submit          => $self->submit,
        context         => $self->context,
        input_dir       => $self->input_dir,
        output_dir      => $self->output_dir,
        validate        => $self->validate,
        test            => $self->test,
    );
}


sub _build_proxy {
    my ($self) = @_;
    my $proxy = $self->config->{proxy};
    my @result = split(/:/, $proxy);
    my ($host, $port);
    $port = pop(@result);
    if (scalar @result > 1) {
        $host = join(":", @result);
    }
    else {
        $host = pop(@result);
    }

    @result = split(/:\/\//, $host);
    if (scalar @result > 1) {
        $host = $result[1];
    }


    return [$host, $port];

}
__PACKAGE__->meta->make_immutable;
no Moose;
1;