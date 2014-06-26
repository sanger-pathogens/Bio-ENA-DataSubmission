package Bio::ENA::DataSubmission::CommandLine::GenerateManifest;

# ABSTRACT: module for generation of manifest files for ENA metadata update

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::GenerateManifest

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::CommandLine::GenerateManifest;
	

=head1 METHODS



=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;

use Path::Find;
use Path::Find::Lanes;
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::Spreadsheet

has 'args'        => ( is => 'ro', isa => 'ArrayRef', required => 1 );

has 'type'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'id'          => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'     => ( is => 'rw', isa => 'Str',      required => 0 );
has 'sample_data' => ( is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1 );

sub BUILD {
	my ( $self ) = @_;

	my ( $type, $id, $outfile, $help );
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		't|type=s'  => \$type,
		'i|id=s'    => \$id,
		'o|outfile' => \$outfile,
		'h|help'    => \$help
	) or Bio::ENA::DataSubmission::Exception->throw( error => "" );

	$self->type($type)       if ( defined $type );
	$self->id($id)           if ( defined $id );
	$self->outfile($outfile) if ( defined $outfile );
	$self->help($help)       if ( defined $help );
}

sub check_inputs{
    my $self = shift; 
    return(
        $self->type
          && ( $self->type eq 'study'
            || $self->type eq 'lane'
            || $self->type eq 'file'
            || $self->type eq 'sample' )
          && $self->id
          && !$self->help
    );
}

sub run {
	my ($self) = @_;

	my $outfile = $self->outfile;

	# sanity checks
	$self->check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	if ( $self->type == 'file' ){
		my $id = $self->id;
		( -e $id ) or Bio::ENA::DataSubmission::Exception::FileDoesNotExist->throw( error => "File $id does not exist\n" );
		( -r $id ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $id\n" );
	}
	( -w  $outfile ) or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" );

	# write data to spreadsheet
	my $data = @{ $self->sample_data };
	my $manifest = Bio::ENA::DataSubmission::Spreadsheet->new(
		data                => $data,
		outfile             => $outfile,
		add_manifest_header => 1
	);
	$manifest->write_xls;
}

sub _build_sample_data {
	my $self = shift;

	my $warehouse_dbh = DBI->connect( "DBI:mysql:host=mcs7:port=3379;database=sequencescape_warehouse",
        "warehouse_ro", undef, { 'RaiseError' => 1, 'PrintError' => 0 } )
      or Bio::ENA::DataSubmission::Exception::ConnectionFail->throw( error => "Failed to create connect to warehouse.\n");

    my @data;

	my $find = Path::Find->new();
	my @pathogen_databases = $find->pathogen_databases;
	for my $database (@pathogen_databases){
		my ( $pathtrack, $dbh, $root ) = $find->get_db_info($database);

        my $find_lanes = Path::Find::Lanes->new(
            search_type    => $self->type,
            search_id      => $self->id,
            pathtrack      => $pathtrack,
            dbh            => $dbh,
            processed_flag => 0
        );
        my @lanes = @{ $find_lanes->lanes };

        unless (@lanes) {
            $dbh->disconnect();
            next;
        }

        for my $lane (@lanes) {
        	my $sample = $self->_get_sample_from_lane( $pathtrack, $lane );
        	next unless (defined $sample);
        	my $sample_name = $sample->name;
        	my $sample_acc = $sample->individual->acc;

        	my @sample_data = $warehouse_dbh->selectrow_array( qq[select supplier_name from current_samples where internal_id = ] . $sample->ssid() );
        	my $supplier_name = $sample[1];
        	push( @data, [ $sample_acc, $sample_name, $supplier_name ] );
        }
	}

	return \@data;
}

sub _get_sample_from_lane {
    my ( $self, $vrtrack, $lane ) = @_;
    my ( $library, $sample );

    $library = VRTrack::Library->new( $vrtrack, $lane->library_id );
    $sample = VRTrack::Sample->new( $vrtrack, $library->sample_id )
      if defined $library;

    return $sample;
}

sub usage_text {
	return "USAGE TEXT\n";
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;