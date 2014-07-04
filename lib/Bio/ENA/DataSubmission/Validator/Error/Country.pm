package Bio::ENA::DataSubmission::Validator::Error::Country;

# ABSTRACT: Module for validation of country from manifest

=head1 SYNOPSIS

Checks that country is in correct format

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'country'   => ( is => 'ro', isa => 'Str', required => 1 );
has 'accession' => ( is => 'ro', isa => 'Str', required => 1 );

sub validate {
	my $self = shift;
	my $country = $self->country;
	my $acc  = $self->accession;

	my $format = (
		   $country =~ m/[\w ]+/ 
		|| $country =~ m/[\w ]+: [\w ,]+/
	);

	$self->set_error_message( $acc, "Incorrect country format. Must match country: region, locality. E.G. United Kingdom: England, Norfolk, Blakeney Point" ) if ( $format );

	return $self;
}

sub fix_it {

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;