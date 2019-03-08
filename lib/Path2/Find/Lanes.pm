package Path2::Find::Lanes;

# ABSTRACT: Logic to find lanes from the tracking database

=head1 SYNOPSIS

Logic to find lanes from the tracking database

   use Path2::Find::Lanes;
   my $obj = Path2::Find::Lanes->new(
     search_type => 'lane',
     search_id => '1234_5',
	 processed_flag => 1
     pathtrack => $self->pathtrack,
     dbh => $dbh
   );
   
   $obj->lanes;
   
=method lanes

Returns an array of matching VRTrack::Lane objects

=cut

use lib "/software/pathogen/internal/pathdev/vr-codebase/modules";

use Moose;
use VRTrack::Lane;
use Data::Dumper;
use lib "../../";
use Path2::Find::Exception;

has 'search_type'    => ( is => 'ro', isa => 'Str', required => 1 );
has 'search_id'      => ( is => 'ro', isa => 'Str', required => 1 );
has 'processed_flag' => ( is => 'ro', isa => 'Int', required => 1 );

has 'file_id_type'   => ( is => 'ro', isa => 'Str', required => 0, default => 'lane' );

has 'pathtrack' => ( is => 'rw', required => 1 );
has 'dbh'       => ( is => 'rw', required => 1 );

has 'lanes' =>
  ( is => 'ro', isa => 'ArrayRef', lazy => 1, builder => '_build_lanes' );

sub _lookup_by_lane {
    my ($self, $s_id) = @_;
    my $search_id = (defined $s_id) ? $s_id : $self->search_id;
    my @lanes;

    my $search_term = 'select lane.name from latest_lane as lane where'
          . ' ( lane.name = "'
          . $search_id . '"'
          . ' OR lane.name like "'
          . escaped($search_id) . '#%"'
          . ' OR lane.acc like "'
          . escaped($search_id) . '" )'
          . ' AND lane.processed & '
          . $self->processed_flag . ' = '
          . $self->processed_flag
          . ' order by lane.name asc';

    my $lane_names =
      $self->dbh->selectall_arrayref($search_term);
    for my $lane_name (@$lane_names) {
        my $lane =
          VRTrack::Lane->new_by_name( $self->pathtrack, @$lane_name[0] );
        if ($lane) {
            push( @lanes, $lane );
        }
    }
    return \@lanes;
}

sub _lookup_by_sample {
    my ($self) = @_;
    my @lanes;

    my $lane_names = $self->dbh->selectall_arrayref(
        'select lane.name from individual as individual
        inner join latest_sample as sample on sample.individual_id = individual.individual_id
        inner join latest_library as library on library.sample_id = sample.sample_id
        inner join latest_lane as lane on lane.library_id = library.library_id
        where'
          . '( individual.acc like "'
          . escaped($self->search_id) . '"'
          . ' OR sample.name like "'
          . escaped($self->search_id) . '" )'
          . ' AND lane.processed & '
          . $self->processed_flag . ' = '
          . $self->processed_flag
          . ' order by lane.name asc'
    );
    for my $lane_name (@$lane_names) {
        my $lane =
          VRTrack::Lane->new_by_name( $self->pathtrack, @$lane_name[0] );
        if ($lane) {
            push( @lanes, $lane );
        }
    }
    return \@lanes;
}

