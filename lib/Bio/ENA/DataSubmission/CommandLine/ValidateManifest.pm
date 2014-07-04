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
use Getopt::Long qw(GetOptionsFromArray);
use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::Spreadsheet;

has 'args'    => ( is => 'ro', isa => 'ArrayRef', required => 1 );

has 'file'    => ( is => 'rw', isa => 'Str',      required => 0 );
has 'report'  => ( is => 'rw', isa => 'Str',      required => 0 );
has 'outfile' => ( is => 'rw', isa => 'Str',      required => 0 );
has 'edit'    => ( is => 'rw', isa => 'Bool',     required => 0 );
has 'help'    => ( is => 'rw', isa => 'Bool',     required => 0 );

sub BUILD {
	my ( $self ) = @_;

	my ( $file, $report, $outfile, $help );
	my $args = $self->args;

	GetOptionsFromArray(
		$args,
		'f|file=s'    => \$file,
		'r|report=s'  => \$report,
		'o|outfile=s' => \$outfile,
		'edit'        => \$edit,
		'h|help'      => \$help
	);

	$self->file($file)       if ( defined $file );
	$self->report($report)   if ( defined $report );
	$self->outfile($outfile) if ( defined $outfile );
	$self->edit($edit)       if ( defined $edit );
	$self->help($help)       if ( defined $help );
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

	# sanity checks
	$self->check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw( error => $self->usage_text );
	( -e $file ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find $file\n" );
	( -r $file ) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot read $file\n" );
	system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $outfile\n" ) if ( defined $outfile );
	system("touch $report &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw( error => "Cannot write to $report\n" ) if ( defined $report );

	my $parser = Bio::ENA::DataSubmission::Spreadsheet->new( infile => $file );
	my @manifest = @{ $parser->parse };
	my @header = @{ shift $manifest };

	foreach my $r ( 0..$#manifest ){
		my @row = @{ $manifest[$r] };
		
		# sample accession
		
	}
}

sub usage_text {
	return "USAGE TEXT\n";
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;