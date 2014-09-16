package Bio::ENA::DataSubmission::Validator::Error::Number;

# ABSTRACT: Module for validation of numeric values

=head1 SYNOPSIS

Checks that cell holds a numeric value

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'cell'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'identifier' => ( is => 'ro', isa => 'Str', required => 1 );

sub validate {
	my $self = shift;
	my $cell = $self->cell;
	my $id   = $self->identifier;

	my $format = ( $cell =~ m/^[\d\.]+$/ );

	$self->set_error_message( $id, "'$cell' is not a number" ) unless ( $format );

	return $self;
}

sub fix_it {

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;