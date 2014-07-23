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

use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::CommandLine::ValidateManifest;
#use Email::MIME;
#use Email::Sender::Simple qw(sendmail);

has 'args'           => ( is => 'ro', isa => 'ArrayRef', required => 1 );

has '_output_root'   => ( is => 'rw', isa => 'Str',      required => 0, default => '/lustre/scratch108/pathogen/pathpipe/ena_updates/' );
has '_output_dest'   => ( is => 'rw', isa => 'Str',      required => 0, lazy_build => 1 );
has 'schema'         => ( is => 'rw', isa => 'Str',      required => 0, default => 'ERC000028' );
has 'manifest'       => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'test'           => ( is => 'rw', isa => 'Bool',     required => 0 );
has 'help'           => ( is => 'rw', isa => 'Bool',     required => 0 );
has '_data_root'     => ( is => 'rw', isa => 'Str',      required => 0, default => '../../../../../data' );
has '_email_to'      => ( is => 'rw', isa => 'Str',      required => 0, default => 'rmd@sanger.ac.uk' );

sub _build__output_dest{
	my $self = shift;
	my $dir = $self->_output_root;

	my @timestamp = localtime(time);
	my $day  = sprintf("%04d-%02d-%02d", $timestamp[5]+1900,$timestamp[4]+1,$timestamp[3]);
	my $user = getpwuid( $< );
	$dir .= $user . '_' . $day;

	Bio::ENA::DataSubmission::Exception::CannotCreateDirectory->throw( error => "Cannot create directory $dir" ) unless( mkdir $dir );
	return $dir;
}

sub BUILD {
	my ( $self ) = @_;

	my ( $file, $schema, $outfile, $test, $help );
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		'f|file=s'    => \$file,
		's|schema=s'  => \$schema,
		'o|outfile=s' => \$outfile,
		'test'        => \$test,
		'h|help'      => \$help
	);

	$self->manifest($file)   if ( defined $file );
	$self->schema($schema)   if ( defined $schema );
	$self->outfile($outfile) if ( defined $outfile );
	$self->test($test)       if ( defined $test );
	$self->help($help)       if ( defined $help );
}

sub check_inputs{
    my $self = shift; 
    return(
        $self->manifest
        && !$self->help
    );
}

sub run {
	my ($self)   = @_;
	my $manifest = $self->manifest;
	my $schema   = $self->schema;
	my $outfile  = $self->outfile;

	# sanity checks
	$self->check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	( -e $manifest ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find $manifest\n" );
	( -r $manifest ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $manifest\n" );
	$outfile = "$manifest.report.xls" unless( defined( $outfile ) );
	$self->outfile($outfile);
	system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" ) if ( defined $outfile );

	# first, validate the manifest
	my @args = ( '-f', $manifest, '-r', $outfile );
	my $validator = Bio::ENA::DataSubmission::CommandLine::ValidateManifest->new( args => \@args );
	Bio::ENA::DataSubmission::Exception::ValidationFail->throw("Manifest $manifest did not pass validation. See $outfile for report\n") if( $validator->run == 0 ); # manifest failed validation

	# generate updated sample XML
	$self->_updated_xml;

	# generate submission XML
	$self->_generate_submission;

	# validate both with XSD
	$self->_validate_with_xsd;

	# copy spreadsheet to /lustre/scratch108/pathogen/pathpipe/ena_updates/
	$self->_record_spreadsheet;

	# email Rob
	# $self->_email;

}

sub _updated_xml {
	my $self     = shift;
	my $test     = $self->test;
	my $dest     = $self->_output_dest;
	my $manifest = $self->manifest;

	# parse manifest and loop through samples
	my $manifest_handler = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $manifest );
	my @manifest = @{ $manifest_handler->parse_manifest };
	my @updated_samples;
	foreach my $sample (@manifest){
		my $new_sample = Bio::ENA::DataSubmission::XML->new()->update( $sample );
		push( @updated_samples, $new_sample );
	}
	my %new_xml = ( 'SAMPLE' => \@updated_samples );
	Bio::ENA::DataSubmission::XML->new( data => \%new_xml, outfile => "$dest/sample.xml", root => 'SAMPLE_SET' )->write;
}

sub _generate_submission {
	my $self = shift;
	my $dest = $self->_output_dest;
	my $root = $self->_data_root;

	my $sub = "$root/submission.xml";
	system("cp $sub $dest/submission.xml");
}

sub _validate_with_xsd {
	my $self = shift;
	my $dest = $self->_output_dest;

	my $xsd_root = $self->_data_root;

	my $sample_validator = Bio::ENA::DataSubmission::XML->new( xml => "$dest/sample.xml", xsd => "$xsd_root/sample.xsd" );
	Bio::ENA::DataSubmission::Exception::ValidationFail->throw( error => "Validation of updated sample XML failed\n" ) unless ( $sample_validator->validate );

	my $submission_validator = Bio::ENA::DataSubmission::XML->new( xml => "$dest/sample.xml", xsd => "$xsd_root/submission.xsd" );
	Bio::ENA::DataSubmission::Exception::ValidationFail->throw( error => "Validation of submission XML failed\n" ) unless ( $submission_validator->validate );

	return 1;
}

sub _record_spreadsheet {
	my $self = shift;
	my $manifest = $self->manifest;
	my $dest = $self->_output_dest;

	system("cp $manifest $dest/manifest.xls");
}

# sub _email {
# 	my $self = shift;
# 	my $dest = $self->_output_dest;
# 	my $to = $self->_email_to;

# 	my $message = Email::MIME->create(
#     	header_str => [
#         	From    => 'cc21@sanger.ac.uk',
#         	To      => $to,
#         	Subject => 'ENA Metadata Update Request',
#     	],
#     	attributes => {
#         	encoding => 'quoted-printable',
#         	charset  => 'ISO-8859-1',
#     	},
#     	body_str => "Hi,\n\nSome sample metadata are ready to update with the ENA. The files are located @ $dest\n\nThanks,\nCarla",
# 	);

# 	sendmail($message);
# }

sub usage_text {
	return <<USAGE;
Usage: update_sample_manifest [options]

	-f|file       input manifest for update
	-o|outfile    output path for validation report
	-h|help       this help message

USAGE
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;