package Bio::ENA::DataSubmission::Validator::Error::PubmedID;

# ABSTRACT: Module for validation of pubmed IDs

=head1 SYNOPSIS

Checks that pubmed ID references a valid publication

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

use Bio::ENA::DataSubmission::XML;
use WWW::Mechanize;

has 'pubmed_id'   => ( is => 'ro', isa => 'Str', required => 1 );
has 'identifier'  => ( is => 'ro', isa => 'Str', required => 1 );
has 'pubmed_url_base' => ( is => 'rw', isa => 'Str', default => 'http://www.ncbi.nlm.nih.gov/pubmed/?term=' );
has '_pubmed_url'     => ( is => 'rw', isa => 'Str', required => 0, lazy_build => 1 );

sub _build__pubmed_url {
	my $self = shift;
	return $self->pubmed_url_base . $self->pubmed_id;
}

sub validate {
	my $self   = shift;
	my $id     = $self->identifier;
	my $pubmed = $self->pubmed_id;

	$self->set_error_message( $id, "ID could not be found in PubMed" ) unless ( $self->_valid_pubmed_id );

	return $self;
}

sub _valid_pubmed_id {
	my $self = shift;
	my $url  = $self->_pubmed_url;
	# For tests check to see if its a file we have on disk
	if( $url =~ /t\/data/)
	{
	  if( -e $url)
	  {return 1;}
	  else
	  {return 0;}
  }

	my $mech = WWW::Mechanize->new();
	$mech->get( $url );

	return 0 if ( $mech->content() =~ /No items found/ );
	return 1;
}

sub fix_it {
	
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;