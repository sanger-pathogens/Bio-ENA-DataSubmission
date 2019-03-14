package Path2::Find::Filter;

# ABSTRACT: Logic to filter lanes based on given criteria

=head1 SYNOPSIS

   use Path2::Find::Filter;
   my $lane_filter = Path2::Find::Filter->new(
	   scriptname => 'pathfind',
       lanes     => \@lanes,
       filetype  => $filetype,
       qc        => $qc,
       root      => $root,
       pathtrack => $pathtrack
   );
   my @matching_paths = $lane_filter->filter;

=method filter

Returns a list of full paths to lanes that match the given criteria

=cut

use Moose;
use Path2::Find;
use File::Find::Rule;
use File::Basename;

use Path2::Find::Exception;

# required
has 'lanes' => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'root'      => ( is => 'ro', required => 1 );
has 'pathtrack' => ( is => 'ro', required => 1 );

# end required

#optional
has 'hierarchy_template' => ( is => 'rw', builder => '_build_hierarchy_template', required => 0 );
has 'filetype'        => ( is => 'ro', required => 0 );
has 'type_extensions' => ( is => 'rw', isa      => 'HashRef', required => 0 );
#has 'alt_type'        => ( is => 'ro', isa      => 'Str', required => 0 );
has 'qc'              => ( is => 'ro', required => 0 );
has 'found'           => ( is => 'rw', default  => 0, writer => '_set_found', required => 0 );
has 'subdirectories' => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub {
        my @empty = ("");
        return \@empty;
    },
    required => 0
);
has 'reference' => ( is => 'ro', required => 0 );
has 'mapper'    => ( is => 'rw', required => 0 );
has 'date'      => ( is => 'ro', required => 0 );
has 'verbose'   => ( is => 'ro', isa => 'Bool', default => 0, required => 0 );
has 'stats'     => ( is => 'ro', isa => 'ArrayRef', required => 0 );
has 'search_depth' => ( is =>'ro', isa => 'Int', required => 0, default => 2 );

# end optional

sub _build_hierarchy_template {
    my ($self) = @_;

    return Path2::Find->new()->hierarchy_template;
}

sub filter {
    my ($self)   = @_;
    my $filetype = $self->filetype;
    my @lanes    = @{ $self->lanes };
    my $qc       = $self->qc;

    my $ref    = $self->reference;
    my $mapper = $self->mapper;
    my $date   = $self->date;

    my $type_extn = $self->type_extensions->{$filetype} if ($filetype);

    my @matching_paths;
    foreach (@lanes) {
        my $l = $_;

        # check if type exension should include mapstat id
        if ( $filetype && $type_extn =~ /MAPSTAT_ID/ ) {
            my $ms_id = $self->_get_mapstat_id($l);
            $type_extn =~ s/MAPSTAT_ID/$ms_id/;
        }

        # check date format
        if ( defined $date ) {
            ( $date =~ /\d{2}-\d{2}-\d{4}/ )
              or Path2::Find::Exception::InvalidInput->throw(
                error => "Date (-d option) '$date' is not in the correct format. Use format: DD-MM-YYYY\n" );
        }

        if ( !$qc || ( defined( $l->qc_status() ) && ( $qc && $qc eq $l->qc_status() ) ) ) {
            my $sub_dir_paths = $self->_get_full_path($l);

            my @paths;
            for my $subdir (keys %{$sub_dir_paths})
            {
              push(@paths, $sub_dir_paths->{$subdir}.$subdir);
            }

            for my $subdir (keys %{$sub_dir_paths}) {
              my $full_path = $sub_dir_paths->{$subdir}.$subdir;

                if ($filetype) {
                    #my $search_path = "$full_path/$type_extn";
                    next unless my $mfiles = $self->find_files( $full_path, $type_extn, $l,$subdir);
                    my @matching_files = @{$mfiles};

                    # exclude pool_1.fastq.gz files
                    @matching_files = grep { !/pool_1.fastq.gz/ } @matching_files;

                    for my $m (@matching_files) {
                        $self->_set_found(1);
                        my %lane_hash = $self->_make_lane_hash( $m, $l, \@paths );

                        # check ref, date or mapper matches
                        next if ( defined $ref    && !$self->_reference_matches( $lane_hash{ref} ) );
                        next if ( defined $mapper && !$self->_mapper_matches( $lane_hash{mapper} ) );
                        next if ( defined $date   && !$self->_date_is_later( $lane_hash{date} ) );

                        push( @matching_paths, \%lane_hash );
                    }
                }
                else {
                    if ( -e $full_path ) {
                        $self->_set_found(1);
                        my %lane_hash = $self->_make_lane_hash( $full_path, $l, \@paths );
                        push( @matching_paths, \%lane_hash );
                    }
                }
            }
        }
    }
    return @matching_paths;
}

