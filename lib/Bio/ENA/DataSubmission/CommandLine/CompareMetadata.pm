package Bio::ENA::DataSubmission::CommandLine::CompareMetadata;

# ABSTRACT: module for comparing ENA metadata against local metadata

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::CompareMetadata

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::CommandLine::CompareMetadata;
	
	1. pull XML from ENA using http://www.ebi.ac.uk/ena/data/view/ERS*****&display=xml
	2. parse to data structure
	3. parse manifest to same data structure
	4. compare data structures
	5. print report

=head1 METHODS



=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;
use Data::Dumper;

use lib "/software/pathogen/internal/prod/lib";
use lib "../lib";
use lib "./lib";

use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::XML;
use Bio::ENA::DataSubmission::Spreadsheet;
use Getopt::Long qw(GetOptionsFromArray);

has 'args'     => ( is => 'ro', isa => 'ArrayRef',   required => 1 );

has 'manifest' => ( is => 'rw', isa => 'Str',        required => 0 );
has 'schema'   => ( is => 'rw', isa => 'Str',        required => 0, default => 'data/ERC000028.xml' );
has 'outfile'  => ( is => 'rw', isa => 'Maybe[Str]', required => 0 );
has 'help'     => ( is => 'rw', isa => 'Bool',       required => 0 );

sub BUILD {
	my ( $self ) = @_;

	my ( $file, $schema, $outfile, $help );
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		'f|file=s'    => \$file,
		's|schema=s'  => \$schema,
		'o|outfile=s' => \$outfile,
		'h|help'      => \$help
	);

	$self->manifest($file)   if ( defined $file );
	$self->schema($schema)   if ( defined $schema );
	$self->outfile($outfile) if ( defined $outfile );
	$self->help($help)       if ( defined $help );
}

sub check_inputs{
    my $self = shift; 
    return(
        $self->manifest
        && !$self->help
    );
}

sub run{
	my ($self) = @_;
	my $manifest = $self->manifest;
	my $schema = $self->schema;
	my $outfile = $self->outfile;

	# sanity checks
	$self->check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	( -e $manifest ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find $manifest\n" );
	( -r $manifest ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $manifest\n" );
	$outfile = "$manifest.report.xls" unless( defined( $outfile ) );
	$self->outfile($outfile);
	system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" ) if ( defined $outfile );

	# loop through manifest and compare to XML from ENA
	my @conflicts;
	my $parser = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $manifest );
	my $xml_handler = Bio::ENA::DataSubmission::XML->new();
	foreach my $entry ( @{ $parser->parse_manifest } ){
		next unless ( defined $entry->{'sample_accession'} );
		my $ena_meta = $xml_handler->parse_xml_metadata( $entry->{'sample_accession'} );
		push( @conflicts, $self->_compare_metadata( $entry, $ena_meta ) );
	}

	$self->_report( \@conflicts );
}

sub _compare_metadata{
	my ($self, $man_hr, $ena_hr) = @_;
	my %ena_data = %{ $ena_hr };
	my %man_data = %{ $man_hr };

	my $acc = $man_data{'sample_accession'};
	my $sample_name = $man_data{'sanger_sample_name'};

	my @conflicts;
	foreach my $k ( keys %ena_data ){
		my $ena_v = $ena_data{$k};
		chomp $ena_v;
		my $man_v = $man_data{$k};
		if( defined $man_v ){
			chomp $man_v;
			push( @conflicts, [$acc, $sample_name, $k, $man_v, $ena_v] ) unless ( $ena_v eq $man_v );
		}
	}
	return @conflicts;
}

sub _report{
	my ( $self, $c ) = @_;
	my $outfile = $self->outfile;

	Bio::ENA::DataSubmission::Exception::NoData->throw("No data supplied for reporting\n") unless ( defined $c );

	my @data = @{ $c };
	if ($#data >= 0){
		unshift(@data, ['Accession', 'Sanger Sample Name', 'Field', 'Manifest', 'ENA']);
		unshift(@data, ['Total Conflicts', $#data]);
	}
	else{
		unshift(@data, ['Total Conflicts', 0]);	
	}
	my $xls = Bio::ENA::DataSubmission::Spreadsheet->new( data => \@data, outfile => $outfile );
	$xls->write_xls;
}

sub usage_text {
	return <<USAGE;
Usage: validate_sample_manifest [options]

	-f|file       input manifest for comparison
	-o|outfile    output path for comparison report
	-h|help       this help message

USAGE
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;