package Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifestForCli;

# ABSTRACT: module for generation of manifest files for ENA genome update

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifestForCli

=head1 SYNOPSIS

	use Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest;
	

=head1 METHODS



=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;
use File::Slurp;
use File::Basename;
use File::Copy qw(copy);
use File::Temp;

use Path::Find;
use Path::Find::Lanes;
use Path::Find::Filter;

use Getopt::Long qw(GetOptionsFromArray);

use Bio::SeqIO;

use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::Spreadsheet;
use Bio::ENA::DataSubmission::FindData;
use Bio::ENA::DataSubmission::AnalysisManifest;
use List::MoreUtils qw(uniq);
use Data::Dumper;

has 'args' => (is => 'ro', isa => 'ArrayRef', required => 1);

has 'type' => (is => 'rw', isa => 'Str', required => 0);
has 'id' => (is => 'rw', isa => 'Str', required => 0);
has 'outfile' => (is => 'rw', isa => 'Str', required => 0, default => 'analysis_manifest.xls');
has 'manifest_data' => (is => 'rw', isa => 'ArrayRef', required => 0, lazy_build => 1);
has 'empty' => (is => 'rw', isa => 'Bool', required => 0, default => 0);
has 'pubmed_id' => (is => 'rw', isa => 'Str', required => 0, default => '');
has 'help' => (is => 'rw', isa => 'Bool', required => 0);
has '_current_date' => (is => 'rw', isa => 'Str', required => 0, lazy_build => 1);
has '_analysis_center' => (is => 'rw', isa => 'Str', required => 0, lazy_build => 1);
has '_show_errors' => (is => 'rw', isa => 'Bool', required => 0, default => 1);

has 'file_type' => (is => 'rw', isa => 'Str', required => 0, default => 'assembly');
has 'assembly_directories' => (is => 'rw', isa => 'Maybe[ArrayRef]');
has 'annotation_directories' => (is => 'rw', isa => 'Maybe[ArrayRef]');
has 'config_file' => (is => 'rw', isa => 'Str', required => 0, default => '/software/pathogen/config/ena_data_submission.conf');

sub _build__current_date {
    my $self = shift;

    my @timestamp = localtime(time);
    my $day = sprintf("%04d-%02d-%02d", $timestamp[5] + 1900, $timestamp[4] + 1, $timestamp[3]);
    return $day;
}

sub _build__analysis_center {
    return 'SC';
}

sub BUILD {
    my ($self) = @_;

    my ($type, $id, $outfile, $empty, $pubmed_id, $no_errors, $help, $config_file, $file_type);
    my $args = $self->args;

    GetOptionsFromArray(
        $args,
        't|type=s'        => \$type,
        'i|id=s'          => \$id,
        'o|outfile=s'     => \$outfile,
        'empty'           => \$empty,
        'p|pubmed_id=s'   => \$pubmed_id,
        'no_errors'       => \$no_errors,
        'h|help'          => \$help,
        'c|config_file=s' => \$config_file,
        'a|file_type=s'   => \$file_type
    );

    $self->type($type) if (defined $type);
    $self->id($id) if (defined $id);
    $self->outfile($outfile) if (defined $outfile);
    $self->empty($empty) if (defined $empty);
    $self->pubmed_id($pubmed_id) if (defined $pubmed_id);
    $self->_show_errors(!$no_errors) if (defined $no_errors);
    $self->help($help) if (defined $help);
    $self->file_type($file_type) if (defined $file_type);

    $self->config_file($config_file) if (defined $config_file);
    (-e $self->config_file) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw(error => "Cannot find config file\n");
    $self->_populate_attributes_from_config_file;
}

sub _populate_attributes_from_config_file {
    my ($self) = @_;
    my $file_contents = read_file($self->config_file);
    my $config_values = eval($file_contents);

    $self->assembly_directories($config_values->{assembly_directories});
    $self->annotation_directories($config_values->{annotation_directories});
}

sub check_inputs {
    my $self = shift;
    return(
        ($self->type
            && ($self->type eq 'study'
            || $self->type eq 'lane'
            || $self->type eq 'file'
            || $self->type eq 'sample')
            && $self->id)
            || $self->empty
            && !$self->help
    );
}

