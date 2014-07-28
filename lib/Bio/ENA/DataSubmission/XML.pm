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
use XML::LibXML;
use LWP;
use Switch;
use Data::Dumper;

has 'xml'     => ( is => 'rw', isa => 'Str',      required => 0 );
has 'url'     => ( is => 'rw', isa => 'Str',      required => 0 );
has 'data'    => ( is => 'rw', isa => 'HashRef',  required => 0 );
has 'xsd'     => ( is => 'ro', isa => 'Str',      required => 0 );
has 'outfile' => ( is => 'rw', isa => 'Str',      required => 0 );
has 'root'    => ( is => 'ro', isa => 'Str',      required => 0, default    => 'root' );
has '_fields' => ( is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1 );

sub _build__fields {
	# this will change with schema eventually
	my @f = qw(anonymized_name bio_material culture_collection	
					specimen_voucher collected_by collection_date country
					specific_host host_status identified_by isolation_source lat_lon
					lab_host environmental_sample mating_type isolate strain
					sub_species sub_strain serovar);
	return \@f;
}

sub validate {
	my $self = shift;
	my $xml  = $self->xml;
	my $xsd  = $self->xsd;

	( -e $xml ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Can't find file: $xml" );
	( -r $xml ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Can't read file: $xml" );
	( -e $xsd ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Can't find file: $xsd" );
	( -r $xsd ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Can't read file: $xsd" );

	my $p = XML::LibXML->new();
	my $doc = $p->parse_file( $xml );
	my $xsd_validator = XML::LibXML::Schema->new( location => $xsd );
	return ( $xsd_validator->validate( $doc ) ) ? 0 : 1;
}

sub update {
	my ( $self, $sample ) = @_;

	my $acc = $sample->{'sample_accession'};
	$self->url("http://www.ebi.ac.uk/ena/data/view/$acc&display=xml");
	my $xml = $self->parse_from_url;
	
	return undef unless( defined $xml->{SAMPLE} );

	my $sample_xml = $xml->{SAMPLE};
	delete $sample->{alias};
	delete $sample->{center_name};
	delete $sample->{SAMPLE_LINKS};
	
	my $v;
	foreach my $k ( keys $sample ){
		$v = $sample->{$k};
		$self->_update_fields( $sample_xml, $k, $v ) if ( defined $v && $v ne '' );
	}

	return $sample_xml;
}

sub _update_fields {
	my ( $self, $xml, $key, $value ) = @_;

	my $found = 0;

	# first check basic data
	switch($key){
		case 'sample_accession'   { $xml->{accession}                      = $value; $found = 1 }
		case 'sample_alias'       { $xml->{alias}                          = $value; $found = 1 }
		case 'tax_id'             { $xml->{SAMPLE_NAME}->{TAXON_ID}        = $value; $found = 1 }
		case 'scientific_name'    { $xml->{SAMPLE_NAME}->{SCIENTIFIC_NAME} = $value; $found = 1 }
		case 'common_name'        { $xml->{SAMPLE_NAME}->{COMMON_NAME}     = $value; $found = 1 }
		case 'sample_title'       { $xml->{TITLE}                          = $value; $found = 1 }
		case 'sample_description' { $xml->{DESCRIPTION}                    = $value; $found = 1 }
	}

	# if not found, then check sample attributes list
	unless( $found ){
		my @attrs = @{ $xml->{SAMPLE_ATTRIBUTES}->{SAMPLE_ATTRIBUTE} };
		foreach my $a ( 0..$#attrs){
			if ( $attrs[$a]->{TAG} eq $key ){
				$xml->{SAMPLE_ATTRIBUTES}->{SAMPLE_ATTRIBUTE}->[$a]->{VALUE} = $value;
				$found = 1;
				last;
			}
		}
	}

	# if still not found, add it
	unless ( $found ){
		push( @{ $xml->{SAMPLE_ATTRIBUTES}->{SAMPLE_ATTRIBUTE} }, {'TAG' => $key, 'VALUE' => $value} )
	}

}

sub parse_from_file {
	my $self = shift;
	my $xml = $self->xml;

	(defined $xml) or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => "XML file must be passed to read\n" );
	(-e $xml && -r $xml) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $xml\n" );

	return XML::Simple->new()->XMLin($xml);
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

sub write {
	my $self    = shift;
	my $outfile = $self->outfile;
	my $data    = $self->data;

	system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write file: $outfile\n" );

	my $writer = XML::Simple->new( RootName => $self->root, XMLDecl => '<?xml version="1.0" encoding="UTF-8"?>', NoAttr => 0 );
	my $out = $writer->XMLout( $data );
	open( OUT, '>', $outfile );
	print OUT $out;
	close OUT;
}

sub parse_xml_metadata{
	my ($self, $acc) = @_;

	$self->url("http://www.ebi.ac.uk/ena/data/view/$acc&display=xml");
	my $xml = $self->parse_from_url;
	my @fields = @{ $self->_fields };

	my %data;
	$data{'sample_title'} = $xml->{SAMPLE}->{TITLE} if (defined($xml->{SAMPLE}->{TITLE}));
	my $sample_name = $xml->{SAMPLE}->{SAMPLE_NAME} if (defined($xml->{SAMPLE}->{SAMPLE_NAME}));
	$data{'tax_id'} = $sample_name->{TAXON_ID} if (defined($sample_name->{TAXON_ID}));
	$data{'common_name'} = $sample_name->{COMMON_NAME} if (defined($sample_name->{TAXON_ID}));
	$data{'scientific_name'} = $sample_name->{SCIENTIFIC_NAME} if (defined($sample_name->{SCIENTIFIC_NAME}));

	my @attributes = @{ $xml->{SAMPLE}->{SAMPLE_ATTRIBUTES}->{SAMPLE_ATTRIBUTE} } if (defined($xml->{SAMPLE}->{SAMPLE_ATTRIBUTES}->{SAMPLE_ATTRIBUTE}));
	foreach my $att ( @attributes ){
		my $tag = $att->{TAG};
		next unless( defined $tag );
		$data{ $tag } = $att->{VALUE} if ( grep( /^$tag$/, @fields ) );
	}
	return \%data;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;