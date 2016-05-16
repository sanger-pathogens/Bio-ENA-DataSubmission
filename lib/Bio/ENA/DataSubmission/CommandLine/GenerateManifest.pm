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
use File::Slurp;
use Data::Dumper;

# use lib "/software/pathogen/internal/prod/lib";
use lib "../lib";
use lib "./lib";

use Path::Find;
use Path::Find::Lanes;
use Getopt::Long qw(GetOptionsFromArray);
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::Spreadsheet;
use Bio::ENA::DataSubmission::FindData;
use List::MoreUtils qw(uniq);

has 'args'         => ( is => 'ro', isa => 'ArrayRef', required => 1 );
                   
has 'type'         => ( is => 'rw', isa => 'Str',      required => 0 );
has 'id'           => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'      => ( is => 'rw', isa => 'Str',      required => 0, default => 'manifest.xls' );
has 'empty'        => ( is => 'rw', isa => 'Bool',     required => 0, default => 0 );
has 'sample_data'  => ( is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1 );
has 'help'         => ( is => 'rw', isa => 'Bool',     required => 0 );
has 'file_id_type' => ( is => 'rw', isa => 'Str',      required => 0, default => 'lane' );

has '_warehouse'   => ( is => 'rw', isa => 'DBI::db',  required => 0, lazy_build => 1 );
has '_show_errors' => ( is => 'rw', isa => 'Bool',     required => 0, default => 1 );

has 'config_file' => ( is => 'rw', isa => 'Str',      required => 0, default    => '/software/pathogen/etc/ena_data_submission.conf');


sub _build__warehouse {
	my $self = shift;

	my $warehouse_dbh = DBI->connect( "DBI:mysql:host=seqw-db:port=3379;database=sequencescape_warehouse",
        "warehouse_ro", undef, { 'RaiseError' => 1, 'PrintError' => 0 } )
      or Bio::ENA::DataSubmission::Exception::ConnectionFail->throw( error => "Failed to create connect to warehouse.\n");
    return $warehouse_dbh;
}

sub BUILD {
	my ( $self ) = @_;

	my ( $type, $file_id_type, $id, $outfile, $empty, $no_errors, $help,$config_file );
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		't|type=s'        => \$type,
    'file_id_type=s'  => \$file_id_type,
		'i|id=s'          => \$id,
		'o|outfile=s'     => \$outfile,
		'empty'           => \$empty,
		'no_errors'       => \$no_errors,
		'h|help'          => \$help,
		'c|config_file=s' => \$config_file
	);

	$self->type($type)                 if ( defined $type );
	$self->file_id_type($file_id_type) if ( defined $file_id_type );
	$self->id($id)                     if ( defined $id );
	$self->outfile($outfile)           if ( defined $outfile );
	$self->empty($empty)               if ( defined $empty );
	$self->help($help)                 if ( defined $help );
	$self->_show_errors(!$no_errors)   if ( defined $no_errors );
	
	$self->config_file($config_file)   if ( defined $config_file );
	( -e $self->config_file ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find config file\n" );
	$self->_populate_attributes_from_config_file;
}

