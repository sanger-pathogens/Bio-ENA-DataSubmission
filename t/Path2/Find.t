#!/usr/bin/env perl
use strict;
use warnings;

BEGIN {
    use Test::Most;
    use Test::Exception;
}



subtest "Should be able to use Path2::Find", sub {
    use_ok('Path2::Find');
};

subtest "Should populate hierarchy template", sub {
    my $obj = Path2::Find->new;
    is $obj->hierarchy_template, 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane', 'hierarchy ok';
};

subtest "Should find existing database", sub {
    check_nfs_dependencies();

    my $obj = Path2::Find->new;
    my $expected_location = '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines';
    my ($vrtrack, $dbi, $root) = $obj->get_db_info('pathogen_prok_track');

    isa_ok $vrtrack, 'VRTrack::VRTrack';
    isa_ok $dbi, 'DBI::db';
    is $root, $expected_location, 'found known directory ok';
};

subtest "Should fail if database does not exist", sub {
    check_nfs_dependencies();

    my $obj = Path2::Find->new;
    dies_ok {$obj->get_db_info('some_unknown_database')} 'DB info dies for unknown DB';
};

subtest "Should find pathogen databases list", sub {
    check_nfs_dependencies();
    my $obj = Path2::Find->new;
    # Check pathogen databases list
    my $databases = scalar $obj->pathogen_databases;
    my $db_list_ok = $databases ? 1 : 0;
    is $db_list_ok, 1, "$databases pathogen databases listed";
};


sub check_nfs_dependencies {
    plan(skip_all => 'E2E test requiring production like file structure and database')
        unless (defined($ENV{'ENA_SUBMISSIONS_E2E'}));
}



done_testing();
exit;
