package Bio::ENA::DataSubmission::XML;

# ABSTRACT: module for parsing, appending and writing spreadsheets for ENA manifests

=head1 NAME

Bio::ENA::DataSubmission::XML

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::XML;
	


=head1 METHODS

parse, validate, update

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;

use Bio::ENA::DataSubmission::Exception;
use XML::Simple;

has 'xml'     => ( is => 'rw', isa => 'Str',     required => 0 );
has 'data'    => ( is => 'rw', isa => 'HashRef', required => 0 );
has 'xsd'     => ( is => 'ro', isa => 'Str',     required => 0 );
has 'outfile' => ( is => 'rw', isa => 'Str',     required => 0 );

sub validate{

}

sub update{

}

sub parse{

}

__PACKAGE__->meta->make_immutable;
no Moose;
1;