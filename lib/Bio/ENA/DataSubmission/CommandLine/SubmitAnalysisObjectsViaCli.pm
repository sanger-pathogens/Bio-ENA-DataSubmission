package Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli;

# ABSTRACT: module for submitting genome assemblies with metadata using the web-in cli

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli

=head1 SYNOPSIS

Creates and run an instance of Bio::ENA::DataSubmission::WEBINCli based on config file and parameters provided

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use Moose;
use Getopt::Long qw(GetOptionsFromArray);
use Bio::ENA::DataSubmission::Exception;

use constant USAGE => <<USAGE;
Usage: submit_analysis_objects_via_cli [options] -f manifest.xls

	-f|file        Manifest file in tab separated, 2 columns format (required)
	-i|input       Input directory where the files referenced in the manifest reside (required)
	-o|output      Output directory for submission details: xml, logs, etc... (required)
	-c|context     Submission context ( one of genome, transcriptome, sequence, reads. Default: genome)
	--no_validate  Do not run validation step
	--test         Use the ENA test submission service
	-h|help        This help message

USAGE


use Bio::ENA::DataSubmission::WEBINCli;
use Bio::ENA::DataSubmission::ConfigReader;

has 'config_reader' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::ConfigReader', required => 0, default =>
    sub {return Bio::ENA::DataSubmission::ConfigReader->new();});
has 'manifest'      => (is => 'ro', isa => 'Str', required => 1);
has 'input_dir'     => (is => 'ro', isa => 'Str', required => 1);
has 'output_dir'    => (is => 'ro', isa => 'Str', required => 1);
has 'validate'      => (is => 'ro', isa => 'Bool', required => 0, default => 1);
has 'test'          => (is => 'ro', isa => 'Bool', required => 0, default => 0);
has 'context'       => (is => 'rw', isa => 'Str',  required => 0, default    => 'genome' );

around BUILDARGS => sub {
    my ($orig, $class, %args) = @_;
    if (exists $args{args}) {
        my $arguments = $args{args};
        my($manifest, $output_dir, $input_dir, $context, $no_validate, $test, $config_file, $help);

        GetOptionsFromArray(
            $arguments,
            'f|file=s'    => \$manifest,
            'o|output_dir=s' => \$output_dir,
            'i|input_dir=s' => \$input_dir,
            't|type=s'      => \$context,
            'no_validate' => \$no_validate,
            'test' => \$test,
            'c|config_file=s' => \$config_file,
            'h|help'      => \$help
        );

        if (defined $help || ! defined $manifest || ! defined $output_dir || ! defined $input_dir) {
            Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => USAGE );
        }

        $args{manifest} = $manifest;
        $args{output_dir} = $output_dir;
        $args{input_dir} = $input_dir;
        if (defined $context) {
            $args{context} = $context;
        }
        if (defined $no_validate) {
            $args{validate} = 0;
        }
        if (defined $test) {
            $args{test} = 1;
        }
        if (defined $config_file) {
            $args{config_reader} = Bio::ENA::DataSubmission::ConfigReader->new(config_file => $config_file);
        }
        delete $args{args};
    }

    $class->$orig(%args);
};

sub BUILD {
    my $self = shift;
    my $config = $self->config_reader->get_config();
    my ($host, $port) = $self->_extract_proxy($config->{proxy});
    $self->{_webincli} = Bio::ENA::DataSubmission::WEBINCli->new(
        http_proxy_host => $host,
        http_proxy_port => $port,
        username        => $config->{webin_user},
        password        => $config->{webin_pass},
        jar_path        => $config->{webin_cli_jar},
        input_dir       => $self->input_dir,
        output_dir      => $self->output_dir,
        manifest        => $self->manifest,
        validate        => $self->validate,
        test            => $self->test,
        context         => $self->context,
    );


}

sub run {
    my $self = shift;
    $self->{_webincli}->run();
}

sub _extract_proxy {
    my ($self, $proxy) = @_;
    my @result = split(/:/, $proxy);
    my ($host, $port);
    $port = pop(@result);
    if (scalar @result > 1) {
        $host = join(":", @result);
    }
    else {
        $host = pop(@result);
    }

    return $host, $port;

}
__PACKAGE__->meta->make_immutable;
no Moose;
1;