package Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli;

# ABSTRACT: module for submitting genome assemblies with metadata using the web-in cli

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli

=head1 SYNOPSIS

Parses arguments, validate inputs and then delegate the submission to Bio::ENA::DataSubmission::Assembler

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use Moose;
use Getopt::Long qw(GetOptionsFromArray);
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::AnalysisSubmission;

use constant USAGE => <<USAGE;
Usage: submit_analysis_objects_via_cli [options] -f manifest.xls

	-f|file        Excel spreadsheet manifest file (required)
	-o|output_dir  Base output directory. A subdirectory within that will be created for the submission (required)
	-c|context     Submission context ( one of genome, transcriptome, sequence, reads. Default: genome)
	--no_validate  Do not run validation step
	--no_submit    Do not run submit step
	--test         Use the ENA test submission service
	--config_file  Location of config file to use (a default one is provided)
	-h|help        This help message

USAGE


has 'config_file' => (is => 'ro', isa => 'Maybe[Str]', required => 0, default => $ENV{'ENA_SUBMISSION_CONFIG'});
has 'spreadsheet' => (is => 'ro', isa => 'Str', required => 1);
has 'output_dir' => (is => 'ro', isa => 'Str', required => 1);
has 'validate' => (is => 'ro', isa => 'Bool', required => 1);
has 'test' => (is => 'ro', isa => 'Bool', required => 1);
has 'context' => (is => 'ro', isa => 'Str', required => 1);
has 'submit' => (is => 'ro', isa => 'Str', required => 1);

has 'container' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::AnalysisSubmission', lazy => 1, builder => '_build_container');

around BUILDARGS => sub {
    my ($orig, $class, %args) = @_;
    if (exists $args{args}) {
        my $arguments = $args{args};
        my ($spreadsheet, $output_dir, $context, $no_validate, $no_submit, $test, $config_file, $help);

        GetOptionsFromArray(
            $arguments,
            'f|file=s'        => \$spreadsheet,
            'o|output_dir=s'  => \$output_dir,
            'c|context=s'        => \$context,
            'no_validate'     => \$no_validate,
            'no_submit'       => \$no_submit,
            'test'            => \$test,
            'config_file=s' => \$config_file,
            'h|help'          => \$help
        );

        if (defined $help || !defined $spreadsheet || !defined $output_dir) {
            Bio::ENA::DataSubmission::Exception::InvalidInput->throw(error => USAGE);
        }

        $args{spreadsheet} = $spreadsheet;
        $args{output_dir} = $output_dir;
        $args{context} = (defined $context) ? $context : "genome";
        $args{validate} = (defined $no_validate) ? 0 : 1;
        $args{submit} = (defined $no_submit) ? 0 : 1;
        $args{test} = (defined $test) ? 1 : 0;
        if (defined $config_file) {
            $args{config_file} = $config_file;
        }
        delete $args{args};
    }

    $class->$orig(%args);
};

sub _build_container {
    my $self = shift;
    (-e $self->output_dir && -d _) or Bio::ENA::DataSubmission::Exception::DirectoryNotFound->throw(error => "Cannot find output directory\n");
    (-e $self->spreadsheet) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw(error => "Cannot find spreadsheet manifest file\n");
    (-f $self->spreadsheet && -r _) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw(error => "Cannot find spreadsheet manifest file\n");
    (-e $self->config_file) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw(error => "Cannot find config file\n");
    (-f $self->config_file && -r _) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw(error => "Cannot find config file\n");
    return Bio::ENA::DataSubmission::AnalysisSubmission->new(
        config_file => $self->config_file,
        spreadsheet => $self->spreadsheet,
        reference_dir  => $self->output_dir,
        validate    => $self->validate,
        test        => $self->test,
        context     => $self->context,
        submit      => $self->submit,
    );
}

sub run {
    my $self = shift;
    $self->container->run();
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;