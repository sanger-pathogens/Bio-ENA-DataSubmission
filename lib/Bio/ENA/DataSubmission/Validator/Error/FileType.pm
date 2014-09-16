package Bio::ENA::DataSubmission::Validator::Error::FileType;

# ABSTRACT: Module for validation of file paths

=head1 SYNOPSIS

Checks that file exists and is read accessible

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'file_type'  => ( is => 'ro', isa => 'Str',      required => 1 );
has 'identifier' => ( is => 'ro', isa => 'Str',      required => 1 );
has 'allowed'    => ( is => 'ro', isa => 'ArrayRef', required => 1 );

sub validate {
	my $self    = shift;
	my $ft      = $self->file_type;
	my $id      = $self->identifier;
	my @allowed = @{ $self->allowed };

	$self->set_error_message( $id, "$ft is not a valid file type" ) unless ( grep { $_ eq $ft } @allowed );

	return $self;
}

sub fix_it {

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;