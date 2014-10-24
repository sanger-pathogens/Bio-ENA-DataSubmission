use strict;
use warnings;
use XML::Simple;

package Bio::ENA::DataSubmission::XMLSimple::Analysis;
use base 'XML::Simple';
# ABSTRACT: XMLSimple Analysis

sub sorted_keys {
	my ( $self, $name, $hashref ) = @_;

	my @ordered = (
		"ANALYSIS_SET", "ANALYSIS", "IDENTIFIERS", "TITLE", "DESCRIPTION", 
		"STUDY_REF", "SAMPLE_REF", "EXPERIMENT_REF", "RUN_REF", "ANALYSIS_REF", "ANALYSIS_TYPE",
		"SEQUENCE_ASSEMBLY", "NAME", "PARTIAL", "COVERAGE", "PROGRAM", "PLATFORM",
		"FILES", "FILE", "ANALYSIS_LINK", "ANALYSIS_ATTRIBUTE"
	);

	my %ordered_hash = map {$_ => 1} @ordered;
	return grep {exists $hashref->{$_}} @ordered, grep {not $ordered_hash{$_}} $self->SUPER::sorted_keys($name, $hashref);
}

1;