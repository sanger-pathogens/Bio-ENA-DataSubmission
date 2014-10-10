package Bio::ENA::DataSubmission::Validator::Error::LatLon;

# ABSTRACT: Module for validation of lat/lon coordinates of sampling location

=head1 SYNOPSIS

Checks -90 < lat < 90 && -180 < lon < 180

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'latlon'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'identifier'   => ( is => 'ro', isa => 'Str', required => 1 );

sub validate {
	my $self   = shift;
	my $id    = $self->identifier;
	my $latlon = $self->latlon;
	
	# check format first
	my @ll = split( '/', $latlon );
	unless ( $#ll == 1 ){
		$self->set_error_message( $id, "Lat/Lon format incorrect. Please use XX.XX/XX.XX E.G. 53.71/-6.35" );		
		return $self;
	}

	chomp @ll;
	my ( $lat, $lon ) = @ll;
	# check for numbers
	unless( $lat =~ m/[\d\-\.]+/ ) {
		$self->set_error_message( $id, "Latitude does not appear to be a number" );
		return $self;
	}
	unless( $lon =~ m/[\d\-\.]+/ ) {
		$self->set_error_message( $id, "Longitude does not appear to be a number" );
		return $self;
	}	
	# check numbers are in valid ranges
	unless ( $lat >= -90 && $lat <= 90 ){
		$self->set_error_message( $id, "Latitude should fall between +/- 90" );
		return $self;
	}
	unless ( $lon >= -180 && $lon <= 180 ){
		$self->set_error_message( $id, "Longitude should fall between +/- 180" );
		return $self;
	}

	return $self;
}

sub fix_it {
	
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;