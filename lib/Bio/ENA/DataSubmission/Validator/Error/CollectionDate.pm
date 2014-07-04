package Bio::ENA::DataSubmission::Validator::Error::CollectionDate;

# ABSTRACT: Module for validation of collection date from manifest

=head1 SYNOPSIS

Checks that collection date is in correct format

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'collection_date' => ( is => 'ro', isa => 'Str', required => 1 );
has 'accession'       => ( is => 'ro', isa => 'Str', required => 1 );

sub validate {
	my $self = shift;
	my $date = $self->collection_date;
	my $acc  = $self->accession;

	my $format = (
		   $date =~ m/\d{4}-\d{2}-\d{2}/ 
		|| $date =~ m/\d{4}-\d{2}/
		|| $date =~ m/\d{4}/
	);

	$self->set_error_message( $acc, "Incorrect collection_date format. Must match YYYY, YYYY-MM or YYYY-MM-DD" ) if ( $format );

	return $self;
}

sub fix_it {

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;