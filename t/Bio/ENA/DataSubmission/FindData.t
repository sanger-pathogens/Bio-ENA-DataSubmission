#!/usr/bin/env perl

BEGIN {
    use Test::Most;
        use Test::Output;
        use Test::Exception;
}

use Moose;
use Path2::Find;
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

subtest "Map study", sub {
	check_nfs_dependencies();
	my $expected = ['9003_1#1','9003_1#2'];
	my $actual = Bio::ENA::DataSubmission::FindData->map('study', '2460', 'assembly', 'lane', sub {
		my (undef, undef, $data) = @_;
		return $data->name;

	});
	is_deeply $actual, $expected, 'mapping correct';
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

done_testing();

sub check_nfs_dependencies {
	plan( skip_all => 'Dependency on path /software missing' ) unless ( -e "/software" );
}

sub new_pathtrack {
	my $find = Path2::Find->new();
	my ($pathtrack, undef, undef) = $find->get_db_info('pathogen_prok_track');

	return $pathtrack;
}