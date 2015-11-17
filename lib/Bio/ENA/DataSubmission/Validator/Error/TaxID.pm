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

has 'common_name'           => ( is => 'ro', isa => 'Maybe[Str]', lazy => 1, builder => '_build_common_name' );

sub _build_common_name
{
    my($self) = @_;
    my $tax_id           = $self->tax_id;
	chomp $tax_id;
	$tax_id = int( $tax_id );
    my $taxon_lookup = NCBI::TaxonLookup->new( taxon_id => $tax_id, taxon_lookup_service => $self->taxon_lookup_service )->common_name;
    return $taxon_lookup;
}

sub validate {
	my $self             = shift;
	my $tax_id           = $self->tax_id;
	my $scientific_name  = $self->scientific_name;
	my $id               = $self->identifier;

	chomp $tax_id;
	$tax_id = int( $tax_id );

	unless( defined $scientific_name ){
		$self->set_error_message( $id, "$tax_id is not a valid taxonomic ID" ) unless ( defined $self->common_name );
	}
	else {
	  if ( $scientific_name ne $self->common_name )
	  {
	    #Remove non word characters and see do they match. [Clostridium] issue.
  	  my $scientific_name_filtered = $scientific_name;
  	  my $taxon_lookup_filtered    = $self->common_name;
  	  $scientific_name_filtered =~ s!\W!!gi;
  	  $taxon_lookup_filtered =~ s!\W!!gi;
  	  
  	  if($scientific_name_filtered ne $taxon_lookup_filtered)
	    {
	    	$self->set_error_message( $id, "Taxon ID '$tax_id' does not match given scientific name '$scientific_name'. $tax_id = ".$self->common_name );
  	  }
  	}
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