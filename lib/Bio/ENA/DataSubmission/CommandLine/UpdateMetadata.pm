package Bio::ENA::DataSubmission::CommandLine::UpdateMetadata;

# ABSTRACT: module for updating ENA metadata with local metadata

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::UpdateMetadata

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::CommandLine::UpdateMetadata;
	my $update = Bio::ENA::DataSubmission::CommandLine::UpdateMetadata->new();

	1. validate manifest, die if not met
	2. pull XML for each sample
	3. update XML with data from manifest
	4. generate submission XML
	5. validate XMLs with XSDs
	6. submit all files for each submission via curl
	7. wait for confirmation XML?
	8. repeat if required

=head1 METHODS



=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;
use Getopt::Long qw(GetOptionsFromArray);
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Slurp;
use Cwd 'abs_path';

use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::CommandLine::ValidateManifest;
use Email::MIME;
use Email::Sender::Simple qw(sendmail);

has 'args'            => ( is => 'ro', isa => 'ArrayRef', required => 1 );

has 'data_root'       => ( is => 'rw', isa => 'Maybe[Str]');
has '_output_root'    => ( is => 'rw', isa => 'Maybe[Str]');
has '_email_to'       => ( is => 'rw', isa => 'Maybe[Str]');
has 'auth_users'     => ( is => 'rw', isa => 'Maybe[ArrayRef]');
has '_output_dest'    => ( is => 'rw', isa => 'Maybe[Str]');
has 'schema'          => ( is => 'rw', isa => 'Maybe[Str]');
has 'output_group'    => ( is => 'rw', isa => 'Maybe[Str]');
has 'proxy'           => ( is => 'rw', isa => 'Maybe[Str]');
has 'ena_base_path'   => ( is => 'rw', isa => 'Maybe[Str]');

has 'manifest'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'         => ( is => 'rw', isa => 'Str',      required => 0 );
has 'test'            => ( is => 'rw', isa => 'Bool',     required => 0 );
has 'help'            => ( is => 'rw', isa => 'Bool',     required => 0 );
has '_current_user'   => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has 'no_validate'     => ( is => 'rw', isa => 'Bool',     required => 0, default    => 0 );
has '_timestamp'      => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has '_sample_xml'     => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has '_submission_xml' => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );

has 'config_file'     => ( is => 'rw', isa => 'Str',      required => 0, default    => '/software/pathogen/etc/ena_data_submission.conf');

sub _populate_attributes_from_config_file
{
  my ($self) = @_;
  my $file_contents = read_file($self->config_file);
  my $config_values = eval($file_contents);

  $self->_output_root($config_values->{output_root});
  $self->data_root(   $config_values->{data_root}  );
  $self->auth_users( $config_values->{auth_users} );
  $self->_email_to(   $config_values->{email_to}   );
  $self->schema(      $config_values->{schema}     );
  $self->output_group($config_values->{output_group});
  $self->proxy($config_values->{proxy});
  $self->ena_base_path($config_values->{ena_base_path});
}

sub _build__output_dest{
	my $self = shift;
	make_path( $self->_output_root ) unless(-d $self->_output_root);
	my $dir = abs_path($self->_output_root);

	my $user      = $self->_current_user;
	my $timestamp = $self->_timestamp;
	$dir .= '/' . $user . '_' . $timestamp;

	my $mode = 0774;
	make_path( $dir, {
		owner => $self->_current_user,
		group => $self->output_group,
		mode  => $mode
	});
	
	Bio::ENA::DataSubmission::Exception::CannotCreateDirectory->throw( error => "Cannot create directory $dir" ) unless(-e $dir);
	chmod $mode, $dir; # sets correct permissions - make_path not working properly

	return $dir;
}

sub _build__current_user {
	my $self = shift;
	return getpwuid( $< );
}

sub _build__timestamp {
	my @timestamp = localtime(time);
	my $day  = sprintf("%04d-%02d-%02d", $timestamp[5]+1900,$timestamp[4]+1,$timestamp[3]);
	my $time = sprintf("%02d-%02d", $timestamp[2], $timestamp[1]);

	return $day . '_' . $time;
}

sub _build__sample_xml {
	my $self = shift;

	my $time = $self->_timestamp;
	return "samples_$time.xml";
}

sub _build__submission_xml {
	my $self = shift;

	my $time = $self->_timestamp;
	return "submission_$time.xml";
}

sub BUILD {
	my ( $self ) = @_;

	my ( $file, $schema, $outfile, $test, $no_validate, $help, $config_file );
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		'f|file=s'    => \$file,
		's|schema=s'  => \$schema,
		'o|outfile=s' => \$outfile,
		'test'        => \$test,
		'no_validate' => \$no_validate,
		'c|config_file=s' => \$config_file,
		'h|help'      => \$help
	);

	$self->manifest($file)           if ( defined $file );
	$self->schema($schema)           if ( defined $schema );
	$self->outfile($outfile)         if ( defined $outfile );
	$self->test($test)               if ( defined $test );
	$self->no_validate($no_validate) if ( defined $no_validate );
	$self->help($help)               if ( defined $help );
	
	$self->config_file($config_file)     if ( defined $config_file );
	
	$self->_check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	( -e $self->config_file ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find config file\n" );

	$self->_populate_attributes_from_config_file() if(-e $self->config_file);
	$self->_output_dest($self->_build__output_dest);
	
}

sub _check_inputs {
    my $self = shift; 
    return(
        $self->manifest
        && !$self->help
    );
}

sub _check_user {
	my $self = shift;
	my $user = $self->_current_user;
	my @auth = @{ $self->auth_users };

	return ( grep {$_ eq $user} @auth );
}

