package Bio::ENA::DataSubmission::CommandLine::ValidateEMBL;

# ABSTRACT: wrapper around ENA flatfile validator (http://www.ebi.ac.uk/ena/software/flat-file-validator)

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::ValidateEMBL

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::CommandLine::ValidateEMBL;
	

=head1 METHODS



=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;
use Getopt::Long qw(GetOptionsFromArray);
use Bio::ENA::DataSubmission::Exception;
use File::Slurp;
use Bio::ENA::DataSubmission::Validator::EMBL;

has 'args'     => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'files'    => ( is => 'rw', isa => 'ArrayRef', required => 0 );
has 'jar_path' => ( is => 'rw', isa => 'Str' );
has 'help'     => ( is => 'rw', isa => 'Bool', required => 0 );

has 'config_file' => ( is => 'rw', isa => 'Str', required => 0, default => '/software/pathogen/etc/ena_data_submission.conf' );

sub BUILD {
    my ($self) = @_;

    my ( $jar_path, $help, $config_file );
    my $args = $self->args;

    GetOptionsFromArray(
        $args,
        'jar_path'        => \$jar_path,
        'h|help'          => \$help,
        'c|config_file=s' => \$config_file
    );

    $self->jar_path($jar_path) if ( defined $jar_path );
    $self->help($help)         if ( defined $help );

    $self->files($args);

    $self->config_file($config_file) if ( defined $config_file );
    ( -e $self->config_file ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find config file\n" );
    $self->_populate_attributes_from_config_file;

}

sub check_inputs {
    my $self = shift;
    return ( $self->files && !$self->help );
}

sub _populate_attributes_from_config_file {
    my ($self)        = @_;
    my $file_contents = read_file( $self->config_file );
    my $config_values = eval($file_contents);
    $self->jar_path( $config_values->{embl_jar_path} );
}

sub run {
    my $self = shift;

    my @files    = @{ $self->files };
    my $jar_path = $self->jar_path;

    #---------------#
    # sanity checks #
    #---------------#

    $self->check_inputs   or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
    ( defined $files[0] ) or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
    for my $file (@files) {
        ( -e $file ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find $file\n" );
        ( -r $file ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $file\n" );
    }
    ( -e $jar_path && -x $jar_path ) or Bio::ENA::DataSubmission::Exception::CannotExecute->throw( error => "Cannot execute $jar_path\n" );

    #-----------------------#
    # build command and run #
    #-----------------------#

    my $embl_validator = Bio::ENA::DataSubmission::Validator::EMBL->new( embl_files => \@files, jar_path => $self->jar_path );
    $embl_validator->validate();
    1;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
