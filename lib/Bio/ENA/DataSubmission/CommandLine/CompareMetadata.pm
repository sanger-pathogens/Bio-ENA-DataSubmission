package Bio::ENA::DataSubmission::CommandLine::CompareMetadata;

# ABSTRACT: module for comparing ENA metadata against local metadata

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::CompareMetadata

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::CommandLine::CompareMetadata;
	
	1. pull XML from ENA using http://www.ebi.ac.uk/ena/data/view/ERS*****&display=xml
	2. parse to data structure
	3. parse manifest to same data structure
	4. compare data structures
	5. print report

=head1 METHODS



=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;

use Bio::ENA::DataSubmission::Exception;

has 'args' => ( is => 'rw', isa => 'Str', required => 0 );

sub run{
	my ($self) = @_;

	
}

sub _parse_manifest{

}

sub _parse_xml{

}

sub _compare_metadata{

}

sub _report{

}


__PACKAGE__->meta->make_immutable;
no Moose;
1;