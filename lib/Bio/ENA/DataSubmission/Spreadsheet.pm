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

use Spreadsheet::ParseExcel;
use Spreadsheet::WriteExcel;
use Bio::ENA::DataSubmission::Exception;

has 'infile'              => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'             => ( is => 'rw', isa => 'Str',      required => 0 );
has 'data'                => ( is => 'rw', isa => 'ArrayRef', required => 0 );
has 'add_manifest_header' => ( is => 'ro', isa => 'Bool',     required => 0, default => 0 );

sub parse{
	my ($self) = @_;
	my $infile = $self->infile;
	my @data;

	(-e $infile) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find file: $infile\n" );
	(-r $infile) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "File $infile cannot be read\n" );

	my $parser = Spreadsheet::ParseExcel->new();
	my $workbook = $parser->parse($infile);

	for my $worksheet ( $workbook->worksheets() ){
    	my ( $row_min, $row_max ) = $worksheet->row_range();
    	my ( $col_min, $col_max ) = $worksheet->col_range();

    	for my $row ( $row_min .. $row_max ) {
        	for my $col ( $col_min .. $col_max ) {
        		$data[$row][$col] = $worksheet->get_cell($row, $col)->value();
        	}
    	}
	}
	return \@data;
}

sub write_xls{
	my ($self) = @_;
	my @data = @{ $self->data };
	my $outfile = $self->outfile;

	# check sanity
	#( -w $outfile ) or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "File $outfile cannot be written to\n");
	( @data ) or Bio::ENA::DataSubmission::Exception::NoData->throw( error => "No data was supplied to the spreadsheet reader\n");

	my $workbook = Spreadsheet::WriteExcel->new($outfile);
	my $worksheet = $workbook->add_worksheet();

	my ($i, $j) = (0, 0);
	if ($self->add_manifest_header){
		$self->_write_header($workbook, $worksheet);
		$i++;
	}

	foreach my $row ( @data ) {
		foreach my $cell ( @{ $row } ) {
			$worksheet->write( $i, $j, $cell );
			$j++;
		}
		$i++;
	}

}

sub _write_header{
	my ( $self, $workbook, $worksheet ) = @_;
	my $outfile = $self->outfile;

	my %green = ( bg_color => 'lime' );
	my $mandatory = $workbook->add_format(%green);

	my @header = qw(sample_accession sanger_sample_name supplier_name sample_alias tax_id* 
					scientific_name* common_name anonymized_name sample_title	
					sample_description bio_material culture_collection	
					specimen_voucher collected_by collection_date* country*
					host* host_status* identified_by isolation_source* lat_lon
					lab_host environmental_sample mating_type isolate strain*
					sub_species sub_strain serovar*);

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

__PACKAGE__->meta->make_immutable;
no Moose;
1;