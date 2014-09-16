package Bio::ENA::DataSubmission::Validator::Error::General;

# ABSTRACT: Module for validation of free-text cells in manifest

=head1 SYNOPSIS

Checks for newline characters in text

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'cell'       => ( is => 'ro', isa => 'Maybe[Str]', required => 1 );
has 'identifier' => ( is => 'ro', isa => 'Maybe[Str]', required => 1 );

sub validate {
	my $self  = shift;
	my $id    = $self->identifier;
	my $cell  = $self->cell;

	chomp $cell;
	$cell =~ s/^\s+//;

	$self->set_error_message( $id, "Newline characters detected within $id" ) if ( $cell =~ m/\n/ );

	return $self;
}

sub fix_it {
	
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;