sub find_files {
    my ( $self, $full_path, $type_extn,$lane_obj, $subdir ) = @_;

    my @matches;

    # If there is a storage path - lookup nexsan directly instead of going via lustre, but return the lustre path
    # There a potential for error here but its a big speed increase.
    my $storage_path = $lane_obj->storage_path;

    if(defined($storage_path) && -e "$storage_path$subdir/$type_extn" )
    {
      push( @matches, "$full_path/$type_extn" );
      return \@matches;
    }
    elsif ( -e "$full_path/$type_extn" ) {
        push( @matches, "$full_path/$type_extn" );
        return \@matches;
    }

    if(defined $type_extn && $type_extn =~ /fastq/){
		$type_extn =~ s/\*//;
		my %fastq_filenames = ();
		# For illumina data, the db stores the names of the fastq files. However, 
		# for pacbio data, the file names stored in db are the bax files. So, we
		# try and work out what the fastq is likely to be called here 
		foreach my $f ( @{$lane_obj->files} ){
			my $file_from_obj = $f->name;
			if ($full_path !~ /pathogen_pacbio_track/) {
				$fastq_filenames{$file_from_obj} = 1;
			}else{
				#eg m140712_044442_00127_c100658932550000001823129311271434_s1_p0.1.bax.h5
				my ($name,$path,$suffix) = fileparse($file_from_obj);
				$name =~ s/\d{1}.ba[xs].h5$/fastq.gz/;
				$fastq_filenames{$name} = 1;
			}
		}
		for my $fname (keys %fastq_filenames){
			push(@matches, "$full_path/$fname") if ( $fname =~ /$type_extn/ && -e "$full_path/$fname");
		}
   	 return \@matches if( @matches );
    }

    
    # -f corrected - return corrected fastq files only
    # the corrected fastq file is named with the lane name followed by .corrected.fastq.gz
    # e.g. 32473_H01.corrected.fastq.gz
    if(defined $type_extn && $type_extn =~ /corrected/){
    	my $corrected_fastq_filename = $lane_obj->hierarchy_name.".corrected.fastq.gz";
    	push(@matches, "$full_path/$corrected_fastq_filename") if ( -e "$full_path/$corrected_fastq_filename");
	return \@matches if( @matches );
    
    }



    my $file_query;
    if ( defined($type_extn) && $type_extn =~ /\*/ ) {
        $file_query = $type_extn;
    }
    #elsif (defined( $self->type_extensions )
    #    && defined( $self->alt_type )
    #    && defined( $self->type_extensions->{ $self->alt_type } ) )
    #{
    #    $file_query = $self->alt_type;
    #}
    elsif ( defined( $self->type_extensions ) && defined( $self->type_extensions->{$type_extn} ) ) {
        $file_query = $self->type_extensions->{$type_extn};
    }

    if ( defined($file_query) ) {
        @matches = File::Find::Rule->file()->extras( { follow => 1 } )->maxdepth($self->search_depth)->name($file_query)->in($full_path);
    }

    return \@matches;
}

