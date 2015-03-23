package Bio::ENA::DataSubmission::CommandLine::ValidateManifest;

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
use Bio::ENA::DataSubmission::Validator::Error::Country;
use Bio::ENA::DataSubmission::Validator::Error::General;
use Bio::ENA::DataSubmission::Validator::Error::LatLon;
use Bio::ENA::DataSubmission::Validator::Error::SampleAccession;
use Bio::ENA::DataSubmission::Validator::Error::TaxID;
use Bio::ENA::DataSubmission::Validator::Error::MandatoryCells;

has 'args'    => ( is => 'ro', isa => 'ArrayRef', required => 1 );

has 'file'    => ( is => 'rw', isa => 'Str',      required => 0 );
has 'report'  => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile' => ( is => 'rw', isa => 'Str',      required => 0 );
has 'edit'    => ( is => 'rw', isa => 'Bool',     required => 0 );
has 'help'    => ( is => 'rw', isa => 'Bool',     required => 0 );
has 'config_file'     => ( is => 'rw', isa => 'Str',      required => 0, default    => '/software/pathogen/etc/ena_data_submission.conf');

has 'ena_base_path'    => ( is => 'rw', isa => 'Str', default  => 'http://www.ebi.ac.uk/ena/data/view/');
has 'taxon_lookup_service' => ( is => 'rw', isa => 'Str', default  => 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&report=xml&id=' );


sub BUILD {
	my ( $self ) = @_;

	my ( $file, $report, $outfile, $edit, $help, $config_file );
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		'f|file=s'        => \$file,
		'r|report=s'      => \$report,
		'o|outfile=s'     => \$outfile,
		'edit'            => \$edit,
		'h|help'          => \$help,
		'c|config_file=s' => \$config_file
	);

	$self->file($file)       if ( defined $file );
	$self->report($report)   if ( defined $report );
	$self->outfile($outfile) if ( defined $outfile );
	$self->edit($edit)       if ( defined $edit );
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

  $self->ena_base_path($config_values->{ena_base_path});
  $self->taxon_lookup_service($config_values->{taxon_lookup_service});
}

sub check_inputs{
    my $self = shift; 
    return(
        $self->file
        && !$self->help
    );
}

sub run {
	my $self = shift;

	my $file = $self->file;
	my $report = $self->report;
	my $outfile = $self->outfile;
	my $edit = $self->edit;

	#---------------#
	# sanity checks #
	#---------------#

	$self->check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	( -e $file ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find $file\n" );
	( -r $file ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $file\n" );
	system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" ) if ( defined $outfile );
	system("touch $report &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $report\n" ) if ( defined $report );

	$report  = "$file.report.txt" unless( defined $report );
	$outfile = "$file.edit.xls"   unless( defined $outfile );

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
		my $acc = $row[0];

		# validate all generally
		for my $c ( 0..$#row ) {
			my $cell = $row[$c];
			if ( defined $cell ){
				my $gen_error = Bio::ENA::DataSubmission::Validator::Error::General->new( 
					identifier => $acc,
					cell       => $cell,
					field      => $header[$c]
				)->validate;
				push( @errors_found, $gen_error ) if ( $gen_error->triggered );
			}
		}

		# validate more specific cells separately

		# mandatory cells
		my $mandatory = [ 4, 5, 14, 15, 16, 17, 19, 25, 28 ];
		my $mandatory_error = Bio::ENA::DataSubmission::Validator::Error::MandatoryCells->new( 
			row => \@row, 
			mandatory => $mandatory
		)->validate;
		push( @errors_found, $mandatory_error ) if ( $mandatory_error->triggered );

		# sample accession
		my $acc_error = Bio::ENA::DataSubmission::Validator::Error::SampleAccession->new(
			accession  => $acc,
			identifier => $acc,
			ena_base_path => $self->ena_base_path
		)->validate;
		push( @errors_found, $acc_error ) if ( $acc_error->triggered );

		# taxon ID and scientific name
		if ( $row[4] && $row[5] ){
			my $taxid_error = Bio::ENA::DataSubmission::Validator::Error::TaxID->new(
				identifier       => $acc,
				tax_id           => $row[4],
				scientific_name  => $row[5],
				taxon_lookup_service => $self->taxon_lookup_service
			)->validate;
			push( @errors_found, $taxid_error ) if ( $taxid_error->triggered );
		}

		# collection_date
		if ( $row[14] ){
			my $cdate_error = Bio::ENA::DataSubmission::Validator::Error::Date->new(
				identifier => $acc,
				date       => $row[14]
			)->validate;
			push( @errors_found, $cdate_error ) if ( $cdate_error->triggered );
		}

		# country
		if ( $row[15] ){
			my $country_error = Bio::ENA::DataSubmission::Validator::Error::Country->new(
				identifier => $acc,
				country    => $row[15]
			)->validate;
			
			if ( $country_error->triggered )
			{
				if($country_error->fix_it)
				{
				    $row[15] = $country_error->country;
				}
				else
				{
	    			push( @errors_found, $country_error ) ;
    			}
			}
		}

		# lat lon
		if( $row[20] ){
			my $lat_lon_error = Bio::ENA::DataSubmission::Validator::Error::LatLon->new(
				identifier => $acc,
				latlon     => $row[20]
			)->validate;
			push( @errors_found, $lat_lon_error ) if ( $lat_lon_error->triggered );
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
