package Bio::ENA::DataSubmission::Validator::Error;
# ABSTRACT: Base Error class from which other error classes will inherit. 

=head1 SYNOPSIS

Base Error class from which other error classes will inherit. 

=method 


=cut

use Moose;

has 'key'       => ( is => 'rw', isa => 'Str'); 
has 'message'   => ( is => 'rw', isa => 'Str'); 
has 'triggered' => ( is => 'rw', isa => 'Bool', default  => 0 ); 

sub set_error_message {
	my ( $self, $accession, $message ) = @_;
	$self->key( $accession );
	$self->message( $message );
	$self->triggered( 1 );
	return $self;
}

sub get_error_message {
	my ($self) = @_;
	return $self->key.": ".$self->message;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;