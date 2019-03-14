# ABSTRACT: Simple wrapper module for VRTrack and DBI. Used for connecting to pathogen tracking databases.

=head1 NAME
Path2::Find


=head1 SYNOPSIS

@databases = Path2::Find->pathogen_databases;
$database  = shift @databases;
my ( $pathtrack, $dbh, $root ) = Path2::Find->get_db_info($database);

=cut


use lib "/software/pathogen/internal/pathdev/vr-codebase/modules";

package Path2::Find;
use DBI;
use VRTrack::VRTrack;

use File::Slurp;
use YAML::XS;
use Moose;
use Config::Any;
use Bio::ENA::DataSubmission::Exception;

has 'config_file' => (is => 'ro', isa => 'Str', lazy_build => 1, required => 0);
has 'config' => (is => 'ro', isa => 'HashRef', lazy_build => 1, required => 0);
has 'connection' => (is => 'ro', isa => 'HashRef', lazy_build => 1, required => 0);
has 'db_root' => (is => 'ro', isa => 'Str', lazy_build => 1, required => 0);
has 'db_sub' => (is => 'ro', isa => 'HashRef', lazy_build => 1, required => 0);
has 'template' => (is => 'ro', isa => 'Str', default => "genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane", required => 0);

sub _build_config_file {

    unless (defined $ENV{PF_CONFIG_FILE}) {
        Bio::ENA::DataSubmission::Exception::EnvironmentVariableNotFound->throw(error => "variable PF_CONFIG_FILE is not defined\n");
    }
    my $file =  $ENV{PF_CONFIG_FILE};
    (-e $file) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw(error => "Cannot find $file\n");
    (-r $file) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw(error => "Cannot read $file\n");
    return $file;
}

sub _build_connection {
    my $self = shift;
    my %connect = %{ $self->config->{connection_params}->{tracking} };
    delete $connect{schema_class};
    delete $connect{driver};
    return \%connect;
}

sub _build_db_root {
    my $self = shift;

    return $self->config->{db_root};
}

sub _build_config {
    my $self = shift;
    my $ca = Config::Any->load_files({ files => [ $self->config_file ], use_ext => 1 });
    my $cfg = $ca->[0]->{ $self->config_file };

    return $cfg;
}

sub _build_db_sub {
    my $self = shift;
    my %dbsub = ('pathogen_virus_track' => 'viruses',
        'pathogen_prok_track'           => 'prokaryotes',
        'pathogen_euk_track'            => 'eukaryotes',
        'pathogen_helminth_track'       => 'helminths',
        'pathogen_rnd_track'            => 'rnd');
    return \%dbsub;
}

sub pathogen_databases {
    my ($self) = @_;

    my %CONNECT = %{$self->connection};

    my $dbi_t = DBI->data_sources("mysql", \%CONNECT);

    my @db_list_all = grep (s/^DBI:mysql://, DBI->data_sources("mysql", \%CONNECT));

    my @db_list = (); # tracking and external databases
    push @db_list, grep (/^pathogen_.+_track$/, @db_list_all);    # pathogens_..._track
    push @db_list, grep (/^pathogen_.+_external$/, @db_list_all); # pathogens_..._external

    @db_list = @{$self->_move_production_databases_to_the_front(\@db_list)};

    my @db_list_out = (); # databases with files on disk
    for my $database (@db_list) {
        my $root_dir = $self->hierarchy_root_dir($database);
        push @db_list_out, $database if defined $root_dir;
    }

    return @db_list_out;
}

# Ensure that our largest production databases are searched first
sub _move_production_databases_to_the_front {
    my ($self, $db_list) = @_;
    my @reordered_db_list;
    my %db_list_lookup = map {$_ => 1} @{$db_list};

    for my $db_name (qw(pathogen_pacbio_track pathogen_prok_track pathogen_euk_track pathogen_virus_track pathogen_helminth_track)) {
        if ($db_list_lookup{$db_name}) {
            push(@reordered_db_list, $db_name);
            delete($db_list_lookup{$db_name});
        }
    }

    for my $db_name (sort keys %db_list_lookup) {
        push(@reordered_db_list, $db_name);
    }
    return \@reordered_db_list;
}


sub hierarchy_root_dir {
    my ($self, $database) = @_;
    my %DB_SUB = %{$self->db_sub};
    my $DB_ROOT = $self->db_root;

    my $sub_dir = exists $DB_SUB{$database} ? $DB_SUB{$database} : $database;
    my $root_dir = "$DB_ROOT/$sub_dir/seq-pipelines";

    return -d $root_dir ? $root_dir : undef;
}

sub lookup_tracking_name_from_database {
    my ($self, $database) = @_;
    my %DB_SUB = %{$self->db_sub};
    exists $DB_SUB{$database} ? $DB_SUB{$database} : $database;
}

sub hierarchy_template {
    my ($self) = @_;
    return $self->template;
}

sub vrtrack {
    my ($self, $database) = @_;

    return undef unless defined $self->hierarchy_root_dir($database);

    my %connect = %{$self->connection};
    $connect{database} = $database;
    my $vrtrack = VRTrack::VRTrack->new(\%connect);

    return $vrtrack;
}

sub dbi {
    my ($self, $database) = @_;

    return undef unless defined $self->hierarchy_root_dir($database);

    my %CONNECT = %{$self->connection};

    my $dbi_connect = "DBI:mysql:dbname=" . $database . ";host=" . $CONNECT{host} . ";port=" . $CONNECT{port};
    $dbi_connect .= ";password=" . $CONNECT{password} if (defined $CONNECT{password});

    my $dbi = DBI->connect($dbi_connect, $CONNECT{user}) or return undef;

    return $dbi;
}

sub get_db_info {
    my ($self, $db) = @_;

    my $vr = $self->vrtrack($db) or die "Failed to create VRTrack object for '$db'\n";
    my $dbh = $self->dbi($db) or die "Failed to create DBI object for '$db'\n";
    my $root = $self->hierarchy_root_dir($db) or die "Failed to find root directory for '$db'\n";
    return($vr, $dbh, $root);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
