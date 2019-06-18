package Bio::ENA::DataSubmission::FindData;

# ABSTRACT: pull lane objects from DB. Return 

=head1 NAME

Bio::ENA::DataSubmission::CommandLine::GenerateAnalysisManifest

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
use Moose::Util::TypeConstraints;
use namespace::autoclean;

use Path2::Find;
use Path2::Find::Lanes;
use Data::Dumper;

has 'type' => (is => 'rw', isa => 'Str', required => 1);
has 'id' => (is => 'rw', isa => 'Str', required => 1);
has 'file_type' => (is => 'rw', isa => 'Str', default => 'assembly');
has 'file_id_type' => (is => 'rw', isa => enum([ qw(lane sample) ]), default => 'lane');

has '_vrtrack' => (is => 'rw', isa => 'VRTrack::VRTrack');
has '_root' => (is => 'rw', isa => 'Str');


sub map {
    my (undef, $type, $id, $file_type, $file_id_type, $mapping) = @_;

    my $finder = Bio::ENA::DataSubmission::FindData->new(
        type         => $type,
        id           => $id,
        file_type    => $file_type,
        file_id_type => $file_id_type,
    );
    return $finder->_map($mapping);
}

sub _map {
    my ($self, $mapping) = @_;
    my @result = ();
    my %data = %{$self->find()};
    for my $id (@{$data{key_order}}) {
        push @result, $mapping->($self, $id, $data{$id});
    }
    return \@result;
}

sub find {
    my $self = shift;

    my $lanes = $self->_get_lanes_from_db;

    my %data = (key_order => []);
    return \%data unless @$lanes;

    if ($self->type eq 'lane' || $self->type eq 'sample') {
        push(@{$data{key_order}}, $self->id);
        $data{$self->id} = $lanes->[0];
    }
    elsif ($self->type eq 'study') {
        for my $l (@$lanes) {
            push(@{$data{key_order}}, $l->name);
            $data{$l->name} = $l;
        }
    }
    elsif ($self->type eq 'file') {
        # set key order as per file
        open(my $fh, '<', $self->id);
        my @ids = <$fh>;
        chomp @ids;
        $data{key_order} = \@ids;

        # match returned lane objects to their ID
        my @found_ids = $self->_found_ids($lanes, \@ids);

        for my $id (@ids) {
            $data{$id} = undef;
            my ($index) = grep {$found_ids[$_] eq $id} 0 .. $#found_ids;
            $data{$id} = $lanes->[$index] if (defined $index);
        }
    }

    return \%data;
}

sub _get_lanes_from_db {
    my $self = shift;
    my $lanes;
    my $find = Path2::Find->new();
    my @pathogen_databases = $find->pathogen_databases;
    my ($pathtrack, $dbh, $root);
    for my $database (@pathogen_databases) {
        ($pathtrack, $dbh, $root) = $find->get_db_info($database);

        my $find_lanes = Path2::Find::Lanes->new(
            search_type    => $self->type,
            search_id      => $self->id,
            file_id_type   => $self->file_id_type,
            pathtrack      => $pathtrack,
            dbh            => $dbh,
        );
        $lanes = $find_lanes->lanes;

        if (@$lanes) {
            $dbh->disconnect();
            last;
        }
    }

    $self->_vrtrack($pathtrack);
    $self->_root($root);

    return $lanes;
}

sub _found_ids {
    my ($self, $lanes, $existing_ids) = @_;

    # extract IDs from lane objects
    my @got_ids;

    # detect whether lane names or sample accessions
    foreach my $lane (@$lanes) {
        if ($self->file_id_type eq 'lane') {
            push @got_ids, $lane->{name};
        }
        else {
            my %valid = map { $_ => 1 } @$existing_ids;
            my $library = VRTrack::Library->new($self->_vrtrack, $lane->library_id);
            if (not defined $library) {
                warn q(WARNING: no sample for library ') . $lane->library_id . q(');
                next;
            }
            my $sample = VRTrack::Sample->new($self->_vrtrack, $library->sample_id);
            if (exists($valid{$sample->individual->acc})) {
                push @got_ids, $sample->individual->acc;
            }
            else {
                push @got_ids, $sample->name;
            }
        }
    }
    return @got_ids;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