sub run {
    my ($self) = @_;

    my $outfile = $self->outfile;

    # sanity checks
    $self->check_inputs or Bio::ENA::DataSubmission::Exception::InvalidInput->throw(error => $self->usage_text);
    if (defined $self->type && $self->type eq 'file') {
        my $id = $self->id;
        (-e $id) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw(error => "File $id does not exist\n");
        (-r $id) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw(error => "Cannot read $id\n");
    }
    system("touch $outfile &> /dev/null") == 0 or Bio::ENA::DataSubmission::Exception::CannotWriteFile->throw(error => "Cannot write to $outfile\n") if (defined $outfile);

    my $header = [
        'name*', 'partial*', 'coverage*', 'program*', 'platform*', 'minimum_gap',
        'file*', 'file_type*', 'title', 'description*', 'study*', 'sample*', 'run',
        'analysis_center', 'analysis_date', 'release_date', 'pubmed_id', 'tax_id', 'common_name', 'locus_tag'
    ];

    # write data to spreadsheet
    my $data = $self->manifest_data;
    #my $manifest = Bio::ENA::DataSubmission::Spreadsheet->new(
    #	data                => $data,
    #	outfile             => $outfile,
    #	_header             => $header,
    #	add_manifest_header => 1
    #);
    #$manifest->write_xls;
    #print "Created manifest file:\t".$self->outfile."\n";

    1;
}

sub _build_manifest_data {
    my $self = shift;

    return [] if ($self->empty);

    #my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1);
    my $temp_directory_obj = File::Temp->newdir();

    my $tmp = $temp_directory_obj->dirname();
    print "temp dir:" . $tmp . "\n";

    my $finder = Bio::ENA::DataSubmission::FindData->new(
        type      => $self->type,
        id        => $self->id,
        file_type => $self->file_type
    );
    my %data = %{$finder->find};

    my @manifest = ();
     for my $k (@{$data{key_order}}) {
        push(@manifest, $self->_manifest_from_db($finder, $data{$k}, $k)->get_content(), $tmp);
     }
    return \@manifest;
}

sub _manifest_from_db {
    my ($self, $f, $lane, $k, $tmp) = @_;

    if (not defined $lane) {
        return Bio::ENA::DataSubmission::AnalysisManifest->new(
            study          => 'not found',
            sample         => 'not found',
            assembly_name  => '',
            assembly_type  => "clone or isolate",
            coverage       => 0,
            program        => '',
            platform       => '',
            molecule_type  => "genomic DNA",
            flat_file      => "I",
            chromosom_list => "J",
            fasta          => "K",
        );
    }
    my ($coverage, $program, $file, $file_type) = $self->_get_file_details($f, $lane);
    my $sample = $self->_get_sample_from_lane($f->_vrtrack, $lane);
    my ($tax_id, $common_name) = $self->_get_species_name_and_taxid_from_lane($f->_vrtrack, $lane);
    my $study = $self->_get_study_from_lane($f->_vrtrack, $lane);
    my $description = $self->_create_description($common_name);

    $file = $self->_temp_copies($tmp, $file, $lane->name);
    my($chromosom_list) = $self->_generate_chromosome_file_if_required($lane->name, $file, $file_type, $tmp);
    my($converted_gff) = $self->_convert_gffs_to_flatfiles_cmds($lane->name, $file, $tmp, $chromosom_list, $sample, $common_name, $tax_id, $study, $description);
    $chromosom_list = $self->gzip($chromosom_list);
    my ($flatfile, $fasta);
    if ($file_type eq 'scaffold_fasta') {
        $fasta = (defined $converted_gff) ? $converted_gff : $file;
    }

    if ($file_type eq 'scaffold_flatfile') {
        $flatfile = (defined $converted_gff) ? $converted_gff : $file;
    }

    my $man = Bio::ENA::DataSubmission::AnalysisManifest->new(
        study          => $study,
        sample         => $sample,
        assembly_name  => $lane->name,
        assembly_type  => "clone or isolate",
        coverage       => $coverage,
        program        => $program,
        platform       => $self->_get_seq_tech_from_lane($f->_vrtrack, $lane),
        molecule_type  => "genomic DNA",
        flat_file      => $flatfile,
        chromosom_list => $chromosom_list,
        fasta          => $fasta,
    );
    return $man;
}


sub _temp_copies {
    my ($self, $tmpdir, $file, $name) = @_;
    my $sample_name = $name;
    chomp($sample_name);

    my ($filename, $directories, $suffix) = fileparse($file, qr/\.[^.]*/);
    if ($suffix eq '.fa') {
        $suffix = '.fasta';
    }

    my $temp_file = $tmpdir . '/' . $sample_name . $suffix;
    copy($file, $temp_file);

    return $self->gzip($temp_file);
}

