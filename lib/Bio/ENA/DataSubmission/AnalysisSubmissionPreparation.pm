package Bio::ENA::DataSubmission::AnalysisSubmissionPreparation;

# ABSTRACT: module for generation of manifest files for ENA genome update

=head1 NAME

Bio::ENA::DataSubmission::AnalysisSubmissionPreparation

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

use Path2::Find;
use Path2::Find::Lanes;
use Path2::Find::Filter;

use Getopt::Long qw(GetOptionsFromArray);

use Bio::SeqIO;

use Bio::ENA::DataSubmission::Exception;
use Bio::ENA::DataSubmission::Spreadsheet;
use Bio::ENA::DataSubmission::FindData;
use Bio::ENA::DataSubmission::AnalysisManifest;
use Bio::ENA::DataSubmission::GffConverter;
use List::MoreUtils qw(uniq);

has 'manifest_spreadsheet' => (is => 'ro', isa => 'ArrayRef', required => 1);
has 'output_dir' => (is => 'ro', isa => 'Str', required => 1);
has 'gff_converter' => (is => 'ro', isa => 'Bio::ENA::DataSubmission::GffConverter', required => 1);
has 'manifest_for_submission' => (is => 'ro', isa => 'ArrayRef', required => 0, lazy_build => 1);
has 'locus_tags' => (is => 'rw', isa => 'ArrayRef', required => 0);


sub BUILD {
    my ($self) = @_;
    (-e $self->output_dir && -d _) or Bio::ENA::DataSubmission::Exception::DirectoryNotFound->throw(error => "Cannot find output directory\n");

}

sub prepare_for_submission {
    my ($self) = @_;

    $self->_copy_data_files();
    $self->_generate_chromosome_files_for_fasta();
    $self->_convert_gffs_to_flatfiles();
    $self->_gzip_files();
    my $manifests = $self->manifest_for_submission;
    $self->_write_manifest_files($manifests);
    $self->_write_transformed_sheet();
    return $self->_generate_data_for_submission();
}

sub _generate_data_for_submission {
    my ($self) = @_;
    my @spreadsheet = @{$self->manifest_spreadsheet};
    my @ready_for_submission = ();
    for my $row (@spreadsheet) {
        push @ready_for_submission, [$row->{manifest}, $row->{analysis_center}];
    }
    return @ready_for_submission;

}

sub _write_manifest_files {
    my ($self, $manifests) = @_;
    my ($manifest);
    for $manifest (@$manifests) {
        my $manifest_file = $self->output_dir . "/" . $manifest->assembly_name . ".manifest";
        open(my $fh, '>', $manifest_file);
        print $fh $manifest->get_content();
        close $fh;
    }
}

sub _build_manifest_for_submission {
    my ($self) = @_;

    my @spreadsheet = @{$self->manifest_spreadsheet};
    my @manifests = map {$self->_to_analysis_manifest_for_cli($_)} @spreadsheet;

    return \@manifests;
}

sub _write_transformed_sheet {
    my $header = [
        'name', 'partial', 'coverage', 'program', 'platform', 'minimum_gap',
        'file', 'file_type', 'title', 'description', 'study', 'sample', 'run',
        'analysis_center', 'analysis_date', 'release_date', 'pubmed_id', 'tax_id', 'common_name', 'locus_tag',
        'chromosome_list_file', 'manifest',
    ];
    my $data = [];
    my ($self) = @_;
    my $temp_file = $self->output_dir . '/submission_spreadsheet.xls';
    my @spreadsheet = @{$self->manifest_spreadsheet};

    for my $row (@spreadsheet) {
        my $row_as_array = [];
        for my $head (@$header) {
            my $value = $row->{$head};
            push @$row_as_array, defined($value) ? $value : '';
        }
        push @$data, $row_as_array;
    }

    my $manifest_handler = Bio::ENA::DataSubmission::Spreadsheet->new(outfile => $temp_file, _header => $header, data => $data, add_manifest_header => 1);
    $manifest_handler->write_xls();
}

sub _to_analysis_manifest_for_cli {
    my ($self, $row) = @_;

    my ($flat_file) = $row->{file_type} eq 'chromosome_flatfile' || $row->{file_type} eq 'scaffold_flatfile' ? $row->{file} : undef;
    my ($fasta_file) = $row->{file_type} eq 'chromosome_fasta' || $row->{file_type} eq 'scaffold_fasta' ? $row->{file} : undef;
    my ($assembly_name) = $row->{name};
    $row->{manifest} = $self->output_dir . "/" . $assembly_name . ".manifest";
    return Bio::ENA::DataSubmission::AnalysisManifest->new(
        study          => $row->{study},
        sample         => $row->{sample},
        assembly_name  => $assembly_name,
        assembly_type  => "clone or isolate",
        coverage       => $row->{coverage},
        program        => $row->{program},
        platform       => $row->{platform},
        molecule_type  => "genomic DNA",
        flat_file      => $flat_file,
        chromosom_list => $row->{chromosome_list_file},
        fasta          => $fasta_file,
    );
}


