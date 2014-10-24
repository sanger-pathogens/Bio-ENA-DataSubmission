package Bio::ENA::DataSubmission;

# ABSTRACT: module for submitting data via the ENA's REST interface

=head1 NAME

Bio::ENA::DataSubmission

=head1 SYNOPSIS

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
use Moose;
use Bio::ENA::DataSubmission::Exception;

has 'submission'                 => ( is => 'ro', isa => 'Str', required => 1 );
has 'receipt'                    => ( is => 'ro', isa => 'Str', required => 1 );
has 'ena_login_string'           => ( is => 'ro', isa => 'Str', required => 1 );
has 'ena_dropbox_submission_url' => ( is => 'ro', isa => 'Str', required => 1 );

has 'study'                      => ( is => 'ro', isa => 'Str', required => 0 );
has 'sample'                     => ( is => 'ro', isa => 'Str', required => 0 );
has 'experiment'                 => ( is => 'ro', isa => 'Str', required => 0 );
has 'analysis'                   => ( is => 'ro', isa => 'Str', required => 0 );
has 'run'                        => ( is => 'ro', isa => 'Str', required => 0 );
has 'project'                    => ( is => 'ro', isa => 'Str', required => 0 );

has '_ena_url'                   => ( is => 'rw', isa => 'Str', required => 0, lazy_build => 1 );
has '_submission_cmd'            => ( is => 'rw', isa => 'Str', required => 0, lazy_build => 1 );

sub _build__ena_url {
	my $self = shift;

	my $url = $self->ena_dropbox_submission_url . $self->ena_login_string;
	return $url;
}

sub _build__submission_cmd {
	my $self = shift;

	my $cmd = 'curl -k -F "SUBMISSION=@' . $self->submission . '"';

    $cmd .= ' -F "STUDY=@'      . $self->study      . '"' if ( defined $self->study );
    $cmd .= ' -F "SAMPLE=@'     . $self->sample     . '"' if ( defined $self->sample );
    $cmd .= ' -F "EXPERIMENT=@' . $self->experiment . '"' if ( defined $self->experiment );
    $cmd .= ' -F "ANALYSIS=@'   . $self->analysis   . '"' if ( defined $self->analysis );
    $cmd .= ' -F "RUN=@'        . $self->run        . '"' if ( defined $self->run );
    $cmd .= ' -F "PROJECT=@'    . $self->project    . '"' if ( defined $self->project );

    $cmd .= ' "' . $self->_ena_url . '"';
    $cmd .= ' > ' . $self->receipt;

    return $cmd;
}

sub submit {
    my $self = shift;

    my $check = $self->_check_files;
    Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find $check" ) if ( $check );

    my $cmd = $self->_submission_cmd;
    system( $cmd );
}

sub _check_files {
	my $self = shift;

	return $self->submission unless ( -e $self->submission );
	return $self->study      unless ( !defined $self->study || -e $self->study );
	return $self->sample     unless ( !defined $self->sample || -e $self->sample );
	return $self->experiment unless ( !defined $self->experiment || -e $self->experiment );
	return $self->analysis   unless ( !defined $self->analysis || -e $self->analysis );
	return $self->run        unless ( !defined $self->run || -e $self->run );
	return $self->project    unless ( !defined $self->project || -e $self->project );

	return 0;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;