sub _gzip{
    # TODO run this afterwards in parallel
    my ($self, $file) = @_;
    my $file_gz = $file . '.gz';
    my @cmd = ("gzip", "-c", "-n", $file, ">", $file_gz);
    system(@cmd);

    return $file_gz;
}

sub _generate_chromosome_file_if_required {
    my ($self, $name, $input_file, $file_type, $temp_dir) = @_;
    my $sample_name = $name;
    chomp($sample_name);
    my $chromosome_filename;
    if (defined($file_type) && $file_type eq 'chromosome_fasta') {
        $chromosome_filename = $temp_dir . $sample_name . ".chromosome_list";
        $self->_generate_chromosome_file($input_file, $chromosome_filename);
    }
    return $chromosome_filename;
}

sub _convert_gffs_to_flatfiles_cmds {
    # TODO run this afterwards in parallel
    my ($self, $name, $input_file, $temp_dir, $chromosome_filename, $locus_tag, $common_name, $tax_id, $study, $description) = @_;
    my $output_file;

    if ($input_file =~ /gff$/) {
        my $sample_name = $name;
        chomp($sample_name);

        $output_file = $temp_dir . $sample_name . '.embl';
        my(@cmd) = ("gff3_to_embl");
        push @cmd, "--locus_tag", $locus_tag if defined $locus_tag && $locus_tag ne "";
        push @cmd, "--chromosome_list", $chromosome_filename if defined $chromosome_filename;
        push @cmd, "--output_filename", $output_file, $common_name, $tax_id, $study, $description, $input_file;
        system(@cmd);
        return $self->gzip($output_file);
    }
    return $output_file;
}


sub _generate_chromosome_file {
    my ($self, $input_file, $output_file) = @_;
    open(my $chr_list_fh, '+>', $output_file);
    my $in = Bio::SeqIO->new(-file => $input_file, '-format' => 'Fasta');

    my $counter = 1;
    while (my $seq = $in->next_seq()) {
        my $cur_size = $seq->length();
        my $seq_name = $seq->display_id();

        if ($cur_size > 1000000) {
            print {$chr_list_fh} join("\t", ($seq_name, $counter, 'Chromosome')) . "\n";
        }
        else {
            print {$chr_list_fh} join("\t", ($seq_name, $counter, 'Plasmid')) . "\n";
        }
        $counter++;
    }
}


sub _manifest_row {
    my ($self, $f, $lane, $k) = @_;

    my @row = ('', 'FALSE', 'not found', '', 'SLX', '0', '', '', '', '', 'not found', 'not found', 'not found', $self->_analysis_center, $self->_current_date, $self->_current_date, $self->pubmed_id, '', '', '');
    @row = $self->_error_row(\@row) if ($self->_show_errors);
    unless (defined $lane) {
        $row[12] = $k;
        return \@row;
    }

    $row[0] = $lane->name;
    ($row[2], $row[3], $row[6], $row[7]) = $self->_get_file_details($f, $lane);
    $row[4] = $self->_get_seq_tech_from_lane($f->_vrtrack, $lane);
    $row[10] = $self->_get_study_from_lane($f->_vrtrack, $lane);
    $row[11] = $self->_get_sample_from_lane($f->_vrtrack, $lane);
    $row[12] = $self->_get_run_from_lane($lane);
    ($row[18], $row[17]) = $self->_get_species_name_and_taxid_from_lane($f->_vrtrack, $lane);
    $row[8] = $self->_create_description($row[18]);
    $row[9] = $row[8];
    return \@row;
}

sub _error_row {
    my ($self, $row) = @_;

    my @new_row;
    for my $cell (@{$row}) {
        $cell =~ s/not found/not found!!/;
        push(@new_row, $cell);
    }
    return @new_row;
}

sub _get_seq_tech_from_lane {
    my ($self, $vrtrack, $lane) = @_;

    my ($library, $seq_tech);

    $library = VRTrack::Library->new($vrtrack, $lane->library_id);
    $seq_tech = VRTrack::Seq_tech->new($vrtrack, $library->seq_tech_id);

    return $seq_tech->name;
}

