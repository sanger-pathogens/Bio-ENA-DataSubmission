#!/usr/bin/env perl
BEGIN { unshift( @INC, './lib' ) }

BEGIN {
    use Test::Most;
	use Test::Output;
	use Test::Exception;
}

use_ok( 'Bio::ENA::DataSubmission' );

my ( $obj, $exp );

#-----------------------#
# test URL construction #
#-----------------------#

$obj = Bio::ENA::DataSubmission->new( submission => '', receipt => 'output_receipt',webin_user => 'user',
webin_pass => 'pass',
ena_dropbox_submission_url => 'http://example.com/' );
$exp = 'http://example.com/user%20pass';
is ( $obj->_ena_url, $exp, "URL construction correct" );

#-------------------#
# test full command #
#-------------------#

$obj = Bio::ENA::DataSubmission->new( 
	submission => 't/data/datasub/submission.xml',
	analysis   => 't/data/datasub/analysis.xml', 
	receipt    => 'output_receipt',
	webin_user => 'user',
	webin_pass => 'pass',
	ena_dropbox_submission_url => 'http://example.com/'
);
$exp = 'curl -F "SUBMISSION=@t/data/datasub/submission.xml" -F "ANALYSIS=@t/data/datasub/analysis.xml" "http://example.com/user%20pass" > output_receipt';
is ( $obj->_submission_cmd, $exp, "Submission command correct" );

done_testing();
