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

$obj = Bio::ENA::DataSubmission->new( submission => '' );
$exp = 'https://wwwdev.ebi.ac.uk/ena/submit/drop-box/submit/?auth=ENA%20Webin-38858%20holy_schisto';
is ( $obj->_ena_url, $exp, "Production server URL correct" );

$obj = Bio::ENA::DataSubmission->new( submission => '', test => 1 );
$exp = 'https://www-test.ebi.ac.uk/ena/submit/drop-box/submit/?auth=ENA%20Webin-38858%20holy_schisto';
is ( $obj->_ena_url, $exp, "Test server URL correct" );

#-------------------#
# test full command #
#-------------------#

$obj = Bio::ENA::DataSubmission->new( 
	submission => 't/data/datasub/submission.xml',
	analysis   => 't/data/datasub/analysis.xml'
);
$exp = 'curl -F "SUBMISSION=@t/data/datasub/submission.xml" -F "ANALYSIS=@t/data/datasub/analysis.xml" "https://wwwdev.ebi.ac.uk/ena/submit/drop-box/submit/?auth=ENA%20Webin-38858%20holy_schisto"';
is ( $obj->_submission_cmd, $exp, "Submission command correct" );

$obj = Bio::ENA::DataSubmission->new( 
	submission => 't/data/datasub/submission.xml',
	project    => 't/data/datasub/project.xml',
	sample     => 't/data/datasub/sample.xml',
	test       => 1,
	_webin_user => 'ENA_4_life',
	_webin_pass => 'easy_password'
);
$exp = 'curl -F "SUBMISSION=@t/data/datasub/submission.xml" -F "SAMPLE=@t/data/datasub/sample.xml" -F "PROJECT=@t/data/datasub/project.xml" "https://www-test.ebi.ac.uk/ena/submit/drop-box/submit/?auth=ENA%20ENA_4_life%20easy_password"';
is ( $obj->_submission_cmd, $exp, "Submission command correct" );

done_testing();