sub run {
	my ($self)   = @_;
	my $manifest = $self->manifest;
	my $schema   = $self->schema;
	my $outfile  = $self->outfile;

	# sanity checks
	$self->_check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	$self->_check_user or Bio::ENA::DataSubmission::Exception::UnauthorisedUser->throw( error => "You are not on the approved list of users for this script\n" );
	( -e $manifest ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find $manifest\n" );
	( -r $manifest ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $manifest\n" );
	$outfile = "$manifest.report.txt" unless( defined( $outfile ) );
	$self->outfile($outfile);
	system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" ) if ( defined $outfile );

	# first, validate the manifest
	unless( $self->no_validate ){
		my @args = ( '-f', $manifest, '-r', $outfile, '-c', $self->config_file );
		my $validator = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new( args => \@args );
		Bio::ENA::DataSubmission::Exception::ValidationFail->throw("Manifest $manifest did not pass validation. See $outfile for report\n") if( $validator->run == 0 ); # manifest failed validation
	}
	
	# generate updated sample XML
	$self->_updated_xml;

	# generate submission XML
	$self->_generate_submission;

	# validate both with XSD
	$self->_validate_with_xsd;

	# copy spreadsheet to /lustre/scratch108/pathogen/pathpipe/ena_updates/
	$self->_record_spreadsheet;

	# email Rob
	$self->_email;
	print "Your request has been sent to: " . $self->_email_to . "\n";

}

sub _updated_xml {
	my $self     = shift;
	my $test     = $self->test;
	my $dest     = $self->_output_dest;
	my $manifest = $self->manifest;
	my $samples  = $self->_sample_xml;

	# parse manifest and loop through samples
	my $manifest_handler = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $manifest );
	my @manifest = @{ $manifest_handler->parse_manifest };
	my @updated_samples;
	foreach my $sample (@manifest){
		my $new_sample = Bio::ENA::DataSubmission::XML->new(ena_base_path => $self->ena_base_path, proxy => $self->proxy )->update_sample( $sample );
		push( @updated_samples, $new_sample );
	}

	my %new_xml = ( 'SAMPLE' => \@updated_samples );
	Bio::ENA::DataSubmission::XML->new( data => \%new_xml, outfile => "$dest/$samples",ena_base_path => $self->ena_base_path, proxy => $self->proxy )->write_sample;
}

sub _generate_submission {
	my $self = shift;
	my $dest = $self->_output_dest;
	my $root = $self->data_root;
	my $sample_xml = $self->_sample_xml;
	my $submission_xml = $self->_submission_xml;

	my $submission;
	{
		local $/ = undef;
		open(my $sub_in, '<', "$root/submission.xml");
		$submission = <$sub_in>;
	}
	$submission =~ s/samples\.xml/$sample_xml/;
	my $alias = $self->_current_user . "_" . $self->_timestamp;
	$submission =~ s/ReleaseSubmissionUpdate/$alias/;

	open(my $sub_out, '>', "$dest/$submission_xml");
	print $sub_out $submission;
	close $sub_out;
}

sub _validate_with_xsd {
	my $self = shift;
	my $dest = $self->_output_dest;

	my $xsd_root = $self->data_root;
	my $sample_xml = $self->_sample_xml;
	my $submission_xml = $self->_submission_xml;

	my $sample_validator = Bio::ENA::DataSubmission::XML->new( xml => "$dest/$sample_xml", xsd => "$xsd_root/sample.xsd", ena_base_path => $self->ena_base_path, proxy => $self->proxy );
	Bio::ENA::DataSubmission::Exception::ValidationFail->throw( error => "Validation of updated sample XML failed. Errors:\n" . $sample_validator->validation_report . "\n" ) unless ( $sample_validator->validate );

	my $submission_validator = Bio::ENA::DataSubmission::XML->new( xml => "$dest/$submission_xml", xsd => "$xsd_root/submission.xsd", ena_base_path => $self->ena_base_path, proxy => $self->proxy );
	Bio::ENA::DataSubmission::Exception::ValidationFail->throw( error => "Validation of submission XML failed. Errors:\n" . $submission_validator->validation_report . "\n" ) unless ( $submission_validator->validate );

	return 1;
}

sub _record_spreadsheet {
	my $self = shift;
	my $manifest = $self->manifest;
	my $dest = $self->_output_dest;

	copy $manifest, "$dest/manifest.xls";
}

sub _email {
	my $self = shift;
	my $to = $self->_email_to;
	my $user = $self->_current_user;

	my $alias = $user . "_" . $self->_timestamp;

	my $message = Email::MIME->create(
    	header_str => [
        	From    => 'cc21@sanger.ac.uk',
        	To      => $to,
        	Cc      => $user . '@sanger.ac.uk',
        	Subject => "ENA Metadata Update Request : $alias",
    	],
    	attributes => {
        	encoding => 'quoted-printable',
        	charset  => 'ISO-8859-1',
    	},
    	body_str => $self->_email_body,
	);

	sendmail($message);
}

sub _email_body {
	my $self = shift;
	my $dest = $self->_output_dest;

	return <<BODY;
Hi,

Some sample metadata are ready for update with the ENA. The files are located @ $dest

Please place the ENA XML receipt in the same directory.

Thanks,
path-help
BODY
}

sub usage_text {
	return <<USAGE;
Usage: update_sample_manifest [options]

	-f|file       input manifest for update
	-o|outfile    output path for validation report
	--no_validate skip validation step (for cases where validation has already been done)
	-h|help       this help message

USAGE
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;