sub _get_study_from_lane {
    my ($self, $vrtrack, $lane) = @_;
    my ($library, $sample, $project, $study);

    $library = VRTrack::Library->new($vrtrack, $lane->library_id);
    $sample = VRTrack::Sample->new($vrtrack, $library->sample_id) if defined $library;
    $project = VRTrack::Project->new($vrtrack, $sample->project_id) if defined $sample;
    $study = VRTrack::Study->new($vrtrack, $project->study_id) if defined $project;

    return $study->acc;
}

sub _get_species_name_and_taxid_from_lane {
    my ($self, $vrtrack, $lane) = @_;
    my ($library, $sample, $individual, $species);

    $library = VRTrack::Library->new($vrtrack, $lane->library_id);
    $sample = VRTrack::Sample->new($vrtrack, $library->sample_id) if defined $library;
    $individual = VRTrack::Individual->new($vrtrack, $sample->individual_id) if defined $sample;
    $species = VRTrack::Species->new($vrtrack, $individual->species_id) if defined $individual;
    unless (defined($species)) {
        return('', '');
    }

    return($species->name, $species->taxon_id);
}

sub _get_sample_from_lane {
    my ($self, $vrtrack, $lane) = @_;
    my ($library, $sample);

    $library = VRTrack::Library->new($vrtrack, $lane->library_id);
    $sample = VRTrack::Sample->new($vrtrack, $library->sample_id)
        if defined $library;

    return $sample->individual->acc;
}

sub _get_run_from_lane {
    my ($self, $lane) = @_;
    return '' unless (defined($lane->acc));
    return $lane->acc;
}

sub _get_file_details {
    my ($self, $finder, $lane) = @_;
    if ($self->file_type eq "assembly") {
        return $self->_get_assembly_details($finder, $lane);
    }
    else {
        return $self->_get_annotation_details($finder, $lane);
    }
}

sub _get_annotation_details {
    my ($self, $finder, $lane) = @_;

    my $yield = $lane->raw_bases;
    my %type_extensions = (gff => '*.gff');
    my $lane_filter = Path::Find::Filter->new(
        lanes           => [ $lane ],
        filetype        => 'gff',
        type_extensions => \%type_extensions,
        root            => $finder->_root,
        pathtrack       => $finder->_vrtrack,
        subdirectories  => $self->annotation_directories,
    );
    my @matching_lanes = $lane_filter->filter;
    return undef unless defined $matching_lanes[0];

    return(100, 'Prokka', $matching_lanes[0]->{path}, 'scaffold_flatfile');
}

sub _get_assembly_details {
    my ($self, $finder, $lane) = @_;

    my $yield = $lane->raw_bases;

    my %type_extensions = (assembly => 'contigs.fa');
    my $lane_filter = Path::Find::Filter->new(
        lanes           => [ $lane ],
        filetype        => 'assembly',
        type_extensions => \%type_extensions,
        root            => $finder->_root,
        pathtrack       => $finder->_vrtrack,
        subdirectories  => $self->assembly_directories,
    );
    my @matching_lanes = $lane_filter->filter;
    return undef unless defined $matching_lanes[0];

    return($self->_calculate_coverage($matching_lanes[0]->{path} . '.stats', $yield), $self->_get_assembly_program($matching_lanes[0]->{path}), $matching_lanes[0]->{path}, 'scaffold_fasta');
}

sub _get_assembly_program {
    my ($self, $path) = @_;
    my $program = 'velvet';
    if ($path =~ /\/(\w+)_assembly/) {
        $program = $1;
    }
    return $program;
}

sub _create_description {
    my ($self, $common_name) = @_;
    if ($self->file_type eq "assembly") {
        return "Assembly of $common_name";
    }
    else {
        return "Annotated assembly of $common_name";
    }
}

sub _calculate_coverage {
    my ($self, $path, $yield) = @_;

    open(my $fh, '<', $path);
    my $line = <$fh>;
    $line = <$fh>;
    $line =~ /sum = (\d+)/;
    my $assembly = int($1);
    my $coverage = int($yield / $assembly);
    return $coverage;
}

sub usage_text {
    return <<USAGE;
Usage: generate_analysis_manifest [options]

	-t|type          lane|study|file|sample
	-i|id            lane ID|study ID|file of lanes|file of samples|sample ID
	-o|outfile       path for output manifest
	--empty          generate empty manifest
	-p|pubmed_id     pubmed ID associated with analysis
	-a|file_type     [assembly|annotation] defaults to assembly
	-h|help          this help message

USAGE
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;
