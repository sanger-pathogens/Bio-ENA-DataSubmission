package Bio::ENA::DataSubmission::Validator::EMBL;

# ABSTRACT: Embl validator

=head1 SYNOPSIS

Wrapper around ENA's validation .jar file

=method 

=cut

use Moose;

has 'jar_path'   => ( is => 'rw', isa => 'Str', required => 1 );
has 'embl_files' => ( is => 'rw', isa => 'ArrayRef', required => 1 );

sub validate {
	my ($self) = @_;

	my @files = @{ $self->embl_files };
	my $jar   = $self->jar_path;

	my $cmd = "java -classpath $jar uk.ac.ebi.client.EnaValidator -r " . join( " ", @files );
	system($cmd);
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;
