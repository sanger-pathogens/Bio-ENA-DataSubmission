#!/usr/bin/env perl
use strict;
use warnings;

use File::Slurp;
use Data::Dumper;

BEGIN { unshift( @INC, './lib' ) }
BEGIN { unshift(@INC, '/software/pathogen/internal/pathdev/vr-codebase/modules') }

use VRTrack::Lane;
use Path2::Find;

BEGIN {
    use Test::Most;
}

subtest "Should be able to use Path2::Find::Filter", sub {
    use_ok('Path2::Find::Filter');
};


my %type_extensions = (
    fastq => '*.fastq.gz',
    bam   => '*.bam',
    map_bam => '*markdup.bam'
);

subtest "Should filter fastq", sub {
    check_nfs_dependencies();

    my ( $pathtrack, $dbh, $root ) = Path2::Find->new->get_db_info('pathogen_prok_track');
    my @fastq_lanes =
        ('5749_8#1', '5749_8#2', '5749_8#3');
    my @fastq_obs = generate_lane_objects($pathtrack, \@fastq_lanes);

    my $filter = Path2::Find::Filter->new(
        lanes           => \@fastq_obs,
        filetype        => 'fastq',
        root            => $root,
        pathtrack       => $pathtrack,
        type_extensions => \%type_extensions
    );
    my @matching_lanes = $filter->filter;

    my $expected_fastq = [
        {
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Blautia/producta/TRACKING/1707/TL266/SLX/TL266_1728612/5749_8#1/5749_8#1_2.fastq.gz',
            'mapstat_id' => undef
        },
        {
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Blautia/producta/TRACKING/1707/TL266/SLX/TL266_1728612/5749_8#1/5749_8#1_1.fastq.gz',
            'mapstat_id' => undef
        },
        {
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Blautia/producta/TRACKING/1707/2950/SLX/2950_1728613/5749_8#2/5749_8#2_2.fastq.gz',
            'mapstat_id' => undef
        },
        {
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Blautia/producta/TRACKING/1707/2950/SLX/2950_1728613/5749_8#2/5749_8#2_1.fastq.gz',
            'mapstat_id' => undef
        },
        {
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Blautia/producta/TRACKING/1707/3507/SLX/3507_1728614/5749_8#3/5749_8#3_2.fastq.gz',
            'mapstat_id' => undef
        },
        {
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Blautia/producta/TRACKING/1707/3507/SLX/3507_1728614/5749_8#3/5749_8#3_1.fastq.gz',
            'mapstat_id' => undef
        }
    ];
    my @matching_lanes_edit = remove_lane_objects(\@matching_lanes);
    @matching_lanes_edit = sort { return @$a->path cmp @$b->path } @matching_lanes_edit;

    is_deeply do_sort(@matching_lanes_edit), do_sort(@$expected_fastq), 'correct fastqs retrieved';
};


subtest "Should filter bam", sub {
    check_nfs_dependencies();

    my ($pathtrack, $dbh, $root) = Path2::Find->new->get_db_info('pathogen_prok_track');
    my @bam_lanes = ('4880_8#1', '4880_8#2', '4880_8#3');
    my @bam_obs = generate_lane_objects($pathtrack, \@bam_lanes);

    my $filter = Path2::Find::Filter->new(
        lanes           => \@bam_obs,
        filetype        => 'bam',
        root            => $root,
        pathtrack       => $pathtrack,
        type_extensions => \%type_extensions
    );
    my @matching_lanes = $filter->filter;

    my $expected_bams = [
        {
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/microti/TRACKING/499/OV254/SLX/OV254_247838/4880_8#1/111360.pe.markdup.bam',
            'mapstat_id' => '111360'
        },
        {
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/microti/TRACKING/499/ATCC35782/SLX/ATCC35782_247839/4880_8#2/111363.pe.markdup.bam',
            'mapstat_id' => '111363'
        },
        {
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Mycobacterium/microti/TRACKING/499/MausIII/SLX/MausIII_247840/4880_8#3/111366.pe.markdup.bam',
            'mapstat_id' => '111366'
        }
    ];
    my @matching_lanes_edit = remove_lane_objects(\@matching_lanes);
    is_deeply do_sort(@matching_lanes_edit), do_sort(@$expected_bams), 'correct bams retrieved';
};

