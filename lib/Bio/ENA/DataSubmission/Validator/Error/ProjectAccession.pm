package Bio::ENA::DataSubmission::Validator::Error::ProjectAccession;

# ABSTRACT: Module for validation of ERP accession from manifest

=head1 SYNOPSIS

Checks that accession is a valid project accession

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

use Bio::ENA::DataSubmission::XML;

has 'accession'   => ( is => 'ro', isa => 'Str', required => 1 );
has 'identifier'  => ( is => 'ro', isa => 'Str', required => 1 );
has 'ena_base_path'     => ( is => 'rw', isa => 'Str',      default  => 'http://www.ebi.ac.uk/ena/data/view/');

sub validate {
	my $self = shift;
	my $acc  = $self->accession;
	my $id   = $self->identifier;

	unless ( $acc =~ m/^ERP/ ){
		$self->set_error_message( $id, "Invalid study accession - must take format ERPXXXXXX" );
		return $self;
	}
	else {
		# pull XML from ENA and verify that it isn't empty
		my $xml = Bio::ENA::DataSubmission::XML->new( url => $self->ena_base_path."$acc&display=xml",ena_base_path => $self->ena_base_path )->parse_from_url;
		$self->set_error_message( $id, "Invalid study accession - could not be found at the ENA" ) unless ( defined $xml->{STUDY} );		
	}

	return $self;
}

sub fix_it {
	
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;