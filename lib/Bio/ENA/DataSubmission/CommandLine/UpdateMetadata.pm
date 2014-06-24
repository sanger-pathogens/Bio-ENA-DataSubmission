package Bio::ENA::DataSubmission::CommandLine::UpdateMetadata;

# ABSTRACT: module for updating ENA metadata with local metadata

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::UpdateMetadata

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::CommandLine::UpdateMetadata;
	
	1. validate manifest, die if not met
	2. pull XML for each sample
	3. update XML with data from manifest
	4. generate submission XML
	5. validate XMLs with XSDs
	6. submit all files for each submission via curl
	7. wait for confirmation XML?
	8. repeat if required

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
has '_xml_dest' => ( is => 'rw', isa => 'Str', required => 0, lazy_build => 1 );

sub _build__xml_dest{
	my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
	return $temp_directory_obj->dirname();
}

sub run{
	my ($self) = @_;

	
}



__PACKAGE__->meta->make_immutable;
no Moose;
1;