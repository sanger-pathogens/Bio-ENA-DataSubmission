#!/usr/bin/env perl

package Bio::ENA::DataSubmission::Bin::SubmitAnalysisObjects;

# ABSTRACT: 
# PODNAME: submit_analysis_objects

=head1 SYNOPSIS


=cut

use strict;
use warnings FATAL => 'all';
use Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli;

Bio::ENA::DataSubmission::CommandLine::SubmitAnalysisObjectsViaCli->new( args => \@ARGV )->run;
