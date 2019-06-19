package Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest;

# ABSTRACT: module for validation of manifest files for ENA metadata update

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::ValidateManifest

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::CommandLine::ValidateManifest;
	

=head1 METHODS



=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;
use File::Slurp;

use Getopt::Long qw(GetOptionsFromArray);
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::Spreadsheet;
use Bio::ENA::DataSubmission::Validator::Report;

# errors
use Bio::ENA::DataSubmission::Validator::Error::Date;
use Bio::ENA::DataSubmission::Validator::Error::General;
use Bio::ENA::DataSubmission::Validator::Error::SampleAccession;
use Bio::ENA::DataSubmission::Validator::Error::MandatoryCells;
use Bio::ENA::DataSubmission::Validator::Error::ProjectAccession;
use Bio::ENA::DataSubmission::Validator::Error::RunAccession;
use Bio::ENA::DataSubmission::Validator::Error::FileType;
use Bio::ENA::DataSubmission::Validator::Error::File;
use Bio::ENA::DataSubmission::Validator::Error::Number;
use Bio::ENA::DataSubmission::Validator::Error::Boolean;
use Bio::ENA::DataSubmission::Validator::Error::PubmedID;

has 'args'       => ( is => 'ro', isa => 'ArrayRef', required => 1 );

has 'file'       => ( is => 'rw', isa => 'Str',      required => 0 );
has 'report'     => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'    => ( is => 'rw', isa => 'Str',      required => 0 );
has 'edit'       => ( is => 'rw', isa => 'Bool',     required => 0 );
has 'help'       => ( is => 'rw', isa => 'Bool',     required => 0 );
has '_filetypes' => ( is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1 );
has 'ena_base_path'    => ( is => 'rw', isa => 'Str', default  => 'http://www.ebi.ac.uk/ena/data/view/');
has 'pubmed_url_base'  => ( is => 'rw', isa => 'Str', default  => 'http://www.ncbi.nlm.nih.gov/pubmed/?term=');

has 'config_file'     => ( is => 'rw', isa => 'Str',      required => 0, default    => $ENV{'ENA_SUBMISSIONS_CONFIG'});

sub _build__filetypes {
	return [ 'tab', 'bam', 'bai', 'cram', 'vcf', 'vcf_aggregate', 'tabix',
			'wig', 'bed', 'gff', 'fasta', 'contig_fasta', 'contig_flatfile',
			'scaffold_fasta', 'scaffold_flatfile', 'scaffold_agp', 'chromosome_fasta',
			'chromosome_flatfile', 'chromosome_agp', 'chromosome_list',
			'unlocalised_contig_list', 'unlocalised_scaffold_list',
			'sample_list', 'readme_file', 'phenotype_file', 'other'
	];
}


sub BUILD {
	my ( $self ) = @_;

	my ( $file, $report, $outfile, $edit, $help,$config_file );
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		'f|file=s'    => \$file,
		'r|report=s'  => \$report,
		'o|outfile=s' => \$outfile,
		'edit'        => \$edit,
		'h|help'      => \$help,
		'c|config_file=s'    => \$config_file
	);

	$self->file($file)       if ( defined $file );
	$self->report($report)   if ( defined $report );
	$self->outfile($outfile) if ( defined $outfile );
	$self->edit($edit)       if ( defined $edit );
	$self->help($help)       if ( defined $help );
	$self->config_file($config_file)       if ( defined $config_file );
	( -e $self->config_file ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find config file\n" );
	$self->_populate_attributes_from_config_file;
}

sub _populate_attributes_from_config_file
{
  my ($self) = @_;
  my $file_contents = read_file($self->config_file);
  my $config_values = eval($file_contents);

  $self->ena_base_path($config_values->{ena_base_path});
  $self->pubmed_url_base($config_values->{pubmed_url_base});
}

sub check_inputs{
    my $self = shift; 
    return(
        $self->file
        && !$self->help
    );
}

sub _check_can_write {
	my (undef, $outfile) = @_;
	open(FILE, ">", $outfile) or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw(error => "Cannot write to $outfile\n");
	close(FILE);
}

