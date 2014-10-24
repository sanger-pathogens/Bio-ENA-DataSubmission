package Bio::ENA::DataSubmission::Validator::Error::TaxID;

# ABSTRACT: Module for validation of taxon ID and scientific name from manifest

=head1 SYNOPSIS

Checks that given taxon ID is valid and corresponds to the given scientific name

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";
use NCBI::TaxonLookup;

has 'tax_id'               => ( is => 'ro', isa => 'Str', required => 1 );
has 'scientific_name'      => ( is => 'ro', isa => 'Str', required => 0 );
has 'identifier'           => ( is => 'ro', isa => 'Str', required => 1 );
has 'taxon_lookup_service' => ( is => 'ro', isa => 'Str', default  => 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&report=xml&id=' );

sub validate {
	my $self             = shift;
	my $tax_id           = $self->tax_id;
	my $scientific_name  = $self->scientific_name;
	my $id               = $self->identifier;

	chomp $tax_id;
	$tax_id = int( $tax_id );
	my $taxon_lookup = NCBI::TaxonLookup->new( taxon_id => $tax_id, taxon_lookup_service => $self->taxon_lookup_service )->common_name;

	unless( defined $scientific_name ){
		$self->set_error_message( $id, "$tax_id is not a valid taxonomic ID" ) unless ( defined $taxon_lookup );
	}
	else {
		$self->set_error_message( $id, "Taxon ID '$tax_id' does not match given scientific name '$scientific_name'. $tax_id = $taxon_lookup" ) unless ( $scientific_name eq $taxon_lookup );
	}

	return $self;
}

sub fix_it {
	my $self             = shift;
	my $tax_id           = $self->tax_id;
	my $scientific_name  = $self->scientific_name;

	chomp $tax_id;
	$tax_id = int( $tax_id );
	my $taxon_lookup = NCBI::TaxonLookup->new( taxon_id => $tax_id, taxon_lookup_service => $self->taxon_lookup_service )->common_name;

	return ( $tax_id, $taxon_lookup );	
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;