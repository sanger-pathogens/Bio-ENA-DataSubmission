#!/usr/bin/env perl
BEGIN { unshift( @INC, './lib' ) }
BEGIN { unshift( @INC, '/software/pathogen/internal/pathdev/vr-codebase/modules' ) }

BEGIN {
    use Test::Most;
        use Test::Output;
        use Test::Exception;
}

use Moose;
use Path::Find;
use VRTrack::Lane;

use Data::Dumper;

use_ok('Bio::ENA::DataSubmission::FindData');


subtest "Lane retrieval", sub {
	check_nfs_dependencies();
	my $pathtrack = new_pathtrack();
	my %exp = ('key_order' => [ '10665_2#90' ], '10665_2#90' => VRTrack::Lane->new_by_name($pathtrack, '10665_2#90'));
	my $obj = Bio::ENA::DataSubmission::FindData->new(
		type => 'lane',
		id   => '10665_2#90'
	);
	is_deeply $obj->find, \%exp, 'lane - data correct';
};

subtest "Sample retrieval", sub {
	check_nfs_dependencies();
	my $pathtrack = new_pathtrack();
	my %exp = ('key_order' => [ 'ERS311489' ], 'ERS311489' => VRTrack::Lane->new_by_name($pathtrack, '10665_2#90'));
	my $obj = Bio::ENA::DataSubmission::FindData->new(
		type => 'sample',
		id   => 'ERS311489'
	);
	is_deeply $obj->find, \%exp, 'sample - data correct';
};

subtest "Study retrieval", sub {
	check_nfs_dependencies();
	my $pathtrack = new_pathtrack();
	my %exp = ('key_order' => [ '9003_1#1', '9003_1#2' ],
		'9003_1#1'      => VRTrack::Lane->new_by_name($pathtrack, '9003_1#1'),
		'9003_1#2'      => VRTrack::Lane->new_by_name($pathtrack, '9003_1#2'),
	);
	my $obj = Bio::ENA::DataSubmission::FindData->new(
		type => 'study',
		id   => '2460'
	);
	is_deeply $obj->find, \%exp, 'study - data correct';
};

# test file of lane ids
subtest "file of lane ids retrieval", sub {
	check_nfs_dependencies();
	my $pathtrack = new_pathtrack();
	my %exp = ('key_order' => [ '10660_2#13', '10665_2#81', '10665_2#90', '11111_1#1' ],
		'10660_2#13'    => VRTrack::Lane->new_by_name($pathtrack, '10660_2#13'),
		'10665_2#81'    => VRTrack::Lane->new_by_name($pathtrack, '10665_2#81'),
		'10665_2#90'    => VRTrack::Lane->new_by_name($pathtrack, '10665_2#90'),
		'11111_1#1'     => undef
	);
	my $obj = Bio::ENA::DataSubmission::FindData->new(
		type => 'file',
		id   => 't/data/lanes.txt'
	);
	is_deeply $obj->find, \%exp, 'file of lane ids - data correct';
};

# test file of sample accessions
# Requires --file_id_type to be passed through to PathFind
#%exp = ( 'key_order'  => [ 'ERS311560', 'ERS311393', 'ERS311489' ],
#         'ERS311560' => VRTrack::Lane->new_by_name( $pathtrack, '10660_1#13' ),
#         'ERS311393' => VRTrack::Lane->new_by_name( $pathtrack, '10665_2#81' ),
#         'ERS311489' => VRTrack::Lane->new_by_name( $pathtrack, '10665_2#90' ),
#    );
#$obj = Bio::ENA::DataSubmission::FindData->new(
#     type => 'file',
#     id   => 't/data/samples.txt'
#);
#is_deeply $obj->find, \%exp, 'file of samples - data correct';

done_testing();

sub check_nfs_dependencies {
	plan( skip_all => 'Dependency on path /software missing' ) unless ( -e "/software" );
}

sub new_pathtrack {
	my $find = Path::Find->new();
	my ( $pathtrack, $dbh, $root ) = $find->get_db_info( 'pathogen_prok_track' );

	return $pathtrack;
}