package Bio::ENA::DataSubmission::Validator::Error::Country;

# ABSTRACT: Module for validation of country from manifest

=head1 SYNOPSIS

Checks that country is in correct format

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'country'   => ( is => 'ro', isa => 'Str', required => 1 );
has 'identifier' => ( is => 'ro', isa => 'Str', required => 1 );

sub validate {
	my $self = shift;
	my $country = $self->country;
	my $acc  = $self->identifier;

	my $format = (
		   $country =~ m/^[a-zA-Z'() ]+$/ 
		|| $country =~ m/^[a-zA-Z'() ]+: .+$/
	);

	$self->set_error_message( $acc, "Incorrect country format. Must match country: region, locality. E.G. United Kingdom: England, Norfolk, Blakeney Point" ) unless ( $format );

	return $self;
}

sub fix_it {

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;