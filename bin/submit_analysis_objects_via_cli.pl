#!/usr/bin/env perl

package Bio::ENA::DataSubmission::Bin::SubmitAnalysisObjects;

# ABSTRACT: 
# PODNAME: submit_analysis_objects

=head1 SYNOPSIS


=cut

BEGIN { unshift( @INC, '../lib' ) }
BEGIN { unshift( @INC, './lib' ) }

use Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli;

Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new( args => \@ARGV )->run;
