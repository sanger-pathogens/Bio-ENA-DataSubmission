package Bio::ENA::DataSubmission::Validator::Error::LatLon;

# ABSTRACT: Module for validation of lat/lon coordinates of sampling location

=head1 SYNOPSIS

Checks -90 < lat < 90 && -180 < lon < 180

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'latlon'      => ( is => 'ro', isa => 'Str', required => 1 );
has 'accession'   => ( is => 'ro', isa => 'Str', required => 1 );

sub validate {
	my $self   = shift;
	my $acc    = $self->accession;
	my $latlon = $self->latlon;
	
	my @ll = split( $latlon, '/' );
	$self->set_error_message( $acc, "Lat/Lon format incorrect. Please use XX.XX/XX.XX E.G. 53.71/-6.35" ) unless ( $#ll == 1 );		

	chomp @ll;
	my $lat = float( $ll[0] ) or $self->set_error_message( $acc, "Latitude does not appear to be a number" );
	my $lon = float( $ll[1] ) or $self->set_error_message( $acc, "Longitude does not appear to be a number" );

	$self->set_error_message( $acc, "Latitude should fall between +/- 90" ) unless ( $lat >= -90 && $lat <= 90 );
	$self->set_error_message( $acc, "Longitude should fall between +/- 180" ) unless ( $lon >= -180 && $lon <= 180 );

	return $self;
}

sub fix_it {
	
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;