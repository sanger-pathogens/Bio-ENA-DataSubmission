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

use Path::Find;
use Path::Find::Lanes;

has 'type' => ( is => 'rw', isa => 'Str', required => 1 );
has 'id'   => ( is => 'rw', isa => 'Str', required => 1 );
has 'file_type'   => ( is => 'rw', isa => 'Str',      required => 0, default    => 'assembly' );

has '_vrtrack' => ( is => 'rw', isa => 'VRTrack::VRTrack' );
has '_root'    => ( is => 'rw', isa => 'Str' );

sub find {
	my $self = shift;

	my @lanes = @{ $self->_get_lanes_from_db };

    my %data = (key_order => []);
    return \%data unless @lanes;

    if ( $self->type eq 'lane' || $self->type eq 'sample' ){
    	push( $data{key_order}, $self->id );
    	$data{$self->id} = $lanes[0];
    }
    elsif ( $self->type eq 'study' ){
    	for my $l ( @lanes ){
    		push( $data{key_order}, $l->name );
    		$data{$l->name} = $l;
    	}
    }
    elsif ( $self->type eq 'file' ){
    	# set key order as per file
    	open( my $fh, '<', $self->id );
    	my @ids = <$fh>;
	chomp @ids;
    	$data{key_order} = \@ids;

    	# match returned lane objects to their ID
    	my @found_ids = $self->_found_ids( \@lanes );
    	for my $id ( @ids ){
    		$data{$id} = undef;
    		my ($index) = grep { $found_ids[$_] eq $id } 0..$#found_ids;
    		$data{$id} = $lanes[$index] if ( defined $index );
    	}
    }

    return \%data;
}

sub _get_lanes_from_db {
    my $self = shift;
	my @lanes;
	my $find = Path::Find->new();
	my @pathogen_databases = $find->pathogen_databases;
    my ( $pathtrack, $dbh, $root );
	for my $database (@pathogen_databases){
		( $pathtrack, $dbh, $root ) = $find->get_db_info($database);

        my $processed_flag = 0;
        if($self->file_type eq 'assembly')
        {
          $processed_flag = 1024;
        }
        elsif($self->file_type eq 'annotation')
        {
          $processed_flag = 2048;
        }
        
        my $find_lanes = Path::Find::Lanes->new(
            search_type    => $self->type,
            search_id      => $self->id,
            pathtrack      => $pathtrack,
            dbh            => $dbh,
            processed_flag => $processed_flag
        );
        @lanes = @{ $find_lanes->lanes };

        if (@lanes) {
            $dbh->disconnect();
            last;
        }
    }

    $self->_vrtrack($pathtrack);
    $self->_root($root);

    return \@lanes;
}

sub _found_ids {
	my ( $self, $l ) = @_;
	my @lanes = @{ $l };
	my $vrtrack = $self->_vrtrack;

	open( my $fh, '<', $self->id );
	my @ids = <$fh>;

	# extract IDs from lane objects
	my @got_ids;

	# detect whether lane names or sample accessions
    if ( $ids[0] =~ /#/ ){
    	@got_ids = $self->_extract_lane_ids(\@lanes);
    }
    else {
    	@got_ids = $self->_extract_accessions(\@lanes, $vrtrack);
    }

    return @got_ids;
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
	my ( $self, $l, $vrtrack ) = @_;

	my @accs;
	for my $lane ( @{ $l } ){
		my $sample = $self->_get_sample_from_lane($lane, $vrtrack);
		push( @accs, $sample->individual->acc );
	}
	return @accs;
}

sub _get_sample_from_lane {
    my ( $self, $lane, $vrtrack ) = @_;
    my ( $library, $sample );

    $library = VRTrack::Library->new( $vrtrack, $lane->library_id );
    $sample = VRTrack::Sample->new( $vrtrack, $library->sample_id ) if defined $library;

    return $sample;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