sub _make_lane_hash {
    my ( $self, $path, $lane_obj, $get_full_paths ) = @_;
    my $vb    = $self->verbose;
    my $stats = $self->stats;

    my %lane_hash;
    my $mapstat = $self->_match_mapstat( $path, $lane_obj );
    my $ms_id = defined $mapstat ? $mapstat->id : undef;
    if ($vb) {
        %lane_hash = (
            lane       => $lane_obj,
            path       => $path,
            mapstat_id => $ms_id,
            ref        => $self->_reference_name($mapstat),
            mapper     => $self->_get_mapper($mapstat),
            date       => $self->_date_changed($mapstat)
        );

    }
    else {
        %lane_hash = (
            lane       => $lane_obj,
            path       => $path,
            mapstat_id => $ms_id
        );
    }

    if ( defined $stats ) {
        $lane_hash{stats} = $self->_get_stats_paths( $path );
    }

    return %lane_hash;
}

sub _match_mapstat {
    my ( $self, $path, $lane ) = @_;

    $path =~ /(\d+)\.[ps]e/;
    my $ms_id = $1;
    return undef unless ( defined $ms_id );

    my @mapstats = @{ $lane->mappings_excluding_qc };
    foreach my $ms (@mapstats) {
        return $ms if ( $ms_id eq $ms->id );
    }
    return undef;
}



sub _get_full_path {
    my ( $self, $lane ) = @_;
    my $root    = $self->root;
    my @subdirs = @{ $self->subdirectories };

    my ( @fps, $lane_path );

    my $hierarchy_template = $self->hierarchy_template;
    my $pathtrack          = $self->pathtrack;

    my %path_details;
    $lane_path = $pathtrack->hierarchy_path_of_lane( $lane, $hierarchy_template );

    foreach my $subdir (@subdirs) {
        $path_details{$subdir} = "$root/$lane_path";
    }

    return \%path_details;
}

sub _get_stats_paths {
    my ( $self, $lane_path ) = @_;
    my @stats = @{ $self->stats };

    $lane_path =~ s/_assembly\/.+$/_assembly/;
    my @stats_paths;
    foreach my $s ( @stats ){
        my @search = glob "$lane_path/$s";
        push( @stats_paths, $search[0] ) if ( defined $search[0] && -e $search[0] );
    }
    return \@stats_paths;
}

sub _reference_matches {
    my ( $self, $lane_ref ) = @_;
    my $given_ref = $self->reference;

    if ( $lane_ref eq $given_ref ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _mapper_matches {
    my ( $self, $lane_mapper ) = @_;
    my $given_mapper = $self->mapper;

    if ( $lane_mapper eq $given_mapper ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _date_is_later {
    my ( $self, $given_date ) = @_;
    my $earliest_date = $self->date;

    my ( $e_dy, $e_mn, $e_yr ) = split( "-", $earliest_date );
    my ( $g_dy, $g_mn, $g_yr ) = split( "-", $given_date );

    my $later = 0;

    $later = 1
      if ( ( $e_yr < $g_yr )
        || ( $e_yr == $g_yr && $e_mn < $g_mn )
        || ( $e_yr == $g_yr && $e_mn == $g_mn && $e_dy < $g_dy ) );

    return $later;
}

sub _reference_name {
    my ( $self, $mapstat ) = @_;

    return 'NA' if ( !defined($mapstat) );
    my $assembly_obj = $mapstat->assembly;

    if ( defined $assembly_obj ) {
        return $assembly_obj->name;
    }
    else {
        return 'NA';
    }
}

sub _get_mapper {
    my ( $self, $mapstat ) = @_;
    return 'NA' if ( !defined($mapstat) );
    my $mapper_obj = $mapstat->mapper;
    if ( defined $mapper_obj ) {
        return $mapper_obj->name;
    }
    else {
        return 'NA';
    }
}

sub _date_changed {
    my ( $self, $mapstat ) = @_;
    return '01-01-1900' if ( !defined($mapstat) );
    my $msch = $mapstat->changed;
    my ( $date, $time ) = split( /\s+/, $msch );
    my @date_elements = split( '-', $date );
    return join( '-', reverse @date_elements );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
