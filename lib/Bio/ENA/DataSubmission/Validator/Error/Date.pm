package Bio::ENA::DataSubmission::Validator::Error::Date;

# ABSTRACT: Module for validation of collection date from manifest

=head1 SYNOPSIS

Checks that collection date is in correct format: YYYY-MM-DD, YYYY-MM or YYYY

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'date'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'identifier' => ( is => 'ro', isa => 'Str', required => 1 );

sub validate {
	my $self = shift;
	my $date = $self->date;
	my $id  = $self->identifier;

  if(defined($date) && $date eq 'NA' )
  {
    return $self;
  }

  # Todo: replace with proper date validation
	my $format = (
		      $date =~ m/^\d{2}-\w{3}-\d{4}$/
       || $date =~ m/^\d{2}-\w{3}-\d{4}\/\d{2}-\w{3}-\d{4}$/
       || $date =~ m/^\d{4}$/
       || $date =~ m/^\d{4}-\d{2}$/
       || $date =~ m/^\d{4}-\d{2}-\d{2}$/
       || $date =~ m/^\d{4}-\d{2}-\d{2}\/\d{4}-\d{2}-\d{2}$/
       || $date =~ m/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}Z$/
       || $date =~ m/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}Z\/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}Z$/
       || $date =~ m/^\d{4}-\d{2}-\d{2}T\d{2}Z$/
       || $date =~ m/^\d{4}-\d{2}\/\d{4}-02$/
       || $date =~ m/^\d{4}\/\d{4}$/
       || $date =~ m/^\w{3}-\d{4}$/
       || $date =~ m/^\w{3}-\d{4}\/\w{3}-\d{4}$/
	);

	$self->set_error_message( $id, "Incorrect date format. Must match YYYY, YYYY-MM, YYYY-MM-DD,... full list at http://www.ebi.ac.uk/ena/WebFeat/qualifiers/collection_date.html" ) unless ( $format );

	return $self;
}

sub fix_it {

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;