sub _populate_attributes_from_config_file
{
  my ($self) = @_;
  my $file_contents = read_file($self->config_file);
  my $config_values = eval($file_contents);
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
	if ( $self->type eq 'file' ){
		my $id = $self->id;
		( -e $id ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "File $id does not exist\n" );
		( -r $id ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $id\n" );
	}
	system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" ) if ( defined $outfile );

  if ( $self->file_id_type ne 'lane' and
       $self->file_id_type ne 'sample' ) {
    Bio::ENA::DataSubmission::Exception::InvalidInput->throw(
      error => "'file_id_type' must be 'lane' or 'sample'\n"
    );
  }

	# write data to spreadsheet
	my $data = $self->sample_data;
	my $manifest = Bio::ENA::DataSubmission::Spreadsheet->new(
		data                => $data,
		outfile             => $outfile,
		add_manifest_header => 1
	);
	$manifest->write_xls;
	1;
}

sub _build_sample_data {
	my $self = shift;

	return [[]] if ( $self->empty );

	my $finder = Bio::ENA::DataSubmission::FindData->new(
		type         => $self->type,
		id           => $self->id,
		file_id_type => $self->file_id_type
	);
	my $data = $finder->find;

	#print "DATA: ";
	#print Dumper \%data;

	my @manifest;
	for my $k ( @{ $data->{key_order} } ){
		push( @manifest, $self->_manifest_row( $finder, $data->{$k}, $k ) );
	}

	# handle duplicates - e.g. same data for plexed lanes
	@manifest = $self->_remove_dups(\@manifest);

	#print Dumper \@manifest;
	#print "TOTAL: " . scalar(@manifest) . "\n";

	return \@manifest;
}

sub _manifest_row{
	my ($self, $f, $lane, $k) = @_;

	# blank row for returning on errors
	my @row = ( $k, 'not found', 'not found' );
	@row = $self->_error_row(\@row) if ( $self->_show_errors );

	return \@row unless ( defined $lane );

	# build data, so long as it's available
	my $sample = $self->_get_sample_from_lane( $f->_vrtrack, $lane );
	return \@row unless (defined $sample);
	my $sample_name = $sample->name || '';
	my $sample_acc = $sample->individual->acc || '';
	
	my $warehouse_dbh = $self->_warehouse;
	my @sample_data = $warehouse_dbh->selectrow_array( qq[select supplier_name from current_samples where internal_id = ] . $sample->ssid() );
	my $supplier_name = '';
	if(@sample_data > 0)
	{
	  $supplier_name = $sample_data[0] || '';
  }
	
	my $sample_alias = '';
	my $lane_name =  $lane->name || '';
	my $sample_anonymized_name = $sample->ssid() || '';
	my $common_name = '';
	my $taxon_id = '';
	
	if(defined($sample->individual) && defined($sample->individual->species))
	{
	  $common_name = $sample->individual->species->name || '';
  	$taxon_id = $sample->individual->species->taxon_id || '';
  }
	
	return [ $sample_acc, $sample_name, $supplier_name, $sample_alias, $taxon_id, $common_name,$common_name, $sample_anonymized_name, $lane_name,'','','','','','1900/2016','','','not provided','','not provided','','','','','',$sample_name,'','','not applicable'];

}

sub _error_row {
	my ($self, $row) = @_;

	my @new_row;
	for my $cell ( @{ $row } ){
		$cell =~ s/not found/not found!!/;
		push( @new_row, $cell );
	}
	return @new_row;
}

sub _remove_dups {
	my ($self, $data) = @_;

	my @uniq;
    my @acc_seen;
    for my $d ( @{ $data } ){
    	my $sample_acc = $d->[0];
    	next if( grep { $_ eq $sample_acc } @acc_seen );
    	push ( @uniq, $d );
    	push( @acc_seen, $sample_acc );
    }
    return @uniq;
}

sub _get_sample_from_lane {
    my ( $self, $vrtrack, $lane ) = @_;
    my ( $library, $sample );

    $library = VRTrack::Library->new( $vrtrack, $lane->library_id );
    $sample = VRTrack::Sample->new( $vrtrack, $library->sample_id )
      if defined $library;

    return $sample;
}

sub _find_missing_ids {
	my ( $self, $l, $d ) = @_;
	my @lanes = @{ $l };
	my @data = @{ $d };

	open( my $fh, '<', $self->id );
	my @ids = <$fh>;

	# extract IDs from lane objects
	my @got_ids;

	# detect whether lane names or sample accessions
    if ( $ids[0] =~ /#/ ){
    	@got_ids = $self->_extract_lane_ids(\@lanes);
    }
    else {
    	@got_ids = $self->_extract_accessions(\@data);
    }

    # find differences
    my @missing;
    for my $id (@ids){
    	chomp $id;
    	push( @missing, $id ) unless ( grep {$_ eq $id} @got_ids );
    }

    print STDERR "Missing data for:\n";
    print STDERR join("\n", @missing) . "\n";
    return @missing;
}

sub _extract_lane_ids {
	my ( $self, $l ) = @_;

	my @lane_ids;
	for my $lane ( @{ $l } ){
		push( @lane_ids, $lane->{name} );
	}
	return @lane_ids;
}

sub _extract_accessions {
	my ( $self, $d ) = @_;

	my @accs;
	for my $datum ( @{ $d } ){
		push( @accs, $datum->[0] );
	}
	return @accs;
}

sub usage_text {
	return <<USAGE;
Usage: generate_sample_manifest [options]

  -t|type          lane|study|file|sample
  --file_id_type   lane|sample  define ID types contained in file. default = lane
  -i|id            lane ID|study ID|file of lane IDs|file of sample accessions|sample ID
  --empty          generate empty manifest
  -o|outfile       path for output manifest
  -h|help          this help message

  When supplying a file of sample IDs ("-t file --file_id_type sample"), the IDs should
  be ERS numbers (e.g. "ERS123456"), not sample accessions.

USAGE
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;