sub run {
	my $self = shift;

	my $file = $self->file;
	my $report = $self->report;
	my $outfile = $self->outfile;

	#---------------#
	# sanity checks #
	#---------------#

	$self->check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	( -e $file ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find $file\n" );
	( -r $file ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $file\n" );

	$report  = "$file.report.txt" unless( defined $report );
	$outfile = "$file.edit.xls"   unless( defined $outfile );

	$self->_check_can_write($outfile);
	$self->_check_can_write($report);

	#---------------#
	# read manifest #
	#---------------#

	my $parser = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $file );
	my @manifest = @{ $parser->parse };
	my @header = @{ shift @manifest };

	#------------#
	# validation #
	#------------#

	my @errors_found;
	foreach my $r ( 0..$#manifest ){
		next unless ( defined $manifest[$r] && defined $manifest[$r]->[0] );
		my @row = @{ $manifest[$r] };
		my $name = $row[0];

		# validate all generally
		for my $c ( 0..$#row ) {
			my $cell = $row[$c];
			if ( defined $cell ){
				my $gen_error = Bio::ENA::DataSubmission::Validator::Error::General->new( 
					identifier => $name,
					cell       => $cell,
					field      => $header[$c]
				)->validate;
				push( @errors_found, $gen_error ) if ( $gen_error->triggered );
			}
		}

		# validate more specific cells separately

		# mandatory cells
		my $mandatory = [ 0, 1, 2, 3, 4, 6, 7, 9, 10, 11 ];
		my $mandatory_error = Bio::ENA::DataSubmission::Validator::Error::MandatoryCells->new( 
			row => \@row, 
			mandatory => $mandatory
		)->validate;
		push( @errors_found, $mandatory_error ) if ( $mandatory_error->triggered );

		# partial
		my $partial_error = Bio::ENA::DataSubmission::Validator::Error::Boolean->new(
			identifier => $name,
			cell       => $row[1]
		)->validate;
		push( @errors_found, $partial_error ) if ( $partial_error->triggered );

		# coverage
		my $coverage_error = Bio::ENA::DataSubmission::Validator::Error::Number->new(
			identifier => $name,
			cell       => $row[2]
		)->validate;
		push( @errors_found, $coverage_error ) if ( $coverage_error->triggered );

		# minimum gap
		if ( $row[5] ){
			my $minimum_gap_error = Bio::ENA::DataSubmission::Validator::Error::Number->new(
				identifier => $name,
				cell       => $row[5]
			)->validate;
			push( @errors_found, $minimum_gap_error ) if ( $minimum_gap_error->triggered );
		}

		# file
		my $file_error = Bio::ENA::DataSubmission::Validator::Error::File->new(
			identifier => $name,
			file       => $row[6]
		)->validate;
		push( @errors_found, $file_error ) if ( $file_error->triggered );

		# file type
		my $file_type_error = Bio::ENA::DataSubmission::Validator::Error::FileType->new(
			identifier => $name,
			file_type  => $row[7],
			allowed    => $self->_filetypes
		)->validate;
		push( @errors_found, $file_type_error ) if ( $file_type_error->triggered );

		# study accession
		my $study_error = Bio::ENA::DataSubmission::Validator::Error::ProjectAccession->new(
			identifier => $name,
			accession => $row[10],
			ena_base_path => $self->ena_base_path
		)->validate;
		push( @errors_found, $study_error ) if ( $study_error->triggered );


		# sample accession
		my $sample_error = Bio::ENA::DataSubmission::Validator::Error::SampleAccession->new(
			identifier => $name,
			accession => $row[11],
			ena_base_path => $self->ena_base_path
		)->validate;
		push( @errors_found, $sample_error ) if ( $sample_error->triggered );

		# run accession
		if ( $row[12] ){
			my $run_error = Bio::ENA::DataSubmission::Validator::Error::RunAccession->new(
				identifier => $name,
				accession => $row[12],
				ena_base_path => $self->ena_base_path
			)->validate;
			push( @errors_found, $run_error ) if ( $run_error->triggered );
		}

		# analysis date
		if ( $row[14] ){
			my $analysis_date_error = Bio::ENA::DataSubmission::Validator::Error::Date->new(
				identifier => $name,
				date       => $row[14]
			)->validate;
			push( @errors_found, $analysis_date_error ) if ( $analysis_date_error->triggered );
		}

		# release date
		if ( $row[15] ){
			my $release_date_error = Bio::ENA::DataSubmission::Validator::Error::Date->new(
				identifier => $name,
				date       => $row[15]
			)->validate;
			push( @errors_found, $release_date_error ) if ( $release_date_error->triggered );
		}

		# pubmed id
		if ( $row[16] ){
			my $pubmed_id_error = Bio::ENA::DataSubmission::Validator::Error::PubmedID->new(
				identifier => $name,
				pubmed_id  => $row[16],
				pubmed_url_base => $self->pubmed_url_base,
			)->validate;
			push( @errors_found, $pubmed_id_error ) if ( $pubmed_id_error->triggered );
		}
	}
		
	#--------------#
	# write report #
	#--------------#

	Bio::ENA::DataSubmission::Validator::Report->new(
	    errors  => \@errors_found,
	    outfile => $report,
	    infile => $self->file
	)->print;

	#-------------------------#
	# edit/fix where possible #
	#-------------------------#

	
	return (scalar(@errors_found) > 0) ? 0 : 1;
}

sub usage_text {
	return <<USAGE;
Usage: validate_sample_manifest [options]

	-f|file       input manifest for validation
	-r|report     output path for validation report
	--edit        create additional manifest with mistakes fixed (where possible)
	-o|outfile    output path for edited manifest
	-h|help       this help message

USAGE
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;
