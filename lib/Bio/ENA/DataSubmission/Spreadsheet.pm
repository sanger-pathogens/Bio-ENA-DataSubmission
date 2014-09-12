package Bio::ENA::DataSubmission::Spreadsheet;

# ABSTRACT: module for parsing, appending and writing spreadsheets for ENA manifests

=head1 NAME

Bio::ENA::DataSubmission::Spreadsheet

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::Spreadsheet;
	my $spreadsheet = Bio::ENA::DataSubmission::Spreadsheet->new( infile => 'test.xls');
	my $data = $spreadsheet->parse;

	my $spreadsheet = Bio::ENA::DataSubmission::Spreadsheet->new( data => \@data, outfile => 'test.xls', );
	$spreadsheet->write_xls;


=head1 METHODS

parse, write_xls, append

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;
use Data::Dumper;

use lib "/software/pathogen/internal/prod/lib";
use Spreadsheet::ParseExcel;
use Spreadsheet::WriteExcel;
use Bio::ENA::DataSubmission::Exception;

has 'infile'              => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'             => ( is => 'rw', isa => 'Str',      required => 0 );
has 'data'                => ( is => 'rw', isa => 'ArrayRef', required => 0 );
has 'add_manifest_header' => ( is => 'ro', isa => 'Bool',     required => 0, default =>    0 );
has '_header'             => ( is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1 );

sub _build__header {
	# maybe this can adapt to different schemas at some point
	my @header = qw(sample_accession sanger_sample_name supplier_name sample_alias tax_id* 
					scientific_name* common_name anonymized_name sample_title	
					sample_description bio_material culture_collection	
					specimen_voucher collected_by collection_date* country*
					host* host_status* identified_by isolation_source* lat_lon
					lab_host environmental_sample mating_type isolate strain*
					sub_species sub_strain serovar*);
	return \@header;
}

sub parse{
	my ($self) = @_;
	my $infile = $self->infile;
	my @data;

	(-e $infile) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find file: $infile\n" );
	(-r $infile) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "File $infile cannot be read\n" );

	my $parser = Spreadsheet::ParseExcel->new();
	my $workbook = $parser->parse($infile);

	Bio::ENA::DataSubmission::Exception::EmptySpreadsheet->throw( error => "Spreadsheet $infile could not be parsed. Perhaps it's empty?\n" ) unless ( defined $workbook );

	for my $worksheet ( $workbook->worksheets() ){
    	my ( $row_min, $row_max ) = $worksheet->row_range();
    	my ( $col_min, $col_max ) = $worksheet->col_range();

    	for my $row ( $row_min .. $row_max ) {
        	for my $col ( $col_min .. $col_max ) {
        		my $cell = $worksheet->get_cell($row, $col);
        		$data[$row][$col] = $cell->value() if ( defined $cell );
        	}
    	}
	}

	@data = _cleanup_whitespace( \@data );

	return \@data;
}

sub _cleanup_whitespace {
	my ($d) = @_;
	my @data = @{ $d };

	my @header = @{ shift @data };
	my @clean = ( \@header );
	foreach my $row ( @data ){
		next unless( defined $row );
		my $keep = 0;
		my @trimmed_row;
		foreach my $c ( 0..$#header ){
			my $cell = $row->[$c];
			push(@trimmed_row, $cell);
			next unless( defined $cell );
			if ( $cell =~ /\S/ ){
				$keep = 1;
			}
		}
		push( @clean, \@trimmed_row ) if ( $keep );
	}

	return @clean;
}

sub write_xls{
	my ($self) = @_;
	my @data = @{ $self->data };
	my $outfile = $self->outfile;

	# check sanity
	system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "File $outfile cannot be written to\n");
	( defined $data[0] ) or Bio::ENA::DataSubmission::Exception::NoData->throw( error => "No data was supplied to the spreadsheet reader\n");

	my $workbook = Spreadsheet::WriteExcel->new($outfile);
	my $worksheet = $workbook->add_worksheet();

	my ($i, $j) = (0, 0);
	if ($self->add_manifest_header){
		$self->_write_header($workbook, $worksheet);
		$i++;
	}

	foreach my $row ( @data ) {
		$j = 0;
		foreach my $cell ( @{ $row } ) {
			$worksheet->write( $i, $j, $cell );
			$j++;
		}
		$i++;
	}
	return 1;
}

sub _write_header{
	my ( $self, $workbook, $worksheet ) = @_;
	my $outfile = $self->outfile;

	my %green = ( bg_color => 'lime' );
	my $mandatory = $workbook->add_format(%green);
	my @header = @{ $self->_header };

	my $c = 0;
	foreach my $h (@header){
		if( $h =~ /\*$/ ){
			$h =~ s/\*$//;
			$worksheet->write( 0, $c, $h, $mandatory );
		}
		else{
			$worksheet->write( 0, $c, $h );
		}
		$c++;
	}
}

sub parse_manifest{
	my $self = shift;

	my @manifest = @{ $self->parse };
	my @header = @{ shift @manifest };

	my @data;
	foreach my $row ( @manifest ){
		push( @data, {} );
		for my $c ( 0..$#{$row} ){
			my $key = $header[$c] eq 'host' ? 'specific_host' : $header[$c];
			$data[-1]->{$key} = $row->[$c];
		}
	}
	return \@data;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;