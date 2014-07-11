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
use LWP;

# BEGIN {
#   $ENV{HTTP_PROXY} = 'http://wwwcache.sanger.ac.uk:3128';
# }

has 'xml'     => ( is => 'rw', isa => 'Str',     required => 0 );
has 'url'     => ( is => 'ro', isa => 'Str',     required => 0 );
has 'data'    => ( is => 'rw', isa => 'HashRef', required => 0 );
has 'xsd'     => ( is => 'ro', isa => 'Str',     required => 0 );
has 'outfile' => ( is => 'rw', isa => 'Str',     required => 0 );

sub validate {

}

sub update {

}

sub parse_from_file {

}

sub parse_from_url {
	my $self = shift;
	my $url = $self->url;

	my $ua = LWP::UserAgent->new;
	$ua->proxy(['http', 'https'], 'http://wwwcache.sanger.ac.uk:3128');
	my $req = HTTP::Request->new( GET => $url );
	my $res = $ua->request( $req );

	$res->is_success or Bio::ENA::DataSubmission::Exception::ConnectionFail->throw( error => "Could not connect to $url\n" );

	return (XML::Simple->new()->XMLin( $res->content ));
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;