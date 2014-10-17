package Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects;

# ABSTRACT: module for submitting genome assemblies with metadata

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjects

=head1 SYNOPSIS

	1. validate manifest, die if not met
	2. Place files in ENA dropbox via FTP
	3. generate analysis XML
	4. generate submission XML
	5. validate XMLs with XSDs
	6. submit all files for each submission via ENA REST API
	7. wait for confirmation XML
	8. generate report

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;
use Getopt::Long qw(GetOptionsFromArray);
use File::Basename;
use File::Copy qw(copy);
use File::Path qw(make_path);
use Cwd 'abs_path';

use Bio::ENA::DataSubmission;
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest;
use Bio::ENA::DataSubmission::XML;
use Bio::ENA::DataSubmission::FTP;
use Bio::ENA::DataSubmission::Spreadsheet;
use DateTime;
use Digest::MD5 qw(md5_hex);
use File::Slurp;

has 'args'            => ( is => 'ro', isa => 'ArrayRef', required => 1 );



has 'analysis_type'   => ( is => 'rw', isa => 'Str',      required => 0, default    => 'sequence_assembly' );
has 'manifest'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'         => ( is => 'rw', isa => 'Str',      required => 0 );
has 'help'            => ( is => 'rw', isa => 'Bool',     required => 0 );

has '_current_user'   => ( is => 'rw', isa => 'Str',      lazy => 1, builder => '_build__current_user');
has '_timestamp'      => ( is => 'rw', isa => 'Str',      lazy => 1, builder => '_build__timestamp');

# Need to be built after the object is constructed
has '_output_dest'    => ( is => 'rw', isa => 'Str'      );
has '_manifest_data'  => ( is => 'rw', isa => 'ArrayRef' );
has '_server_dest'    => ( is => 'rw', isa => 'Str'      );
has '_release_dates'  => ( is => 'rw', isa => 'ArrayRef' );
has 'ena_login_string' => ( is => 'rw', isa => 'Str'     );
has 'ena_base_path'    => ( is => 'rw', isa => 'Str'     );

has 'no_validate'     => ( is => 'rw', isa => 'Bool',     required => 0, default    => 0 );
has '_no_upload'      => ( is => 'rw', isa => 'Bool',     required => 0, default    => 0 );

has 'config_file'     => ( is => 'rw', isa => 'Str',      required => 0, default    => '/software/pathogen/etc/ena_data_submission.conf');

# Populated after the object is constructed and the config file is read
has 'data_root'                   => ( is => 'rw', isa => 'Maybe[Str]');
has '_output_root'                => ( is => 'rw', isa => 'Maybe[Str]');
has '_webin_user'                 => ( is => 'rw', isa => 'Maybe[Str]');
has '_webin_pass'                 => ( is => 'rw', isa => 'Maybe[Str]');
has '_webin_host'                 => ( is => 'rw', isa => 'Maybe[Str]');
has '_ena_dropbox_submission_url' => ( is => 'rw', isa => 'Maybe[Str]');
has '_auth_users'                 => ( is => 'rw', isa => 'Maybe[ArrayRef]');

