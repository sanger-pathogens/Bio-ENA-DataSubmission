#!/usr/bin/env perl
use strict;
use warnings;
use File::Slurp;
use Data::Dumper;

BEGIN { unshift( @INC, './lib' ) }
BEGIN { unshift( @INC, '/software/pathogen/internal/pathdev/vr-codebase/modules' ) }


use VRTrack::Lane;
use Path2::Find;

BEGIN {
    use Test::Most;
}

subtest "Should be able to use Path2::Find::Lanes", sub {
    use_ok('Path2::Find::Lanes');
};

subtest "Should find by study", sub {
    check_nfs_dependencies();
    my ($pathtrack, $dbh, $root) = Path2::Find->new->get_db_info('pathogen_prok_track');
    my($lanes_obj);

    ok(
        $lanes_obj = Path2::Find::Lanes->new(
            search_type    => 'study',
            search_id      => '2005',
            pathtrack      => $pathtrack,
            dbh            => $dbh,
            processed_flag => 256
        ),
        'creating lanes object - search on study'
    );
    isa_ok $lanes_obj, 'Path2::Find::Lanes';

    my $lanes = $lanes_obj->lanes;

    my @test_lanes1 = ('7114_6#1', '7114_6#2', '7114_6#3');
    my @expected_lanes1 = generate_lane_objects($pathtrack, \@test_lanes1);

    is_deeply $lanes, \@expected_lanes1, 'correct lanes recovered';
};

subtest "Should find lane from file", sub {
    check_nfs_dependencies();
    my ($pathtrack, $dbh, $root) = Path2::Find->new->get_db_info('pathogen_prok_track');
    my($lanes_obj);

    ok(
        $lanes_obj = Path2::Find::Lanes->new(
            search_type    => 'file',
            search_id      => 't/data/Lanes/test_lanes.txt',
            pathtrack      => $pathtrack,
            dbh            => $dbh,
            processed_flag => 1
        ),
        'creating lanes object - search on file'
    );
    isa_ok $lanes_obj, 'Path2::Find::Lanes';

    my $lanes = $lanes_obj->lanes;

    open(FILE, "<", "t/data/Lanes/test_lanes.txt");
    my @test_lanes2 = <FILE>;
    chomp @test_lanes2;
    my @expected_lanes2 = generate_lane_objects($pathtrack, \@test_lanes2);

    is_deeply $lanes, \@expected_lanes2, 'correct lanes recovered';
};


subtest "Should find lane from ID", sub {
    check_nfs_dependencies();
    my ($pathtrack, $dbh, $root) = Path2::Find->new->get_db_info('pathogen_prok_track');
    my($lanes_obj);
    ok(
        $lanes_obj = Path2::Find::Lanes->new(
            search_type    => 'lane',
            search_id      => '8086_1',
            pathtrack      => $pathtrack,
            dbh            => $dbh,
            processed_flag => 4
        ),
        'creating lanes object - search on lane ID'
    );
    isa_ok $lanes_obj, 'Path2::Find::Lanes';

    my $lanes = $lanes_obj->lanes;

    my @test_lanes3 = (
        '8086_1#1', '8086_1#2', '8086_1#3', '8086_1#4',
        '8086_1#5', '8086_1#6', '8086_1#7', '8086_1#8'
    );
    my @expected_lanes3 = generate_lane_objects($pathtrack, \@test_lanes3);

    is_deeply $lanes, \@expected_lanes3, 'correct lanes recovered';
};

# subtest "Should find lane from species", sub {
#     check_nfs_dependencies();
#     my ($pathtrack, $dbh, $root) = Path2::Find->new->get_db_info('pathogen_prok_track');
#     my($lanes_obj);
#
#     ok(
#         $lanes_obj = Path2::Find::Lanes->new(
#             search_type    => 'species',
#             search_id      => 'Blautia producta',
#             pathtrack      => $pathtrack,
#             dbh            => $dbh,
#             processed_flag => 1
#         ),
#         'creating lanes object - search on species name'
#     );
#     isa_ok $lanes_obj, 'Path2::Find::Lanes';
#
#     my $lanes = $lanes_obj->lanes;
#
#     my @test_lanes4 = (
#         '5749_8#1', '5749_8#2', '5749_8#3', '8080_1#72'
#     );
#     my @expected_lanes4 = generate_lane_objects($pathtrack, \@test_lanes4);
#     is_deeply $lanes, \@expected_lanes4, 'correct lanes recovered';
#
# };

subtest "Should find lane from file of samples", sub {
    check_nfs_dependencies();
    my ($pathtrack, $dbh, $root) = Path2::Find->new->get_db_info('pathogen_prok_track');
    my($lanes_obj);

    ok(
        $lanes_obj = Path2::Find::Lanes->new(
            search_type    => 'file',
            search_id      => 't/data/Lanes/test_sample.txt',
            file_id_type   => 'sample',
            pathtrack      => $pathtrack,
            dbh            => $dbh,
            processed_flag => 0
        ),
        'creating lanes object - search on sample file'
    );
    isa_ok $lanes_obj, 'Path2::Find::Lanes';

    my $lanes = $lanes_obj->lanes;

    my @test_lanes5 = ('10660_1#13', '10660_2#13', '10665_2#81');
    my @expected_lanes5 = generate_lane_objects($pathtrack, \@test_lanes5);
    is_deeply $lanes, \@expected_lanes5, 'correct lanes recovered from samples';

};

subtest "Should find lane from library", sub {
    check_nfs_dependencies();
    my ($pathtrack, $dbh, $root) = Path2::Find->new->get_db_info('pathogen_prok_track');
    my($lanes_obj);
    ok(
        $lanes_obj = Path2::Find::Lanes->new(
            search_type    => 'library',
            search_id      => 'TL266 1728612',
            pathtrack      => $pathtrack,
            dbh            => $dbh,
            processed_flag => 1
        ),
        'creating lanes object - search on species name'
    );
    isa_ok $lanes_obj, 'Path2::Find::Lanes';

    my $lanes = $lanes_obj->lanes;

    my @test_lanes6 = (
        '5749_8#1'
    );
    my @expected_lanes6 = generate_lane_objects($pathtrack, \@test_lanes6);
    is_deeply $lanes, \@expected_lanes6, 'correct lanes recovered';

};

done_testing();

sub generate_lane_objects {
    my ( $pathtrack, $lanes ) = @_;

    my @lane_obs;
    foreach my $l (@$lanes) {
        my $l_o = VRTrack::Lane->new_by_name( $pathtrack, $l );
        if ($l_o) {
            push( @lane_obs, $l_o );
        }
    }
    return @lane_obs;
}

sub check_nfs_dependencies {
    plan( skip_all => 'Dependency on path /software missing' ) unless ( -e "/software" );
}