sub _lookup_by_study {
    my ($self) = @_;
    my @lanes;

    my $search_id = $self->search_id;

    my $sql_query = 'select lane.name from latest_project as project
      inner join latest_sample as sample on sample.project_id = project.project_id
      inner join latest_library as library on library.sample_id = sample.sample_id
      inner join latest_lane as lane on lane.library_id = library.library_id
      where (project.ssid like "'
          . escaped($search_id)
          . '" OR  project.name like "'
          . escaped($search_id)
          . '") AND lane.processed & '
          . $self->processed_flag . ' = '
          . $self->processed_flag
          . ' order by lane.name asc';
    
    my $lane_names = $self->dbh->selectall_arrayref( $sql_query );

    for my $lane_name (@$lane_names) {
        my $lane =
          VRTrack::Lane->new_by_name( $self->pathtrack, @$lane_name[0] );
        if ($lane) {
            push( @lanes, $lane );
        }
    }
    return \@lanes;
}

sub _lookup_by_library {
    my ($self) = @_;
    my @lanes;

    my $search_id = $self->search_id;
    my $sql_query = 'select lane.name from latest_library as library
      inner join latest_lane as lane on lane.library_id = library.library_id
      where ( library.name like "'
          . escaped($search_id)
          . '") AND lane.processed & '
          . $self->processed_flag . ' = '
          . $self->processed_flag
          . ' order by lane.name asc';
    my $lane_names = $self->dbh->selectall_arrayref( $sql_query );

    for my $lane_name (@$lane_names) {
        my $lane =
          VRTrack::Lane->new_by_name( $self->pathtrack, @$lane_name[0] );
        if ($lane) {
            push( @lanes, $lane );
        }
    }
    return \@lanes;
}


sub _lookup_by_species {
    my ($self) = @_;
    my @lanes;

    my $lane_names = $self->dbh->selectall_arrayref(
        'select lane.name from species as species
        inner join individual as individual on individual.species_id = species.species_id
        inner join latest_sample as sample on sample.individual_id = individual.individual_id
        inner join latest_library as library on library.sample_id = sample.sample_id
        inner join latest_lane as lane on lane.library_id = library.library_id
      where species.name like "%'
          . escaped($self->search_id)
          . '%" AND lane.processed & '
          . $self->processed_flag . ' = '
          . $self->processed_flag
          . ' order by lane.name asc'
    );
    for my $lane_name (@$lane_names) {
        my $lane =
          VRTrack::Lane->new_by_name( $self->pathtrack, @$lane_name[0] );
        if ($lane) {
            push( @lanes, $lane );
        }
    }
    return \@lanes;
}

# xxxfind -t database -i pathogen_abc_track
sub _lookup_by_database {
    my ($self) = @_;
    my @lanes;

    my @current_database_name_row =
      $self->dbh->selectrow_array('select DATABASE();');
    if ( $current_database_name_row[0] ne $self->search_id ) {
        return \@lanes;
    }

    my $lane_names = $self->dbh->selectall_arrayref(
        'select lane.name from latest_lane as lane
      where lane.processed & '
          . $self->processed_flag . ' = '
          . $self->processed_flag
          . ' order by lane.name asc'
    );
    for my $lane_name (@$lane_names) {
        my $lane =
          VRTrack::Lane->new_by_name( $self->pathtrack, @$lane_name[0] );
        if ($lane) {
            push( @lanes, $lane );
        }
    }
    return \@lanes;
}

sub _lookup_by_file {
  my ($self) = @_;
  my @lanes;

  open( my $fh, $self->search_id ) || Path2::Find::Exception::FileDoesNotExist->throw( error => "Error: Could not open file '" . $self->search_id . "'\n");
  my @file_ids = <$fh>;
  close $fh;
  chomp @file_ids;

  return \@lanes if ( scalar @file_ids == 0 );

  my $lane_names;
  if ( $self->file_id_type eq 'lane' ){
    $lane_names = $self->_lane_file( \@file_ids );
  }
  elsif ( $self->file_id_type eq 'sample' ){
    $lane_names = $self->_sample_file( \@file_ids );
  }

  for my $lane_name (@$lane_names) {
      my $lane = VRTrack::Lane->new_by_name( $self->pathtrack, @$lane_name[0] );
      if ($lane) {
          push( @lanes, $lane );
      }
  }

  return \@lanes;
}

sub _lane_file {
  my ( $self, $lanes ) = @_;

  my $lane_name_search_query = join( '" OR lane.name like "', @{ $lanes } );
  $lane_name_search_query = ' (lane.name like "' . $lane_name_search_query . '") ';

  my $lane_acc_search_query = '';
  $lane_acc_search_query = join( '" OR lane.acc = "', @{ $lanes } );
  $lane_acc_search_query = ' OR (lane.acc = "' . $lane_acc_search_query . '") ';

  my $lane_names =
    $self->dbh->selectall_arrayref( 'select lane.name from latest_lane as lane where '
        . '( ' . $lane_name_search_query
        .  $lane_acc_search_query . ' )'
        . ' AND lane.processed & '
        . $self->processed_flag . ' = '
        . $self->processed_flag
        . ' order by lane.name asc' );

  return $lane_names;
}

sub _sample_file {
  my ( $self, $samples ) = @_;
 
  my $sample_name_search_query = join('" OR sample.name like "', @{ $samples } );
    $sample_name_search_query = ' (sample.name like "' . $sample_name_search_query . '") ';

    my $sample_acc_search_query = join ( '" OR individual.acc like "', @{ $samples } );
    $sample_acc_search_query = ' (individual.acc like "' . $sample_acc_search_query . '") ';

    my $sql_query = 'select lane.name from individual as individual
        inner join latest_sample as sample on sample.individual_id = individual.individual_id
        inner join latest_library as library on library.sample_id = sample.sample_id
        inner join latest_lane as lane on lane.library_id = library.library_id
        where '
        . '( ' . $sample_name_search_query
        . ' OR ' . $sample_acc_search_query . ' )'
        . ' AND lane.processed & '
        . $self->processed_flag . ' = '
        . $self->processed_flag
        . ' order by lane.name asc';
    my $lane_names = $self->dbh->selectall_arrayref( $sql_query );

    return $lane_names; 
}

sub _build_lanes {
    my ($self) = @_;
    my @lanes = [];

    if ( $self->search_type eq 'lane' ) {
        return $self->_lookup_by_lane;
    }
    elsif ( $self->search_type eq 'sample' ) {
        return $self->_lookup_by_sample;
    }
    elsif ( $self->search_type eq 'database' ) {
        return $self->_lookup_by_database;
    }
    elsif ( $self->search_type eq 'study' ) {
        return $self->_lookup_by_study;
    }
    elsif ( $self->search_type eq 'file' ) {
        return $self->_lookup_by_file;
    }
    elsif ( $self->search_type eq 'library' ) {
        return $self->_lookup_by_library;
    }
    elsif ( $self->search_type eq 'species' ) {
        return $self->_lookup_by_species;
    }

    return \@lanes;
}

sub escaped {
  my ($str) = @_;
  $str =~ s/_/\\_/g;
  $str =~ s/%/\\%/g;
  return $str;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
