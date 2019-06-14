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
has 'help'     => ( is => 'rw', isa => 'Bool', required => 0 );

has 'jar_path' => (is => 'ro', isa => 'Str', , lazy => 1, builder => '_build_jar_path');
has 'data_root' => (is => 'ro', isa => 'Maybe[Str]', required => 0, default => $ENV{'ENA_SUBMISSIONS_DATA'});

sub BUILD {
    my ($self) = @_;

    my ( $help );
    my $args = $self->args;

    GetOptionsFromArray(
        $args,
        'h|help'          => \$help
    );

    $self->help($help)         if ( defined $help );
    $self->files($args);
}

sub _build_jar_path {
    my ($self) = @_;
    return $self->data_root . '/embl-client.jar';
}


sub check_inputs {
    my $self = shift;
    return ( $self->files && !$self->help );
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

sub usage_text {
	return <<USAGE;
Usage: validate_embl [options] embl_files

	-h|help        This help message

USAGE
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
