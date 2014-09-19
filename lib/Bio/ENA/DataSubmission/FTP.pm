package Bio::ENA::DataSubmission::FTP;

# ABSTRACT: module for uploading data to ENA FTP server

=head1 NAME

Bio::ENA::DataSubmission::FTP

=head1 SYNOPSIS

	

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;
use Net::FTP;

has 'server'   => ( is => 'rw', isa => 'Str',      required => 0, default => 'webin.ebi.ac.uk' );
has 'username' => ( is => 'rw', isa => 'Str',      required => 0, default => '' );
has 'password' => ( is => 'rw', isa => 'Str',      required => 0, default => '' );
has 'files'    => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'error'    => ( is => 'rw', isa => 'Str',      required => 0 );

sub upload {
	my $self = shift;

	my $server   = $self->server;
	my $username = $self->username;
	my $password = $self->password;

	# check files exist first
	for my $file ( @{ $self->files } ){
		unless( -e $file ){
			$self->error( "Cannot find $file\n" );
			return 0;
		}
	}

	# open FTP connection
	unless ( my $ftp = Net::FTP->new( $server ) ){
		$self->error( "Cannot connect to $server" );
		return 0;
	}

	# authenticate
	unless ( $ftp->login( $username, $password ) ) {
		$self->error( "Authentication failed for $server" );
		return 0;
	}

	$ftp->binary(); # set mode

	for my $file ( @{ $self->files } ){
		unless ( $ftp->put( $file ) ){
			$self->error( "Failed to upload $file\n" );
			return 0;
		}
	}

	unless ( $ftp->quit ) {
		$self->error( $ftp->message );
		return 0;
	}

	return 1;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;