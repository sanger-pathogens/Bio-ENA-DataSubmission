package Bio::ENA::DataSubmission::Validator::EMBL;

# ABSTRACT: 

=head1 SYNOPSIS

Wrapper around ENA's validation .jar file

=method 

=cut

use Moose;

has 'jar_path'   => ( is => 'rw', isa => 'Str',      default => '/Users/cc21/bin/embl-client.jar' );
has 'embl_files' => ( is => 'rw', isa => 'ArrayRef', required => 1 );

sub validate {
	my $self = @_;

	my @files = @{ $self->embl_files };
	my $jar   = $self->jar_path;

	my $cmd = "java -classpath $jar uk.ac.ebi.client.EnaValidator -r -l 0 " . join( " ", @files );
	system($cmd);
}