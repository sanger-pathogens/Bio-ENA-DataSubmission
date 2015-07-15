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

use Path::Find;
use Path::Find::Lanes;
use Data::Dumper;

has 'type' => ( is => 'rw', isa => 'Str', required => 1 );
has 'id'   => ( is => 'rw', isa => 'Str', required => 1 );
has 'file_type'    => ( is => 'rw', isa => 'Str', default => 'assembly' );
has 'file_id_type' => ( is => 'rw', isa => enum( [ qw( lane sample ) ] ), default => 'lane' );

has '_vrtrack' => ( is => 'rw', isa => 'VRTrack::VRTrack' );
has '_root'    => ( is => 'rw', isa => 'Str' );

sub find {
	my $self = shift;

	my $lanes = $self->_get_lanes_from_db;

    my %data = (key_order => []);
    return \%data unless @$lanes;

    if ( $self->type eq 'lane' || $self->type eq 'sample' ){
    	push( $data{key_order}, $self->id );
    	$data{$self->id} = $lanes->[0];
    }
    elsif ( $self->type eq 'study' ){
    	for my $l ( @$lanes ){
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
    	my @found_ids = $self->_found_ids( $lanes );

    	for my $id ( @ids ){
    		$data{$id} = undef;
    		my ($index) = grep { $found_ids[$_] eq $id } 0..$#found_ids;
    		$data{$id} = $lanes->[$index] if ( defined $index );
    	}
    }

    return \%data;
}

sub _get_lanes_from_db {
    my $self = shift;
	my $lanes;
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
  my ( $self, $lanes ) = @_;

  my @got_ids;
  ID: foreach my $lane ( @$lanes ) {
    if ( $self->file_id_type eq 'lane' ) {
       push @got_ids, $lane->{name};
    }
    else {
      my $library = VRTrack::Library->new( $self->_vrtrack, $lane->library_id );
      if ( not defined $library ) {
        warn q(WARNING: no sample for library ') . $lane->library_id . q(');
        next ID;
      }
      my $sample = VRTrack::Sample->new( $self->_vrtrack, $library->sample_id );
      push @got_ids, $sample->individual->acc;
    }
  }

  return @got_ids;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
