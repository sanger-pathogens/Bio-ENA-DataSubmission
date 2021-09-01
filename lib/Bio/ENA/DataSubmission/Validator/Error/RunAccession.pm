package Bio::ENA::DataSubmission::Validator::Error::RunAccession;

# ABSTRACT: Module for validation of sample accession from manifest

=head1 SYNOPSIS

Checks that accession is a valid sample accession

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

use Bio::ENA::DataSubmission::XML;

has 'accession'   => ( is => 'ro', isa => 'Str', required => 1 );
has 'identifier'  => ( is => 'ro', isa => 'Str', required => 1 );
has 'ena_base_path'     => ( is => 'rw', isa => 'Str',      default  => 'http://www.ebi.ac.uk/ena/browser/api/xml/');

sub validate {
	my $self = shift;
	my $acc  = $self->accession;
	my $id   = $self->identifier;

	if( $acc =~ m/^ERR/ || $acc =~ m/^SRR/){
		# pull XML from ENA and verify that it isn't empty
		my $xml = Bio::ENA::DataSubmission::XML->new( url => $self->ena_base_path."$acc",ena_base_path => $self->ena_base_path )->parse_from_url;
		$self->set_error_message( $id, "Invalid run accession - could not be found at the ENA" ) unless ( defined $xml->{RUN} );
	}
	else {
		$self->set_error_message( $id, "Invalid run accession - must take format ERRxxxxx or SRRxxxxx" );
		return $self;
	}

	return $self;
}

sub fix_it {

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
