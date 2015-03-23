package Bio::ENA::DataSubmission::Validator::Error::Country;

# ABSTRACT: Module for validation of country from manifest

=head1 SYNOPSIS

Checks that country is in correct format

=cut

use Moose;
use File::Slurp::Tiny 'read_lines';
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'country'              => ( is => 'rw', isa => 'Str', required => 1 );
has 'identifier'           => ( is => 'ro', isa => 'Str', required => 1 );
has 'valid_countries'      => ( is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_build_valid_countries');
has 'valid_countries_file' => ( is => 'ro', isa => 'Str', default => 'valid_countries.txt' );
has 'data_root'            => ( is => 'ro', isa => 'Str', default => './data' );


sub _build_valid_countries
{
	my($self) = @_;
	my @countries = read_lines($self->data_root.'/'.$self->valid_countries_file, chomp => 1);
	return \@countries;
}

sub validate {
	my $self = shift;
	my $country = $self->country;
	my $acc  = $self->identifier;
	
	my $format = (
		   $country =~ m/^[^:\d*]+(: .+)?$/ 
	);
	$self->set_error_message( $acc, "Incorrect country format. Must match country: region, locality. E.G. United Kingdom: England, Norfolk, Blakeney Point" ) unless ( $format );

    my $found_valid_country = 0;
    for my $valid_country(@{$self->valid_countries})
	{
		if($country =~ /^$valid_country/)
		{
			$found_valid_country = 1;
			return $self;
		}
	}
	if($found_valid_country == 0)
	{
		$self->set_error_message( $acc, "Country name isnt in the controlled vocabulary, see http://www.insdc.org/country.html" );
	}

	return $self;
}

sub fix_it {
	my($self) = @_;
	
	my %alias_to_country = (
		'UK'            => 'United Kingdom',  
		'Great Britain' => 'United Kingdom',
	    'England'       => 'United Kingdom: England', 
	    'Scotland'      => 'United Kingdom: Scotland',
		'Wales'         => 'United Kingdom: Wales',
		'London'        => 'United Kingdom: England, London',
		'Cambridge'     => 'United Kingdom: England, Cambridge',
		'US'            => 'USA',
	);
	
	for my $alias (keys %alias_to_country)
	{
		if($self->country eq $alias)
		{
			$self->country($alias_to_country{$alias});
			return 1; 
		}
	}
	return 0;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;