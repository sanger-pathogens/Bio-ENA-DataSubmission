package Bio::ENA::DataSubmission::Validator::Error::MandatorySampleAccession;

# ABSTRACT: Module for validation of free-text cells in manifest

=head1 SYNOPSIS

Checks for newline characters in text

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'row'       => ( is => 'ro', isa => 'Maybe[ArrayRef]', required => 1 );
has 'mandatory' => ( is => 'ro', isa => 'Int',             required => 1 );
has 'rownumber' => ( is => 'ro', isa => 'Int',             required => 1 );

sub validate {
	my $self = shift;

	return $self unless ( defined $self->row );

	my @row  = @{ $self->row };
	
	my $index = $self->rownumber + 1;

	unless ( defined $row[$self->mandatory] ) {
		$self->set_error_message( "", "Missing sample accession number for row " . $index );
	}


	return $self;
}

sub fix_it {
	
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;