sub BUILD {
	my $self = shift;

	my ( 
		$file, $outfile, $analysis_type,
		$no_validate, $no_upload, $help, $config_file
	);
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		'f|file=s'    => \$file,
		'o|outfile=s' => \$outfile,
		't|type'      => \$analysis_type,
		'no_validate' => \$no_validate,
		'c|config_file=s' => \$config_file,
		'h|help'      => \$help
	);

	$self->manifest($file)               if ( defined $file );
	$self->outfile($outfile)             if ( defined $outfile );
	$self->analysis_type($analysis_type) if ( defined $analysis_type );
	$self->no_validate($no_validate)     if ( defined $no_validate );
	$self->help($help)                   if ( defined $help );
	$self->config_file($config_file)     if ( defined $config_file );
	
	$self->_check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	( -e $self->config_file ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find config file for Submit Analysis Objects\n" );

	$self->_populate_attributes_from_config_file() if(-e $self->config_file);
	
	my $manifest = $self->manifest;

	# sanity checks
	$self->_check_user or Bio::ENA::DataSubmission::Exception::UnauthorisedUser->throw( error => "You are not on the approved list of users for this script\n" );
	( -e $manifest ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find $manifest\n" );
	( -r $manifest ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $manifest\n" );
	$outfile = "$manifest.report.xls" unless( defined( $outfile ) );
	$self->outfile($outfile);
	system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" ) if ( defined $outfile );
	

  $self->_output_dest($self->_build__output_dest);
  $self->_manifest_data($self->_build__manifest_data);
  $self->_server_dest($self->_build__server_dest);
  $self->_release_dates($self->_build__release_dates);
}


sub _build__output_dest{
	my $self = shift;
	make_path( $self->_output_root ) unless(-d $self->_output_root);
	my $dir = abs_path($self->_output_root);

	my $user      = $self->_current_user;
	my $timestamp = $self->_timestamp;
	$dir .= '/' . $user . '_' . $timestamp;

	make_path( $dir );
	return $dir;
}

sub _build__release_dates {
	my $self = shift;
	my @manifest = @{ $self->_manifest_data };
	
	my @dates;
	for my $row ( @manifest ) {
		push( @dates, $row->{release_date} ) if ( defined $row->{release_date});
	}
	return \@dates;
}

sub _build__current_user {
	my $self = shift;
	return getpwuid( $< );
}

sub _build__timestamp {
  my $self = shift;
	my @timestamp = localtime(time);
	my $day  = sprintf("%04d-%02d-%02d", $timestamp[5]+1900,$timestamp[4]+1,$timestamp[3]);
	my $time = sprintf("%02d-%02d", $timestamp[2], $timestamp[1]);

	return $day . '_' . $time;
}

sub _build__manifest_data {
	my $self = shift;

	my $manifest_handler = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $self->manifest );
	return $manifest_handler->parse_manifest;
}

sub _build__server_dest {
	my $self = shift;

	return '/' . $self->analysis_type . '/' . $self->_current_user . '_' . $self->_timestamp;
}


sub _populate_attributes_from_config_file
{
  my ($self) = @_;
  my $file_contents = read_file($self->config_file);
  my $config_values = eval($file_contents);

  $self->_output_root($config_values->{output_root});
  $self->data_root(   $config_values->{data_root} );
  $self->_auth_users( $config_values->{auth_users});
  $self->_webin_user( $config_values->{webin_user});
  $self->_webin_pass( $config_values->{webin_pass});
  $self->_webin_host( $config_values->{webin_host});
  $self->ena_login_string( $config_values->{ena_login_string});
  $self->_ena_dropbox_submission_url($config_values->{ena_dropbox_submission_url});
  $self->ena_base_path($config_values->{ena_base_path});
}

sub _check_inputs {
	my $self = shift;

	return (
		defined($self->manifest) && defined($self->config_file) && !$self->help
	);
}

sub _check_user {
	my $self = shift;

	return 1;
}

sub run {
	my $self = shift;
  
  my $outfile = $self->outfile;

  $self->_convert_secondary_project_accession_to_primary_manifest_data();
	# first, validate the manifest
	unless( $self->no_validate ){
		my @args = ( '-f', $self->manifest, '-r', $outfile, '-c', $self->config_file );
		my $validator = Bio::ENA::DataSubmission::CommandLine::ValidateAnalysisManifest->new( args => \@args );
		Bio::ENA::DataSubmission::Exception::ValidationFail->throw("Manifest $self->manifest did not pass validation. See $outfile for report\n") if( $validator->run == 0 ); # manifest failed validation
	}

  $self->_gzip_input_files();
	
	# Place files in ENA dropbox via FTP
	unless( defined($self->_no_upload) && $self->_no_upload == 1 ){
	  $self->_convert_gffs_to_flatfiles();
	  my $files = $self->_parse_filelist;
	  
		my $dest  = $self->_server_dest; 
		my $uploader = Bio::ENA::DataSubmission::FTP->new( files => $files, destination => $dest, username => $self->_webin_user, password => $self->_webin_pass, server => $self->_webin_host );
		$uploader->upload or Bio::ENA::DataSubmission::Exception::FTPError->throw( error => $uploader->error );
		# Save submitted files
  	$self->_keep_local_copy_of_submitted_files($files);
	}

	# generate analysis XML
	$self->_update_analysis_xml;

	# generate submission XML
	$self->_generate_submissions;

	# validate XMLs with XSDs
	$self->_validate_with_xsd;
	
	# submit all files for each submission via ENA REST API
	$self->_submit;

	# generate report from XML receipts
	$self->_report;

}

sub _convert_gffs_to_flatfiles
{
  my ($self) = @_;
  for my $cmd (@{$self->_convert_gffs_to_flatfiles_cmds})
  {
    system($cmd);
  }
}

sub _convert_secondary_project_accession_to_primary
{
  my ($self, $accession) = @_;
  return $accession unless($accession =~ /ERP/);

  my $xml = Bio::ENA::DataSubmission::XML->new( url => $self->ena_base_path."$accession&display=xml",ena_base_path => $self->ena_base_path )->parse_from_url;

  if(defined($xml) && 
     defined($xml->{STUDY}) && 
     defined($xml->{STUDY}->[0]) && 
     defined($xml->{STUDY}->[0]->{IDENTIFIERS}) && 
     defined($xml->{STUDY}->[0]->{IDENTIFIERS}->[0]) && 
     defined($xml->{STUDY}->[0]->{IDENTIFIERS}->[0]->{SECONDARY_ID}) && 
     defined($xml->{STUDY}->[0]->{IDENTIFIERS}->[0]->{SECONDARY_ID}->[0])  )
  {
    return $xml->{STUDY}->[0]->{IDENTIFIERS}->[0]->{SECONDARY_ID}->[0];
  }
  return $accession;
}

sub _convert_gffs_to_flatfiles_cmds
{
   my ($self) = @_;
   
   my @manifest = @{ $self->_manifest_data };
   my @commands_to_run;
   my %filelist;
   for my $row ( @manifest ) {
     chomp($row->{name});
     my $sample_name = $row->{name};
     my ( $filename, $directories, $suffix ) = fileparse( $row->{file}, qr/\.[^.]*/ );
     next unless(  $row->{file} =~ /gff$/);
     
     my $input_file = $row->{file};
     my $output_file = $sample_name.'.embl' ;
     
     push(@commands_to_run, "gff3_to_embl --output_filename $output_file \"$row->{common_name}\" \"$row->{tax_id}\" \"$row->{study}\" \"$row->{description}\" \"$input_file\""); 
     $row->{file} = $output_file ;
   }
   return \@commands_to_run;
}

sub _keep_local_copy_of_submitted_files
{
  my ($self, $files) = @_;
  my $data_file_path = join('/',($self->_output_dest,'datafiles'));
  
  make_path( $data_file_path ) unless(-d $data_file_path);
  for my $local_file ( keys %{ $files } )
  {
    my $target = $files->{$local_file};
    copy($local_file, join('/',($data_file_path,$target)));
  }
  1;
}

sub _parse_filelist {
	my ($self) = @_;
	my @manifest = @{ $self->_manifest_data };

	my %filelist;
	for my $row ( @manifest ) {
	  chomp($row->{name});
	  my $sample_name = $row->{name};
	  my ( $filename, $directories, $suffix ) = fileparse( $row->{file}, qr/\.[^.]*\.gz/ );
		$filelist{$row->{file}} = $sample_name.$suffix ;
	}
	return \%filelist;
}

sub _calc_md5
{
  my ($self, $file)     = @_;
  
  open(my $fh, $file);
  binmode($fh);
  my $ctx = Digest::MD5->new;
  $ctx->addfile($fh);
  return $ctx->hexdigest; 
}
sub _gzip_input_files
{
  my ($self)     = @_;
  
  my @manifest = @{ $self->_manifest_data };
	foreach my $row (@manifest ){
	  my $file_gz = $row->{file}.'.gz';
	  system("gzip -c -n ".$row->{file}." > $file_gz ");
	  
	  $row->{file} = $file_gz;
	}
	1;
}

sub _convert_secondary_project_accession_to_primary_manifest_data
{
  my ($self)     = @_;
  my @manifest = @{ $self->_manifest_data };
	my %updated_data;
	foreach my $row (@manifest){
	  $row->{study} = $self->_convert_secondary_project_accession_to_primary($row->{study});
	}
	1;
}

sub _update_analysis_xml {
	my ($self)     = @_;
	my $dest     = $self->_output_dest;
  my @manifest = @{ $self->_manifest_data };
	# parse manifest and loop
	my %updated_data;
	foreach my $row (@manifest){
	  $row->{study} = $self->_convert_secondary_project_accession_to_primary($row->{study});
		$row->{checksum} = $self->_calc_md5($row->{file}); # add MD5 checksum 
		$row->{file} = $self->_server_path( $row->{file}, $row->{name} ); # change file path from local to server
		my $analysis_xml = Bio::ENA::DataSubmission::XML->new(data_root => $self->data_root)->update_analysis( $row );
		my $release_date = $row->{release_date};
		# split data based on release dates. release date set in submission XML
		$updated_data{$release_date} = [] unless ( defined $updated_data{$release_date} );
		push( @{ $updated_data{$release_date} }, $analysis_xml );
	}

	my @release_dates;
	for my $k ( keys %updated_data ){
		my %new_xml = ( 'ANALYSIS' => $updated_data{$k} );
		my $outfile = $self->_analysis_xml( $k );
		Bio::ENA::DataSubmission::XML->new( data => \%new_xml, outfile => $outfile,data_root => $self->data_root )->write_analysis;
		push( @release_dates, $k );
	}
	$self->_release_dates( \@release_dates );
}

sub _server_path {
	my ( $self, $local, $name ) = @_;
	my $s_dest = $self->_server_dest;

	my ( $filename, $directories, $suffix ) = fileparse( $local, qr/\.[^.]*\.gz/ );
	return "$s_dest/$name".$suffix;
}

sub _analysis_xml {
	my ( $self, $id ) = @_;
	my $dest = $self->_output_dest;

	return "$dest/analysis_$id.xml";
}

sub _submission_xml {
	my ( $self, $id ) = @_;
	my $dest = $self->_output_dest;

	return "$dest/submission_$id.xml";
}

sub _receipt_xml {
	my ( $self, $id ) = @_;
	my $dest = $self->_output_dest;

	return "$dest/receipt_$id.xml";
}

sub _generate_submissions {
	my $self = shift;
	my @dates    = @{ $self->_release_dates }; 

	my $sub_template = Bio::ENA::DataSubmission::XML->new( xml => $self->data_root . "/submission.xml",data_root => $self->data_root )->parse_from_file;	

	for my $date ( @dates ){
		my ( $filename, $directories, $suffix ) = fileparse( $self->_analysis_xml( $date ), ('.xml') );
		my $file = "$filename$suffix"; # remove directories

		my @actions = ( { ADD => [ { source => $file, schema => 'analysis' } ] } );
		if ( $self->_later_than_today( $date ) ){
			# hold until release date
			push( @actions, { HOLD => [ { HoldUntilDate => $date } ] } );
		}
		else {
			# release immediately
			push( @actions, { RELEASE => [ {} ] } );
		}

		# construct XML data structure
		my $sub_template = { 
			ACTIONS     => [{ ACTION => \@actions }],
			alias       => $self->_current_user . '_' . $self->_timestamp . "_release_$date",
			center_name => 'SC'
		};
		
		# write to file
		my $outfile = $self->_submission_xml( $date );
		Bio::ENA::DataSubmission::XML->new( data => $sub_template, outfile =>  $outfile ,data_root => $self->data_root)->write_submission;
	}
	return 1;
}

sub _later_than_today {
	my ( $self, $date ) = @_;

	chomp $date;
	my @date_data = split( '-', $date );
	my $release_date = DateTime->new( 
		year  => $date_data[0], 
		month => $date_data[1], 
		day   => $date_data[2] 
	);
	my $today = DateTime->today;

	my $diff = $release_date->subtract_datetime( $today );

	return 1 if ( $diff->{months} > 0 || $diff->{days} > 0 );
	return 0;
}

sub _validate_with_xsd {
	my $self = shift;
	my $dest = $self->_output_dest;
	my $xsd_root = $self->data_root;

	for my $date ( @{ $self->_release_dates } ){
		my $analysis_xml = $self->_analysis_xml( $date );
		my $sample_validator = Bio::ENA::DataSubmission::XML->new( xml => $analysis_xml, xsd => "$xsd_root/analysis.xsd",data_root => $self->data_root );
		Bio::ENA::DataSubmission::Exception::ValidationFail->throw( error => "Validation of updated sample XML failed. Errors:\n" . $sample_validator->validation_report . "\n" ) unless ( $sample_validator->validate );

		my $submission_xml = $self->_submission_xml( $date );
		my $submission_validator = Bio::ENA::DataSubmission::XML->new( xml => $submission_xml, xsd => "$xsd_root/submission.xsd",data_root => $self->data_root );
		Bio::ENA::DataSubmission::Exception::ValidationFail->throw( error => "Validation of submission XML failed. Errors:\n" . $submission_validator->validation_report . "\n" ) unless ( $submission_validator->validate );
	}

	return 1;
}

sub _submit {
	my $self = shift;

	for my $date ( @{ $self->_release_dates } ){
		my $sub_obj = Bio::ENA::DataSubmission->new(
			submission => $self->_submission_xml( $date ),
			analysis   => $self->_analysis_xml( $date ),
			receipt    => $self->_receipt_xml( $date ),
			ena_login_string => $self->ena_login_string,
			ena_dropbox_submission_url => $self->_ena_dropbox_submission_url
		);
		$sub_obj->submit;
	}
}

sub _report {
	my $self = shift;

	# parse and store all required info from receipt XMLs
	my %receipts;
	for my $date ( @{ $self->_release_dates } ){
		my $receipt = $self->_receipt_xml( $date );
		$receipts{$date} = $self->_parse_receipt( $receipt );
	}

	# loop through manifest and match to receipt
	my @report = ( ['name', 'success', 'errors'] );
	my @manifest = @{ $self->_manifest_data };
	for my $row ( @manifest ) {
		my $release = $row->{release_date};
		my $receipt_details = [ $row->{name}, $receipts{$release}->{success} ?$receipts{$release}->{success} : '' , $receipts{$release}->{errors} ?$receipts{$release}->{errors} : '' ];
		push( @report, $receipt_details );
	}

	my $report_xls = Bio::ENA::DataSubmission::Spreadsheet->new(
		data                =>\@report,
		_header              => ['name','success','errors'],
		outfile             => $self->outfile,
	);
	$report_xls->write_xls;
}

sub _parse_receipt {
	my ( $self, $receipt ) = @_;

	my $xml = Bio::ENA::DataSubmission::XML->new( xml => $receipt, data_root => $self->data_root )->parse_from_file;
	my %receipt_details ;
	
	if(defined($xml->{MESSAGES}) && defined($xml->{MESSAGES}->[0]) && defined( $xml->{MESSAGES}->[0]->{ERROR}))
	{
	  $receipt_details{errors} = join( ';', @{ $xml->{MESSAGES}->[0]->{ERROR} } );
  }
  
  if(defined($xml->{success}))
  {
    $receipt_details{success} = $xml->{success};
  }
	
	return \%receipt_details;
}

sub usage_text {
	return <<USAGE;
Usage: submit_analysis_objects [options]

	-f|file    
	-o|outfile     Output file for report ( .xls format )
	-t|type        Default = sequence_assembly
	--no_validate  Do not run manifest validation step
	-h|help'       This help message

USAGE
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;