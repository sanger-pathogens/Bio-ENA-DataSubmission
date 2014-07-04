package Bio::GFFValidator::Errors::BaseError;
# ABSTRACT: 

=head1 SYNOPSIS

Base Error class from which other error classes will inherit. 

=method 


=cut

use Moose;

has 'accession' => ( is => 'rw', isa => 'Str'); 
has 'message'   => ( is => 'rw', isa => 'Str'); 
has 'triggered' => ( is => 'rw', isa => 'Bool', default  => 0 ); 

sub set_error_message {
	my ( $self, $accession, $message ) = @_;
	$self->accession( $accession );
	$self->message( $message );
	$self->triggered( 1 );
	return $self;
}

sub get_error_message {
	my ($self) = @_;
	return $self->value.": ".$self->message;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;