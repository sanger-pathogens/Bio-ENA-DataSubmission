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
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::AnalysisSubmissionPreparation;
use Bio::ENA::DataSubmission::AnalysisSubmissionExecution;
use Bio::ENA::DataSubmission::AnalysisSubmissionCoordinator;
use Bio::ENA::DataSubmission::GffConverter;
use Bio::ENA::DataSubmission::ConfigReader;
use Bio::ENA::DataSubmission::SpreadsheetEnricher;
use Bio::ENA::DataSubmission::AccessionConverter;
use File::Path qw(make_path);

has 'config_file' => (is => 'ro', isa => 'Str', required => 1);
has 'spreadsheet' => (is => 'ro', isa => 'Str', required => 1);
has 'reference_dir' => (is => 'ro', isa => 'Str', required => 1);
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
has 'input_dir' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_input_dir');
has 'output_dir' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_output_dir');
has 'current_user' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_current_user');
has 'timestamp' => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_timestamp');
has 'spreadsheet_converter' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::SpreadsheetEnricher', lazy => 1, builder => '_build_spreadsheet_converter');
has 'accession_converter' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::AccessionConverter', lazy => 1, builder => '_build_accession_converter');


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
    my $spreadsheet = $manifest_handler->parse_manifest;
    $self->spreadsheet_converter->enrich($spreadsheet);
    return $spreadsheet;
}

sub _build_spreadsheet_converter {
    my ($self) = @_;
    return Bio::ENA::DataSubmission::SpreadsheetEnricher->new(converter => $self->accession_converter);
}

sub _build_accession_converter {
    my ($self) = @_;
    return Bio::ENA::DataSubmission::AccessionConverter->new(ena_base_path => $self->config->{ena_base_path});
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

sub _build_input_dir {
    my ($self) = @_;
    my ($result) = $self->reference_dir . "/" . $self->current_user . "_" . $self->timestamp  . "/input";
    make_path($result);
    (-e $result && -d _) or Bio::ENA::DataSubmission::Exception::DirectoryNotFound->throw(error => "Cannot create input directory at $result\n");

    return $result;
}

sub _build_output_dir {
    my ($self) = @_;
    my ($result) = $self->reference_dir . "/" . $self->current_user . "_" . $self->timestamp  . "/output";
    make_path($result);
    (-e $result && -d _) or Bio::ENA::DataSubmission::Exception::DirectoryNotFound->throw(error => "Cannot create output directory at $result\n");

    return $result;
}

sub _build_current_user {
    my ($self) = @_;

    return getpwuid( $< );
}

sub _build_timestamp {
    my ($self) = @_;
    my @timestamp = localtime(time);
    my $day  = sprintf("%04d-%02d-%02d", $timestamp[5]+1900,$timestamp[4]+1,$timestamp[3]);
    my $time = sprintf("%02d-%02d-%02d", $timestamp[2], $timestamp[1], $timestamp[0]);

    return $day . '_' . $time;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;