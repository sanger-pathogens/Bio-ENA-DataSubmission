package Bio::ENA::DataSubmission::Spreadsheet;

# ABSTRACT: module for parsing, appending and writing spreadsheets for ENA manifests

=head1 NAME

Bio::ENA::DataSubmission::Spreadsheet

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::Spreadsheet;
	my $spreadsheet = Bio::ENA::DataSubmission::Spreadsheet->new( infile => 'test.xls');
	my $data = $spreadsheet->parse;

	my $spreadsheet = Bio::ENA::DataSubmission::Spreadsheet->new( data => \@data, outfile => 'test.xls');
	$spreadsheet->write_xls;

	my $spreadsheet = Bio::ENA::DataSubmission::Spreadsheet->new( infile => 'test.xls', data => \@data, outfile => 'test_out.xls');
	$spreadsheet->append;

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
use Path::Find;
use Path::Find::Lanes;
use Bio::ENA::DataSubmission::Exception;

has 'infile'  => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile' => ( is => 'rw', isa => 'Str',      required => 0 );
has 'data'    => ( is => 'rw', isa => 'ArrayRef', required => 0 );
has 'add_manifest_header' => ( is => 'ro', isa => 'Bool', required => 0, default => 0 );

sub parse{
	
}

sub write_xls{
	
}

sub _write_header{
	
}




__PACKAGE__->meta->make_immutable;
no Moose;
1;