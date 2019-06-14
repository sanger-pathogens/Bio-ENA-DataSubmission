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
use File::Slurp;

use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::XML;
use Bio::ENA::DataSubmission::Spreadsheet;
use Getopt::Long qw(GetOptionsFromArray);

has 'args'     => ( is => 'ro', isa => 'ArrayRef',   required => 1 );

has 'manifest' => ( is => 'rw', isa => 'Str',        required => 0 );
has 'outfile'  => ( is => 'rw', isa => 'Maybe[Str]', required => 0 );
has 'help'     => ( is => 'rw', isa => 'Bool',       required => 0 );

has 'config_file' => ( is => 'rw', isa => 'Maybe[Str]',      required => 0, default => $ENV{'ENA_SUBMISSIONS_CONFIG'});
has 'proxy'           => ( is => 'rw', isa => 'Maybe[Str]');
has 'ena_base_path'   => ( is => 'rw', isa => 'Maybe[Str]');


sub BUILD {
	my ( $self ) = @_;

	my ( $file, $outfile, $help,$config_file );
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		'f|file=s'    => \$file,
		'o|outfile=s' => \$outfile,
		'h|help'      => \$help,
		'c|config_file=s' => \$config_file
	);

	$self->manifest($file)   if ( defined $file );
	$self->outfile($outfile) if ( defined $outfile );
	$self->help($help)       if ( defined $help );
	
	$self->config_file($config_file) if ( defined $config_file );
	( -e $self->config_file ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find config file\n" );
	$self->_populate_attributes_from_config_file;
}

sub _populate_attributes_from_config_file
{
  my ($self) = @_;
  my $file_contents = read_file($self->config_file);
  my $config_values = eval($file_contents);
  $self->proxy($config_values->{proxy});
  $self->ena_base_path($config_values->{ena_base_path});
}

sub check_inputs{
    my $self = shift; 
    return(
        $self->manifest
        && !$self->help
    );
}

sub _check_can_write {
	my (undef, $outfile) = @_;
	open(FILE, ">", $outfile) or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" );
	close(FILE);
}

sub run{
	my ($self) = @_;
	my $manifest = $self->manifest;
	my $outfile = $self->outfile;

	# sanity checks
	$self->check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	( -e $manifest ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find $manifest\n" );
	( -r $manifest ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $manifest\n" );
	$outfile = "$manifest.report.xls" unless( defined( $outfile ) );
	$self->outfile($outfile);
	$self->_check_can_write($outfile);

	# loop through manifest and compare to XML from ENA
	my @conflicts;
	my $parser = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $manifest );
	my $xml_handler = Bio::ENA::DataSubmission::XML->new(ena_base_path => $self->ena_base_path, proxy => $self->proxy);
	foreach my $entry ( @{ $parser->parse_manifest } ){
		next unless ( defined $entry->{'sample_accession'} );
		my $ena_meta = $xml_handler->parse_xml_metadata( $entry->{'sample_accession'} );
		push( @conflicts, $self->_compare_metadata( $entry, $ena_meta ) );
	}

	$self->_report( \@conflicts );
}

sub _compare_metadata{
	my (undef, $man_hr, $ena_hr) = @_;
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
			next if ($man_v eq '' || $ena_v eq '');
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
Usage: compare_sample_metadata [options]

	-f|file       input manifest for comparison
	-o|outfile    output path for comparison report
	-h|help       this help message

USAGE
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;