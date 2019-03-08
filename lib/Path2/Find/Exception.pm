package Path2::Find::Exception;
# ABSTRACT: Exceptions for input data 

=head1 SYNOPSIS

Exceptions for input data 

=cut


use Exception::Class (
    Path2::Find::Exception::InvalidInput         => { description => 'Input arguments are invalid' },
    Path2::Find::Exception::FileDoesNotExist     => { description => 'Cannot find file' },
);

1;