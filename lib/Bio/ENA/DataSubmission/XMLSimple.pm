use strict;
use warnings;
use XML::Simple;

package Bio::ENA::DataSubmission::XMLSimple;
use base 'XML::Simple';

use Data::Dumper;

sub sorted_keys {
	my ( $self, $name, $hashref ) = @_;

	my @ordered = (
		"IDENTIFIERS", "TITLE", "SAMPLE_NAME", "DESCRIPTION", "CHECKLIST", "SAMPLE_LINKS", "SAMPLE_ATTRIBUTES",
		"PRIMARY_ID", "SECONDARY_ID", "EXTERNAL_ID", "SUBMITTER_ID", "UUID",
		"TAXON_ID", "SCIENTIFIC_NAME", "COMMON_NAME", "ANONYMIZED_NAME", "INDIVIDUAL_NAME"
	);

	my %ordered_hash = map {$_ => 1} @ordered;
	return grep {exists $hashref->{$_}} @ordered, grep {not $ordered_hash{$_}} $self->SUPER::sorted_keys($name, $hashref);
}

1;