package Bio::ENA::DataSubmission::WEBINCli;

# ABSTRACT: Wrapper around webin cli

=head1 NAME

Bio::ENA::DataSubmission::WEBINCli

=head1 SYNOPSIS

Wrapper around ENA's webin cli for analysis submissions

=method 

=cut

use Moose;
use Bio::ENA::DataSubmission::Exception;

has 'jar_path' => ( is => 'rw', isa => 'Str',  required => 1 );
has 'username' => ( is => 'rw', isa => 'Str',  required => 1 );
has 'password' => ( is => 'rw', isa => 'Str',  required => 1 );
has 'http_proxy_host' => ( is => 'rw', isa => 'Str',  required => 1 );
has 'http_proxy_port' => ( is => 'rw', isa => 'Int',  required => 1 );
has 'context'  => ( is => 'rw', isa => 'Str',  required => 0, default    => 'genome' );
has 'input_dir' => ( is => 'rw', isa => 'Str',  required => 1);
has 'output_dir'=> ( is => 'rw', isa => 'Str',  required => 1);
has 'manifest' => ( is => 'rw', isa => 'Str',  required => 1);
has 'test'     => ( is => 'rw', isa => 'Bool', required => 0, default    => 0 );
has 'validate' => ( is => 'rw', isa => 'Bool', required => 0, default    => 1 );
has 'submit'   => ( is => 'rw', isa => 'Bool', required => 0, default    => 1 );

sub run {
	my ($self) = @_;

    $self->_validate();
	my @args = $self->_build_arguments_to_system_call();
	return system(@args)
}

sub _validate {
    my ($self) = @_;

    ( -e $self->input_dir && -d _) or Bio::ENA::DataSubmission::Exception::DirectoryNotFound->throw( error => "Cannot find input directory\n" );
    ( -e $self->output_dir && -d _) or Bio::ENA::DataSubmission::Exception::DirectoryNotFound->throw( error => "Cannot find output directory\n" );
    ( -e $self->manifest ) or Bio::ENA::DataSubmission::Exception::FileNotFound->throw( error => "Cannot find manifest file\n" );
    ( -f $self->manifest && -r _) or Bio::ENA::DataSubmission::Exception::CannotReadFile->throw( error => "Cannot find manifest file\n" );
}

sub _build_arguments_to_system_call {
    my ($self) = @_;

    my @args = ("java", "-Dhttp.proxyHost=" . $self->http_proxy_host, "-Dhttp.proxyPort=" . $self->http_proxy_port,
        "-jar", $self->jar_path, "-username", $self->username, "-password", $self->password, "-inputDir",
        $self->input_dir, "-outputDir", $self->output_dir, "-manifest", $self->manifest, "-context", $self->context);
    if ($self->test) {
        push @args, "-test";
    }
    if ($self->validate) {
        push @args, "-validate";
    }
    if ($self->submit) {
        push @args, "-submit";
    }

    return @args;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
