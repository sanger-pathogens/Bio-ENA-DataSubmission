use strict;
use warnings;
use XML::Simple;

package Bio::ENA::DataSubmission::XMLSimple::Submission;
use base 'XML::Simple';

use Data::Dumper;

sub sorted_keys {
	my ( $self, $name, $hashref ) = @_;

	my @ordered = (
		"IDENTIFIERS", "TITLE", "CONTACTS", "CONTACT", "ACTIONS", 
		"ACTION", "ADD", "MODIFY", "CANCEL", "SURPRESS",
		"HOLD", "RELEASE", "PROTECT", "VALIDATE", "SUBMISSION_LINKS",
		"SUBMISSION_LINK", "SUBMISSION_ATTRIBUTES", "SUBMISSION_ATTRIBUTE"
	);

	my %ordered_hash = map {$_ => 1} @ordered;
	return grep {exists $hashref->{$_}} @ordered, grep {not $ordered_hash{$_}} $self->SUPER::sorted_keys($name, $hashref);
}

1;