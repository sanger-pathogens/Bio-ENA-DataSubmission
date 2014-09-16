package Bio::ENA::DataSubmission::Validator::Error::File;

# ABSTRACT: Module for validation of file paths

=head1 SYNOPSIS

Checks that file exists and is read accessible

=cut

use Moose;
extends "Bio::ENA::DataSubmission::Validator::Error";

has 'file'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'identifier' => ( is => 'ro', isa => 'Str', required => 1 );

sub validate {
	my $self = shift;
	my $file = $self->file;
	my $id   = $self->identifier;

	if (! -e $file){
		$self->set_error_message( $id, "Cannot find file: $file" );
	}
	elsif (! -r $file){
		$self->set_error_message( $id, "$file is not read accessible" );	
	}

	return $self;
}

sub fix_it {

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;