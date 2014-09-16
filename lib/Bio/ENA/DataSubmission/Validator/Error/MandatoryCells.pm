package Bio::ENA::DataSubmission::Validator::Error::MandatoryCells;

# ABSTRACT: Module for validation of free-text cells in manifest

=head1 SYNOPSIS

Checks for newline characters in text

=cut

use Moose;
use Data::Dumper;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'row'       => ( is => 'ro', isa => 'Maybe[ArrayRef]', required => 1 );
has 'mandatory' => ( is => 'ro', isa => 'ArrayRef',        required => 1 );

sub validate {
	my $self = shift;

	return $self unless ( defined $self->row );

	my @row  = @{ $self->row };
	
	my $acc = $row[0];
	my @man = @{ $self->mandatory };

	foreach my $i ( @man ){
		unless ( defined $row[$i] ) {
			$self->set_error_message( $acc, "Mandatory cells missing" );
			last;
		}
	}
	
	return $self;
}

sub fix_it {
	
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;