package Bio::ENA::DataSubmission::Validator::Error::TaxID;

# ABSTRACT: Module for validation of accession from manifest

=head1 SYNOPSIS

Checks that accession is a valid study accession

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

use Bio::ENA::DataSubmission::XML;

has 'accession'   => ( is => 'ro', isa => 'Str', required => 1 );

sub validate {
	my $self = shift;
	my $acc  = $self->accession;

	unless ( $acc =~ m/ERS/ ){
		$self->set_error_message( $acc, "Invalid accession - must take format ERSXXXXXX" );
	}
	else {
		# pull XML from ENA and verify that it isn't empty
		my $xml = Bio::ENA::DataSubmission::XML->new( url => "http://www.ebi.ac.uk/ena/data/view/$acc&display=xml" )->parse_from_url;
		$self->set_error_message( $acc, "Invalid accession - could not be found at the ENA" ) unless ( defined $xml->{SAMPLE} );		
	}

	return $self;
}

sub fix_it {
	
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;