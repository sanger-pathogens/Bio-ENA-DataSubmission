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

has 'errors'              => ( is => 'rw', isa => 'ArrayRef', required => 1 );
has 'outfile'             => ( is => 'rw', isa => 'Str',      required => 1 );

sub print {
	my ($self) = @_;
	my @error_list = @{ $self->errors };
	
	open( FH, '>', $self->outfile );

	# print summary
	my $num_errors = scalar( @error_list );
	my $result = $num_errors == 0 ? "PASS" : "FAIL";
	print FH "Validation result: $result\tErrors: $num_errors\n";

	# print errors
	for my $error ( @error_list ){
		my $error_message = $error->get_error_message;
		print FH "$error_message\n";
	}

	close FH;

}

__PACKAGE__->meta->make_immutable;
no Moose;
1;