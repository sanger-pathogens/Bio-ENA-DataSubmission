#!/usr/bin/env perl

BEGIN {
    use strict;
    use warnings FATAL => 'all';

    use Test::Most;
	use Test::Output;
	use Test::Exception;
	use_ok('Bio::ENA::DataSubmission::Validator::Error::Date');
}


my @valid_date_format = ('2001','2001-01','NA','2001-12','2001-01-01','2001-12-31');
for my $date (@valid_date_format)
{
  ok(my $obj = Bio::ENA::DataSubmission::Validator::Error::Date->new(identifier => '123', date => $date), "initialise object for $date");
  ok($obj->validate,"validate $date");
  is($obj->triggered, 0, "no errors for $date");
}

my @invalid_date_format = ('1-1','','2001-1','2001-1-01','abcd-ef-gh');
for my $date (@invalid_date_format)
{
  ok(my $obj = Bio::ENA::DataSubmission::Validator::Error::Date->new(identifier => '123', date => $date), "initialise object for $date");
  ok($obj->validate,"validate $date");
  is($obj->triggered, 1, "errors for $date");
}

done_testing();