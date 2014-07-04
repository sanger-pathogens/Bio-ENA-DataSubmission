package Bio::ENA::DataSubmission::Validator::Report;

# ABSTRACT: module for reporting of validation errors

=head1 NAME

Bio::ENA::DataSubmission::Validator::Report

=head1 SYNOPSIS


=head1 METHODS


=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;

has 'errors'              => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'             => ( is => 'rw', isa => 'Str',      required => 0 );

sub print {
	my ($self) = @_;
	
	open( FH, $self->outfile );

	for my $error ( @{ $self->errors } ){
		my $error_message = $error->get_error_message;
		print FH "$error_message\n";
	}

}

__PACKAGE__->meta->make_immutable;
no Moose;
1;