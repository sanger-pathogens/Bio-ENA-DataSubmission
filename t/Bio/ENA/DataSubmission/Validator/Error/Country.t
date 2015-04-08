#!/usr/bin/env perl
BEGIN { unshift( @INC, './lib' ) }

BEGIN {
    use Test::Most;
	use Test::Output;
	use Test::Exception;
	use_ok('Bio::ENA::DataSubmission::Validator::Error::Country');
}


my @valid_countries = ("Afghanistan",
"American Samoa",
"Antigua and Barbuda",
"Cote d'Ivoire",
"Falkland Islands (Islas Malvinas)",
"French Southern and Antarctic Lands",
"South Georgia and the South Sandwich Islands",
"USA",
"Afghanistan: ABC, EFG");

for my $country (@valid_countries)
{
  ok(my $obj = Bio::ENA::DataSubmission::Validator::Error::Country->new(country => $country, identifier => 'ABC'), "initialise object for $country");
  ok($obj->validate,"validate $country");
  is($obj->triggered, 0, "no errors for $country");
}

my @invalid_date_format = ('USA1','USA*','1USA','USA:MD');
for my $country (@invalid_date_format)
{
    ok(my $obj = Bio::ENA::DataSubmission::Validator::Error::Country->new(country => $country, identifier => 'ABC'), "initialise object for $country");
    ok($obj->validate,"validate $country");
    is($obj->triggered, 1, "errors for $country");
	is($obj->fix_it, 0, "Country cant be corrected");
}
   
my @invalid_but_fixable = ('UK','Great Britain','England', 'Scotland',  'Wales',  'London',  'Cambridge',  'US', 'UK', 'Vietnam' );
for my $country (@invalid_but_fixable)
{
    ok(my $obj = Bio::ENA::DataSubmission::Validator::Error::Country->new(country => $country, identifier => 'ABC'), "initialise object for $country");
    ok($obj->validate,"validate $date");
    is($obj->triggered, 1, "errors for $date");
	is($obj->fix_it, 1, "Country corrected to ".$obj->country);
}


done_testing();