package Bio::ENA::DataSubmission::ConfigReader;

# ABSTRACT: reads a config file and expose the properties

=head1 NAME

Bio::ENA::DataSubmission::ConfigReader

=head1 SYNOPSIS

Reads a config file and returns the corresponding hash

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use Moose;
use File::Slurp qw(read_file);

has 'config_file'     => ( is => 'rw', isa => 'Str',      required => 0, default    => '/software/pathogen/config/ena_data_submission.conf');


sub get_config
{
  my ($self) = @_;
  my $file_contents = read_file($self->config_file);
  return eval($file_contents);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;