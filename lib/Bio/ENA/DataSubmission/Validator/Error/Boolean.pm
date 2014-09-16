package Bio::ENA::DataSubmission::Validator::Error::Boolean;

# ABSTRACT: Module for validation of boolean values

=head1 SYNOPSIS

Checks that cell is either TRUE or FALSE

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'cell'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'identifier' => ( is => 'ro', isa => 'Str', required => 1 );

sub validate {
	my $self = shift;
	my $cell = $self->cell;
	my $id   = $self->identifier;

	my $format = (
		   uc($cell) eq 'TRUE'
		|| uc($cell) eq 'FALSE'
	);

	$self->set_error_message( $id, "Not a boolean value (TRUE or FALSE)" ) unless ( $format );

	return $self;
}

sub fix_it {

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;