sub _copy_data_files {
    my ($self) = @_;
    my @spreadsheet = @{$self->manifest_spreadsheet};

    for my $row (@spreadsheet) {
        chomp($row->{name});
        my $sample_name = $row->{name};
        my ($filename, $directories, $suffix) = fileparse($row->{file}, qr/\.[^.]*/);
        if ($suffix eq '.fa') {
            $suffix = '.fasta';
        }

        my $temp_file = $self->output_dir . '/' . $sample_name . $suffix;
        copy($row->{file}, $temp_file);
        print "Copied $row->{file} to $temp_file\n";
        $row->{file} = $temp_file;
    }
    return 1;
}

sub _generate_chromosome_files_for_fasta {
    my ($self) = @_;
    my @spreadsheet = @{$self->manifest_spreadsheet};

    for my $row (@spreadsheet) {
        if (defined($row->{file_type}) && $row->{file_type} eq 'chromosome_fasta') {
            my $chromosome_filename = $self->output_dir . "/" . $row->{name} . ".chromosome_list";
            $self->_generate_chromosome_file_for_fasta($row->{file}, $chromosome_filename);
            $row->{chromosome_list_file} = $chromosome_filename;
        }
    }
}

sub _generate_chromosome_file_for_fasta {
    my ($self, $input_file, $output_file) = @_;
    open(my $chr_list_fh, '+>', $output_file);
    my $in = Bio::SeqIO->new(-file => $input_file, '-format' => 'Fasta');

    my $counter = 1;
    while (my $seq = $in->next_seq()) {
        my $cur_size = $seq->length();
        my $seq_name = $seq->display_id();
        my $type = ($cur_size > 1000000) ? 'Chromosome' : 'Plasmid';
        print {$chr_list_fh} join("\t", ($seq_name, $counter, $type)) . "\n";
        $counter++;
    }
    close($chr_list_fh);
    print "Generated $output_file\n";
}

sub _convert_gffs_to_flatfiles {
    my ($self) = @_;
    $self->locus_tags([]);
    my @spreadsheet = @{$self->manifest_spreadsheet};
    for my $row (@spreadsheet) {
        next unless ($row->{file} =~ /gff$/);
        chomp($row->{name});
        my $sample_name = $row->{name};
        my $output_file = $self->output_dir . "/" . $sample_name . '.embl';
        my $locus_tag = $self->_get_locus_tag($row);
        $self->_populate_flat_file_chromosome_list($row);
        $self->gff_converter->convert($locus_tag, $row->{chromosome_list_file}, $output_file, $row->{file}, $row->{common_name}, $row->{tax_id}, $row->{study}, $row->{description});
        $row->{file} = $output_file;
    }
}

sub _get_locus_tag {
    my ($self, $row) = @_;

    my ($locus_tag) = (defined($row->{locus_tag}) && $row->{locus_tag} ne "") ? $row->{locus_tag} : undef;
    push @{$self->locus_tags}, $locus_tag;

    return $locus_tag;

}

sub _populate_flat_file_chromosome_list {
    my ($self, $row) = @_;

    if (defined($row->{file_type}) && $row->{file_type} eq 'chromosome_flatfile') {
        my $sample_name = $row->{name};
        chomp $sample_name;
        $row->{chromosome_list_file} = $self->output_dir . "/" . $sample_name . ".chromosome_list";
    }
}

sub _gzip {
    my ($input) = @_;
    my @cmd = ("gzip", "-f", "-n", $input);
    print "Executing: \"" . join("\" \"", @cmd) . "\"\n"; 
    system(@cmd);
}

sub _gzip_files {
    my ($self) = @_;
    my @spreadsheet = @{$self->manifest_spreadsheet};
    foreach my $row (@spreadsheet) {
        my $file_gz = $row->{file} . '.gz';
        _gzip($row->{file});
        $row->{file} = $file_gz;
        if (defined($row->{chromosome_list_file}) && (-e $row->{chromosome_list_file})) {
            my $file_cl_gz = $row->{chromosome_list_file} . '.gz';
            _gzip($row->{chromosome_list_file});
            $row->{chromosome_list_file} = $file_cl_gz;
        }
    }
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;
