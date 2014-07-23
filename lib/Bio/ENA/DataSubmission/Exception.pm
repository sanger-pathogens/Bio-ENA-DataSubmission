package Bio::ENA::DataSubmission::Exception;
# ABSTRACT: Exceptions for input data 

=head1 SYNOPSIS

Exceptions for input data 

=cut


use Exception::Class (
    Bio::ENA::DataSubmission::Exception::InvalidInput          => { description => 'Input arguments are invalid' },
    Bio::ENA::DataSubmission::Exception::FileNotFound          => { description => 'Cannot find file' },
    Bio::ENA::DataSubmission::Exception::ConnectionFail        => { description => 'Failed to connect to database' },
    Bio::ENA::DataSubmission::Exception::NoData                => { description => 'No data was supplied to the spreadsheet writer' },
    Bio::ENA::DataSubmission::Exception::CannotWriteFile       => { description => 'Supplied path does not have write access' },
    Bio::ENA::DataSubmission::Exception::CannotReadFile        => { description => 'Supplied path does not have read access' },
    Bio::ENA::DataSubmission::Exception::TagNotFound           => { description => 'Key does not match any tags in XML' },
    Bio::ENA::DataSubmission::Exception::EmptySpreadsheet      => { description => 'Supplied spreadsheet appears to be empty' },
    Bio::ENA::DataSubmission::Exception::ValidationFail        => { description => 'Validation of the manifest failed' },
    Bio::ENA::DataSubmission::Exception::CannotCreateDirectory => { description => 'Cannot create directory' },
);

1;