subtest "Should support verbose output", sub {
    check_nfs_dependencies();

    my ($pathtrack, $dbh, $root) = Path2::Find->new->get_db_info('pathogen_prok_track');
    my @verbose_lanes = ('8086_1#1', '8086_1#2', '8086_1#3');
    my @verbose_obs = generate_lane_objects($pathtrack, \@verbose_lanes);

    my $filter = Path2::Find::Filter->new(
        lanes           => \@verbose_obs,
        root            => $root,
        pathtrack       => $pathtrack,
        filetype        => 'map_bam',
        type_extensions => \%type_extensions,
        verbose         => 1
    );
    my @matching_lanes = $filter->filter;

    my $expected_verbose = [
        {
            'ref'        => 'Salmonella_enterica_subsp_enterica_serovar_Typhimurium_SL1344_v1',
            'mapper'     => 'smalt',
            'date'       => '10-07-2013',
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Salmonella/enterica_subsp_enterica_serovar_Typhimurium/TRACKING/2234/TyCTRL1/SLX/TyCTRL1_5521546/8086_1#1/539784.se.markdup.bam',
            'mapstat_id' => '539784'
        },
        {
            'ref'        => 'Salmonella_enterica_subsp_enterica_serovar_Typhimurium_SL1344_v1',
            'mapper'     => 'smalt',
            'date'       => '25-06-2013',
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Salmonella/enterica_subsp_enterica_serovar_Typhimurium/TRACKING/2234/TyCTRL2/SLX/TyCTRL2_5521547/8086_1#2/522282.se.markdup.bam',
            'mapstat_id' => '522282'
        },
        {
            'ref'        => 'Salmonella_enterica_subsp_enterica_serovar_Typhimurium_SL1344_v1',
            'mapper'     => 'smalt',
            'date'       => '25-06-2013',
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Salmonella/enterica_subsp_enterica_serovar_Typhimurium/TRACKING/2234/TyCPI1/SLX/TyCPI1_5521548/8086_1#3/522279.se.markdup.bam',
            'mapstat_id' => '522279'
        }
    ];
    my @matching_lanes_edit = remove_lane_objects(\@matching_lanes);
    is_deeply do_sort(@matching_lanes_edit), do_sort(@$expected_verbose), 'correct verbose files recovered';
};


subtest "Should filter on date", sub {
    check_nfs_dependencies();
    my ($pathtrack, $dbh, $root) = Path2::Find->new->get_db_info('pathogen_prok_track');
    my @verbose_lanes = ('8086_1#1', '8086_1#2', '8086_1#3');
    my @verbose_obs = generate_lane_objects($pathtrack, \@verbose_lanes);

    my $filter = Path2::Find::Filter->new(
        lanes           => \@verbose_obs,
        root            => $root,
        pathtrack       => $pathtrack,
        filetype        => 'map_bam',
        type_extensions => \%type_extensions,
        verbose         => 1
    );
    $filter->{date} = "01-07-2013";
    my @matching_lanes = $filter->filter;

    my $expected_date = [
        {
            'ref'        => 'Salmonella_enterica_subsp_enterica_serovar_Typhimurium_SL1344_v1',
            'mapper'     => 'smalt',
            'date'       => '10-07-2013',
            'path'       => '/lustre/scratch118/infgen/pathogen/pathpipe/prokaryotes/seq-pipelines/Salmonella/enterica_subsp_enterica_serovar_Typhimurium/TRACKING/2234/TyCTRL1/SLX/TyCTRL1_5521546/8086_1#1/539784.se.markdup.bam',
            'mapstat_id' => '539784'
        }
    ];
    my @matching_lanes_edit = remove_lane_objects(\@matching_lanes);
    is_deeply do_sort(@matching_lanes_edit), do_sort(@$expected_date), 'correctly dated files recovered';
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

sub remove_lane_objects {
	my ($ds) = shift;
	my @new_ds;
	foreach my $d (@$ds){
		my %h = %{ $d };
		delete $h{lane};
		push(@new_ds, \%h);
	}
	return @new_ds;
}

sub check_nfs_dependencies {
    plan( skip_all => 'Dependency on path /software missing' ) unless ( -e "/software" );
}

sub do_sort {
    my (@ref) = @_;
    my @result = sort { return $a->{path} cmp $b->{path} } @ref;
    return \@result;
}

