#!/usr/bin/env perl


# AUTHOR

# Felix Manske, felix.manske@uni-muenster.de


# COPYRIGHT

# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright
#  notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#  notice, this list of conditions and the following disclaimer in the
#  documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO,  PROCUREMENT  OF  SUBSTITUTE GOODS  OR  SERVICES;
# LOSS  OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.


#==================================================================================================#
# Tests for importSGA.pl
#==================================================================================================#
# DESCRIPTION
# 
#	Test the insert/update of data via importSGA.pl. These are very high level tests and aim to
#	replicate typical user workflows. Detailed tests have been performed for the single modules.
#
#
# USAGE
#
# 	./test_importSGA.pl
#
#			
# DEPENDENCIES
# 
#	DateTime::Duration
#	DateTime::Format::ISO8601
#	Test2::Bundle::More
#	Test2::Tools::Compare
#	Try::Tiny
#==================================================================================================#


use strict;
use warnings;

use DateTime::Duration;
use DateTime::Format::ISO8601;
use FindBin;
use Storable qw(dclone);
use Test2::Bundle::More qw(ok done_testing todo);
use Test2::Tools::Compare qw(is isnt);
use Try::Tiny;

use lib "$FindBin::Bin/../../lib/perl/";
use MetagDB::Db qw(connectDebug);


#
#--------------------------------------------------------------------------------------------------#
# Internal function to extract a letter based on its position in the alphabet.
#--------------------------------------------------------------------------------------------------#
#
sub getLetter  {
	my $int = int($_[0]);
	my $alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	
	if ($int >= length($alphabet)) {
		die "ERROR: Integer is too large";
	}
	else {
		return substr($alphabet, $int, 1);
	}
}


#
#--------------------------------------------------------------------------------------------------#
# Create database relations, functions, and views
#--------------------------------------------------------------------------------------------------#
#
sub createDB  {
	my $dbh = $_[0];
	my $schema = $_[1];
	
	# Suppress messages on terminal
	do {
		local *STDERR;
		open(STDERR, '>', '/dev/null');
		
		# Create the relations/indices/functions/views in the test database
		$dbh->do($schema);
		$dbh->commit;
	};	
	
	
	return $dbh;	
}


#
#--------------------------------------------------------------------------------------------------#
# Drop database relations, functions, and views
#--------------------------------------------------------------------------------------------------#
#
sub dropDB  {
	my $dbh = $_[0];
	my $schema = $_[1];
	
	
	# Store all materialized views from the schema
	my @items = ();
	while ($schema =~ m/create\s+materialized\s+view\s+([a-z_]+)/ig) {
		push(@items, $1)
	}
	
	# Parse the array from end to start and drop all views
	# (order reversed to account for dependencies)
	for (my $i = $#items; $i >= 0; $i--) {
		$dbh->do("DROP MATERIALIZED VIEW $items[$i]");
	}
	
	# Store all views from the schema
	@items = ();
	while ($schema =~ m/create\s+view\s+([a-z_]+)/ig) {
		push(@items, $1)
	}
	
	# Drop all views
	for (my $i = $#items; $i >= 0; $i--) {
		$dbh->do("DROP VIEW $items[$i]");
	}

	# Store of all relations from the schema
	@items = ();
	while ($schema =~ m/create\s+table\s+([a-zA-Z_]+)/g) {
		push(@items, $1)
	}
	
	# Drop all relations
	for (my $i = $#items; $i >= 0; $i--) {
		$dbh->do("DROP TABLE $items[$i]");
	}
	
	# Store of all functions from the schema
	@items = ();
	while ($schema =~ m/create\s+function\s+([a-zA-Z_]+)/ig) {
		push(@items, $1)
	}
	# Drop all functions
	for (my $i = $#items; $i >= 0; $i--) {
		$dbh->do("DROP FUNCTION $items[$i]");
	}
	
	# Store of all extensions from the schema
	@items = ();
	while ($schema =~ m/create\s+extension\s+([a-zA-Z_]+)/ig) {
		push(@items, $1)
	}
	# Drop all extensions
	for (my $i = $#items; $i >= 0; $i--) {
		$dbh->do("DROP EXTENSION $items[$i]");
	}
	$dbh->commit();
	
	
	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Test to insert/update measures (standards only indirectly checked via z-score)
#--------------------------------------------------------------------------------------------------#
#
sub test_measures {
	my $dbh = $_[0];
	my $schema = $_[1];
	my $basePath = $_[2];
	
	my $err = "";
	my $resR = "";
	my $resDerivedR = "";
	my $resSeqClassR = "";
	my $resChangeR = "";
	my $expecMeasureR = [
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'natural', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '2000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '50', 'maternal body mass at delivery', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '40', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'hypertension', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1901-01-01', 'mother\'s birth date', 'd', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1.5', 'mother\'s height', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1', 'pregnancy order', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'm', 'sex', 's', ["m", "f", "NA"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '2200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, '2400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, '2600', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, '2800', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, '5000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, '6000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, '7000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'caesarean section', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '55', 'maternal body mass at delivery', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '50', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'diabetes', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1901-02-02', 'mother\'s birth date', 'd', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1.6', 'mother\'s height', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3', 'pregnancy order', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'f', 'sex', 's', ["m", "f", "NA"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, '3600', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, '3800', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, '4000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, '4200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, '4400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, '5400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, '6400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, '7400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 1, undef, undef, undef, undef],
	];
	my $expecDerivedR = [
		["fb1", "1920-01-01", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb1", "1920-01-01", "meconium", 'difference in body mass at delivery', 'i', 10],
		["fb1", "1920-01-01", "meconium", 'mother\'s age at delivery', 'i', '19.00'],
		["fb1", "1920-01-01", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 17.78],
		["fb1", "1920-01-01", "meconium", "mother\'s pre-pregnancy BMI category", 's', "underweight"],
		["fb1", "1920-01-01", "meconium", 'z-score', 'i', -3.21],
		["fb1", "1920-01-01", "meconium", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-01", "meconium", 'z-score subcategory', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score', 'i', -2.72],
		["fb1", "1920-01-04", "3d", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-01-15", "2w", 'z-score', 'i', -2.99],
		["fb1", "1920-01-15", "2w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-15", "2w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-02-15", "6w", 'z-score', 'i', -4.54],
		["fb1", "1920-02-15", "6w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-02-15", "6w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-04-01", "3m", 'z-score', 'i', -5.8],
		["fb1", "1920-04-01", "3m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-04-01", "3m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-07-01", "6m", 'z-score', 'i', -6.91],
		["fb1", "1920-07-01", "6m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-07-01", "6m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-10-01", "9m", 'z-score', 'i', -7.23],
		["fb1", "1920-10-01", "9m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-10-01", "9m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-01-01", "1y", 'z-score', 'i', -7.33],
		["fb1", "1921-01-01", "1y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-01-01", "1y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-07-01", "1.5y", 'z-score', 'i', -6.05],
		["fb1", "1921-07-01", "1.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-07-01", "1.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-01-01", "2y", 'z-score', 'i', -5.53],
		["fb1", "1922-01-01", "2y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-01-01", "2y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-07-01", "2.5y", 'z-score', 'i', -5.04],
		["fb1", "1922-07-01", "2.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-07-01", "2.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb2", "1921-02-02", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb2", "1921-02-02", "meconium", 'difference in body mass at delivery', 'i', 5],
		["fb2", "1921-02-02", "meconium", 'mother\'s age at delivery', 'i', '20.00'],
		["fb2", "1921-02-02", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 19.53],
		["fb2", "1921-02-02", "meconium", "mother\'s pre-pregnancy BMI category", 's', "normal weight"],
		["fb2", "1921-02-02", "meconium", 'z-score', 'i', -0.52],
		["fb2", "1921-02-02", "meconium", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-02", "meconium", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score', 'i', -0.07],
		["fb2", "1921-02-05", "3d", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score', 'i', -0.34],
		["fb2", "1921-02-16", "2w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score', 'i', -1.77],
		["fb2", "1921-03-16", "6w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score', 'i', -3.29],
		["fb2", "1921-05-02", "3m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score', 'i', -4.66],
		["fb2", "1921-08-02", "6m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score', 'i', -5.18],
		["fb2", "1921-11-02", "9m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score', 'i', -5.44],
		["fb2", "1922-02-02", "1y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score', 'i', -5.06],
		["fb2", "1922-08-02", "1.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score', 'i', -4.72],
		["fb2", "1923-02-02", "2y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score', 'i', -4.37],
		["fb2", "1923-08-02", "2.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score subcategory', 's', 'AGA']
	];
	my $expecMeasure_updatedR = [
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'caesarean section', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '2100', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'yes', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '52', 'maternal body mass at delivery', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '41', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, "thyroid disease", 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1903-01-01', 'mother\'s birth date', 'd', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1.51', 'mother\'s height', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '2', 'pregnancy order', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'f', 'sex', 's', ["m", "f", "NA"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '2200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, '2400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, '2600', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, '2800', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, '5000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, '6000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, '7000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'caesarean section', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '55', 'maternal body mass at delivery', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '50', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'diabetes', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1901-02-02', 'mother\'s birth date', 'd', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1.6', 'mother\'s height', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3', 'pregnancy order', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'f', 'sex', 's', ["m", "f", "NA"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, '3600', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, '3800', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, '4000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, '4200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, '4400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, '5400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, '6400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, '7400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 1, undef, undef, undef, undef],
	];
	my $expecDerived_updatedR = [
		["fb1", "1920-01-01", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb1", "1920-01-01", "meconium", 'difference in body mass at delivery', 'i', 11],
		["fb1", "1920-01-01", "meconium", 'mother\'s age at delivery', 'i', '17.00'],
		["fb1", "1920-01-01", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 17.98],
		["fb1", "1920-01-01", "meconium", "mother\'s pre-pregnancy BMI category", 's', "underweight"],
		["fb1", "1920-01-01", "meconium", 'z-score', 'i', -2.81],
		["fb1", "1920-01-01", "meconium", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-01", "meconium", 'z-score subcategory', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score', 'i', -2.48],
		["fb1", "1920-01-04", "3d", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-01-15", "2w", 'z-score', 'i', -2.65],
		["fb1", "1920-01-15", "2w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-15", "2w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-02-15", "6w", 'z-score', 'i', -4.08],
		["fb1", "1920-02-15", "6w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-02-15", "6w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-04-01", "3m", 'z-score', 'i', -5.18],
		["fb1", "1920-04-01", "3m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-04-01", "3m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-07-01", "6m", 'z-score', 'i', -6.23],
		["fb1", "1920-07-01", "6m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-07-01", "6m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-10-01", "9m", 'z-score', 'i', -6.59],
		["fb1", "1920-10-01", "9m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-10-01", "9m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-01-01", "1y", 'z-score', 'i', -6.74],
		["fb1", "1921-01-01", "1y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-01-01", "1y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-07-01", "1.5y", 'z-score', 'i', -5.52],
		["fb1", "1921-07-01", "1.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-07-01", "1.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-01-01", "2y", 'z-score', 'i', -5.13],
		["fb1", "1922-01-01", "2y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-01-01", "2y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-07-01", "2.5y", 'z-score', 'i', -4.75],
		["fb1", "1922-07-01", "2.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-07-01", "2.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb2", "1921-02-02", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb2", "1921-02-02", "meconium", 'difference in body mass at delivery', 'i', 5],
		["fb2", "1921-02-02", "meconium", 'mother\'s age at delivery', 'i', '20.00'],
		["fb2", "1921-02-02", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 19.53],
		["fb2", "1921-02-02", "meconium", "mother\'s pre-pregnancy BMI category", 's', "normal weight"],
		["fb2", "1921-02-02", "meconium", 'z-score', 'i', -0.52],
		["fb2", "1921-02-02", "meconium", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-02", "meconium", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score', 'i', -0.07],
		["fb2", "1921-02-05", "3d", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score', 'i', -0.34],
		["fb2", "1921-02-16", "2w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score', 'i', -1.77],
		["fb2", "1921-03-16", "6w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score', 'i', -3.29],
		["fb2", "1921-05-02", "3m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score', 'i', -4.66],
		["fb2", "1921-08-02", "6m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score', 'i', -5.18],
		["fb2", "1921-11-02", "9m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score', 'i', -5.44],
		["fb2", "1922-02-02", "1y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score', 'i', -5.06],
		["fb2", "1922-08-02", "1.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score', 'i', -4.72],
		["fb2", "1923-02-02", "2y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score', 'i', -4.37],
		["fb2", "1923-08-02", "2.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score subcategory', 's', 'AGA']
	];
	my $expecMeasure_updatedPatR = [
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'natural', 'birth mode', 's', ["natural", "caesarean section"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '2000', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '50', 'maternal body mass at delivery', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '40', 'maternal body mass before pregnancy', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'hypertension', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1901-01-01', 'mother\'s birth date', 'd', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1.5', 'mother\'s height', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1', 'pregnancy order', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'm', 'sex', 's', ["m", "f", "NA"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 1, undef, undef, undef, undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '2200', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-04", undef, 1, undef, undef, undef, undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-15", undef, 0, '2400', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-15", undef, 1, undef, undef, undef, undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-02-15", undef, 0, '2600', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-02-15", undef, 1, undef, undef, undef, undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-04-01", undef, 0, '2800', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-04-01", undef, 1, undef, undef, undef, undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-07-01", undef, 0, '3000', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-07-01", undef, 1, undef, undef, undef, undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-10-01", undef, 0, '3200', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-10-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-10-01", undef, 1, undef, undef, undef, undef],
		["FarBoo1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1921-01-01", undef, 0, '3400', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1921-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1921-01-01", undef, 1, undef, undef, undef, undef],
		["FarBoo1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1921-07-01", undef, 0, '5000', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1921-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1921-07-01", undef, 1, undef, undef, undef, undef],
		["FarBoo1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1922-01-01", undef, 0, '6000', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1922-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1922-01-01", undef, 1, undef, undef, undef, undef],
		["FarBoo1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1922-07-01", undef, 0, '7000', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1922-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1922-07-01", undef, 1, undef, undef, undef, undef],
		["FarBoo1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1923-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1923-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'natural', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '2000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '50', 'maternal body mass at delivery', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '40', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'hypertension', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1901-01-01', 'mother\'s birth date', 'd', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1.5', 'mother\'s height', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1', 'pregnancy order', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'm', 'sex', 's', ["m", "f", "NA"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '2200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, '2400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, '2600', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, '2800', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, '5000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, '6000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, '7000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'caesarean section', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '55', 'maternal body mass at delivery', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '50', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'diabetes', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1901-02-02', 'mother\'s birth date', 'd', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1.6', 'mother\'s height', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3', 'pregnancy order', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'f', 'sex', 's', ["m", "f", "NA"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, '3600', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, '3800', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, '4000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, '4200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, '4400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, '5400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, '6400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, '7400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 1, undef, undef, undef, undef]
	];
	my $expecDerived_updatedPatR = [
		["fb1", "1920-01-01", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb1", "1920-01-01", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb1", "1920-01-01", "meconium", 'difference in body mass at delivery', 'i', 10],
		["fb1", "1920-01-01", "meconium", 'difference in body mass at delivery', 'i', 10],
		["fb1", "1920-01-01", "meconium", 'mother\'s age at delivery', 'i', '19.00'],
		["fb1", "1920-01-01", "meconium", 'mother\'s age at delivery', 'i', '19.00'],
		["fb1", "1920-01-01", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 17.78],
		["fb1", "1920-01-01", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 17.78],
		["fb1", "1920-01-01", "meconium", "mother\'s pre-pregnancy BMI category", 's', "underweight"],
		["fb1", "1920-01-01", "meconium", "mother\'s pre-pregnancy BMI category", 's', "underweight"],
		["fb1", "1920-01-01", "meconium", 'z-score', 'i', -3.21],
		["fb1", "1920-01-01", "meconium", 'z-score', 'i', -3.21],
		["fb1", "1920-01-01", "meconium", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-01", "meconium", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-01", "meconium", 'z-score subcategory', 's', 'SGA'],
		["fb1", "1920-01-01", "meconium", 'z-score subcategory', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score', 'i', -2.72],
		["fb1", "1920-01-04", "3d", 'z-score', 'i', -2.72],
		["fb1", "1920-01-04", "3d", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-01-04", "3d", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-01-15", "2w", 'z-score', 'i', -2.99],
		["fb1", "1920-01-15", "2w", 'z-score', 'i', -2.99],
		["fb1", "1920-01-15", "2w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-15", "2w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-15", "2w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-01-15", "2w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-02-15", "6w", 'z-score', 'i', -4.54],
		["fb1", "1920-02-15", "6w", 'z-score', 'i', -4.54],
		["fb1", "1920-02-15", "6w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-02-15", "6w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-02-15", "6w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-02-15", "6w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-04-01", "3m", 'z-score', 'i', -5.8],
		["fb1", "1920-04-01", "3m", 'z-score', 'i', -5.8],
		["fb1", "1920-04-01", "3m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-04-01", "3m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-04-01", "3m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-04-01", "3m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-07-01", "6m", 'z-score', 'i', -6.91],
		["fb1", "1920-07-01", "6m", 'z-score', 'i', -6.91],
		["fb1", "1920-07-01", "6m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-07-01", "6m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-07-01", "6m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-07-01", "6m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-10-01", "9m", 'z-score', 'i', -7.23],
		["fb1", "1920-10-01", "9m", 'z-score', 'i', -7.23],
		["fb1", "1920-10-01", "9m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-10-01", "9m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-10-01", "9m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-10-01", "9m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-01-01", "1y", 'z-score', 'i', -7.33],
		["fb1", "1921-01-01", "1y", 'z-score', 'i', -7.33],
		["fb1", "1921-01-01", "1y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-01-01", "1y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-01-01", "1y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-01-01", "1y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-07-01", "1.5y", 'z-score', 'i', -6.05],
		["fb1", "1921-07-01", "1.5y", 'z-score', 'i', -6.05],
		["fb1", "1921-07-01", "1.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-07-01", "1.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-07-01", "1.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-07-01", "1.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-01-01", "2y", 'z-score', 'i', -5.53],
		["fb1", "1922-01-01", "2y", 'z-score', 'i', -5.53],
		["fb1", "1922-01-01", "2y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-01-01", "2y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-01-01", "2y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-01-01", "2y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-07-01", "2.5y", 'z-score', 'i', -5.04],
		["fb1", "1922-07-01", "2.5y", 'z-score', 'i', -5.04],
		["fb1", "1922-07-01", "2.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-07-01", "2.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-07-01", "2.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-07-01", "2.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb2", "1921-02-02", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb2", "1921-02-02", "meconium", 'difference in body mass at delivery', 'i', 5],
		["fb2", "1921-02-02", "meconium", 'mother\'s age at delivery', 'i', '20.00'],
		["fb2", "1921-02-02", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 19.53],
		["fb2", "1921-02-02", "meconium", "mother\'s pre-pregnancy BMI category", 's', "normal weight"],
		["fb2", "1921-02-02", "meconium", 'z-score', 'i', -0.52],
		["fb2", "1921-02-02", "meconium", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-02", "meconium", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score', 'i', -0.07],
		["fb2", "1921-02-05", "3d", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score', 'i', -0.34],
		["fb2", "1921-02-16", "2w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score', 'i', -1.77],
		["fb2", "1921-03-16", "6w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score', 'i', -3.29],
		["fb2", "1921-05-02", "3m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score', 'i', -4.66],
		["fb2", "1921-08-02", "6m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score', 'i', -5.18],
		["fb2", "1921-11-02", "9m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score', 'i', -5.44],
		["fb2", "1922-02-02", "1y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score', 'i', -5.06],
		["fb2", "1922-08-02", "1.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score', 'i', -4.72],
		["fb2", "1923-02-02", "2y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score', 'i', -4.37],
		["fb2", "1923-08-02", "2.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score subcategory', 's', 'AGA']
	];
	my $expecMeasure_updatedPat_oneSamplR = [
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'natural', 'birth mode', 's', ["natural", "caesarean section"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '2000', 'body mass', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '50', 'maternal body mass at delivery', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '40', 'maternal body mass before pregnancy', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'hypertension', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1901-01-01', 'mother\'s birth date', 'd', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1.5', 'mother\'s height', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1', 'pregnancy order', 'i', undef],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'm', 'sex', 's', ["m", "f", "NA"]],
		["FarBoo1", "fb1", "1920-01-01", "1920-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'natural', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '2000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '50', 'maternal body mass at delivery', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '40', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'hypertension', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1901-01-01', 'mother\'s birth date', 'd', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1.5', 'mother\'s height', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1', 'pregnancy order', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'm', 'sex', 's', ["m", "f", "NA"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '2200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, '2400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, '2600', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, '2800', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, '5000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, '6000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, '7000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'caesarean section', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '55', 'maternal body mass at delivery', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '50', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'diabetes', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1901-02-02', 'mother\'s birth date', 'd', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1.6', 'mother\'s height', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3', 'pregnancy order', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'f', 'sex', 's', ["m", "f", "NA"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, '3600', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, '3800', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, '4000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, '4200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, '4400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, '5400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, '6400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, '7400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 1, undef, undef, undef, undef]
	];
	my $expecDerived_updatedPat_oneSamplR = [
		["fb1", "1920-01-01", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb1", "1920-01-01", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb1", "1920-01-01", "meconium", 'difference in body mass at delivery', 'i', 10],
		["fb1", "1920-01-01", "meconium", 'difference in body mass at delivery', 'i', 10],
		["fb1", "1920-01-01", "meconium", 'mother\'s age at delivery', 'i', '19.00'],
		["fb1", "1920-01-01", "meconium", 'mother\'s age at delivery', 'i', '19.00'],
		["fb1", "1920-01-01", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 17.78],
		["fb1", "1920-01-01", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 17.78],
		["fb1", "1920-01-01", "meconium", "mother\'s pre-pregnancy BMI category", 's', "underweight"],
		["fb1", "1920-01-01", "meconium", "mother\'s pre-pregnancy BMI category", 's', "underweight"],
		["fb1", "1920-01-01", "meconium", 'z-score', 'i', -3.21],
		["fb1", "1920-01-01", "meconium", 'z-score', 'i', -3.21],
		["fb1", "1920-01-01", "meconium", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-01", "meconium", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-01", "meconium", 'z-score subcategory', 's', 'SGA'],
		["fb1", "1920-01-01", "meconium", 'z-score subcategory', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score', 'i', -2.72],
		["fb1", "1920-01-04", "3d", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-01-15", "2w", 'z-score', 'i', -2.99],
		["fb1", "1920-01-15", "2w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-15", "2w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-02-15", "6w", 'z-score', 'i', -4.54],
		["fb1", "1920-02-15", "6w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-02-15", "6w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-04-01", "3m", 'z-score', 'i', -5.8],
		["fb1", "1920-04-01", "3m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-04-01", "3m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-07-01", "6m", 'z-score', 'i', -6.91],
		["fb1", "1920-07-01", "6m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-07-01", "6m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-10-01", "9m", 'z-score', 'i', -7.23],
		["fb1", "1920-10-01", "9m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-10-01", "9m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-01-01", "1y", 'z-score', 'i', -7.33],
		["fb1", "1921-01-01", "1y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-01-01", "1y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-07-01", "1.5y", 'z-score', 'i', -6.05],
		["fb1", "1921-07-01", "1.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-07-01", "1.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-01-01", "2y", 'z-score', 'i', -5.53],
		["fb1", "1922-01-01", "2y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-01-01", "2y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-07-01", "2.5y", 'z-score', 'i', -5.04],
		["fb1", "1922-07-01", "2.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-07-01", "2.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb2", "1921-02-02", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb2", "1921-02-02", "meconium", 'difference in body mass at delivery', 'i', 5],
		["fb2", "1921-02-02", "meconium", 'mother\'s age at delivery', 'i', '20.00'],
		["fb2", "1921-02-02", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 19.53],
		["fb2", "1921-02-02", "meconium", "mother\'s pre-pregnancy BMI category", 's', "normal weight"],
		["fb2", "1921-02-02", "meconium", 'z-score', 'i', -0.52],
		["fb2", "1921-02-02", "meconium", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-02", "meconium", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score', 'i', -0.07],
		["fb2", "1921-02-05", "3d", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score', 'i', -0.34],
		["fb2", "1921-02-16", "2w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score', 'i', -1.77],
		["fb2", "1921-03-16", "6w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score', 'i', -3.29],
		["fb2", "1921-05-02", "3m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score', 'i', -4.66],
		["fb2", "1921-08-02", "6m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score', 'i', -5.18],
		["fb2", "1921-11-02", "9m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score', 'i', -5.44],
		["fb2", "1922-02-02", "1y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score', 'i', -5.06],
		["fb2", "1922-08-02", "1.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score', 'i', -4.72],
		["fb2", "1923-02-02", "2y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score', 'i', -4.37],
		["fb2", "1923-08-02", "2.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score subcategory', 's', 'AGA']
	];

	my $expecMeasure_updatedSamplR = [
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'natural', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '2000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '50', 'maternal body mass at delivery', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '40', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'hypertension', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1901-01-01', 'mother\'s birth date', 'd', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1.5', 'mother\'s height', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1', 'pregnancy order', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'm', 'sex', 's', ["m", "f", "NA"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '2200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, '2400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, '2600', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, '2800', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, '5000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, '6000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, '7000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, '7000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'caesarean section', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '55', 'maternal body mass at delivery', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '50', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'diabetes', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1901-02-02', 'mother\'s birth date', 'd', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1.6', 'mother\'s height', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3', 'pregnancy order', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'f', 'sex', 's', ["m", "f", "NA"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, '3600', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, '3800', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, '4000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, '4200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, '4400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, '5400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, '6400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, '7400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 1, undef, undef, undef, undef]
	];
	my $expecDerived_updatedSamplR = [
		["fb1", "1920-01-01", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb1", "1920-01-01", "meconium", 'difference in body mass at delivery', 'i', 10],
		["fb1", "1920-01-01", "meconium", 'mother\'s age at delivery', 'i', '19.00'],
		["fb1", "1920-01-01", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 17.78],
		["fb1", "1920-01-01", "meconium", "mother\'s pre-pregnancy BMI category", 's', "underweight"],
		["fb1", "1920-01-01", "meconium", 'z-score', 'i', -3.21],
		["fb1", "1920-01-01", "meconium", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-01", "meconium", 'z-score subcategory', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score', 'i', -2.72],
		["fb1", "1920-01-04", "3d", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-01-15", "2w", 'z-score', 'i', -2.99],
		["fb1", "1920-01-15", "2w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-15", "2w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-02-15", "6w", 'z-score', 'i', -4.54],
		["fb1", "1920-02-15", "6w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-02-15", "6w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-04-01", "3m", 'z-score', 'i', -5.8],
		["fb1", "1920-04-01", "3m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-04-01", "3m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-07-01", "6m", 'z-score', 'i', -6.91],
		["fb1", "1920-07-01", "6m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-07-01", "6m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-10-01", "9m", 'z-score', 'i', -7.23],
		["fb1", "1920-10-01", "9m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-10-01", "9m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-01-01", "1y", 'z-score', 'i', -7.33],
		["fb1", "1921-01-01", "1y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-01-01", "1y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-07-01", "1.5y", 'z-score', 'i', -6.05],
		["fb1", "1921-07-01", "1.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-07-01", "1.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-01-01", "2y", 'z-score', 'i', -5.53],
		["fb1", "1922-01-01", "2y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-01-01", "2y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-07-01", "2.5y", 'z-score', 'i', -5.04],
		["fb1", "1922-07-01", "2.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-07-01", "2.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1923-01-01", "3y", 'z-score', 'i', -5.39],
		["fb1", "1923-01-01", "3y", 'z-score category', 's', 'SGA'],
		["fb1", "1923-01-01", "3y", 'z-score subcategory', 's', 'no catch-up'],
		["fb2", "1921-02-02", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb2", "1921-02-02", "meconium", 'difference in body mass at delivery', 'i', 5],
		["fb2", "1921-02-02", "meconium", 'mother\'s age at delivery', 'i', '20.00'],
		["fb2", "1921-02-02", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 19.53],
		["fb2", "1921-02-02", "meconium", "mother\'s pre-pregnancy BMI category", 's', "normal weight"],
		["fb2", "1921-02-02", "meconium", 'z-score', 'i', -0.52],
		["fb2", "1921-02-02", "meconium", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-02", "meconium", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score', 'i', -0.07],
		["fb2", "1921-02-05", "3d", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score', 'i', -0.34],
		["fb2", "1921-02-16", "2w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score', 'i', -1.77],
		["fb2", "1921-03-16", "6w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score', 'i', -3.29],
		["fb2", "1921-05-02", "3m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score', 'i', -4.66],
		["fb2", "1921-08-02", "6m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score', 'i', -5.18],
		["fb2", "1921-11-02", "9m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score', 'i', -5.44],
		["fb2", "1922-02-02", "1y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score', 'i', -5.06],
		["fb2", "1922-08-02", "1.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score', 'i', -4.72],
		["fb2", "1923-02-02", "2y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score', 'i', -4.37],
		["fb2", "1923-08-02", "2.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score subcategory', 's', 'AGA']
	];
	my $expecMeasure_addMeasureR = [
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'natural', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '2000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '50', 'maternal body mass at delivery', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '40', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'hypertension', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1901-01-01', 'mother\'s birth date', 'd', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1.5', 'mother\'s height', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, '1', 'pregnancy order', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 0, 'm', 'sex', 's', ["m", "f", "NA"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '2200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, '2400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, '2600', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, '2800', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, '5000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, '6000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, '7000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, '8000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'caesarean section', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '55', 'maternal body mass at delivery', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '50', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'diabetes', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1901-02-02', 'mother\'s birth date', 'd', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1.6', 'mother\'s height', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3', 'pregnancy order', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'f', 'sex', 's', ["m", "f", "NA"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, '3600', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, '3800', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, '4000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, '4200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, '4400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, '5400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, '6400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, '7400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 1, undef, undef, undef, undef],
	];
	my $expecDerived_addMeasureR = [
		["fb1", "1920-01-01", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb1", "1920-01-01", "meconium", 'difference in body mass at delivery', 'i', 10],
		["fb1", "1920-01-01", "meconium", 'mother\'s age at delivery', 'i', '19.00'],
		["fb1", "1920-01-01", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 17.78],
		["fb1", "1920-01-01", "meconium", "mother\'s pre-pregnancy BMI category", 's', "underweight"],
		["fb1", "1920-01-01", "meconium", 'z-score', 'i', -3.21],
		["fb1", "1920-01-01", "meconium", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-01", "meconium", 'z-score subcategory', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score', 'i', -2.72],
		["fb1", "1920-01-04", "3d", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-04", "3d", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-01-15", "2w", 'z-score', 'i', -2.99],
		["fb1", "1920-01-15", "2w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-15", "2w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-02-15", "6w", 'z-score', 'i', -4.54],
		["fb1", "1920-02-15", "6w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-02-15", "6w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-04-01", "3m", 'z-score', 'i', -5.8],
		["fb1", "1920-04-01", "3m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-04-01", "3m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-07-01", "6m", 'z-score', 'i', -6.91],
		["fb1", "1920-07-01", "6m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-07-01", "6m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-10-01", "9m", 'z-score', 'i', -7.23],
		["fb1", "1920-10-01", "9m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-10-01", "9m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-01-01", "1y", 'z-score', 'i', -7.33],
		["fb1", "1921-01-01", "1y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-01-01", "1y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-07-01", "1.5y", 'z-score', 'i', -6.05],
		["fb1", "1921-07-01", "1.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-07-01", "1.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-01-01", "2y", 'z-score', 'i', -5.53],
		["fb1", "1922-01-01", "2y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-01-01", "2y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-07-01", "2.5y", 'z-score', 'i', -5.04],
		["fb1", "1922-07-01", "2.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-07-01", "2.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1923-01-01", "3y", 'z-score', 'i', -4.6],
		["fb1", "1923-01-01", "3y", 'z-score category', 's', 'SGA'],
		["fb1", "1923-01-01", "3y", 'z-score subcategory', 's', 'no catch-up'],
		["fb2", "1921-02-02", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb2", "1921-02-02", "meconium", 'difference in body mass at delivery', 'i', 5],
		["fb2", "1921-02-02", "meconium", 'mother\'s age at delivery', 'i', '20.00'],
		["fb2", "1921-02-02", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 19.53],
		["fb2", "1921-02-02", "meconium", "mother\'s pre-pregnancy BMI category", 's', "normal weight"],
		["fb2", "1921-02-02", "meconium", 'z-score', 'i', -0.52],
		["fb2", "1921-02-02", "meconium", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-02", "meconium", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score', 'i', -0.07],
		["fb2", "1921-02-05", "3d", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score', 'i', -0.34],
		["fb2", "1921-02-16", "2w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score', 'i', -1.77],
		["fb2", "1921-03-16", "6w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score', 'i', -3.29],
		["fb2", "1921-05-02", "3m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score', 'i', -4.66],
		["fb2", "1921-08-02", "6m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score', 'i', -5.18],
		["fb2", "1921-11-02", "9m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score', 'i', -5.44],
		["fb2", "1922-02-02", "1y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score', 'i', -5.06],
		["fb2", "1922-08-02", "1.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score', 'i', -4.72],
		["fb2", "1923-02-02", "2y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score', 'i', -4.37],
		["fb2", "1923-08-02", "2.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score subcategory', 's', 'AGA']
	];
	my $expecMeasure_noMecR = [
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'natural', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '2200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '50', 'maternal body mass at delivery', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '40', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'hypertension', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '1901-01-01', 'mother\'s birth date', 'd', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '1.5', 'mother\'s height', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, '1', 'pregnancy order', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 0, 'm', 'sex', 's', ["m", "f", "NA"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-04", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, '2400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-01-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, '2600', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-02-15", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, '2800', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-04-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'breastfed', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1920-10-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, '5000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1921-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, '6000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, '7000', 'body mass', 'i', undef],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1922-07-01", undef, 1, undef, undef, undef, undef],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, "diet extension", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 0, 'no', 'probiotics', 'b', ["yes", "no"]],
		["Foobar1", "fb1", "1920-01-01", "1923-01-01", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'caesarean section', 'birth mode', 's', ["natural", "caesarean section"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'maternal antibiotics during pregnancy', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '55', 'maternal body mass at delivery', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '50', 'maternal body mass before pregnancy', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'diabetes', 'maternal illness during pregnancy', 's', ["diabetes", "thyroid disease",
			"hypertension", "diabetes + thyroid disease", "diabetes + hypertension", "thyroid disease + hypertension",
			"diabetes + thyroid disease + hypertension"]
		],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1901-02-02', 'mother\'s birth date', 'd', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '1.6', 'mother\'s height', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, '3', 'pregnancy order', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 0, 'f', 'sex', 's', ["m", "f", "NA"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, '3200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-05", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, '3400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-02-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, '3600', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-03-16", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, '3800', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-05-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, '4000', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'formula', 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, '4200', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1921-11-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, '4400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, '5400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1922-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, '6400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-02-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, '7400', 'body mass', 'i', undef],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1923-08-02", undef, 1, undef, undef, undef, undef],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'antibiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, "formula", 'feeding mode', 's', ["breastfed", "formula" , "mixed", "diet extension"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 0, 'yes', 'probiotics', 'b', ["yes", "no"]],
		["Foobar2", "fb2", "1921-02-02", "1924-02-02", undef, 1, undef, undef, undef, undef],
	];
	my $expecDerived_noMecR = [
		["fb1", "1920-01-04", "3d", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb1", "1920-01-04", "3d", 'difference in body mass at delivery', 'i', 10],
		["fb1", "1920-01-04", "3d", 'mother\'s age at delivery', 'i', '19.00'],
		["fb1", "1920-01-04", "3d", 'mother\'s pre-pregnancy BMI', 'i', 17.78],
		["fb1", "1920-01-04", "3d", "mother\'s pre-pregnancy BMI category", 's', "underweight"],
		["fb1", "1920-01-04", "3d", 'z-score', 'i', -2.72],
		["fb1", "1920-01-04", "3d", 'z-score category', 's', 'SGA'], # first sample special category name: SGA/AGA
		["fb1", "1920-01-04", "3d", 'z-score subcategory', 's', 'SGA'],
		["fb1", "1920-01-15", "2w", 'z-score', 'i', -2.99],
		["fb1", "1920-01-15", "2w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-01-15", "2w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-02-15", "6w", 'z-score', 'i', -4.54],
		["fb1", "1920-02-15", "6w", 'z-score category', 's', 'SGA'],
		["fb1", "1920-02-15", "6w", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-04-01", "3m", 'z-score', 'i', -5.8],
		["fb1", "1920-04-01", "3m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-04-01", "3m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-07-01", "6m", 'z-score', 'i', -6.91],
		["fb1", "1920-07-01", "6m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-07-01", "6m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1920-10-01", "9m", 'z-score', 'i', -7.23],
		["fb1", "1920-10-01", "9m", 'z-score category', 's', 'SGA'],
		["fb1", "1920-10-01", "9m", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-01-01", "1y", 'z-score', 'i', -7.33],
		["fb1", "1921-01-01", "1y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-01-01", "1y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1921-07-01", "1.5y", 'z-score', 'i', -6.05],
		["fb1", "1921-07-01", "1.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1921-07-01", "1.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-01-01", "2y", 'z-score', 'i', -5.53],
		["fb1", "1922-01-01", "2y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-01-01", "2y", 'z-score subcategory', 's', 'no catch-up'],
		["fb1", "1922-07-01", "2.5y", 'z-score', 'i', -5.04],
		["fb1", "1922-07-01", "2.5y", 'z-score category', 's', 'SGA'],
		["fb1", "1922-07-01", "2.5y", 'z-score subcategory', 's', 'no catch-up'],
		["fb2", "1921-02-02", "meconium", 'category of difference in body mass at delivery', 's', 'not enough'],
		["fb2", "1921-02-02", "meconium", 'difference in body mass at delivery', 'i', 5],
		["fb2", "1921-02-02", "meconium", 'mother\'s age at delivery', 'i', '20.00'],
		["fb2", "1921-02-02", "meconium", 'mother\'s pre-pregnancy BMI', 'i', 19.53],
		["fb2", "1921-02-02", "meconium", "mother\'s pre-pregnancy BMI category", 's', "normal weight"],
		["fb2", "1921-02-02", "meconium", 'z-score', 'i', -0.52],
		["fb2", "1921-02-02", "meconium", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-02", "meconium", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score', 'i', -0.07],
		["fb2", "1921-02-05", "3d", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-05", "3d", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score', 'i', -0.34],
		["fb2", "1921-02-16", "2w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-02-16", "2w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score', 'i', -1.77],
		["fb2", "1921-03-16", "6w", 'z-score category', 's', 'AGA'],
		["fb2", "1921-03-16", "6w", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score', 'i', -3.29],
		["fb2", "1921-05-02", "3m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-05-02", "3m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score', 'i', -4.66],
		["fb2", "1921-08-02", "6m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-08-02", "6m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score', 'i', -5.18],
		["fb2", "1921-11-02", "9m", 'z-score category', 's', 'AGA'],
		["fb2", "1921-11-02", "9m", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score', 'i', -5.44],
		["fb2", "1922-02-02", "1y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-02-02", "1y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score', 'i', -5.06],
		["fb2", "1922-08-02", "1.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1922-08-02", "1.5y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score', 'i', -4.72],
		["fb2", "1923-02-02", "2y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-02-02", "2y", 'z-score subcategory', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score', 'i', -4.37],
		["fb2", "1923-08-02", "2.5y", 'z-score category', 's', 'AGA'],
		["fb2", "1923-08-02", "2.5y", 'z-score subcategory', 's', 'AGA']
	];			
	my $expecSeqClassR = [];
	# id_change: patient, sample, measurement, type
	my $expecChangeR = [
		[1, 1, 1, 1],
		[1, 1, undef, undef] # control sample without measurement/type
	];
	my $expecChange_updatedR = [
		[1, 1, 1, 1],
		[1, 1, 2, 1],
		[1, 1, undef, undef] # control sample without measurement/type
	];
	my $expecChange_updatedPatR = [
		[1, 1, 1, 1],
		[1, 1, undef, undef], # control sample without measurement/type,
		[2, 2, 2, 1],
		[2, 2, undef, undef] # control sample without measurement/type
	];
	my $expecChange_updatedSamplR = [
		[1, 1, 1, 1],
		[1, 1, undef, undef], # control sample without measurement/type,
		[1, 2, 2, 1],
		[1, 2, undef, undef] # control sample without measurement/type
	];
	my $expecChange_addMeasureR = [
		[1, 1, 1, 1],
		[1, 1, 2, 1],
		[1, 1, undef, undef], # control sample without measurement/type,
	];
	
	my $testF = "./data/spreadsheets/test_SGA.xlsx";
	my $testF_noRunBar = "./data/spreadsheets/test_SGA_noRunBar.xlsx";
	my $testF_noRunBar_onePat = "./data/spreadsheets/test_SGA_noRunBar_onePat.xlsx";
	my $testF_noRunBar_oneSampl = "./data/spreadsheets/test_SGA_noRunBar_oneSampl.xlsx";
	# Lacking the 3y-sample for the first patient.
	my $testF_noRunBar_oneSamplLess = "./data/spreadsheets/test_SGA_noRunBar_oneSamplLess.xlsx";
	my $testF_noRunBar_noFirst = "./data/spreadsheets/test_SGA_noRunBar_noFirst.xlsx";
	my $testF_noRunBar_addMeasure = "./data/spreadsheets/test_SGA_noRunBar_addMeasure.xlsx";
	

	#------------------------------------------------------------------------------#
	# Fresh insert from XLSX without run and barcode and no data in basePath
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqClassR = "";
		$resChangeR = "";
		
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqClassR = $dbh->selectall_arrayref(
			"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
				"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
		);
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok(1==2, 'Testing no run and barcode');
	}
	finally {
		is ($err, "", 'Testing no run and barcode - error msg');
		is ($resChangeR, $expecChangeR, 'Testing no run and barcode - any new data inserted?');
		is ($resR, $expecMeasureR, 'Testing no run and barcode - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing no run and barcode - derived measurements');
		is ($resSeqClassR, $expecSeqClassR, 'Testing no run and barcode - sequences and classifications')
	};
	
	
	#------------------------------------------------------------------------------#
	# Ignore old data when inserting full Excel, Excel with all samples for
	# patient, Excel with one selected sample for one patient.
	#------------------------------------------------------------------------------#
	my @runs = (
		[$testF_noRunBar, 'full file'],
		[$testF_noRunBar_onePat, 'one patient'],
		[$testF_noRunBar_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Always initialize with full data
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
			$expecChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Ignore insert of data that is already present in the database
		# => id_change indicates version of data --> should be the same
		# => there should not be duplicates of records
		# => records should contain the same data
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
						
			# This insert should do nothing, as data is identical to old data
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert --> should not have changed!
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc , s.id_change asc, m.id_change asc, t.id_change asc"
			);
			
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok(1==2, 'Testing insert old data with ->' . $name . '<-');
		}
		finally {
			is ($err, "", 'Testing insert old data with ->' . $name . '<- - error msg');
			is ($resChangeR, $expecChangeR, 'Testing insert old data ->' . $name . '<- - updated?');
			is ($resR, $expecMeasureR, 'Testing insert old data ->' . $name . '<- - measurements');
			is ($resDerivedR, $expecDerivedR, 'Testing insert old data ->' . $name . '<- - derived measurements');
			is ($resSeqClassR, $expecSeqClassR, 'Testing insert old data ->' . $name . '<- - sequences and classifications')
		};
	}
	
	
	#------------------------------------------------------------------------------#
	# Ignore old data and update new when inserting full Excel, Excel with all
	# samples for patient, Excel with one selected sample for one patient.
	#------------------------------------------------------------------------------#
	my $testF_noRunBar_update = "./data/spreadsheets/test_SGA_noRunBar_updateMod.xlsx";
	my $testF_noRunBar_update_onePat = "./data/spreadsheets/test_SGA_noRunBar_updateMod_onePat.xlsx";
	my $testF_noRunBar_update_oneSampl = "./data/spreadsheets/test_SGA_noRunBar_updateMod_oneSampl.xlsx";
	
	@runs = (
		[$testF_noRunBar_update, 'full file'],
		[$testF_noRunBar_update_onePat, 'one patient'],
		[$testF_noRunBar_update_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Always initialize with full data (not updated)
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Ignore old data, but update changed records
		# => id_change indicates version of data --> should have change for measurement
		# => update changed records
		# => there should be no duplicates of records
		# => existing records should not have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
			
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert, but data should not have changed.
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok(1==2, 'Testing update with ->' . $name . '<-');
		}
		finally {
			is ($err, "", 'Testing update with ->' . $name . '<- - error msg');
			is ($resChangeR, $expecChange_updatedR, 'Testing update ->' . $name . '<- - updated?');
			is ($resR, $expecMeasure_updatedR, 'Testing update ->' . $name . '<- - measurements');
			is ($resDerivedR, $expecDerived_updatedR, 'Testing update ->' . $name . '<- - derived measurements');
			is ($resSeqClassR, $expecSeqClassR, 'Testing update ->' . $name . '<- - sequences and classifications');
		};
	}
	

	#------------------------------------------------------------------------------#
	# Ignore updates that only affect derived columns in Excel (these columns are
	# calculated on the fly) when inserting full Excel, Excel with all samples for
	# patient, Excel with one selected sample for one patient.
	#------------------------------------------------------------------------------#
	$testF_noRunBar_update = "./data/spreadsheets/test_SGA_noRunBar_updateDerived.xlsx";
	$testF_noRunBar_update_onePat = "./data/spreadsheets/test_SGA_noRunBar_updateDerived_onePat.xlsx";
	$testF_noRunBar_update_oneSampl = "./data/spreadsheets/test_SGA_noRunBar_updateDerived_oneSampl.xlsx";
	
	@runs = (
		[$testF_noRunBar_update, 'full file'],
		[$testF_noRunBar_update_onePat, 'one patient'],
		[$testF_noRunBar_update_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Initialize with full data (not updated)
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
			$expecChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Ignore changes in Excel that only affect the derived columns
		# => id_change indicates version of data --> should not change
		# => there should be no duplicates of records
		# => records should not have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
			
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert --> should not have changed!
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok(1==2, 'Testing ignore update with ->' . $name . '<-');
		}
		finally {
			is ($err, "", 'Testing ignore update with ->' . $name . '<- - error msg');
			is ($resChangeR, $expecChangeR, 'Testing ignore update with ->' . $name . '<- - updated?');
			is ($resR, $expecMeasureR, 'Testing ignore update with ->' . $name . '<- - measurements');
			is ($resDerivedR, $expecDerivedR, 'Testing ignore update with ->' . $name . '<- - derived measurements');
			is ($resSeqClassR, $expecSeqClassR, 'Testing ignore update with ->' . $name . '<- - sequences and classifications');
		};
	}
	
	
	#------------------------------------------------------------------------------#
	# Attempt to update unique columns --> interpreted as new record when
	# inserting full Excel, Excel with all samples for patient, Excel with one
	# selected sample for one patient.
	# These tests also verify the deliberate addition of patients/samples in the
	# Excel file.
	#------------------------------------------------------------------------------#
	
	# 1) patient alias
	$testF_noRunBar_update = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_patAlias.xlsx";
	$testF_noRunBar_update_onePat = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_patAlias_onePat.xlsx";
	$testF_noRunBar_update_oneSampl = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_patAlias_oneSampl.xlsx";
	
	@runs = (
		[$testF_noRunBar_update, 'full file'],
		[$testF_noRunBar_update_onePat, 'one patient'],
		[$testF_noRunBar_update_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Initialize with full data (not updated)
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Create a new patient with samples
		# => id_change indicates version of data --> should change
		# => there should be no duplicates of records
		# => existing records should not have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
			
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by alias asc, accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok(1==2, '"Update" patient alias with ->' . $name . '<-');
		}
		finally {
			is ($err, "", '"Update" patient alias with ->' . $name . '<- - error msg');
			is ($resChangeR, $expecChange_updatedPatR, '"Update" patient alias with ->' . $name . '<- - updated?');
			if ($name ne "one sample") {
				is ($resR, $expecMeasure_updatedPatR, '"Update" patient alias with ->' . $name . '<- - measurements');
				is ($resDerivedR, $expecDerived_updatedPatR, '"Update" patient alias with ->' . $name . '<- - derived measurements');
			}
			else {
				is ($resR, $expecMeasure_updatedPat_oneSamplR, '"Update" patient alias with ->' . $name . '<- - measurements');
				is ($resDerivedR, $expecDerived_updatedPat_oneSamplR, '"Update" patient alias with ->' . $name . '<- - derived measurements');
			}
			is ($resSeqClassR, $expecSeqClassR, '"Update" patient alias with ->' . $name . '<- - sequences and classifications');
		
		};
	}
	
	
	# 2) hospital code
	$testF_noRunBar_update = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_patHcode.xlsx";
	$testF_noRunBar_update_onePat = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_patHcode_onePat.xlsx";
	$testF_noRunBar_update_oneSampl = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_patHcode_oneSampl.xlsx";
	
	# Adjust the expectations
	my $tmp_measureR = dclone($expecMeasure_updatedPatR);
	my $tmp_derivedR = dclone($expecDerived_updatedPatR);
	my $tmp_measure_oneSamplR = dclone($expecMeasure_updatedPat_oneSamplR);
	my $tmp_derived_oneSamplR = dclone($expecDerived_updatedPat_oneSamplR);
	# Rename "BarFoo1" --> "FooBar1" and "fb1" --> "bf1"
	foreach my $elem (@{$tmp_measureR}) {
		if ($elem->[0] eq "FarBoo1") {
			$elem->[0] = "Foobar1";
			$elem->[1] = "bf1";
		}	
	}
	# Rename every second element of "fb1" to "bf1"
	my $i = 0;
	foreach my $elem (@{$tmp_derivedR}) {
		if ($elem->[0] eq "fb1") {
			if ($i % 2 == 0) {
				$elem->[0] = "bf1";
			}
			$i++;
		}
	}
	my @tmps = sort {
		lc($a->[0])	cmp	lc($b->[0])	or
		lc($a->[1])	cmp	lc($b->[1])	or
		lc($a->[3])	cmp	lc($b->[3])
	} @{$tmp_derivedR};
	$tmp_derivedR = dclone(\@tmps);
	
	# Rename "BarFoo1" --> "FooBar1" and "fb1" --> "bf1"
	foreach my $elem (@{$tmp_measure_oneSamplR}) {
		if ($elem->[0] eq "FarBoo1") {
			$elem->[0] = "Foobar1";
			$elem->[1] = "bf1";
		}	
	}
	# Rename every second element of "fb1" at timepoint "meconium" to "bf1"
	$i = 0;
	foreach my $elem (@{$tmp_derived_oneSamplR}) {
		if ($elem->[0] eq "fb1" and $elem->[2] eq "meconium") {
			if ($i % 2 == 0) {
				$elem->[0] = "bf1";
			}
			$i++;
		}
	}
	@tmps = sort {
		lc($a->[0])	cmp	lc($b->[0])	or
		lc($a->[1])	cmp	lc($b->[1])	or
		lc($a->[3])	cmp	lc($b->[3])
	} @{$tmp_derived_oneSamplR};
	$tmp_derived_oneSamplR = dclone(\@tmps);
	
	@runs = (
		[$testF_noRunBar_update, 'full file'],
		[$testF_noRunBar_update_onePat, 'one patient'],
		[$testF_noRunBar_update_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Initialize with full data (not updated)
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Create a new patient with samples
		# => id_change indicates version of data --> should change
		# => there should be no duplicates of records
		# => existing records should not have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
			
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by alias asc, accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok(1==2, '"Update" patient hospital code with ->' . $name . '<-');
		}
		finally {
			is ($err, "", '"Update" patient hospital code with ->' . $name . '<- - error msg');
			is ($resChangeR, $expecChange_updatedPatR, '"Update" patient hospital code with ->' . $name . '<- - updated?');
			if ($name ne "one sample") {
				is ($resR, $tmp_measureR, '"Update" patient hospital code with ->' . $name . '<- - measurements');
				is ($resDerivedR, $tmp_derivedR, '"Update" patient hospital code with ->' . $name . '<- - derived measurements');
			}
			else {
				is ($resR, $tmp_measure_oneSamplR, '"Update" patient hospital code with ->' . $name . '<- - measurements');
				is ($resDerivedR, $tmp_derived_oneSamplR, '"Update" patient hospital code with ->' . $name . '<- - derived measurements');
			}	
			is ($resSeqClassR, $expecSeqClassR, '"Update" patient hospital code with ->' . $name . '<- - sequences and classifications');
		};
	}
	
	
	# 3) patient birth date
	$testF_noRunBar_update = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_patBdate.xlsx";
	$testF_noRunBar_update_onePat = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_patBdate_onePat.xlsx";
	$testF_noRunBar_update_oneSampl = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_patBdate_oneSampl.xlsx";
	
	# Adjust the expectations
	$tmp_measureR = dclone($expecMeasure_updatedPatR);
	$tmp_derivedR = dclone($expecDerived_updatedPatR);
	$tmp_measure_oneSamplR = dclone($expecMeasure_updatedPat_oneSamplR);
	$tmp_derived_oneSamplR = dclone($expecDerived_updatedPat_oneSamplR);
	# Rename "BarFoo1" --> "FooBar1" and set birthdate to "1919-12-31"
	# Decrease all sampling dates for this patient by one
	# --> derived measures are not altered
	foreach my $elem (@{$tmp_measureR}) {
		if ($elem->[0] eq "FarBoo1") {
			$elem->[0] = "Foobar1";
			$elem->[2] = '1919-12-31';
			# decrease sampling date by one
			my $dt = DateTime::Format::ISO8601->parse_datetime($elem->[3]);
			$dt = $dt - DateTime::Duration->new(days => 1);
			$elem->[3] = $dt->ymd('-')
		}	
	}

	# Change sampling date of every second element
	$i = 0;
	foreach my $elem (@{$tmp_derivedR}) {
		if ($elem->[0] eq "fb1") {
			if ($i % 2 == 0) {
				# decrease sampling date by one
				my $dt = DateTime::Format::ISO8601->parse_datetime($elem->[1]);
				$dt = $dt - DateTime::Duration->new(days => 1);
				$elem->[1] = $dt->ymd('-')
			}
			$i++;
		}
	}
	@tmps = sort {
		lc($a->[0])	cmp	lc($b->[0])	or
		lc($a->[1])	cmp	lc($b->[1])	or
		lc($a->[3])	cmp	lc($b->[3])
	} @{$tmp_derivedR};
	$tmp_derivedR = dclone(\@tmps);
	
	# Rename "BarFoo1" --> "FooBar1" and set birthdate to "1919-12-31"
	# Decrease all sampling dates for this patient by one
	# --> derived measures are not altered
	foreach my $elem (@{$tmp_measure_oneSamplR}) {
		if ($elem->[0] eq "FarBoo1") {
			$elem->[0] = "Foobar1";
			$elem->[2] = '1919-12-31';
			# decrease sampling date by one
			my $dt = DateTime::Format::ISO8601->parse_datetime($elem->[3]);
			$dt = $dt - DateTime::Duration->new(days => 1);
			$elem->[3] = $dt->ymd('-')
		}	
	}
	
	# Change sampling date of every second element
	$i = 0;
	foreach my $elem (@{$tmp_derived_oneSamplR}) {
		if ($elem->[0] eq "fb1" and $elem->[2] eq "meconium") {
			if ($i % 2 == 0) {
				# decrease sampling date by one
				my $dt = DateTime::Format::ISO8601->parse_datetime($elem->[1]);
				$dt = $dt - DateTime::Duration->new(days => 1);
				$elem->[1] = $dt->ymd('-')
			}
			$i++;
		}
	}
	@tmps = sort {
		lc($a->[0])	cmp	lc($b->[0])	or
		lc($a->[1])	cmp	lc($b->[1])	or
		lc($a->[3])	cmp	lc($b->[3])
	} @{$tmp_derived_oneSamplR};
	$tmp_derived_oneSamplR = dclone(\@tmps);
	
	@runs = (
		[$testF_noRunBar_update, 'full file'],
		[$testF_noRunBar_update_onePat, 'one patient'],
		[$testF_noRunBar_update_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Initialize with full data (not updated)
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Create a new patient with samples
		# => id_change indicates version of data --> should change
		# => there should be no duplicates of records
		# => existing records should not have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
			
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by alias asc, accession asc, birthdate asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok(1==2, '"Update" patient birth date with ->' . $name . '<-');
		}
		finally {
			is ($err, "", '"Update" patient birth date with ->' . $name . '<- - error msg');
			is ($resChangeR, $expecChange_updatedPatR, '"Update" patient birth date with ->' . $name . '<- - updated?');
			if ($name ne "one sample") {
				is ($resR, $tmp_measureR, '"Update" patient birth date with ->' . $name . '<- - measurements');
				is ($resDerivedR, $tmp_derivedR, '"Update" patient birth date with ->' . $name . '<- - derived measurements');
			}
			else {
				is ($resR, $tmp_measure_oneSamplR, '"Update" patient birth date with ->' . $name . '<- - measurements');
				is ($resDerivedR, $tmp_derived_oneSamplR, '"Update" patient birth date with ->' . $name . '<- - derived measurements');
			}	
			is ($resSeqClassR, $expecSeqClassR, '"Update" patient birth date with ->' . $name . '<- - sequences and classifications');
		};
	}
	
	
	# 4) sample createdate => Leads to fresh insert of a sample, if the timepoint did not exist, yet
	$testF_noRunBar_update = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_sampleCdate.xlsx";
	$testF_noRunBar_update_onePat = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_sampleCdate_onePat.xlsx";
	$testF_noRunBar_update_oneSampl = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_sampleCdate_oneSampl.xlsx";
	
	@runs = (
		[$testF_noRunBar_update, 'full file'],
		[$testF_noRunBar_update_onePat, 'one patient'],
		[$testF_noRunBar_update_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Initialize with full data (not updated)
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar_oneSamplLess --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Change a sample for existing patient (the new timepoint does not
		# exist, yet)
		# => id_change indicates version of data --> should change
		# => there should be no duplicates of records
		# => existing records should not have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
			
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by alias asc, accession asc, birthdate asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok(1==2, '"Update" sample createdate with ->' . $name . '<-');
		}
		finally {
			is ($err, "", '"Update" sample createdate with ->' . $name . '<- - error msg');
			is ($resChangeR, $expecChange_updatedSamplR, '"Update" sample createdate with ->' . $name . '<- - updated?');
			is ($resR, $expecMeasure_updatedSamplR, '"Update" sample createdate with ->' . $name . '<- - measurements');
			is ($resDerivedR, $expecDerived_updatedSamplR, '"Update" sample createdate with ->' . $name . '<- - derived measurements');
			is ($resSeqClassR, $expecSeqClassR, '"Update" sample createdate with ->' . $name . '<- - sequences and classifications');
		};
	}
	
	
	# 5) sample create date: ERROR, if timepoint for the same patient already exists
	$testF_noRunBar_update = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_sampleCdate2.xlsx";
	$testF_noRunBar_update_onePat = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_sampleCdate2_onePat.xlsx";
	$testF_noRunBar_update_oneSampl = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_sampleCdate2_oneSampl.xlsx";
	
	@runs = (
		[$testF_noRunBar_update, 'full file'],
		[$testF_noRunBar_update_onePat, 'one patient'],
		[$testF_noRunBar_update_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Initialize with full data (not updated)
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Change a sample for existing patient (the new timepoint exists already)
		# => ERROR
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
			
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by alias asc, accession asc, birthdate asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);			
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
		}
		finally {
			ok ($err =~ m/Timepoint ->3y<-.*is invalid or not unique/, '"Update" sample createdate with ->' . $name . '<-, but timepoint exists - error msg');
			# No addition to first successful insert
			is ($resChangeR, $expecChangeR, '"Update" sample createdate with ->' . $name . '<-, but timepoint exists - updated?');
			is ($resR, $expecMeasureR, '"Update" sample createdate with ->' . $name . '<-, but timepoint exists - measurements');
			is ($resDerivedR, $expecDerivedR, '"Update" sample createdate with ->' . $name . '<-, but timepoint exists - derived measurements');
			is ($resSeqClassR, $expecSeqClassR, '"Update" sample createdate with ->' . $name . '<-, but timepoint exists - sequences and classifications');
		};
	}
	
	
	# 6) sample create date: ERROR, if attempting to add a new first sample for patient,
	# due to issues with static measurements that are assigned to first sample for patient.
	$testF_noRunBar_update = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_sampleCdate3.xlsx";
	$testF_noRunBar_update_onePat = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_sampleCdate3_onePat.xlsx";
	$testF_noRunBar_update_oneSampl = "./data/spreadsheets/test_SGA_noRunBar_updateUniq_sampleCdate3_oneSampl.xlsx";
		
	@runs = (
		[$testF_noRunBar_update, 'full file'],
		[$testF_noRunBar_update_onePat, 'one patient'],
		[$testF_noRunBar_update_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Initialize with full data lacking the meconium sample (sample at birth)
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar_noFirst --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Add meconium sample for existing patient --> taken earlier than any
		# sample for the patient in the database.
		# => ERROR
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
			
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by alias asc, accession asc, birthdate asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);			
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
		}
		finally {
			ok ($err =~ m/ERROR.*Not possible to set a new first date for patient/, '"Update" sample createdate with ->' . $name . '<- to create new first sample - error msg');
			# No addition to first successful insert --> meconium sample is missing
			is ($resChangeR, $expecChangeR, '"Update" sample createdate with ->' . $name . '<- to create new first sample - updated?');
			is ($resR, $expecMeasure_noMecR, '"Update" sample createdate with ->' . $name . '<- to create new first sample - measurements');
			is ($resDerivedR, $expecDerived_noMecR, '"Update" sample createdate with ->' . $name . '<- to create new first sample - derived measurements');
			is ($resSeqClassR, $expecSeqClassR, '"Update" sample createdate with ->' . $name . '<- to create new first sample - sequences and classifications');
		};
	}
	
	
	#------------------------------------------------------------------------------#
	# Add measurement values for samples that had no value before
	# => internally: INSERT
	#------------------------------------------------------------------------------#
	$testF_noRunBar_update = "./data/spreadsheets/test_SGA_noRunBar_addMeasure.xlsx";
	$testF_noRunBar_update_onePat = "./data/spreadsheets/test_SGA_noRunBar_addMeasure_onePat.xlsx";
	$testF_noRunBar_update_oneSampl = "./data/spreadsheets/test_SGA_noRunBar_addMeasure_oneSampl.xlsx";
	
	@runs = (
		[$testF_noRunBar_update, 'full file'],
		[$testF_noRunBar_update_onePat, 'one patient'],
		[$testF_noRunBar_update_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Initialize with full data (not updated)
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Add measurement value to measure that was previously empty
		# => id_change indicates version of data --> should change
		# => there should be no duplicates of records
		# => existing records should not have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
			
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by alias asc, accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok(1==2, 'Add a measurement with ->' . $name . '<-');
		}
		finally {
			is ($err, "", 'Add a measurement with ->' . $name . '<- - error msg');
			is ($resChangeR, $expecChange_addMeasureR, 'Add a measurement with ->' . $name . '<- - updated?');
			is ($resR, $expecMeasure_addMeasureR, 'Add a measurement with ->' . $name . '<- - measurements');
			is ($resDerivedR, $expecDerived_addMeasureR, 'Add a measurement with ->' . $name . '<- - derived measurements');
			is ($resSeqClassR, $expecSeqClassR, 'Add a measurement with ->' . $name . '<- - sequences and classifications');
		
		};
	}
	
	
	#------------------------------------------------------------------------------#
	# Empty a measurement that had a value before
	# => internally: DELETE => not allowed => data does not change!
	# => not what users expect!
	#------------------------------------------------------------------------------#
	$testF_noRunBar_update = "./data/spreadsheets/test_SGA_noRunBar.xlsx";
	$testF_noRunBar_update_onePat = "./data/spreadsheets/test_SGA_noRunBar_onePat.xlsx";
	$testF_noRunBar_update_oneSampl = "./data/spreadsheets/test_SGA_noRunBar_oneSampl.xlsx";
	
	@runs = (
		[$testF_noRunBar_update, 'full file'],
		[$testF_noRunBar_update_onePat, 'one patient'],
		[$testF_noRunBar_update_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Initialize with full data (not updated)
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar_addMeasure --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Attempt to empty a measurement value
		# => internally interpreted as delete => ignored
		# => id_change indicates version of data --> should not change
		# => nothing should have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
			
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by alias asc, accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok(1==2, 'Emptying a measurement with ->' . $name . '<- does not work');
		}
		finally {
			is ($err, "", 'Emptying a measurement with ->' . $name . '<- does not work - error msg');
			is ($resChangeR, $expecChangeR, 'Emptying a measurement with ->' . $name . '<- does not work - updated?');
			is ($resR, $expecMeasure_addMeasureR, 'Emptying a measurement with ->' . $name . '<- does not work - measurements');
			is ($resDerivedR, $expecDerived_addMeasureR, 'Emptying a measurement with ->' . $name . '<- does not work - derived measurements');
			is ($resSeqClassR, $expecSeqClassR, 'Emptying a measurement with ->' . $name . '<- does not work - sequences and classifications');
		
		};
	}
	

	#------------------------------------------------------------------------------#
	# Attempt to add a new patient without any sample
	#------------------------------------------------------------------------------#
	$testF_noRunBar_update = "./data/spreadsheets/test_SGA_noRunBar_newPat.xlsx";
	$testF_noRunBar_update_onePat = "./data/spreadsheets/test_SGA_noRunBar_newPat_onePat.xlsx";
	
	@runs = (
		[$testF_noRunBar_update, 'full file'],
		[$testF_noRunBar_update_onePat, 'one patient'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Initialize with full data (not updated)
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null  \\ 
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Attempt to add a new patient without any sample
		# => ERROR
		#------------------------------------------------------------------------------#
		try {
			$resR = "";
			$resDerivedR = "";
			$resSeqClassR = "";
			$resChangeR = "";
			
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by alias asc, accession asc, birthdate asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqClassR = $dbh->selectall_arrayref(
				"select * from sequence seq full outer join classification c on seq.id = c.id_sequence " .
					"full outer join taxclass tc on tc.id_classification = c.id full outer join taxonomy t on t.id = tc.id_taxonomy"
			);
			
			# Change of id_change signals a new insert
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id group by p.id_change, ".
				"s.id_change, m.id_change, t.id_change order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
		}
		finally {
			ok ($err =~ m/ERROR.*No date/, 'Attempt to add a new patient without any sample with ->' . $name . '<- - error msg');
			# No addition to first successful insert
			is ($resChangeR, $expecChangeR, 'Attempt to add a new patient without any sample with ->' . $name . '<- - updated?');
			is ($resR, $expecMeasureR, 'Attempt to add a new patient without any sample with ->' . $name . '<- - measurements');
			is ($resDerivedR, $expecDerivedR, 'Attempt to add a new patient without any sample with ->' . $name . '<- - derived measurements');
			is ($resSeqClassR, $expecSeqClassR, 'Attempt to add a new patient without any sample with ->' . $name . '<- - sequences and classifications');
		};
	}

	
	return $expecMeasureR, $expecDerivedR;
};


#
#--------------------------------------------------------------------------------------------------#
# Test to insert/update sequences (taxonomy not tested)
#--------------------------------------------------------------------------------------------------#
#
sub test_seqs {
	my $dbh = $_[0];
	my $schema = $_[1];
	my $basePath = $_[2];
	my $randDir = $_[3];
	my $expecMeasureR = $_[4];
	my $expecDerivedR = $_[5];
	
	my $err = "";
	my $resR = "";
	my $resDerivedR = "";
	my $resSeqR = "";
	my $resChangeR = "";
	
	# Control sample sequences inserted for every case sample
	# alias, accession, birthdate, createdate, iscontrol, readid, runid, barcode, flowcellid, callermodel,
	# nucs, quality, seqerr, seqlen
	my $expecSeqR = [
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 'f', '10_1_1', '10', '1', 'flowcell', 'basecaller', 'GTAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 'f', '10_1_2', '10', '1', 'flowcell', 'basecaller', 'GTAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1923-02-02', 'f', '10_2_1', '10', '2', 'flowcell', 'basecaller', 'GTAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1923-02-02', 'f', '10_2_2', '10', '2', 'flowcell', 'basecaller', 'GTATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 't', '10_99_1', '10', '99', 'flowcell', 'basecaller', 'GTCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1923-02-02', 't', '10_99_1', '10', '99', 'flowcell', 'basecaller', 'GTCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 't', '10_99_2', '10', '99', 'flowcell', 'basecaller', 'GTCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1923-02-02', 't', '10_99_2', '10', '99', 'flowcell', 'basecaller', 'GTCCA', '!!!!!', 1, 5],		
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 'f', '11_1_1', '11', '1', 'flowcell', 'basecaller', 'GGAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 'f', '11_1_2', '11', '1', 'flowcell', 'basecaller', 'GGAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1923-08-02', 'f','11_2_1', '11', '2', 'flowcell', 'basecaller', 'GGAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1923-08-02', 'f','11_2_2', '11', '2', 'flowcell', 'basecaller', 'GGATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 't', '11_99_1', '11', '99', 'flowcell', 'basecaller', 'GGCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1923-08-02', 't', '11_99_1', '11', '99', 'flowcell', 'basecaller', 'GGCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 't', '11_99_2', '11', '99', 'flowcell', 'basecaller', 'GGCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1923-08-02', 't', '11_99_2', '11', '99', 'flowcell', 'basecaller', 'GGCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 'f', '1_1_1', '1', '1', 'flowcell', 'basecaller', 'AAAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 'f', '1_1_2', '1', '1', 'flowcell', 'basecaller', 'AAAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-02', 'f', '1_2_1', '1', '2', 'flowcell', 'basecaller', 'AAAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-02', 'f', '1_2_2', '1', '2', 'flowcell', 'basecaller', 'AAATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 't', '1_99_1', '1', '99', 'flowcell', 'basecaller', 'AACC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-02', 't', '1_99_1', '1', '99', 'flowcell', 'basecaller', 'AACC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 't', '1_99_2', '1', '99', 'flowcell', 'basecaller', 'AACCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-02', 't', '1_99_2', '1', '99', 'flowcell', 'basecaller', 'AACCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 'f', '2_1_1', '2', '1', 'flowcell', 'basecaller', 'ATAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 'f', '2_1_2', '2', '1', 'flowcell', 'basecaller', 'ATAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-05', 'f', '2_2_1', '2', '2', 'flowcell', 'basecaller', 'ATAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-05', 'f', '2_2_2', '2', '2', 'flowcell', 'basecaller', 'ATATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 't', '2_99_1', '2', '99', 'flowcell', 'basecaller', 'ATCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-05', 't','2_99_1', '2', '99', 'flowcell', 'basecaller', 'ATCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 't', '2_99_2', '2', '99', 'flowcell', 'basecaller', 'ATCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-05', 't','2_99_2', '2', '99', 'flowcell', 'basecaller', 'ATCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 'f', '3_1_1', '3', '1', 'flowcell', 'basecaller', 'AGAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 'f', '3_1_2', '3', '1', 'flowcell', 'basecaller', 'AGAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-16', 'f', '3_2_1', '3', '2', 'flowcell', 'basecaller', 'AGAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-16', 'f', '3_2_2', '3', '2', 'flowcell', 'basecaller', 'AGATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 't', '3_99_1', '3', '99', 'flowcell', 'basecaller', 'AGCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-16', 't', '3_99_1', '3', '99', 'flowcell', 'basecaller', 'AGCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 't', '3_99_2', '3', '99', 'flowcell', 'basecaller', 'AGCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-16', 't', '3_99_2', '3', '99', 'flowcell', 'basecaller', 'AGCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 'f', '4_1_1', '4', '1', 'flowcell', 'basecaller', 'ACAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 'f', '4_1_2', '4', '1', 'flowcell', 'basecaller', 'ACAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-03-16', 'f', '4_2_1', '4', '2', 'flowcell', 'basecaller', 'ACAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-03-16', 'f', '4_2_2', '4', '2', 'flowcell', 'basecaller', 'ACATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 't', '4_99_1', '4', '99', 'flowcell', 'basecaller', 'ACCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-03-16', 't', '4_99_1', '4', '99', 'flowcell', 'basecaller', 'ACCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 't', '4_99_2', '4', '99', 'flowcell', 'basecaller', 'ACCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-03-16', 't', '4_99_2', '4', '99', 'flowcell', 'basecaller', 'ACCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 'f', '5_1_1', '5', '1', 'flowcell', 'basecaller', 'TAAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 'f', '5_1_2', '5', '1', 'flowcell', 'basecaller', 'TAAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-05-02', 'f', '5_2_1', '5', '2', 'flowcell', 'basecaller', 'TAAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-05-02', 'f', '5_2_2', '5', '2', 'flowcell', 'basecaller', 'TAATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 't', '5_99_1', '5', '99', 'flowcell', 'basecaller', 'TACC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-05-02', 't', '5_99_1', '5', '99', 'flowcell', 'basecaller', 'TACC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 't', '5_99_2', '5', '99', 'flowcell', 'basecaller', 'TACCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-05-02', 't', '5_99_2', '5', '99', 'flowcell', 'basecaller', 'TACCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 'f', '6_1_1', '6', '1', 'flowcell', 'basecaller', 'TTAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 'f', '6_1_2', '6', '1', 'flowcell', 'basecaller', 'TTAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-08-02', 'f', '6_2_1', '6', '2', 'flowcell', 'basecaller', 'TTAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-08-02', 'f', '6_2_2', '6', '2', 'flowcell', 'basecaller', 'TTATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 't', '6_99_1', '6', '99', 'flowcell', 'basecaller', 'TTCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-08-02', 't', '6_99_1', '6', '99', 'flowcell', 'basecaller', 'TTCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 't', '6_99_2', '6', '99', 'flowcell', 'basecaller', 'TTCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-08-02', 't', '6_99_2', '6', '99', 'flowcell', 'basecaller', 'TTCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 'f', '7_1_1', '7', '1', 'flowcell', 'basecaller', 'TGAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 'f', '7_1_2', '7', '1', 'flowcell', 'basecaller', 'TGAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-11-02', 'f', '7_2_1', '7', '2', 'flowcell', 'basecaller', 'TGAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-11-02', 'f', '7_2_2', '7', '2', 'flowcell', 'basecaller', 'TGATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 't', '7_99_1', '7', '99', 'flowcell', 'basecaller', 'TGCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-11-02', 't', '7_99_1', '7', '99', 'flowcell', 'basecaller', 'TGCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 't', '7_99_2', '7', '99', 'flowcell', 'basecaller', 'TGCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-11-02', 't', '7_99_2', '7', '99', 'flowcell', 'basecaller', 'TGCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 'f', '8_1_1', '8', '1', 'flowcell', 'basecaller', 'TCAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 'f', '8_1_2', '8', '1', 'flowcell', 'basecaller', 'TCAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1922-02-02', 'f', '8_2_1', '8', '2', 'flowcell', 'basecaller', 'TCAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1922-02-02', 'f', '8_2_2', '8', '2', 'flowcell', 'basecaller', 'TCATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 't', '8_99_1', '8', '99', 'flowcell', 'basecaller', 'TCCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1922-02-02', 't', '8_99_1', '8', '99', 'flowcell', 'basecaller', 'TCCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 't', '8_99_2', '8', '99', 'flowcell', 'basecaller', 'TCCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1922-02-02', 't', '8_99_2', '8', '99', 'flowcell', 'basecaller', 'TCCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 'f', '9_1_1', '9', '1', 'flowcell', 'basecaller', 'GAAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 'f', '9_1_2', '9', '1', 'flowcell', 'basecaller', 'GAAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1922-08-02', 'f', '9_2_1', '9', '2', 'flowcell', 'basecaller', 'GAAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1922-08-02', 'f','9_2_2', '9', '2', 'flowcell', 'basecaller', 'GAATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 't', '9_99_1', '9', '99', 'flowcell', 'basecaller', 'GACC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1922-08-02', 't', '9_99_1', '9', '99', 'flowcell', 'basecaller', 'GACC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 't', '9_99_2', '9', '99', 'flowcell', 'basecaller', 'GACCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1922-08-02', 't', '9_99_2', '9', '99', 'flowcell', 'basecaller', 'GACCA', '!!!!!', 1, 5],
	];
	my $expecSeq_onePatR = [
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 'f', '10_1_1', '10', '1', 'flowcell', 'basecaller', 'GTAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 'f', '10_1_2', '10', '1', 'flowcell', 'basecaller', 'GTAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 't', '10_99_1', '10', '99', 'flowcell', 'basecaller', 'GTCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 't', '10_99_2', '10', '99', 'flowcell', 'basecaller', 'GTCCA', '!!!!!', 1, 5],		
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 'f', '11_1_1', '11', '1', 'flowcell', 'basecaller', 'GGAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 'f', '11_1_2', '11', '1', 'flowcell', 'basecaller', 'GGAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 't', '11_99_1', '11', '99', 'flowcell', 'basecaller', 'GGCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 't', '11_99_2', '11', '99', 'flowcell', 'basecaller', 'GGCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 'f', '1_1_1', '1', '1', 'flowcell', 'basecaller', 'AAAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 'f', '1_1_2', '1', '1', 'flowcell', 'basecaller', 'AAAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 't', '1_99_1', '1', '99', 'flowcell', 'basecaller', 'AACC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 't', '1_99_2', '1', '99', 'flowcell', 'basecaller', 'AACCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 'f', '2_1_1', '2', '1', 'flowcell', 'basecaller', 'ATAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 'f', '2_1_2', '2', '1', 'flowcell', 'basecaller', 'ATAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 't', '2_99_1', '2', '99', 'flowcell', 'basecaller', 'ATCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 't', '2_99_2', '2', '99', 'flowcell', 'basecaller', 'ATCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 'f', '3_1_1', '3', '1', 'flowcell', 'basecaller', 'AGAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 'f', '3_1_2', '3', '1', 'flowcell', 'basecaller', 'AGAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 't', '3_99_1', '3', '99', 'flowcell', 'basecaller', 'AGCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 't', '3_99_2', '3', '99', 'flowcell', 'basecaller', 'AGCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 'f', '4_1_1', '4', '1', 'flowcell', 'basecaller', 'ACAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 'f', '4_1_2', '4', '1', 'flowcell', 'basecaller', 'ACAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 't', '4_99_1', '4', '99', 'flowcell', 'basecaller', 'ACCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 't', '4_99_2', '4', '99', 'flowcell', 'basecaller', 'ACCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 'f', '5_1_1', '5', '1', 'flowcell', 'basecaller', 'TAAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 'f', '5_1_2', '5', '1', 'flowcell', 'basecaller', 'TAAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 't', '5_99_1', '5', '99', 'flowcell', 'basecaller', 'TACC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 't', '5_99_2', '5', '99', 'flowcell', 'basecaller', 'TACCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 'f', '6_1_1', '6', '1', 'flowcell', 'basecaller', 'TTAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 'f', '6_1_2', '6', '1', 'flowcell', 'basecaller', 'TTAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 't', '6_99_1', '6', '99', 'flowcell', 'basecaller', 'TTCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 't', '6_99_2', '6', '99', 'flowcell', 'basecaller', 'TTCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 'f', '7_1_1', '7', '1', 'flowcell', 'basecaller', 'TGAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 'f', '7_1_2', '7', '1', 'flowcell', 'basecaller', 'TGAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 't', '7_99_1', '7', '99', 'flowcell', 'basecaller', 'TGCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 't', '7_99_2', '7', '99', 'flowcell', 'basecaller', 'TGCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 'f', '8_1_1', '8', '1', 'flowcell', 'basecaller', 'TCAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 'f', '8_1_2', '8', '1', 'flowcell', 'basecaller', 'TCAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 't', '8_99_1', '8', '99', 'flowcell', 'basecaller', 'TCCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 't', '8_99_2', '8', '99', 'flowcell', 'basecaller', 'TCCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 'f', '9_1_1', '9', '1', 'flowcell', 'basecaller', 'GAAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 'f', '9_1_2', '9', '1', 'flowcell', 'basecaller', 'GAAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 't', '9_99_1', '9', '99', 'flowcell', 'basecaller', 'GACC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 't', '9_99_2', '9', '99', 'flowcell', 'basecaller', 'GACCA', '!!!!!', 1, 5],
	];
	my $expecSeq_oneSamplR = [
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 'f', '1_1_1', '1', '1', 'flowcell', 'basecaller', 'AAAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 'f', '1_1_2', '1', '1', 'flowcell', 'basecaller', 'AAAAA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 't', '1_99_1', '1', '99', 'flowcell', 'basecaller', 'AACC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 't', '1_99_2', '1', '99', 'flowcell', 'basecaller', 'AACCA', '!!!!!', 1, 5],
	];
	# id_change: patient, sample, measurement, type, sequence
	my $expecChangeR = [
		[1, 1, 1, 1, 2], # case sample with sequences
		[1, 1, 1, 1, undef], # case sample without sequences
		[1, 1, undef, undef, 2], # control sample without measurement/type
		[1, 1, undef, undef, undef] # control sample without measurement/type and sequences
	];
	
	my $testF_noRunBar = "./data/spreadsheets/test_SGA_noRunBar.xlsx";
	my $testF_seq = "./data/spreadsheets/test_SGA.xlsx";
	my $testF_seq_onePat = "./data/spreadsheets/test_SGA_onePat.xlsx";
	my $testF_seq_oneSampl = "./data/spreadsheets/test_SGA_oneSampl.xlsx";
	my $testF_updateSeq = "./data/spreadsheets/test_SGA_updateSeq.xlsx";

	
	#------------------------------------------------------------------------------#
	# Sequences not found, although run and barcode are provided in Excel (here:
	# wrong basePath).
	# => Issue WARNINGS about missing data
	# => Insert data from Excel
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";
		$resChangeR = "";
					
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $randDir \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change " .
			"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample group by p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change ".
			"order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc, seq.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok (1==2, 'Testing sequences not found');
		
	}
	finally {
		# ERROR string only contains WARNINGS about missing sequence files
		ok ($err =~ m/^((WARNING: ERROR: No results for directory pattern .* and file pattern ->\\\.fastq\.\*<- at .* line \d+\.)\s+)+$/,
			'Testing sequences not found - error msg');
		# The rest of the data is inserted, as requested
		is ($resChangeR, [[1, 1, 1, 1, undef], [1, 1, undef, undef, undef]], 'Testing sequences not found - new data inserted?');
		is ($resR, $expecMeasureR, 'Testing sequences not found - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing sequences not found - derived measurements');
		is ($resSeqR, [], 'Testing sequences not found - sequences')
	};

	
	#------------------------------------------------------------------------------#
	# Valid full insert
	# => Insert data from Excel
	# => Insert sequences
	#------------------------------------------------------------------------------#
	# id_change: patient, sample, measurement, type, sequence
	my $expecChange_modR = [
		[1, 1, 1, 1, 1], # case sample with sequences
		[1, 1, 1, 1, undef], # case sample without sequences
		[1, 1, undef, undef, 1], # control sample without measurement/type
		[1, 1, undef, undef, undef] # control sample without measurement/type and sequences
	];
	
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";
		$resChangeR = "";
					
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change " .
			"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample group by p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change ".
			"order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc, seq.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok (1==2, 'Testing valid insert');
		
	}
	finally {
		# Sequence tests don't include classification files
		ok ($err =~ m/^((WARNING: ERROR: No results for directory pattern .* and file pattern ->\.\*calc\\\.LIN\\\.txt\.\*<- at .* line \d+\.)\s+)+$/,
			'Testing valid insert - error msg');
		is ($resChangeR, $expecChange_modR, 'Testing valid insert - new data inserted?');
		is ($resR, $expecMeasureR, 'Testing valid insert - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing valid insert - derived measurements');
		is ($resSeqR, $expecSeqR, 'Testing valid insert - sequences')
	};
	
	
	#------------------------------------------------------------------------------#
	# Add sequences when inserting full Excel, Excel with all samples for
	# patient, Excel with one selected sample for one patient.
	#------------------------------------------------------------------------------#
	my @runs = (
		[$testF_seq, 'full file', $expecSeqR],
		[$testF_seq_onePat, 'one patient', $expecSeq_onePatR],
		[$testF_seq_oneSampl, 'one sample', $expecSeq_oneSamplR],
	);
	foreach my $run (@runs) {
		my ($file, $name, $tmp_expecSeqR) = @{$run};
		
		
		#------------------------------------------------------------------------------#
		# Always initialize with Excel without sequence data
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Add sequence data
		# => id_change indicates version of data --> should change
		# => there should be no duplicates of records
		# => existing records should not have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqR = "";
			$resChangeR = "";
						
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqR = $dbh->selectall_arrayref(
				"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
					"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
					"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
					"order by seq.readid asc, p.alias asc"
			);
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
				"on s.id = seq.id_sample group by p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change ".
				"order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc, seq.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok (1==2, 'Testing to add new sequence data with ->' . $name . '<-');
		}
		finally {
			# Sequence tests don't include classification files
			ok ($err =~ m/^((WARNING: ERROR: No results for directory pattern .* and file pattern ->\.\*calc\\\.LIN\\\.txt\.\*<- at .* line \d+\.)\s+)+$/,
				'Testing to add new sequence data with ->' . $name . '<- - error msg');
			is ($resChangeR, $expecChangeR, 'Testing to add new sequence data with ->' . $name . '<- - updated?');
			is ($resR, $expecMeasureR, 'Testing to add new sequence data with ->' . $name . '<- - measurements');
			is ($resDerivedR, $expecDerivedR, 'Testing to add new sequence data with ->' . $name . '<- - derived measurements');
			is ($resSeqR, $tmp_expecSeqR, 'Testing to add new sequence data with ->' . $name . '<- - sequences')
		};
	}


	#------------------------------------------------------------------------------#
	# Ignore old records when inserting full Excel, Excel with all samples for
	# patient, Excel with one selected sample for one patient.
	#------------------------------------------------------------------------------#
	@runs = (
		[$testF_seq, 'full file'],
		[$testF_seq_onePat, 'one patient'],
		[$testF_seq_oneSampl, 'one sample'],
	);
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};
		my $tmp_expecChangeR = "";	
			
		
		#------------------------------------------------------------------------------#
		# Always initialize with Excel including sequence data
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
			
			$tmp_expecChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
				"on s.id = seq.id_sample group by p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change ".
				"order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc, seq.id_change asc"
			);
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Attempt to add old sequence data
		# => id_change indicates version of data --> should not change
		# => there should be no duplicates of records
		# => no records should have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqR = "";
			$resChangeR = "";
						
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqR = $dbh->selectall_arrayref(
				"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
					"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
					"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
					"order by seq.readid asc, p.alias asc"
			);
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change " .
				"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
				"on s.id = seq.id_sample group by p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change ".
				"order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc, seq.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok (1==2, 'Testing to add old sequence data with ->' . $name . '<-');
		}
		finally {
			# Sequence tests don't include classification files
			ok ($err =~ m/^((WARNING: ERROR: No results for directory pattern .* and file pattern ->\.\*calc\\\.LIN\\\.txt\.\*<- at .* line \d+\.)\s+)+$/,
				'Testing to add old sequence data with ->' . $name . '<- - error msg');
			is ($resChangeR, $tmp_expecChangeR, 'Testing to add old sequence data with ->' . $name . '<- - updated?');
			is ($resR, $expecMeasureR, 'Testing to add old sequence data with ->' . $name . '<- - measurements');
			is ($resDerivedR, $expecDerivedR, 'Testing to add old sequence data with ->' . $name . '<- - derived measurements');
			is ($resSeqR, $expecSeqR, 'Testing to add old sequence data with ->' . $name . '<- - sequences')
		};
	}
	
	
	#------------------------------------------------------------------------------#
	# Attempt to remove sequence data by emptying run and barcode in Excel
	# => does not work; data is left unchanged.
	# => id_change indicates version of data --> should not change
	#------------------------------------------------------------------------------#
	my $tmp_expecChangeR = "";
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";

		# Add Excel with sequences		
		qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		
		$tmp_expecChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change " .
			"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample group by p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change ".
			"order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc, seq.id_change asc"
		);
		
		# Attempt to remove sequences by providing Excel with empty run_bar field			
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};			
		
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change " .
			"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample group by p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change ".
			"order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc, seq.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok(1==2, 'Testing removing existing sequence data does not work [1/2]')
	}
	finally {
		is ($resChangeR, $tmp_expecChangeR, 'Testing removing existing sequence data does not work [1/2] - updated?');
		is ($resR, $expecMeasureR, 'Testing removing existing sequence data does not work [1/2] - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing removing existing sequence data does not work [1/2] - derived measurements');
		is ($resSeqR, $expecSeqR, 'Testing removing existing sequence data does not work [1/2] - sequences')
	};
	
	
	#------------------------------------------------------------------------------#
	# Attempt to remove sequence data by not providing the data (still referred to
	# in Excel by run and barcode).
	# => does not work; data is left unchanged.
	# => id_change indicates version of data --> should not change
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";
		$tmp_expecChangeR = "";

		# Add Excel with sequences		
		qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		
		$tmp_expecChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change " .
			"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample group by p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change ".
			"order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc, seq.id_change asc"
		);
		
		# Attempt to remove sequences by providing Excel with empty run_bar field			
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $randDir \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};			
		
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change " .
			"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample group by p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change ".
			"order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc, seq.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok(1==2, 'Testing removing existing sequence data does not work [2/2]');
	}
	finally {
		ok ($err =~ m/^((WARNING: ERROR: No results for directory pattern .* and file pattern ->\\\.fastq\.\*<- at .* line \d+\.)\s+)+$/,
			'Testing removing existing sequence data does not work [2/2] - error msg');
		is ($resChangeR, $tmp_expecChangeR, 'Testing removing existing sequence data does not work [2/2] - updated?');
		is ($resR, $expecMeasureR, 'Testing removing existing sequence data does not work [2/2] - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing removing existing sequence data does not work [2/2] - derived measurements');
		is ($resSeqR, $expecSeqR, 'Testing removing existing sequence data does not work [2/2] - sequences')
	};
	

	#------------------------------------------------------------------------------#
	# Attempt to replace sequence data with completely new data
	# => does not work and produces a huge mess. Old sequences are not deleted,
	# 	new sequences are simply added to the old.
	# => id_change indicates version of data --> should change
	#------------------------------------------------------------------------------#
	my $tmp_expecSeqR = "";
	
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";
		$tmp_expecChangeR = [
			[1, 1, 1, 1, 1], # case sample with sequences (original insert)
			[1, 1, 1, 1, 2], # case sample with sequences (updated seq)
			[1, 1, 1, 1, undef], # case sample without sequences
			[1, 1, undef, undef, 1], # control sample without measurement/type (here: no update for control samples)
			[1, 1, undef, undef, undef] # control sample without measurement/type and sequences
		];
		
		# Same data is inserted twice, after sequences for patients were swapped.
		# In this case, the control sequences (barcode 99) are not inserted
		# twice, since both patients used the same control data before.
		# --> Duplicate each array ref from expecSeqR and modify it
		# (fb1 --> fb2: birthdate and sample createdate increase by 1 year,
		# 1 month and 1 day; fb2-->fb1: vice versa)
		my @tmps = ();
		foreach my $seqR (@{$expecSeqR}) {
			# The original entry
			push(@tmps, $seqR);
			# The supposed replacement entry which is actually just added to the db
			my $tmpR = dclone($seqR);
			if ($tmpR->[5] !~ m/99/) {
				if ($tmpR->[0] =~ m/[a-zA-Z]1$/) {
					$tmpR->[0] =~ s/\d$/2/;
					$tmpR->[1] =~ s/\d$/2/;
					# Add 1 day, 1 month, 1 year to date while keeping
					# padding 0s.
					$tmpR->[2] =~ s/(\d+)/sprintf('%0.2d', $1+1)/ge;
					$tmpR->[3] =~ s/(\d+)/sprintf('%0.2d', $1+1)/ge;
				}
				elsif ($tmpR->[0] =~ m/[a-zA-Z]2$/) {
					$tmpR->[0] =~ s/\d$/1/;
					$tmpR->[1] =~ s/\d$/1/;
					# Subtract 1 day, 1 month, 1 year from date while
					# keeping padding 0s.
					$tmpR->[2] =~ s/(\d+)/sprintf('%0.2d', $1-1)/ge;
					$tmpR->[3] =~ s/(\d+)/sprintf('%0.2d', $1-1)/ge;
				}
				else {
					die "ERROR: Unexpected alias ->$tmpR->[0]<-";
				}
				push(@tmps, $tmpR);
			}
		}
		$tmp_expecSeqR = [sort {$a->[5] cmp $b->[5] || $a->[0] cmp $b->[0]} @tmps];

		# Add Excel with sequences		
		qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
				
		# Attempt to update sequences by providing Excel with different run and barcode
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_updateSeq --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};			
		
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change " .
			"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample group by p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change ".
			"order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc, seq.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok (1==2, 'Testing replacing sequences does not work')
	}
	finally {
		# Sequence tests don't include classification files
		ok ($err =~ m/^((WARNING: ERROR: No results for directory pattern .* and file pattern ->\.\*calc\\\.LIN\\\.txt\.\*<- at .* line \d+\.)\s+)+$/,
			'Testing replacing sequences does not work - error msg');
		is ($resChangeR, $tmp_expecChangeR, 'Testing replacing sequences does not work - updated?');
		is ($resR, $expecMeasureR, 'Testing replacing sequences does not work - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing replacing sequences does not work - derived measurements');
		is ($resSeqR, $tmp_expecSeqR, 'Testing replacing sequences does not work - sequences')
	};
	
	
	#------------------------------------------------------------------------------#
	# Update sequence data that can actually be updated: flowcellid, callermodel,
	# nucs, and quality.
	# => non-sequence data should not change
	# => sequence data should be updated without inserting new records
	# => id_change indicates version of data --> should change
	#
	# Together with the previous test, this test implies that changing values of
	# the other db columns will insert new sequences.
	#------------------------------------------------------------------------------#
	$tmp_expecSeqR = dclone($expecSeqR);
	# works directly on array ref
	map {
		$_->[8] = 'newFlow';
		$_->[9] = 'newBase';
		$_->[10] .= "A";
		$_->[11] =~ s/\!/\+/g; $_->[11] .= "+";
		$_->[12] = 0.1;
		$_->[13] +=1
	} @{$tmp_expecSeqR};
	
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";
		my $basePath_mod = $basePath =~ s/org/mod_seq/r;

		# Add Excel with sequences		
		qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
				
		# Add Excel with sequences that vary in flowcellid, callermodel, nucs, and quality
		# => values that can actually be updated
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath_mod \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change " .
			"from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample group by p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change ".
			"order by p.id_change asc, s.id_change asc, m.id_change asc, t.id_change asc, seq.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok (1==2, 'Testing update of updatable sequence data')
	}
	finally {
		# Sequence tests don't include classification files
		ok ($err =~ m/^((WARNING: ERROR: No results for directory pattern .* and file pattern ->\.\*calc\\\.LIN\\\.txt\.\*<- at .* line \d+\.)\s+)+$/,
			'Testing update of updatable sequence data - error msg');
		is ($resChangeR, $expecChangeR, 'Testing update of updatable sequence data - updated?');
		is ($resR, $expecMeasureR, 'Testing update of updatable sequence data - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing update of updatable sequence data - derived measurements');
		is ($resSeqR, $tmp_expecSeqR, 'Testing update of updatable sequence data - sequences')
	};
	
	
	return;
};


#
#--------------------------------------------------------------------------------------------------#
# Test to insert/update classification/taxclass/taxonomy
#--------------------------------------------------------------------------------------------------#
#
sub test_class {
	my $dbh = $_[0];
	my $schema = $_[1];
	my $basePath = $_[2];
	my $randDir = $_[3];
	my $expecMeasureR = $_[4];
	my $expecDerivedR = $_[5];
	
	my $err = "";
	my $resR = "";
	my $resDerivedR = "";
	my $resSeqR = "";
	my $resClassR = "";
	my $resChangeR = "";
	
	# Control sample sequences inserted for every case sample
	# alias, accession, birthdate, createdate, iscontrol, readid, runid, barcode, flowcellid, callermodel,
	# nucs, quality, seqerr, seqlen
	my $expecSeqR = [
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 'f', '10_1_1', '10', '1', 'flowcell', 'basecaller', 'GTAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 'f', '10_1_2', '10', '1', 'flowcell', 'basecaller', 'GTAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1923-02-02', 'f', '10_2_1', '10', '2', 'flowcell', 'basecaller', 'GTAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1923-02-02', 'f', '10_2_2', '10', '2', 'flowcell', 'basecaller', 'GTATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 't', '10_99_1', '10', '99', 'flowcell', 'basecaller', 'GTCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1923-02-02', 't', '10_99_1', '10', '99', 'flowcell', 'basecaller', 'GTCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-01-01', 't', '10_99_2', '10', '99', 'flowcell', 'basecaller', 'GTCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1923-02-02', 't', '10_99_2', '10', '99', 'flowcell', 'basecaller', 'GTCCA', '!!!!!', 1, 5],		
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 'f', '11_1_1', '11', '1', 'flowcell', 'basecaller', 'GGAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 'f', '11_1_2', '11', '1', 'flowcell', 'basecaller', 'GGAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1923-08-02', 'f','11_2_1', '11', '2', 'flowcell', 'basecaller', 'GGAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1923-08-02', 'f','11_2_2', '11', '2', 'flowcell', 'basecaller', 'GGATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 't', '11_99_1', '11', '99', 'flowcell', 'basecaller', 'GGCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1923-08-02', 't', '11_99_1', '11', '99', 'flowcell', 'basecaller', 'GGCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1922-07-01', 't', '11_99_2', '11', '99', 'flowcell', 'basecaller', 'GGCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1923-08-02', 't', '11_99_2', '11', '99', 'flowcell', 'basecaller', 'GGCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 'f', '1_1_1', '1', '1', 'flowcell', 'basecaller', 'AAAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 'f', '1_1_2', '1', '1', 'flowcell', 'basecaller', 'AAAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-02', 'f', '1_2_1', '1', '2', 'flowcell', 'basecaller', 'AAAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-02', 'f', '1_2_2', '1', '2', 'flowcell', 'basecaller', 'AAATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 't', '1_99_1', '1', '99', 'flowcell', 'basecaller', 'AACC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-02', 't', '1_99_1', '1', '99', 'flowcell', 'basecaller', 'AACC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-01', 't', '1_99_2', '1', '99', 'flowcell', 'basecaller', 'AACCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-02', 't', '1_99_2', '1', '99', 'flowcell', 'basecaller', 'AACCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 'f', '2_1_1', '2', '1', 'flowcell', 'basecaller', 'ATAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 'f', '2_1_2', '2', '1', 'flowcell', 'basecaller', 'ATAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-05', 'f', '2_2_1', '2', '2', 'flowcell', 'basecaller', 'ATAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-05', 'f', '2_2_2', '2', '2', 'flowcell', 'basecaller', 'ATATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 't', '2_99_1', '2', '99', 'flowcell', 'basecaller', 'ATCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-05', 't','2_99_1', '2', '99', 'flowcell', 'basecaller', 'ATCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-04', 't', '2_99_2', '2', '99', 'flowcell', 'basecaller', 'ATCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-05', 't','2_99_2', '2', '99', 'flowcell', 'basecaller', 'ATCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 'f', '3_1_1', '3', '1', 'flowcell', 'basecaller', 'AGAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 'f', '3_1_2', '3', '1', 'flowcell', 'basecaller', 'AGAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-16', 'f', '3_2_1', '3', '2', 'flowcell', 'basecaller', 'AGAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-16', 'f', '3_2_2', '3', '2', 'flowcell', 'basecaller', 'AGATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 't', '3_99_1', '3', '99', 'flowcell', 'basecaller', 'AGCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-16', 't', '3_99_1', '3', '99', 'flowcell', 'basecaller', 'AGCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-01-15', 't', '3_99_2', '3', '99', 'flowcell', 'basecaller', 'AGCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-02-16', 't', '3_99_2', '3', '99', 'flowcell', 'basecaller', 'AGCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 'f', '4_1_1', '4', '1', 'flowcell', 'basecaller', 'ACAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 'f', '4_1_2', '4', '1', 'flowcell', 'basecaller', 'ACAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-03-16', 'f', '4_2_1', '4', '2', 'flowcell', 'basecaller', 'ACAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-03-16', 'f', '4_2_2', '4', '2', 'flowcell', 'basecaller', 'ACATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 't', '4_99_1', '4', '99', 'flowcell', 'basecaller', 'ACCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-03-16', 't', '4_99_1', '4', '99', 'flowcell', 'basecaller', 'ACCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-02-15', 't', '4_99_2', '4', '99', 'flowcell', 'basecaller', 'ACCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-03-16', 't', '4_99_2', '4', '99', 'flowcell', 'basecaller', 'ACCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 'f', '5_1_1', '5', '1', 'flowcell', 'basecaller', 'TAAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 'f', '5_1_2', '5', '1', 'flowcell', 'basecaller', 'TAAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-05-02', 'f', '5_2_1', '5', '2', 'flowcell', 'basecaller', 'TAAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-05-02', 'f', '5_2_2', '5', '2', 'flowcell', 'basecaller', 'TAATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 't', '5_99_1', '5', '99', 'flowcell', 'basecaller', 'TACC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-05-02', 't', '5_99_1', '5', '99', 'flowcell', 'basecaller', 'TACC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-04-01', 't', '5_99_2', '5', '99', 'flowcell', 'basecaller', 'TACCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-05-02', 't', '5_99_2', '5', '99', 'flowcell', 'basecaller', 'TACCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 'f', '6_1_1', '6', '1', 'flowcell', 'basecaller', 'TTAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 'f', '6_1_2', '6', '1', 'flowcell', 'basecaller', 'TTAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-08-02', 'f', '6_2_1', '6', '2', 'flowcell', 'basecaller', 'TTAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-08-02', 'f', '6_2_2', '6', '2', 'flowcell', 'basecaller', 'TTATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 't', '6_99_1', '6', '99', 'flowcell', 'basecaller', 'TTCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-08-02', 't', '6_99_1', '6', '99', 'flowcell', 'basecaller', 'TTCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-07-01', 't', '6_99_2', '6', '99', 'flowcell', 'basecaller', 'TTCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-08-02', 't', '6_99_2', '6', '99', 'flowcell', 'basecaller', 'TTCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 'f', '7_1_1', '7', '1', 'flowcell', 'basecaller', 'TGAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 'f', '7_1_2', '7', '1', 'flowcell', 'basecaller', 'TGAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-11-02', 'f', '7_2_1', '7', '2', 'flowcell', 'basecaller', 'TGAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-11-02', 'f', '7_2_2', '7', '2', 'flowcell', 'basecaller', 'TGATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 't', '7_99_1', '7', '99', 'flowcell', 'basecaller', 'TGCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1921-11-02', 't', '7_99_1', '7', '99', 'flowcell', 'basecaller', 'TGCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1920-10-01', 't', '7_99_2', '7', '99', 'flowcell', 'basecaller', 'TGCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1921-11-02', 't', '7_99_2', '7', '99', 'flowcell', 'basecaller', 'TGCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 'f', '8_1_1', '8', '1', 'flowcell', 'basecaller', 'TCAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 'f', '8_1_2', '8', '1', 'flowcell', 'basecaller', 'TCAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1922-02-02', 'f', '8_2_1', '8', '2', 'flowcell', 'basecaller', 'TCAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1922-02-02', 'f', '8_2_2', '8', '2', 'flowcell', 'basecaller', 'TCATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 't', '8_99_1', '8', '99', 'flowcell', 'basecaller', 'TCCC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1922-02-02', 't', '8_99_1', '8', '99', 'flowcell', 'basecaller', 'TCCC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-01-01', 't', '8_99_2', '8', '99', 'flowcell', 'basecaller', 'TCCCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1922-02-02', 't', '8_99_2', '8', '99', 'flowcell', 'basecaller', 'TCCCA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 'f', '9_1_1', '9', '1', 'flowcell', 'basecaller', 'GAAA', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 'f', '9_1_2', '9', '1', 'flowcell', 'basecaller', 'GAAAA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1922-08-02', 'f', '9_2_1', '9', '2', 'flowcell', 'basecaller', 'GAAT', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1922-08-02', 'f','9_2_2', '9', '2', 'flowcell', 'basecaller', 'GAATA', '!!!!!', 1, 5],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 't', '9_99_1', '9', '99', 'flowcell', 'basecaller', 'GACC', '!!!!', 1, 4],
		['Foobar2', 'fb2', '1921-02-02', '1922-08-02', 't', '9_99_1', '9', '99', 'flowcell', 'basecaller', 'GACC', '!!!!', 1, 4],
		['Foobar1', 'fb1', '1920-01-01', '1921-07-01', 't', '9_99_2', '9', '99', 'flowcell', 'basecaller', 'GACCA', '!!!!!', 1, 5],
		['Foobar2', 'fb2', '1921-02-02', '1922-08-02', 't', '9_99_2', '9', '99', 'flowcell', 'basecaller', 'GACCA', '!!!!!', 1, 5],
	];
	# runid, barcode, readid, program, database, name, rank
	# control samples appear twice, as each individual control sample is used
	# as controls for each barcode of a run. 
	my $expecClassR = [
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'd10_1', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'p10_1', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'c10_1', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'sc10_1', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'o10_1', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'so10_1', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'f10_1', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'g10_1', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 's10_1', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'str10_1', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'd10_2', 'domain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'p10_2', 'phylum'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'c10_2', 'class'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'sc10_2', 'subclass'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'o10_2', 'order'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'so10_2', 'suborder'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'f10_2', 'family'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'g10_2', 'genus'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 's10_2', 'species'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'str10_2', 'strain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'd11_1', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'p11_1', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'c11_1', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'sc11_1', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'o11_1', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'so11_1', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'f11_1', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'g11_1', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 's11_1', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'str11_1', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'd11_2', 'domain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'p11_2', 'phylum'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'c11_2', 'class'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'sc11_2', 'subclass'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'o11_2', 'order'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'so11_2', 'suborder'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'f11_2', 'family'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'g11_2', 'genus'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 's11_2', 'species'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'str11_2', 'strain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'd1_2', 'domain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'p1_2', 'phylum'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'c1_2', 'class'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'sc1_2', 'subclass'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'o1_2', 'order'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'so1_2', 'suborder'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'f1_2', 'family'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'g1_2', 'genus'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 's1_2', 'species'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'str1_2', 'strain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'd2_1', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'p2_1', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'c2_1', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'sc2_1', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'o2_1', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'so2_1', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'f2_1', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'g2_1', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 's2_1', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'str2_1', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'd2_2', 'domain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'p2_2', 'phylum'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'c2_2', 'class'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'sc2_2', 'subclass'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'o2_2', 'order'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'so2_2', 'suborder'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'f2_2', 'family'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'g2_2', 'genus'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 's2_2', 'species'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'str2_2', 'strain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'd3_1', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'p3_1', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'c3_1', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'sc3_1', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'o3_1', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'so3_1', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'f3_1', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'g3_1', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 's3_1', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'str3_1', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'd3_2', 'domain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'p3_2', 'phylum'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'c3_2', 'class'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'sc3_2', 'subclass'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'o3_2', 'order'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'so3_2', 'suborder'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'f3_2', 'family'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'g3_2', 'genus'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 's3_2', 'species'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'str3_2', 'strain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'd4_1', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'p4_1', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'c4_1', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'sc4_1', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'o4_1', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'so4_1', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'f4_1', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'g4_1', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 's4_1', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'str4_1', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'd4_2', 'domain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'p4_2', 'phylum'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'c4_2', 'class'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'sc4_2', 'subclass'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'o4_2', 'order'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'so4_2', 'suborder'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'f4_2', 'family'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'g4_2', 'genus'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 's4_2', 'species'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'str4_2', 'strain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'd5_1', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'p5_1', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'c5_1', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'sc5_1', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'o5_1', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'so5_1', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'f5_1', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'g5_1', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 's5_1', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'str5_1', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'd5_2', 'domain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'p5_2', 'phylum'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'c5_2', 'class'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'sc5_2', 'subclass'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'o5_2', 'order'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'so5_2', 'suborder'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'f5_2', 'family'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'g5_2', 'genus'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 's5_2', 'species'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'str5_2', 'strain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'd6_1', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'p6_1', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'c6_1', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'sc6_1', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'o6_1', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'so6_1', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'f6_1', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'g6_1', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 's6_1', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'str6_1', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'd6_2', 'domain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'p6_2', 'phylum'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'c6_2', 'class'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'sc6_2', 'subclass'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'o6_2', 'order'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'so6_2', 'suborder'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'f6_2', 'family'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'g6_2', 'genus'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 's6_2', 'species'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'str6_2', 'strain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'd7_1', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'p7_1', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'c7_1', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'sc7_1', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'o7_1', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'so7_1', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'f7_1', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'g7_1', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 's7_1', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'str7_1', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'd7_2', 'domain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'p7_2', 'phylum'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'c7_2', 'class'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'sc7_2', 'subclass'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'o7_2', 'order'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'so7_2', 'suborder'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'f7_2', 'family'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'g7_2', 'genus'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 's7_2', 'species'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'str7_2', 'strain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'd8_1', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'p8_1', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'c8_1', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'sc8_1', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'o8_1', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'so8_1', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'f8_1', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'g8_1', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 's8_1', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'str8_1', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'd8_2', 'domain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'p8_2', 'phylum'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'c8_2', 'class'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'sc8_2', 'subclass'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'o8_2', 'order'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'so8_2', 'suborder'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'f8_2', 'family'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'g8_2', 'genus'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 's8_2', 'species'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'str8_2', 'strain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'd9_1', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'p9_1', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'c9_1', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'sc9_1', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'o9_1', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'so9_1', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'f9_1', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'g9_1', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 's9_1', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'str9_1', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'd9_2', 'domain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'p9_2', 'phylum'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'c9_2', 'class'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'sc9_2', 'subclass'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'o9_2', 'order'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'so9_2', 'suborder'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'f9_2', 'family'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'g9_2', 'genus'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 's9_2', 'species'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'str9_2', 'strain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain']
	];
	my $expecClass_onePatR = [
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'd10_1', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'p10_1', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'c10_1', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'sc10_1', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'o10_1', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'so10_1', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'f10_1', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'g10_1', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 's10_1', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'str10_1', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'd11_1', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'p11_1', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'c11_1', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'sc11_1', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'o11_1', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'so11_1', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'f11_1', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'g11_1', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 's11_1', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'str11_1', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'd2_1', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'p2_1', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'c2_1', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'sc2_1', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'o2_1', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'so2_1', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'f2_1', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'g2_1', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 's2_1', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'str2_1', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'd3_1', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'p3_1', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'c3_1', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'sc3_1', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'o3_1', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'so3_1', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'f3_1', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'g3_1', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 's3_1', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'str3_1', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'd4_1', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'p4_1', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'c4_1', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'sc4_1', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'o4_1', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'so4_1', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'f4_1', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'g4_1', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 's4_1', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'str4_1', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'd5_1', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'p5_1', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'c5_1', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'sc5_1', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'o5_1', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'so5_1', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'f5_1', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'g5_1', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 's5_1', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'str5_1', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'd6_1', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'p6_1', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'c6_1', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'sc6_1', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'o6_1', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'so6_1', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'f6_1', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'g6_1', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 's6_1', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'str6_1', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'd7_1', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'p7_1', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'c7_1', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'sc7_1', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'o7_1', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'so7_1', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'f7_1', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'g7_1', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 's7_1', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'str7_1', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'd8_1', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'p8_1', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'c8_1', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'sc8_1', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'o8_1', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'so8_1', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'f8_1', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'g8_1', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 's8_1', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'str8_1', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'd9_1', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'p9_1', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'c9_1', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'sc9_1', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'o9_1', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'so9_1', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'f9_1', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'g9_1', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 's9_1', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'str9_1', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain']
	];
	my $expecClass_oneSamplR = [
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain']
	];
	# additional new classifications:
	# run 1 barcode 1: read 1: FILTERED; read 2: classification from read 1
	# run 1 barcode 99: read 1: FILTERED; read 2: classification from read 1
	my $expecClass_oneSampl_updatedR = [
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'd10_1', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'p10_1', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'c10_1', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'sc10_1', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'o10_1', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'so10_1', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'f10_1', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'g10_1', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 's10_1', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'str10_1', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'd10_2', 'domain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'p10_2', 'phylum'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'c10_2', 'class'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'sc10_2', 'subclass'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'o10_2', 'order'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'so10_2', 'suborder'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'f10_2', 'family'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'g10_2', 'genus'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 's10_2', 'species'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'str10_2', 'strain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'd11_1', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'p11_1', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'c11_1', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'sc11_1', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'o11_1', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'so11_1', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'f11_1', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'g11_1', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 's11_1', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'str11_1', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'd11_2', 'domain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'p11_2', 'phylum'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'c11_2', 'class'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'sc11_2', 'subclass'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'o11_2', 'order'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'so11_2', 'suborder'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'f11_2', 'family'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'g11_2', 'genus'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 's11_2', 'species'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'str11_2', 'strain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'd1_2', 'domain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'p1_2', 'phylum'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'c1_2', 'class'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'sc1_2', 'subclass'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'o1_2', 'order'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'so1_2', 'suborder'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'f1_2', 'family'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'g1_2', 'genus'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 's1_2', 'species'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'str1_2', 'strain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'd2_1', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'p2_1', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'c2_1', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'sc2_1', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'o2_1', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'so2_1', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'f2_1', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'g2_1', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 's2_1', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'str2_1', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'd2_2', 'domain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'p2_2', 'phylum'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'c2_2', 'class'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'sc2_2', 'subclass'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'o2_2', 'order'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'so2_2', 'suborder'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'f2_2', 'family'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'g2_2', 'genus'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 's2_2', 'species'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'str2_2', 'strain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'd3_1', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'p3_1', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'c3_1', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'sc3_1', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'o3_1', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'so3_1', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'f3_1', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'g3_1', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 's3_1', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'str3_1', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'd3_2', 'domain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'p3_2', 'phylum'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'c3_2', 'class'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'sc3_2', 'subclass'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'o3_2', 'order'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'so3_2', 'suborder'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'f3_2', 'family'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'g3_2', 'genus'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 's3_2', 'species'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'str3_2', 'strain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'd4_1', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'p4_1', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'c4_1', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'sc4_1', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'o4_1', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'so4_1', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'f4_1', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'g4_1', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 's4_1', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'str4_1', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'd4_2', 'domain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'p4_2', 'phylum'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'c4_2', 'class'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'sc4_2', 'subclass'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'o4_2', 'order'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'so4_2', 'suborder'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'f4_2', 'family'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'g4_2', 'genus'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 's4_2', 'species'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'str4_2', 'strain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'd5_1', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'p5_1', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'c5_1', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'sc5_1', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'o5_1', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'so5_1', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'f5_1', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'g5_1', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 's5_1', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'str5_1', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'd5_2', 'domain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'p5_2', 'phylum'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'c5_2', 'class'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'sc5_2', 'subclass'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'o5_2', 'order'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'so5_2', 'suborder'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'f5_2', 'family'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'g5_2', 'genus'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 's5_2', 'species'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'str5_2', 'strain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'd6_1', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'p6_1', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'c6_1', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'sc6_1', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'o6_1', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'so6_1', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'f6_1', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'g6_1', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 's6_1', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'str6_1', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'd6_2', 'domain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'p6_2', 'phylum'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'c6_2', 'class'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'sc6_2', 'subclass'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'o6_2', 'order'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'so6_2', 'suborder'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'f6_2', 'family'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'g6_2', 'genus'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 's6_2', 'species'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'str6_2', 'strain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'd7_1', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'p7_1', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'c7_1', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'sc7_1', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'o7_1', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'so7_1', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'f7_1', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'g7_1', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 's7_1', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'str7_1', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'd7_2', 'domain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'p7_2', 'phylum'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'c7_2', 'class'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'sc7_2', 'subclass'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'o7_2', 'order'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'so7_2', 'suborder'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'f7_2', 'family'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'g7_2', 'genus'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 's7_2', 'species'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'str7_2', 'strain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'd8_1', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'p8_1', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'c8_1', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'sc8_1', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'o8_1', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'so8_1', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'f8_1', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'g8_1', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 's8_1', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'str8_1', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'd8_2', 'domain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'p8_2', 'phylum'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'c8_2', 'class'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'sc8_2', 'subclass'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'o8_2', 'order'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'so8_2', 'suborder'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'f8_2', 'family'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'g8_2', 'genus'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 's8_2', 'species'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'str8_2', 'strain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'd9_1', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'p9_1', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'c9_1', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'sc9_1', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'o9_1', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'so9_1', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'f9_1', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'g9_1', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 's9_1', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'str9_1', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'd9_2', 'domain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'p9_2', 'phylum'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'c9_2', 'class'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'sc9_2', 'subclass'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'o9_2', 'order'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'so9_2', 'suborder'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'f9_2', 'family'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'g9_2', 'genus'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 's9_2', 'species'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'str9_2', 'strain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain']
	];
	# additional new classifications:
	# run * barcode 1: read 1: FILTERED; read 2: classification from read 1
	# run * barcode 99: read 1: FILTERED; read 2: classification from read 1
	my $expecClass_onePat_updatedR = [
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'd10_1', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'p10_1', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'c10_1', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'sc10_1', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'o10_1', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'so10_1', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'f10_1', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'g10_1', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 's10_1', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'str10_1', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'd10_1', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'p10_1', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'c10_1', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'sc10_1', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'o10_1', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'so10_1', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'f10_1', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'g10_1', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 's10_1', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'str10_1', 'strain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'd10_2', 'domain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'p10_2', 'phylum'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'c10_2', 'class'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'sc10_2', 'subclass'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'o10_2', 'order'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'so10_2', 'suborder'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'f10_2', 'family'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'g10_2', 'genus'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 's10_2', 'species'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'str10_2', 'strain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'd11_1', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'p11_1', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'c11_1', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'sc11_1', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'o11_1', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'so11_1', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'f11_1', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'g11_1', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 's11_1', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'str11_1', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'd11_1', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'p11_1', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'c11_1', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'sc11_1', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'o11_1', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'so11_1', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'f11_1', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'g11_1', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 's11_1', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'str11_1', 'strain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'd11_2', 'domain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'p11_2', 'phylum'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'c11_2', 'class'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'sc11_2', 'subclass'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'o11_2', 'order'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'so11_2', 'suborder'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'f11_2', 'family'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'g11_2', 'genus'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 's11_2', 'species'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'str11_2', 'strain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'd1_2', 'domain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'p1_2', 'phylum'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'c1_2', 'class'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'sc1_2', 'subclass'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'o1_2', 'order'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'so1_2', 'suborder'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'f1_2', 'family'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'g1_2', 'genus'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 's1_2', 'species'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'str1_2', 'strain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'd2_1', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'p2_1', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'c2_1', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'sc2_1', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'o2_1', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'so2_1', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'f2_1', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'g2_1', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 's2_1', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'str2_1', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'd2_1', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'p2_1', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'c2_1', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'sc2_1', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'o2_1', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'so2_1', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'f2_1', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'g2_1', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 's2_1', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'str2_1', 'strain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'd2_2', 'domain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'p2_2', 'phylum'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'c2_2', 'class'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'sc2_2', 'subclass'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'o2_2', 'order'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'so2_2', 'suborder'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'f2_2', 'family'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'g2_2', 'genus'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 's2_2', 'species'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'str2_2', 'strain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'd3_1', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'p3_1', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'c3_1', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'sc3_1', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'o3_1', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'so3_1', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'f3_1', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'g3_1', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 's3_1', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'str3_1', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'd3_1', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'p3_1', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'c3_1', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'sc3_1', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'o3_1', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'so3_1', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'f3_1', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'g3_1', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 's3_1', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'str3_1', 'strain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'd3_2', 'domain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'p3_2', 'phylum'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'c3_2', 'class'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'sc3_2', 'subclass'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'o3_2', 'order'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'so3_2', 'suborder'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'f3_2', 'family'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'g3_2', 'genus'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 's3_2', 'species'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'str3_2', 'strain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'd4_1', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'p4_1', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'c4_1', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'sc4_1', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'o4_1', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'so4_1', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'f4_1', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'g4_1', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 's4_1', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'str4_1', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'd4_1', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'p4_1', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'c4_1', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'sc4_1', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'o4_1', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'so4_1', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'f4_1', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'g4_1', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 's4_1', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'str4_1', 'strain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'd4_2', 'domain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'p4_2', 'phylum'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'c4_2', 'class'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'sc4_2', 'subclass'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'o4_2', 'order'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'so4_2', 'suborder'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'f4_2', 'family'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'g4_2', 'genus'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 's4_2', 'species'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'str4_2', 'strain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'd5_1', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'p5_1', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'c5_1', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'sc5_1', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'o5_1', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'so5_1', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'f5_1', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'g5_1', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 's5_1', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'str5_1', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'd5_1', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'p5_1', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'c5_1', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'sc5_1', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'o5_1', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'so5_1', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'f5_1', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'g5_1', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 's5_1', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'str5_1', 'strain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'd5_2', 'domain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'p5_2', 'phylum'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'c5_2', 'class'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'sc5_2', 'subclass'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'o5_2', 'order'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'so5_2', 'suborder'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'f5_2', 'family'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'g5_2', 'genus'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 's5_2', 'species'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'str5_2', 'strain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'd6_1', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'p6_1', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'c6_1', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'sc6_1', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'o6_1', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'so6_1', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'f6_1', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'g6_1', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 's6_1', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'str6_1', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'd6_1', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'p6_1', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'c6_1', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'sc6_1', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'o6_1', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'so6_1', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'f6_1', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'g6_1', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 's6_1', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'str6_1', 'strain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'd6_2', 'domain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'p6_2', 'phylum'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'c6_2', 'class'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'sc6_2', 'subclass'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'o6_2', 'order'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'so6_2', 'suborder'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'f6_2', 'family'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'g6_2', 'genus'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 's6_2', 'species'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'str6_2', 'strain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'd7_1', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'p7_1', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'c7_1', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'sc7_1', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'o7_1', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'so7_1', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'f7_1', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'g7_1', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 's7_1', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'str7_1', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'd7_1', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'p7_1', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'c7_1', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'sc7_1', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'o7_1', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'so7_1', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'f7_1', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'g7_1', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 's7_1', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'str7_1', 'strain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'd7_2', 'domain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'p7_2', 'phylum'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'c7_2', 'class'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'sc7_2', 'subclass'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'o7_2', 'order'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'so7_2', 'suborder'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'f7_2', 'family'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'g7_2', 'genus'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 's7_2', 'species'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'str7_2', 'strain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'd8_1', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'p8_1', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'c8_1', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'sc8_1', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'o8_1', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'so8_1', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'f8_1', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'g8_1', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 's8_1', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'str8_1', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'd8_1', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'p8_1', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'c8_1', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'sc8_1', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'o8_1', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'so8_1', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'f8_1', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'g8_1', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 's8_1', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'str8_1', 'strain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'd8_2', 'domain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'p8_2', 'phylum'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'c8_2', 'class'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'sc8_2', 'subclass'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'o8_2', 'order'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'so8_2', 'suborder'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'f8_2', 'family'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'g8_2', 'genus'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 's8_2', 'species'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'str8_2', 'strain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'd9_1', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'p9_1', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'c9_1', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'sc9_1', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'o9_1', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'so9_1', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'f9_1', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'g9_1', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 's9_1', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'str9_1', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'd9_1', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'p9_1', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'c9_1', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'sc9_1', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'o9_1', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'so9_1', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'f9_1', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'g9_1', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 's9_1', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'str9_1', 'strain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'd9_2', 'domain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'p9_2', 'phylum'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'c9_2', 'class'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'sc9_2', 'subclass'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'o9_2', 'order'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'so9_2', 'suborder'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'f9_2', 'family'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'g9_2', 'genus'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 's9_2', 'species'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'str9_2', 'strain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		
	];
	# additional new classifications:
	# run * barcode *: read 1: FILTERED; read 2: classification from read 1
	my $expecClass_updatedR = [
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'd10_1', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'p10_1', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'c10_1', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'sc10_1', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'o10_1', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'so10_1', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'f10_1', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'g10_1', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 's10_1', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'str10_1', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'd10_1', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'p10_1', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'c10_1', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'sc10_1', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'o10_1', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'so10_1', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'f10_1', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'g10_1', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 's10_1', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'str10_1', 'strain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'd10_2', 'domain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'p10_2', 'phylum'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'c10_2', 'class'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'sc10_2', 'subclass'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'o10_2', 'order'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'so10_2', 'suborder'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'f10_2', 'family'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'g10_2', 'genus'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 's10_2', 'species'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'str10_2', 'strain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'd10_2', 'domain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'p10_2', 'phylum'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'c10_2', 'class'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'sc10_2', 'subclass'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'o10_2', 'order'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'so10_2', 'suborder'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'f10_2', 'family'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'g10_2', 'genus'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 's10_2', 'species'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'str10_2', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'd11_1', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'p11_1', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'c11_1', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'sc11_1', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'o11_1', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'so11_1', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'f11_1', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'g11_1', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 's11_1', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'str11_1', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'd11_1', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'p11_1', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'c11_1', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'sc11_1', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'o11_1', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'so11_1', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'f11_1', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'g11_1', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 's11_1', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'str11_1', 'strain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'd11_2', 'domain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'p11_2', 'phylum'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'c11_2', 'class'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'sc11_2', 'subclass'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'o11_2', 'order'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'so11_2', 'suborder'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'f11_2', 'family'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'g11_2', 'genus'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 's11_2', 'species'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'str11_2', 'strain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'd11_2', 'domain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'p11_2', 'phylum'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'c11_2', 'class'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'sc11_2', 'subclass'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'o11_2', 'order'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'so11_2', 'suborder'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'f11_2', 'family'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'g11_2', 'genus'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 's11_2', 'species'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'str11_2', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'd1_2', 'domain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'p1_2', 'phylum'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'c1_2', 'class'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'sc1_2', 'subclass'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'o1_2', 'order'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'so1_2', 'suborder'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'f1_2', 'family'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'g1_2', 'genus'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 's1_2', 'species'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'str1_2', 'strain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'd1_2', 'domain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'p1_2', 'phylum'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'c1_2', 'class'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'sc1_2', 'subclass'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'o1_2', 'order'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'so1_2', 'suborder'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'f1_2', 'family'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'g1_2', 'genus'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 's1_2', 'species'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'str1_2', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'd2_1', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'p2_1', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'c2_1', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'sc2_1', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'o2_1', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'so2_1', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'f2_1', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'g2_1', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 's2_1', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'str2_1', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'd2_1', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'p2_1', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'c2_1', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'sc2_1', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'o2_1', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'so2_1', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'f2_1', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'g2_1', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 's2_1', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'str2_1', 'strain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'd2_2', 'domain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'p2_2', 'phylum'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'c2_2', 'class'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'sc2_2', 'subclass'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'o2_2', 'order'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'so2_2', 'suborder'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'f2_2', 'family'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'g2_2', 'genus'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 's2_2', 'species'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'str2_2', 'strain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'd2_2', 'domain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'p2_2', 'phylum'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'c2_2', 'class'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'sc2_2', 'subclass'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'o2_2', 'order'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'so2_2', 'suborder'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'f2_2', 'family'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'g2_2', 'genus'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 's2_2', 'species'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'str2_2', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'd3_1', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'p3_1', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'c3_1', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'sc3_1', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'o3_1', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'so3_1', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'f3_1', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'g3_1', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 's3_1', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'str3_1', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'd3_1', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'p3_1', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'c3_1', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'sc3_1', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'o3_1', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'so3_1', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'f3_1', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'g3_1', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 's3_1', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'str3_1', 'strain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'd3_2', 'domain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'p3_2', 'phylum'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'c3_2', 'class'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'sc3_2', 'subclass'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'o3_2', 'order'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'so3_2', 'suborder'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'f3_2', 'family'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'g3_2', 'genus'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 's3_2', 'species'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'str3_2', 'strain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'd3_2', 'domain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'p3_2', 'phylum'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'c3_2', 'class'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'sc3_2', 'subclass'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'o3_2', 'order'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'so3_2', 'suborder'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'f3_2', 'family'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'g3_2', 'genus'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 's3_2', 'species'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'str3_2', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'd4_1', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'p4_1', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'c4_1', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'sc4_1', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'o4_1', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'so4_1', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'f4_1', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'g4_1', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 's4_1', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'str4_1', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'd4_1', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'p4_1', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'c4_1', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'sc4_1', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'o4_1', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'so4_1', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'f4_1', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'g4_1', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 's4_1', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'str4_1', 'strain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'd4_2', 'domain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'p4_2', 'phylum'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'c4_2', 'class'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'sc4_2', 'subclass'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'o4_2', 'order'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'so4_2', 'suborder'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'f4_2', 'family'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'g4_2', 'genus'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 's4_2', 'species'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'str4_2', 'strain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'd4_2', 'domain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'p4_2', 'phylum'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'c4_2', 'class'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'sc4_2', 'subclass'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'o4_2', 'order'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'so4_2', 'suborder'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'f4_2', 'family'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'g4_2', 'genus'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 's4_2', 'species'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'str4_2', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'd5_1', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'p5_1', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'c5_1', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'sc5_1', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'o5_1', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'so5_1', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'f5_1', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'g5_1', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 's5_1', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'str5_1', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'd5_1', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'p5_1', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'c5_1', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'sc5_1', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'o5_1', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'so5_1', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'f5_1', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'g5_1', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 's5_1', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'str5_1', 'strain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'd5_2', 'domain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'p5_2', 'phylum'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'c5_2', 'class'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'sc5_2', 'subclass'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'o5_2', 'order'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'so5_2', 'suborder'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'f5_2', 'family'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'g5_2', 'genus'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 's5_2', 'species'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'str5_2', 'strain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'd5_2', 'domain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'p5_2', 'phylum'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'c5_2', 'class'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'sc5_2', 'subclass'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'o5_2', 'order'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'so5_2', 'suborder'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'f5_2', 'family'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'g5_2', 'genus'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 's5_2', 'species'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'str5_2', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'd6_1', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'p6_1', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'c6_1', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'sc6_1', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'o6_1', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'so6_1', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'f6_1', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'g6_1', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 's6_1', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'str6_1', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'd6_1', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'p6_1', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'c6_1', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'sc6_1', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'o6_1', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'so6_1', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'f6_1', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'g6_1', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 's6_1', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'str6_1', 'strain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'd6_2', 'domain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'p6_2', 'phylum'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'c6_2', 'class'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'sc6_2', 'subclass'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'o6_2', 'order'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'so6_2', 'suborder'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'f6_2', 'family'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'g6_2', 'genus'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 's6_2', 'species'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'str6_2', 'strain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'd6_2', 'domain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'p6_2', 'phylum'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'c6_2', 'class'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'sc6_2', 'subclass'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'o6_2', 'order'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'so6_2', 'suborder'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'f6_2', 'family'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'g6_2', 'genus'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 's6_2', 'species'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'str6_2', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'd7_1', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'p7_1', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'c7_1', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'sc7_1', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'o7_1', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'so7_1', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'f7_1', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'g7_1', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 's7_1', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'str7_1', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'd7_1', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'p7_1', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'c7_1', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'sc7_1', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'o7_1', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'so7_1', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'f7_1', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'g7_1', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 's7_1', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'str7_1', 'strain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'd7_2', 'domain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'p7_2', 'phylum'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'c7_2', 'class'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'sc7_2', 'subclass'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'o7_2', 'order'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'so7_2', 'suborder'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'f7_2', 'family'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'g7_2', 'genus'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 's7_2', 'species'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'str7_2', 'strain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'd7_2', 'domain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'p7_2', 'phylum'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'c7_2', 'class'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'sc7_2', 'subclass'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'o7_2', 'order'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'so7_2', 'suborder'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'f7_2', 'family'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'g7_2', 'genus'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 's7_2', 'species'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'str7_2', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'd8_1', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'p8_1', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'c8_1', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'sc8_1', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'o8_1', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'so8_1', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'f8_1', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'g8_1', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 's8_1', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'str8_1', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'd8_1', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'p8_1', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'c8_1', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'sc8_1', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'o8_1', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'so8_1', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'f8_1', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'g8_1', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 's8_1', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'str8_1', 'strain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'd8_2', 'domain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'p8_2', 'phylum'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'c8_2', 'class'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'sc8_2', 'subclass'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'o8_2', 'order'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'so8_2', 'suborder'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'f8_2', 'family'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'g8_2', 'genus'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 's8_2', 'species'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'str8_2', 'strain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'd8_2', 'domain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'p8_2', 'phylum'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'c8_2', 'class'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'sc8_2', 'subclass'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'o8_2', 'order'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'so8_2', 'suborder'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'f8_2', 'family'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'g8_2', 'genus'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 's8_2', 'species'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'str8_2', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'd9_1', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'p9_1', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'c9_1', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'sc9_1', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'o9_1', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'so9_1', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'f9_1', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'g9_1', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 's9_1', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'str9_1', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'd9_1', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'p9_1', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'c9_1', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'sc9_1', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'o9_1', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'so9_1', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'f9_1', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'g9_1', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 's9_1', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'str9_1', 'strain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'd9_2', 'domain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'p9_2', 'phylum'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'c9_2', 'class'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'sc9_2', 'subclass'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'o9_2', 'order'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'so9_2', 'suborder'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'f9_2', 'family'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'g9_2', 'genus'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 's9_2', 'species'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'str9_2', 'strain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'd9_2', 'domain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'p9_2', 'phylum'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'c9_2', 'class'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'sc9_2', 'subclass'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'o9_2', 'order'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'so9_2', 'suborder'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'f9_2', 'family'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'g9_2', 'genus'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 's9_2', 'species'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'str9_2', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'UNMATCHED', 'strain']
	];
	# additional new classifications with database MTX:
	# run 1 barcode 1: read 1: FILTERED; read 2: classification from read 1 RDP
	# run 1 barcode 99: read 1: FILTERED; read 2: classification from read 1 RDP
	my $expecClass_updatedClassDb_oneSamplR = [
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'd10_1', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'p10_1', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'c10_1', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'sc10_1', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'o10_1', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'so10_1', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'f10_1', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'g10_1', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 's10_1', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'str10_1', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'd10_2', 'domain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'p10_2', 'phylum'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'c10_2', 'class'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'sc10_2', 'subclass'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'o10_2', 'order'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'so10_2', 'suborder'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'f10_2', 'family'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'g10_2', 'genus'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 's10_2', 'species'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'str10_2', 'strain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'd11_1', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'p11_1', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'c11_1', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'sc11_1', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'o11_1', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'so11_1', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'f11_1', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'g11_1', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 's11_1', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'str11_1', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'd11_2', 'domain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'p11_2', 'phylum'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'c11_2', 'class'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'sc11_2', 'subclass'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'o11_2', 'order'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'so11_2', 'suborder'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'f11_2', 'family'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'g11_2', 'genus'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 's11_2', 'species'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'str11_2', 'strain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'd1_1', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'p1_1', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'c1_1', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'sc1_1', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'o1_1', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'so1_1', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'f1_1', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'g1_1', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 's1_1', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'd1_2', 'domain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'p1_2', 'phylum'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'c1_2', 'class'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'sc1_2', 'subclass'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'o1_2', 'order'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'so1_2', 'suborder'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'f1_2', 'family'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'g1_2', 'genus'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 's1_2', 'species'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'str1_2', 'strain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'd2_1', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'p2_1', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'c2_1', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'sc2_1', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'o2_1', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'so2_1', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'f2_1', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'g2_1', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 's2_1', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'str2_1', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'd2_2', 'domain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'p2_2', 'phylum'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'c2_2', 'class'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'sc2_2', 'subclass'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'o2_2', 'order'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'so2_2', 'suborder'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'f2_2', 'family'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'g2_2', 'genus'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 's2_2', 'species'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'str2_2', 'strain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'd3_1', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'p3_1', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'c3_1', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'sc3_1', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'o3_1', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'so3_1', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'f3_1', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'g3_1', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 's3_1', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'str3_1', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'd3_2', 'domain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'p3_2', 'phylum'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'c3_2', 'class'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'sc3_2', 'subclass'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'o3_2', 'order'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'so3_2', 'suborder'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'f3_2', 'family'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'g3_2', 'genus'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 's3_2', 'species'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'str3_2', 'strain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'd4_1', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'p4_1', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'c4_1', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'sc4_1', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'o4_1', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'so4_1', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'f4_1', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'g4_1', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 's4_1', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'str4_1', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'd4_2', 'domain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'p4_2', 'phylum'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'c4_2', 'class'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'sc4_2', 'subclass'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'o4_2', 'order'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'so4_2', 'suborder'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'f4_2', 'family'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'g4_2', 'genus'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 's4_2', 'species'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'str4_2', 'strain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'd5_1', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'p5_1', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'c5_1', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'sc5_1', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'o5_1', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'so5_1', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'f5_1', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'g5_1', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 's5_1', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'str5_1', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'd5_2', 'domain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'p5_2', 'phylum'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'c5_2', 'class'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'sc5_2', 'subclass'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'o5_2', 'order'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'so5_2', 'suborder'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'f5_2', 'family'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'g5_2', 'genus'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 's5_2', 'species'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'str5_2', 'strain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'd6_1', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'p6_1', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'c6_1', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'sc6_1', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'o6_1', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'so6_1', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'f6_1', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'g6_1', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 's6_1', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'str6_1', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'd6_2', 'domain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'p6_2', 'phylum'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'c6_2', 'class'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'sc6_2', 'subclass'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'o6_2', 'order'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'so6_2', 'suborder'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'f6_2', 'family'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'g6_2', 'genus'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 's6_2', 'species'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'str6_2', 'strain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'd7_1', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'p7_1', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'c7_1', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'sc7_1', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'o7_1', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'so7_1', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'f7_1', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'g7_1', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 's7_1', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'str7_1', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'd7_2', 'domain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'p7_2', 'phylum'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'c7_2', 'class'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'sc7_2', 'subclass'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'o7_2', 'order'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'so7_2', 'suborder'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'f7_2', 'family'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'g7_2', 'genus'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 's7_2', 'species'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'str7_2', 'strain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'd8_1', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'p8_1', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'c8_1', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'sc8_1', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'o8_1', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'so8_1', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'f8_1', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'g8_1', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 's8_1', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'str8_1', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'd8_2', 'domain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'p8_2', 'phylum'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'c8_2', 'class'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'sc8_2', 'subclass'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'o8_2', 'order'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'so8_2', 'suborder'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'f8_2', 'family'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'g8_2', 'genus'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 's8_2', 'species'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'str8_2', 'strain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'd9_1', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'p9_1', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'c9_1', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'sc9_1', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'o9_1', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'so9_1', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'f9_1', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'g9_1', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 's9_1', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'str9_1', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'd9_2', 'domain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'p9_2', 'phylum'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'c9_2', 'class'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'sc9_2', 'subclass'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'o9_2', 'order'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'so9_2', 'suborder'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'f9_2', 'family'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'g9_2', 'genus'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 's9_2', 'species'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'str9_2', 'strain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain']
	];
	my $expecClass_updatedClassDb_onePatR = [
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'd10_1', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'p10_1', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'c10_1', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'sc10_1', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'o10_1', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'so10_1', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'f10_1', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'g10_1', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 's10_1', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'str10_1', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'd10_1', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'p10_1', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'c10_1', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'sc10_1', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'o10_1', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'so10_1', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'f10_1', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'g10_1', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 's10_1', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'str10_1', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'd10_2', 'domain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'p10_2', 'phylum'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'c10_2', 'class'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'sc10_2', 'subclass'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'o10_2', 'order'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'so10_2', 'suborder'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'f10_2', 'family'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'g10_2', 'genus'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 's10_2', 'species'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'str10_2', 'strain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'd11_1', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'p11_1', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'c11_1', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'sc11_1', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'o11_1', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'so11_1', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'f11_1', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'g11_1', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 's11_1', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'str11_1', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'd11_1', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'p11_1', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'c11_1', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'sc11_1', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'o11_1', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'so11_1', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'f11_1', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'g11_1', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 's11_1', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'str11_1', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'd11_2', 'domain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'p11_2', 'phylum'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'c11_2', 'class'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'sc11_2', 'subclass'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'o11_2', 'order'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'so11_2', 'suborder'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'f11_2', 'family'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'g11_2', 'genus'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 's11_2', 'species'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'str11_2', 'strain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'd1_1', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'p1_1', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'c1_1', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'sc1_1', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'o1_1', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'so1_1', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'f1_1', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'g1_1', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 's1_1', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'd1_2', 'domain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'p1_2', 'phylum'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'c1_2', 'class'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'sc1_2', 'subclass'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'o1_2', 'order'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'so1_2', 'suborder'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'f1_2', 'family'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'g1_2', 'genus'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 's1_2', 'species'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'str1_2', 'strain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'd2_1', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'p2_1', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'c2_1', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'sc2_1', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'o2_1', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'so2_1', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'f2_1', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'g2_1', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 's2_1', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'str2_1', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'd2_1', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'p2_1', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'c2_1', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'sc2_1', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'o2_1', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'so2_1', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'f2_1', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'g2_1', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 's2_1', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'str2_1', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'd2_2', 'domain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'p2_2', 'phylum'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'c2_2', 'class'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'sc2_2', 'subclass'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'o2_2', 'order'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'so2_2', 'suborder'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'f2_2', 'family'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'g2_2', 'genus'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 's2_2', 'species'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'str2_2', 'strain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'd3_1', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'p3_1', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'c3_1', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'sc3_1', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'o3_1', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'so3_1', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'f3_1', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'g3_1', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 's3_1', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'str3_1', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'd3_1', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'p3_1', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'c3_1', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'sc3_1', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'o3_1', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'so3_1', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'f3_1', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'g3_1', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 's3_1', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'str3_1', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'd3_2', 'domain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'p3_2', 'phylum'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'c3_2', 'class'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'sc3_2', 'subclass'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'o3_2', 'order'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'so3_2', 'suborder'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'f3_2', 'family'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'g3_2', 'genus'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 's3_2', 'species'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'str3_2', 'strain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'd4_1', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'p4_1', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'c4_1', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'sc4_1', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'o4_1', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'so4_1', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'f4_1', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'g4_1', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 's4_1', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'str4_1', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'd4_1', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'p4_1', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'c4_1', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'sc4_1', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'o4_1', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'so4_1', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'f4_1', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'g4_1', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 's4_1', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'str4_1', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'd4_2', 'domain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'p4_2', 'phylum'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'c4_2', 'class'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'sc4_2', 'subclass'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'o4_2', 'order'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'so4_2', 'suborder'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'f4_2', 'family'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'g4_2', 'genus'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 's4_2', 'species'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'str4_2', 'strain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'd5_1', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'p5_1', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'c5_1', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'sc5_1', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'o5_1', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'so5_1', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'f5_1', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'g5_1', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 's5_1', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'str5_1', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'd5_1', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'p5_1', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'c5_1', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'sc5_1', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'o5_1', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'so5_1', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'f5_1', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'g5_1', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 's5_1', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'str5_1', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'd5_2', 'domain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'p5_2', 'phylum'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'c5_2', 'class'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'sc5_2', 'subclass'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'o5_2', 'order'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'so5_2', 'suborder'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'f5_2', 'family'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'g5_2', 'genus'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 's5_2', 'species'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'str5_2', 'strain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'd6_1', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'p6_1', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'c6_1', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'sc6_1', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'o6_1', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'so6_1', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'f6_1', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'g6_1', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 's6_1', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'str6_1', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'd6_1', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'p6_1', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'c6_1', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'sc6_1', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'o6_1', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'so6_1', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'f6_1', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'g6_1', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 's6_1', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'str6_1', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'd6_2', 'domain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'p6_2', 'phylum'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'c6_2', 'class'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'sc6_2', 'subclass'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'o6_2', 'order'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'so6_2', 'suborder'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'f6_2', 'family'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'g6_2', 'genus'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 's6_2', 'species'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'str6_2', 'strain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'd7_1', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'p7_1', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'c7_1', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'sc7_1', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'o7_1', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'so7_1', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'f7_1', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'g7_1', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 's7_1', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'str7_1', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'd7_1', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'p7_1', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'c7_1', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'sc7_1', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'o7_1', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'so7_1', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'f7_1', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'g7_1', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 's7_1', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'str7_1', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'd7_2', 'domain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'p7_2', 'phylum'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'c7_2', 'class'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'sc7_2', 'subclass'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'o7_2', 'order'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'so7_2', 'suborder'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'f7_2', 'family'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'g7_2', 'genus'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 's7_2', 'species'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'str7_2', 'strain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'd8_1', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'p8_1', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'c8_1', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'sc8_1', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'o8_1', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'so8_1', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'f8_1', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'g8_1', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 's8_1', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'str8_1', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'd8_1', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'p8_1', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'c8_1', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'sc8_1', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'o8_1', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'so8_1', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'f8_1', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'g8_1', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 's8_1', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'str8_1', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'd8_2', 'domain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'p8_2', 'phylum'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'c8_2', 'class'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'sc8_2', 'subclass'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'o8_2', 'order'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'so8_2', 'suborder'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'f8_2', 'family'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'g8_2', 'genus'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 's8_2', 'species'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'str8_2', 'strain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'd9_1', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'p9_1', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'c9_1', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'sc9_1', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'o9_1', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'so9_1', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'f9_1', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'g9_1', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 's9_1', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'str9_1', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'd9_1', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'p9_1', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'c9_1', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'sc9_1', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'o9_1', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'so9_1', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'f9_1', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'g9_1', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 's9_1', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'str9_1', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'd9_2', 'domain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'p9_2', 'phylum'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'c9_2', 'class'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'sc9_2', 'subclass'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'o9_2', 'order'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'so9_2', 'suborder'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'f9_2', 'family'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'g9_2', 'genus'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 's9_2', 'species'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'str9_2', 'strain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain']
	];
	my $expecClass_updatedClassDbR = [
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'd10_1', 'domain'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'p10_1', 'phylum'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'c10_1', 'class'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'sc10_1', 'subclass'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'o10_1', 'order'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'so10_1', 'suborder'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'f10_1', 'family'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'g10_1', 'genus'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 's10_1', 'species'],
		['10', '1', '10_1_1', 'MetaG', 'RDP', 'str10_1', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'd10_1', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'p10_1', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'c10_1', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'sc10_1', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'o10_1', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'so10_1', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'f10_1', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'g10_1', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 's10_1', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'MTX', 'str10_1', 'strain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '1', '10_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '2', '10_2_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['10', '2', '10_2_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['10', '2', '10_2_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['10', '2', '10_2_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['10', '2', '10_2_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['10', '2', '10_2_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['10', '2', '10_2_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['10', '2', '10_2_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['10', '2', '10_2_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['10', '2', '10_2_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'd10_2', 'domain'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'p10_2', 'phylum'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'c10_2', 'class'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'sc10_2', 'subclass'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'o10_2', 'order'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'so10_2', 'suborder'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'f10_2', 'family'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'g10_2', 'genus'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 's10_2', 'species'],
		['10', '2', '10_2_1', 'MetaG', 'RDP', 'str10_2', 'strain'],
		['10', '2', '10_2_2', 'MetaG', 'MTX', 'd10_2', 'domain'],
		['10', '2', '10_2_2', 'MetaG', 'MTX', 'p10_2', 'phylum'],
		['10', '2', '10_2_2', 'MetaG', 'MTX', 'c10_2', 'class'],
		['10', '2', '10_2_2', 'MetaG', 'MTX', 'sc10_2', 'subclass'],
		['10', '2', '10_2_2', 'MetaG', 'MTX', 'o10_2', 'order'],
		['10', '2', '10_2_2', 'MetaG', 'MTX', 'so10_2', 'suborder'],
		['10', '2', '10_2_2', 'MetaG', 'MTX', 'f10_2', 'family'],
		['10', '2', '10_2_2', 'MetaG', 'MTX', 'g10_2', 'genus'],
		['10', '2', '10_2_2', 'MetaG', 'MTX', 's10_2', 'species'],
		['10', '2', '10_2_2', 'MetaG', 'MTX', 'str10_2', 'strain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '2', '10_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['10', '99', '10_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'd11_1', 'domain'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'p11_1', 'phylum'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'c11_1', 'class'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'sc11_1', 'subclass'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'o11_1', 'order'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'so11_1', 'suborder'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'f11_1', 'family'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'g11_1', 'genus'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 's11_1', 'species'],
		['11', '1', '11_1_1', 'MetaG', 'RDP', 'str11_1', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'd11_1', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'p11_1', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'c11_1', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'sc11_1', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'o11_1', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'so11_1', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'f11_1', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'g11_1', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 's11_1', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'MTX', 'str11_1', 'strain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '1', '11_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '2', '11_2_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['11', '2', '11_2_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['11', '2', '11_2_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['11', '2', '11_2_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['11', '2', '11_2_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['11', '2', '11_2_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['11', '2', '11_2_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['11', '2', '11_2_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['11', '2', '11_2_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['11', '2', '11_2_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'd11_2', 'domain'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'p11_2', 'phylum'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'c11_2', 'class'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'sc11_2', 'subclass'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'o11_2', 'order'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'so11_2', 'suborder'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'f11_2', 'family'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'g11_2', 'genus'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 's11_2', 'species'],
		['11', '2', '11_2_1', 'MetaG', 'RDP', 'str11_2', 'strain'],
		['11', '2', '11_2_2', 'MetaG', 'MTX', 'd11_2', 'domain'],
		['11', '2', '11_2_2', 'MetaG', 'MTX', 'p11_2', 'phylum'],
		['11', '2', '11_2_2', 'MetaG', 'MTX', 'c11_2', 'class'],
		['11', '2', '11_2_2', 'MetaG', 'MTX', 'sc11_2', 'subclass'],
		['11', '2', '11_2_2', 'MetaG', 'MTX', 'o11_2', 'order'],
		['11', '2', '11_2_2', 'MetaG', 'MTX', 'so11_2', 'suborder'],
		['11', '2', '11_2_2', 'MetaG', 'MTX', 'f11_2', 'family'],
		['11', '2', '11_2_2', 'MetaG', 'MTX', 'g11_2', 'genus'],
		['11', '2', '11_2_2', 'MetaG', 'MTX', 's11_2', 'species'],
		['11', '2', '11_2_2', 'MetaG', 'MTX', 'str11_2', 'strain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '2', '11_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['11', '99', '11_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'd1_1', 'domain'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'p1_1', 'phylum'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'c1_1', 'class'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'sc1_1', 'subclass'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'o1_1', 'order'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'so1_1', 'suborder'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'f1_1', 'family'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'g1_1', 'genus'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 's1_1', 'species'],
		['1', '1', '1_1_1', 'MetaG', 'RDP', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'd1_1', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'p1_1', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'c1_1', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'sc1_1', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'o1_1', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'so1_1', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'f1_1', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'g1_1', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 's1_1', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'MTX', 'str1_1', 'strain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '1', '1_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '2', '1_2_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['1', '2', '1_2_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['1', '2', '1_2_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['1', '2', '1_2_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['1', '2', '1_2_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['1', '2', '1_2_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['1', '2', '1_2_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['1', '2', '1_2_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['1', '2', '1_2_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['1', '2', '1_2_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'd1_2', 'domain'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'p1_2', 'phylum'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'c1_2', 'class'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'sc1_2', 'subclass'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'o1_2', 'order'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'so1_2', 'suborder'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'f1_2', 'family'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'g1_2', 'genus'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 's1_2', 'species'],
		['1', '2', '1_2_1', 'MetaG', 'RDP', 'str1_2', 'strain'],
		['1', '2', '1_2_2', 'MetaG', 'MTX', 'd1_2', 'domain'],
		['1', '2', '1_2_2', 'MetaG', 'MTX', 'p1_2', 'phylum'],
		['1', '2', '1_2_2', 'MetaG', 'MTX', 'c1_2', 'class'],
		['1', '2', '1_2_2', 'MetaG', 'MTX', 'sc1_2', 'subclass'],
		['1', '2', '1_2_2', 'MetaG', 'MTX', 'o1_2', 'order'],
		['1', '2', '1_2_2', 'MetaG', 'MTX', 'so1_2', 'suborder'],
		['1', '2', '1_2_2', 'MetaG', 'MTX', 'f1_2', 'family'],
		['1', '2', '1_2_2', 'MetaG', 'MTX', 'g1_2', 'genus'],
		['1', '2', '1_2_2', 'MetaG', 'MTX', 's1_2', 'species'],
		['1', '2', '1_2_2', 'MetaG', 'MTX', 'str1_2', 'strain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '2', '1_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['1', '99', '1_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],	
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'd2_1', 'domain'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'p2_1', 'phylum'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'c2_1', 'class'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'sc2_1', 'subclass'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'o2_1', 'order'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'so2_1', 'suborder'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'f2_1', 'family'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'g2_1', 'genus'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 's2_1', 'species'],
		['2', '1', '2_1_1', 'MetaG', 'RDP', 'str2_1', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'd2_1', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'p2_1', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'c2_1', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'sc2_1', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'o2_1', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'so2_1', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'f2_1', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'g2_1', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 's2_1', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'MTX', 'str2_1', 'strain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '1', '2_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '2', '2_2_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['2', '2', '2_2_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['2', '2', '2_2_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['2', '2', '2_2_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['2', '2', '2_2_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['2', '2', '2_2_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['2', '2', '2_2_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['2', '2', '2_2_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['2', '2', '2_2_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['2', '2', '2_2_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'd2_2', 'domain'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'p2_2', 'phylum'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'c2_2', 'class'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'sc2_2', 'subclass'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'o2_2', 'order'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'so2_2', 'suborder'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'f2_2', 'family'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'g2_2', 'genus'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 's2_2', 'species'],
		['2', '2', '2_2_1', 'MetaG', 'RDP', 'str2_2', 'strain'],
		['2', '2', '2_2_2', 'MetaG', 'MTX', 'd2_2', 'domain'],
		['2', '2', '2_2_2', 'MetaG', 'MTX', 'p2_2', 'phylum'],
		['2', '2', '2_2_2', 'MetaG', 'MTX', 'c2_2', 'class'],
		['2', '2', '2_2_2', 'MetaG', 'MTX', 'sc2_2', 'subclass'],
		['2', '2', '2_2_2', 'MetaG', 'MTX', 'o2_2', 'order'],
		['2', '2', '2_2_2', 'MetaG', 'MTX', 'so2_2', 'suborder'],
		['2', '2', '2_2_2', 'MetaG', 'MTX', 'f2_2', 'family'],
		['2', '2', '2_2_2', 'MetaG', 'MTX', 'g2_2', 'genus'],
		['2', '2', '2_2_2', 'MetaG', 'MTX', 's2_2', 'species'],
		['2', '2', '2_2_2', 'MetaG', 'MTX', 'str2_2', 'strain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '2', '2_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['2', '99', '2_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'd3_1', 'domain'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'p3_1', 'phylum'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'c3_1', 'class'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'sc3_1', 'subclass'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'o3_1', 'order'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'so3_1', 'suborder'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'f3_1', 'family'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'g3_1', 'genus'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 's3_1', 'species'],
		['3', '1', '3_1_1', 'MetaG', 'RDP', 'str3_1', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'd3_1', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'p3_1', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'c3_1', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'sc3_1', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'o3_1', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'so3_1', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'f3_1', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'g3_1', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 's3_1', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'MTX', 'str3_1', 'strain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '1', '3_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '2', '3_2_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['3', '2', '3_2_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['3', '2', '3_2_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['3', '2', '3_2_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['3', '2', '3_2_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['3', '2', '3_2_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['3', '2', '3_2_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['3', '2', '3_2_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['3', '2', '3_2_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['3', '2', '3_2_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'd3_2', 'domain'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'p3_2', 'phylum'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'c3_2', 'class'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'sc3_2', 'subclass'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'o3_2', 'order'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'so3_2', 'suborder'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'f3_2', 'family'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'g3_2', 'genus'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 's3_2', 'species'],
		['3', '2', '3_2_1', 'MetaG', 'RDP', 'str3_2', 'strain'],
		['3', '2', '3_2_2', 'MetaG', 'MTX', 'd3_2', 'domain'],
		['3', '2', '3_2_2', 'MetaG', 'MTX', 'p3_2', 'phylum'],
		['3', '2', '3_2_2', 'MetaG', 'MTX', 'c3_2', 'class'],
		['3', '2', '3_2_2', 'MetaG', 'MTX', 'sc3_2', 'subclass'],
		['3', '2', '3_2_2', 'MetaG', 'MTX', 'o3_2', 'order'],
		['3', '2', '3_2_2', 'MetaG', 'MTX', 'so3_2', 'suborder'],
		['3', '2', '3_2_2', 'MetaG', 'MTX', 'f3_2', 'family'],
		['3', '2', '3_2_2', 'MetaG', 'MTX', 'g3_2', 'genus'],
		['3', '2', '3_2_2', 'MetaG', 'MTX', 's3_2', 'species'],
		['3', '2', '3_2_2', 'MetaG', 'MTX', 'str3_2', 'strain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '2', '3_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['3', '99', '3_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'd4_1', 'domain'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'p4_1', 'phylum'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'c4_1', 'class'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'sc4_1', 'subclass'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'o4_1', 'order'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'so4_1', 'suborder'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'f4_1', 'family'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'g4_1', 'genus'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 's4_1', 'species'],
		['4', '1', '4_1_1', 'MetaG', 'RDP', 'str4_1', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'd4_1', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'p4_1', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'c4_1', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'sc4_1', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'o4_1', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'so4_1', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'f4_1', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'g4_1', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 's4_1', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'MTX', 'str4_1', 'strain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '1', '4_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '2', '4_2_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['4', '2', '4_2_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['4', '2', '4_2_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['4', '2', '4_2_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['4', '2', '4_2_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['4', '2', '4_2_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['4', '2', '4_2_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['4', '2', '4_2_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['4', '2', '4_2_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['4', '2', '4_2_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'd4_2', 'domain'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'p4_2', 'phylum'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'c4_2', 'class'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'sc4_2', 'subclass'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'o4_2', 'order'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'so4_2', 'suborder'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'f4_2', 'family'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'g4_2', 'genus'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 's4_2', 'species'],
		['4', '2', '4_2_1', 'MetaG', 'RDP', 'str4_2', 'strain'],
		['4', '2', '4_2_2', 'MetaG', 'MTX', 'd4_2', 'domain'],
		['4', '2', '4_2_2', 'MetaG', 'MTX', 'p4_2', 'phylum'],
		['4', '2', '4_2_2', 'MetaG', 'MTX', 'c4_2', 'class'],
		['4', '2', '4_2_2', 'MetaG', 'MTX', 'sc4_2', 'subclass'],
		['4', '2', '4_2_2', 'MetaG', 'MTX', 'o4_2', 'order'],
		['4', '2', '4_2_2', 'MetaG', 'MTX', 'so4_2', 'suborder'],
		['4', '2', '4_2_2', 'MetaG', 'MTX', 'f4_2', 'family'],
		['4', '2', '4_2_2', 'MetaG', 'MTX', 'g4_2', 'genus'],
		['4', '2', '4_2_2', 'MetaG', 'MTX', 's4_2', 'species'],
		['4', '2', '4_2_2', 'MetaG', 'MTX', 'str4_2', 'strain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '2', '4_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['4', '99', '4_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'd5_1', 'domain'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'p5_1', 'phylum'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'c5_1', 'class'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'sc5_1', 'subclass'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'o5_1', 'order'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'so5_1', 'suborder'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'f5_1', 'family'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'g5_1', 'genus'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 's5_1', 'species'],
		['5', '1', '5_1_1', 'MetaG', 'RDP', 'str5_1', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'd5_1', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'p5_1', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'c5_1', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'sc5_1', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'o5_1', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'so5_1', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'f5_1', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'g5_1', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 's5_1', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'MTX', 'str5_1', 'strain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '1', '5_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '2', '5_2_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['5', '2', '5_2_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['5', '2', '5_2_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['5', '2', '5_2_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['5', '2', '5_2_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['5', '2', '5_2_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['5', '2', '5_2_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['5', '2', '5_2_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['5', '2', '5_2_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['5', '2', '5_2_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'd5_2', 'domain'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'p5_2', 'phylum'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'c5_2', 'class'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'sc5_2', 'subclass'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'o5_2', 'order'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'so5_2', 'suborder'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'f5_2', 'family'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'g5_2', 'genus'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 's5_2', 'species'],
		['5', '2', '5_2_1', 'MetaG', 'RDP', 'str5_2', 'strain'],
		['5', '2', '5_2_2', 'MetaG', 'MTX', 'd5_2', 'domain'],
		['5', '2', '5_2_2', 'MetaG', 'MTX', 'p5_2', 'phylum'],
		['5', '2', '5_2_2', 'MetaG', 'MTX', 'c5_2', 'class'],
		['5', '2', '5_2_2', 'MetaG', 'MTX', 'sc5_2', 'subclass'],
		['5', '2', '5_2_2', 'MetaG', 'MTX', 'o5_2', 'order'],
		['5', '2', '5_2_2', 'MetaG', 'MTX', 'so5_2', 'suborder'],
		['5', '2', '5_2_2', 'MetaG', 'MTX', 'f5_2', 'family'],
		['5', '2', '5_2_2', 'MetaG', 'MTX', 'g5_2', 'genus'],
		['5', '2', '5_2_2', 'MetaG', 'MTX', 's5_2', 'species'],
		['5', '2', '5_2_2', 'MetaG', 'MTX', 'str5_2', 'strain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '2', '5_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['5', '99', '5_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'd6_1', 'domain'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'p6_1', 'phylum'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'c6_1', 'class'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'sc6_1', 'subclass'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'o6_1', 'order'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'so6_1', 'suborder'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'f6_1', 'family'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'g6_1', 'genus'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 's6_1', 'species'],
		['6', '1', '6_1_1', 'MetaG', 'RDP', 'str6_1', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'd6_1', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'p6_1', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'c6_1', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'sc6_1', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'o6_1', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'so6_1', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'f6_1', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'g6_1', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 's6_1', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'MTX', 'str6_1', 'strain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '1', '6_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '2', '6_2_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['6', '2', '6_2_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['6', '2', '6_2_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['6', '2', '6_2_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['6', '2', '6_2_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['6', '2', '6_2_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['6', '2', '6_2_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['6', '2', '6_2_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['6', '2', '6_2_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['6', '2', '6_2_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'd6_2', 'domain'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'p6_2', 'phylum'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'c6_2', 'class'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'sc6_2', 'subclass'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'o6_2', 'order'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'so6_2', 'suborder'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'f6_2', 'family'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'g6_2', 'genus'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 's6_2', 'species'],
		['6', '2', '6_2_1', 'MetaG', 'RDP', 'str6_2', 'strain'],
		['6', '2', '6_2_2', 'MetaG', 'MTX', 'd6_2', 'domain'],
		['6', '2', '6_2_2', 'MetaG', 'MTX', 'p6_2', 'phylum'],
		['6', '2', '6_2_2', 'MetaG', 'MTX', 'c6_2', 'class'],
		['6', '2', '6_2_2', 'MetaG', 'MTX', 'sc6_2', 'subclass'],
		['6', '2', '6_2_2', 'MetaG', 'MTX', 'o6_2', 'order'],
		['6', '2', '6_2_2', 'MetaG', 'MTX', 'so6_2', 'suborder'],
		['6', '2', '6_2_2', 'MetaG', 'MTX', 'f6_2', 'family'],
		['6', '2', '6_2_2', 'MetaG', 'MTX', 'g6_2', 'genus'],
		['6', '2', '6_2_2', 'MetaG', 'MTX', 's6_2', 'species'],
		['6', '2', '6_2_2', 'MetaG', 'MTX', 'str6_2', 'strain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '2', '6_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['6', '99', '6_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'd7_1', 'domain'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'p7_1', 'phylum'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'c7_1', 'class'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'sc7_1', 'subclass'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'o7_1', 'order'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'so7_1', 'suborder'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'f7_1', 'family'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'g7_1', 'genus'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 's7_1', 'species'],
		['7', '1', '7_1_1', 'MetaG', 'RDP', 'str7_1', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'd7_1', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'p7_1', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'c7_1', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'sc7_1', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'o7_1', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'so7_1', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'f7_1', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'g7_1', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 's7_1', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'MTX', 'str7_1', 'strain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '1', '7_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '2', '7_2_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['7', '2', '7_2_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['7', '2', '7_2_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['7', '2', '7_2_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['7', '2', '7_2_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['7', '2', '7_2_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['7', '2', '7_2_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['7', '2', '7_2_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['7', '2', '7_2_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['7', '2', '7_2_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'd7_2', 'domain'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'p7_2', 'phylum'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'c7_2', 'class'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'sc7_2', 'subclass'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'o7_2', 'order'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'so7_2', 'suborder'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'f7_2', 'family'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'g7_2', 'genus'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 's7_2', 'species'],
		['7', '2', '7_2_1', 'MetaG', 'RDP', 'str7_2', 'strain'],
		['7', '2', '7_2_2', 'MetaG', 'MTX', 'd7_2', 'domain'],
		['7', '2', '7_2_2', 'MetaG', 'MTX', 'p7_2', 'phylum'],
		['7', '2', '7_2_2', 'MetaG', 'MTX', 'c7_2', 'class'],
		['7', '2', '7_2_2', 'MetaG', 'MTX', 'sc7_2', 'subclass'],
		['7', '2', '7_2_2', 'MetaG', 'MTX', 'o7_2', 'order'],
		['7', '2', '7_2_2', 'MetaG', 'MTX', 'so7_2', 'suborder'],
		['7', '2', '7_2_2', 'MetaG', 'MTX', 'f7_2', 'family'],
		['7', '2', '7_2_2', 'MetaG', 'MTX', 'g7_2', 'genus'],
		['7', '2', '7_2_2', 'MetaG', 'MTX', 's7_2', 'species'],
		['7', '2', '7_2_2', 'MetaG', 'MTX', 'str7_2', 'strain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '2', '7_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['7', '99', '7_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'd8_1', 'domain'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'p8_1', 'phylum'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'c8_1', 'class'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'sc8_1', 'subclass'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'o8_1', 'order'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'so8_1', 'suborder'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'f8_1', 'family'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'g8_1', 'genus'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 's8_1', 'species'],
		['8', '1', '8_1_1', 'MetaG', 'RDP', 'str8_1', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'd8_1', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'p8_1', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'c8_1', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'sc8_1', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'o8_1', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'so8_1', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'f8_1', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'g8_1', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 's8_1', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'MTX', 'str8_1', 'strain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '1', '8_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '2', '8_2_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['8', '2', '8_2_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['8', '2', '8_2_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['8', '2', '8_2_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['8', '2', '8_2_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['8', '2', '8_2_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['8', '2', '8_2_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['8', '2', '8_2_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['8', '2', '8_2_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['8', '2', '8_2_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'd8_2', 'domain'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'p8_2', 'phylum'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'c8_2', 'class'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'sc8_2', 'subclass'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'o8_2', 'order'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'so8_2', 'suborder'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'f8_2', 'family'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'g8_2', 'genus'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 's8_2', 'species'],
		['8', '2', '8_2_1', 'MetaG', 'RDP', 'str8_2', 'strain'],
		['8', '2', '8_2_2', 'MetaG', 'MTX', 'd8_2', 'domain'],
		['8', '2', '8_2_2', 'MetaG', 'MTX', 'p8_2', 'phylum'],
		['8', '2', '8_2_2', 'MetaG', 'MTX', 'c8_2', 'class'],
		['8', '2', '8_2_2', 'MetaG', 'MTX', 'sc8_2', 'subclass'],
		['8', '2', '8_2_2', 'MetaG', 'MTX', 'o8_2', 'order'],
		['8', '2', '8_2_2', 'MetaG', 'MTX', 'so8_2', 'suborder'],
		['8', '2', '8_2_2', 'MetaG', 'MTX', 'f8_2', 'family'],
		['8', '2', '8_2_2', 'MetaG', 'MTX', 'g8_2', 'genus'],
		['8', '2', '8_2_2', 'MetaG', 'MTX', 's8_2', 'species'],
		['8', '2', '8_2_2', 'MetaG', 'MTX', 'str8_2', 'strain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '2', '8_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['8', '99', '8_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'd9_1', 'domain'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'p9_1', 'phylum'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'c9_1', 'class'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'sc9_1', 'subclass'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'o9_1', 'order'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'so9_1', 'suborder'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'f9_1', 'family'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'g9_1', 'genus'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 's9_1', 'species'],
		['9', '1', '9_1_1', 'MetaG', 'RDP', 'str9_1', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'd9_1', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'p9_1', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'c9_1', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'sc9_1', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'o9_1', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'so9_1', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'f9_1', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'g9_1', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 's9_1', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'MTX', 'str9_1', 'strain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '1', '9_1_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '2', '9_2_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['9', '2', '9_2_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['9', '2', '9_2_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['9', '2', '9_2_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['9', '2', '9_2_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['9', '2', '9_2_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['9', '2', '9_2_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['9', '2', '9_2_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['9', '2', '9_2_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['9', '2', '9_2_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'd9_2', 'domain'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'p9_2', 'phylum'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'c9_2', 'class'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'sc9_2', 'subclass'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'o9_2', 'order'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'so9_2', 'suborder'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'f9_2', 'family'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'g9_2', 'genus'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 's9_2', 'species'],
		['9', '2', '9_2_1', 'MetaG', 'RDP', 'str9_2', 'strain'],
		['9', '2', '9_2_2', 'MetaG', 'MTX', 'd9_2', 'domain'],
		['9', '2', '9_2_2', 'MetaG', 'MTX', 'p9_2', 'phylum'],
		['9', '2', '9_2_2', 'MetaG', 'MTX', 'c9_2', 'class'],
		['9', '2', '9_2_2', 'MetaG', 'MTX', 'sc9_2', 'subclass'],
		['9', '2', '9_2_2', 'MetaG', 'MTX', 'o9_2', 'order'],
		['9', '2', '9_2_2', 'MetaG', 'MTX', 'so9_2', 'suborder'],
		['9', '2', '9_2_2', 'MetaG', 'MTX', 'f9_2', 'family'],
		['9', '2', '9_2_2', 'MetaG', 'MTX', 'g9_2', 'genus'],
		['9', '2', '9_2_2', 'MetaG', 'MTX', 's9_2', 'species'],
		['9', '2', '9_2_2', 'MetaG', 'MTX', 'str9_2', 'strain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '2', '9_2_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'MTX', 'FILTERED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'class'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'order'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'family'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'species'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_1', 'MetaG', 'RDP', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'MTX', 'UNMATCHED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'domain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'phylum'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'class'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'subclass'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'order'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'suborder'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'family'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'genus'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'species'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain'],
		['9', '99', '9_99_2', 'MetaG', 'RDP', 'FILTERED', 'strain']
	];	
	# id_change: patient, sample, measurement, type, sequence, classification, taxclass, taxonomy
	my $expecChangeR = [
		[1, 1, 1, 1, 1, 2, 2, 2], # case sample with sequences and classifications/taxclass/taxonomy
		[1, 1, 1, 1, undef, undef, undef, undef], # case sample without sequences and classifications/taxclass/taxonomy
		[1, 1, undef, undef, 1, 2, 2, 2], # control sample without measurement/type
		[1, 1, undef, undef, undef, undef, undef, undef] # control sample without measurement/type/sequences/classifications/taxclass/taxonomy
	];
	
	my $testF_noRunBar = "./data/spreadsheets/test_SGA_noRunBar.xlsx";
	my $testF_seq = "./data/spreadsheets/test_SGA.xlsx";
	my $testF_seq_onePat = "./data/spreadsheets/test_SGA_onePat.xlsx";
	my $testF_seq_oneSampl = "./data/spreadsheets/test_SGA_oneSampl.xlsx";
	my $testF_updClassDb = "./data/spreadsheets/test_SGA_updatedClassDb.xlsx";
	my $testF_updClassDb_onePat = "./data/spreadsheets/test_SGA_updatedClassDb_onePat.xlsx";
	my $testF_updClassDb_oneSampl = "./data/spreadsheets/test_SGA_updatedClassDb_oneSampl.xlsx";
	my $testF_updClassPrgrm = "./data/spreadsheets/test_SGA_updatedClassPrgrm.xlsx";
	my $testF_updClassPrgrm_onePat = "./data/spreadsheets/test_SGA_updatedClassPrgrm_onePat.xlsx";
	my $testF_updClassPrgrm_oneSampl = "./data/spreadsheets/test_SGA_updatedClassPrgrm_oneSampl.xlsx";

	
	#------------------------------------------------------------------------------#
	# Classifications not found, although run and barcode are provided in Excel
	# (here: basePath only points to sequences).
	# => Issue WARNINGS about missing data
	# => Insert data from Excel + sequences
	#------------------------------------------------------------------------------#
	my $basePath_mod = $basePath . "/seq";
	
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";
		$resClassR = "";
		$resChangeR = "";
					
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath_mod \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resClassR = $dbh->selectall_arrayref("select seq.runid, seq.barcode, seq.readid, c.program, c.database, t.name, t.rank " .
			"from sequence seq inner join classification c on c.id_sequence = seq.id left outer join taxclass tc on " . 
			"tc.id_classification = c.id left outer join taxonomy t on t.id = tc.id_taxonomy order by seq.readid asc, " .
			"c.program asc, c.database asc, " .
			"array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank) asc, " . 
			"t.name asc");
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
			"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
			"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
			"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
			"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok(1==2, 'Testing classifications not found');
	}
	finally {
		# ERROR string only contains WARNINGS about missing classification files
		ok ($err =~ m/^((WARNING: ERROR: No results for directory pattern .* and file pattern ->\.\*calc\\\.LIN\\\.txt\.\*<- at .* line \d+\.)\s+)+$/,
			'Testing classifications not found - error msg');
		# The rest of the data is inserted, as requested
		is ($resChangeR, [[1, 1, 1, 1, 1, undef, undef, undef], [1, 1, 1, 1, undef, undef, undef, undef],
			[1, 1, undef, undef, 1, undef, undef, undef], [1, 1, undef, undef, undef, undef, undef, undef]],
			'Testing classifications not found - new data inserted?');
		is ($resR, $expecMeasureR, 'Testing classifications not found - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing classifications not found - derived measurements');
		is ($resSeqR, $expecSeqR, 'Testing classifications not found - sequences');
		is ($resClassR, [], 'Testing classifications not found - classifications');
	};
	
	
	#------------------------------------------------------------------------------#
	# Classifications for sequences that cannot be found (here: basePath only
	# points to classifications). Implies that also partial updates of
	# classification/taxclass/taxonomy won't work.
	# => Issue WARNINGS about missing data
	# => Don't insert classification data
	# => Insert data from Excel
	#------------------------------------------------------------------------------#
	$basePath_mod = $basePath . "/class";
	
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";
		$resClassR = "";
		$resChangeR = "";
					
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath_mod \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resClassR = $dbh->selectall_arrayref("select seq.runid, seq.barcode, seq.readid, c.program, c.database, t.name, t.rank " .
			"from sequence seq inner join classification c on c.id_sequence = seq.id left outer join taxclass tc on " . 
			"tc.id_classification = c.id left outer join taxonomy t on t.id = tc.id_taxonomy order by seq.readid asc, " .
			"c.program asc, c.database asc, " .
			"array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank) asc, " . 
			"t.name asc");
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
			"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
			"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
			"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
			"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok(1==2, 'Testing insert classifications without sequences');
	}
	finally {
		# ERROR string only contains WARNINGS about missing sequence files
		ok ($err =~ m/^((WARNING: ERROR: No results for directory pattern .* and file pattern ->\\\.fastq\.\*<- at .* line \d+\.)\s+)+$/,
			'Testing insert classifications without sequences - error msg');
		# Except sequences and classifications, the rest of the data is inserted, as requested
		is ($resChangeR, [[1, 1, 1, 1, undef, undef, undef, undef], [1, 1, undef, undef, undef, undef, undef, undef]],
			'Testing insert classifications without sequences - new data inserted?');
		is ($resR, $expecMeasureR, 'Testing insert classifications without sequences - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing insert classifications without sequences - derived measurements');
		is ($resSeqR, [], 'Testing insert classifications without sequences - sequences');
		is ($resClassR, [], 'Testing insert classifications without sequences - classifications');
	};
	
	
	#------------------------------------------------------------------------------#
	# Read IDs in classification and sequence files don't match.
	# => Rollback
	#------------------------------------------------------------------------------#
	$basePath_mod = $basePath =~ s/org$/err/r;
	
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";
		$resClassR = "";
		$resChangeR = "";
					
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath_mod \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resClassR = $dbh->selectall_arrayref("select seq.runid, seq.barcode, seq.readid, c.program, c.database, t.name, t.rank " .
			"from sequence seq inner join classification c on c.id_sequence = seq.id left outer join taxclass tc on " . 
			"tc.id_classification = c.id left outer join taxonomy t on t.id = tc.id_taxonomy order by seq.readid asc, " .
			"c.program asc, c.database asc, " .
			"array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank) asc, " . 
			"t.name asc");
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
			"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
			"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
			"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
			"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok(1==2, 'Testing classifications and sequences do not match');
	}
	finally {
		ok ($err =~ m/^ERROR.* read ID.* do not match/, 'Testing classifications and sequences do not match - error msg');
		is ($resChangeR, [], 'Testing classifications and sequences do not match - new data inserted?');
		is ($resR, [], 'Testing classifications and sequences do not match - measurements');
		is ($resDerivedR, [], 'Testing classifications and sequences do not match - derived measurements');
		is ($resSeqR, [], 'Testing classifications and sequences do not match - sequences');
		is ($resClassR, [], 'Testing classifications and sequences do not match - classifications');
	};
	
	
	#------------------------------------------------------------------------------#
	# Valid full insert.
	# => Insert data from Excel
	# => Insert sequences
	# => Insert classifications
	#------------------------------------------------------------------------------#
	my $expecChange_modR = [
		[1, 1, 1, 1, 1, 1, 1, 1], # case sample with sequences and classifications/taxclass/taxonomy
		[1, 1, 1, 1, undef, undef, undef, undef], # case sample without sequences and classifications/taxclass/taxonomy
		[1, 1, undef, undef, 1, 1, 1, 1], # control sample without measurement/type
		[1, 1, undef, undef, undef, undef, undef, undef] # control sample without measurement/type/sequences/classifications/taxclass/taxonomy
	];
	
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";
		$resClassR = "";
		$resChangeR = "";
					
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resClassR = $dbh->selectall_arrayref("select seq.runid, seq.barcode, seq.readid, c.program, c.database, t.name, t.rank " .
			"from sequence seq inner join classification c on c.id_sequence = seq.id left outer join taxclass tc on " . 
			"tc.id_classification = c.id left outer join taxonomy t on t.id = tc.id_taxonomy order by seq.readid asc, " .
			"c.program asc, c.database asc, " .
			"array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank) asc, " . 
			"t.name asc");
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
			"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
			"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
			"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
			"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok(1==2, 'Testing valid full insert');
	}
	finally {
		is ($err, '', 'Testing valid full insert - error msg');
		is ($resChangeR, $expecChange_modR,	'Testing valid full insert - new data inserted?');
		is ($resR, $expecMeasureR, 'Testing valid full insert - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing valid full insert - derived measurements');
		is ($resSeqR, $expecSeqR, 'Testing valid full insert - sequences');
		is ($resClassR, $expecClassR, 'Testing valid full insert - classifications');
	};


	#------------------------------------------------------------------------------#
	# Add classifications when inserting full Excel, Excel with
	# all samples for patient, Excel with one selected sample for one patient.
	#------------------------------------------------------------------------------#
	# id_change: patient, sample, measurement, type, sequence, classification, taxclass, taxonomy
	$expecChange_modR = [
		[1, 1, 1, 1, 1, 2, 2, 2], # case sample with sequences and classifications/taxclass/taxonomy
		[1, 1, 1, 1, 1, undef, undef, undef], # case sample with sequences, but no classifications/taxclass/taxonomy
		[1, 1, 1, 1, undef, undef, undef, undef], # case sample without sequences and classifications/taxclass/taxonomy
		[1, 1, undef, undef, 1, 2, 2, 2], # control sample without measurement/type
		[1, 1, undef, undef, 1, undef, undef, undef], # control sample with sequences, but without measurement/type/classifications/taxclass/taxonomy
		[1, 1, undef, undef, undef, undef, undef, undef] # control sample without measurement/type/sequences/classifications/taxclass/taxonomy
	];
	my @runs = (
		[$testF_seq, 'full file', $expecClassR, $expecChangeR],
		[$testF_seq_onePat, 'one patient', $expecClass_onePatR, $expecChange_modR],
		[$testF_seq_oneSampl, 'one sample', $expecClass_oneSamplR, $expecChange_modR],
	);
	$basePath_mod = $basePath . "/seq";
	foreach my $run (@runs) {
		my ($file, $name, $tmp_expecClassR, $tmp_expecChangeR) = @{$run};
			
		
		#------------------------------------------------------------------------------#
		# Always initialize with Excel containing run and barcode. basePath only
		# contains sequences.
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath_mod \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Add classification data
		# => id_change indicates version of data --> should change
		# => existing records should not have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqR = "";
			$resClassR = "";
			$resChangeR = "";
						
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqR = $dbh->selectall_arrayref(
				"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
					"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
					"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
					"order by seq.readid asc, p.alias asc"
			);
			$resClassR = $dbh->selectall_arrayref("select seq.runid, seq.barcode, seq.readid, c.program, c.database, t.name, t.rank " .
				"from sequence seq inner join classification c on c.id_sequence = seq.id left outer join taxclass tc on " . 
				"tc.id_classification = c.id left outer join taxonomy t on t.id = tc.id_taxonomy order by seq.readid asc, " .
				"c.program asc, c.database asc, " .
				"array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank) asc, " . 
				"t.name asc");
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
				"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
				"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
				"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
				"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
				"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok (1==2, 'Testing to add classification data with ->' . $name . '<-');
		}
		finally {
			is ($err, "", 'Testing to add classification data with ->' . $name . '<- - error msg');
			is ($resChangeR, $tmp_expecChangeR, 'Testing to add classification data with ->' . $name . '<- - updated?');
			is ($resR, $expecMeasureR, 'Testing to add classification data with ->' . $name . '<- - measurements');
			is ($resDerivedR, $expecDerivedR, 'Testing to add classification data with ->' . $name . '<- - derived measurements');
			is ($resSeqR, $expecSeqR, 'Testing to add classification data with ->' . $name . '<- - sequences');
			is ($resClassR, $tmp_expecClassR, 'Testing to add classification data with ->' . $name . '<- - classifications');
		};
	}
	
	
	#------------------------------------------------------------------------------#
	# Ignore old records when inserting full Excel, Excel with all samples for
	# patient, Excel with one selected sample for one patient.
	#------------------------------------------------------------------------------#
	@runs = (
		[$testF_seq, 'full file'],
		[$testF_seq_onePat, 'one patient'],
		[$testF_seq_oneSampl, 'one sample'],
	);
	my $tmp_expecChangeR = "";
	
	foreach my $run (@runs) {
		my ($file, $name) = @{$run};

		
		#------------------------------------------------------------------------------#
		# Always initialize with Excel including classification data
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
			
			$tmp_expecChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
				"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
				"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
				"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
				"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
				"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
			);
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Attempt to add old classification data
		# => id_change indicates version of data --> should not change
		# => there should be no duplicates of records
		# => no records should have changed
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqR = "";
			$resClassR = "";
			$resChangeR = "";
						
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqR = $dbh->selectall_arrayref(
				"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
					"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
					"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
					"order by seq.readid asc, p.alias asc"
			);
			$resClassR = $dbh->selectall_arrayref("select seq.runid, seq.barcode, seq.readid, c.program, c.database, t.name, t.rank " .
				"from sequence seq inner join classification c on c.id_sequence = seq.id left outer join taxclass tc on " . 
				"tc.id_classification = c.id left outer join taxonomy t on t.id = tc.id_taxonomy order by seq.readid asc, " .
				"c.program asc, c.database asc, " .
				"array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank) asc, " . 
				"t.name asc");
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
				"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
				"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
				"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
				"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
				"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok (1==2, 'Testing to add old classification data with ->' . $name . '<-');
		}
		finally {
			is ($err, "", 'Testing to add old classification data with ->' . $name . '<- - error msg');
			is ($resChangeR, $tmp_expecChangeR, 'Testing to add old classification data with ->' . $name . '<- - updated?');
			is ($resR, $expecMeasureR, 'Testing to add old classification data with ->' . $name . '<- - measurements');
			is ($resDerivedR, $expecDerivedR, 'Testing to add old classification data with ->' . $name . '<- - derived measurements');
			is ($resSeqR, $expecSeqR, 'Testing to add old classification data with ->' . $name . '<- - sequences');
			is ($resClassR, $expecClassR, 'Testing to add old classification data with ->' . $name . '<- - classifications');
		};
	}
	
	
	#------------------------------------------------------------------------------#
	# Attempt to update classification data (taxclass).
	# => here: uses data that already exists in taxonomy, but makes new connections
	#	to classification via taxclass. Same result expected, if completely new
	#	taxa were used.
	# => does not replace old connections --> huge mess
	# => id_change indicates version of data --> should change
	#------------------------------------------------------------------------------#
	@runs = (
		[$testF_seq, 'full file', $expecClass_updatedR],
		[$testF_seq_onePat, 'one patient', $expecClass_onePat_updatedR],
		[$testF_seq_oneSampl, 'one sample', $expecClass_oneSampl_updatedR],
	);
	$basePath_mod = $basePath =~ s/org$/mod_class/r;
	# id_change: patient, sample, measurement, type, sequence, classification, taxclass, taxonomy
	$expecChange_modR = [
		[1, 1, 1, 1, 1, 1, 1, 1], # case sample with sequences and classifications/taxclass/taxonomy
		[1, 1, 1, 1, 1, 1, 2, 1], # case sample with sequences and classifications/taxclass/taxonomy
		[1, 1, 1, 1, undef, undef, undef, undef], # case sample without sequences and classifications/taxclass/taxonomy
		[1, 1, undef, undef, 1, 1, 1, 1], # control sample without measurement/type
		[1, 1, undef, undef, 1, 1, 2, 1], # control sample without measurement/type
		[1, 1, undef, undef, undef, undef, undef, undef] # control sample without measurement/type/sequences/classifications/taxclass/taxonomy
	];
	
	foreach my $run (@runs) {
		my ($file, $name, $tmp_expecClassR) = @{$run};

		
		#------------------------------------------------------------------------------#
		# Always initialize with Excel including classification data
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Change basePath to dir with updated classification files
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqR = "";
			$resClassR = "";
			$resChangeR = "";
						
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath_mod \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqR = $dbh->selectall_arrayref(
				"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
					"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
					"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
					"order by seq.readid asc, p.alias asc"
			);
			$resClassR = $dbh->selectall_arrayref("select seq.runid, seq.barcode, seq.readid, c.program, c.database, t.name, t.rank " .
				"from sequence seq inner join classification c on c.id_sequence = seq.id left outer join taxclass tc on " . 
				"tc.id_classification = c.id left outer join taxonomy t on t.id = tc.id_taxonomy order by seq.readid asc, " .
				"c.program asc, c.database asc, " .
				"array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank) asc, " . 
				"t.name asc");
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
				"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
				"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
				"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
				"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
				"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok (1==2, 'Testing to update classification data with ->' . $name . '<- [1/3]');
		}
		finally {
			is ($err, "", 'Testing to update classification data with ->' . $name . '<- [1/3] - error msg');
			is ($resChangeR, $expecChange_modR, 'Testing to update classification data with ->' . $name . '<- [1/3] - updated?');
			is ($resR, $expecMeasureR, 'Testing to update classification data with ->' . $name . '<- [1/3] - measurements');
			is ($resDerivedR, $expecDerivedR, 'Testing to update classification data with ->' . $name . '<- [1/3] - derived measurements');
			is ($resSeqR, $expecSeqR, 'Testing to update classification data with ->' . $name . '<- [1/3] - sequences');
			is ($resClassR, $tmp_expecClassR, 'Testing to update classification data with ->' . $name . '<- [1/3] - classifications');
		};
	}


	#------------------------------------------------------------------------------#
	# Attempt to update classification data (classification).
	# => here: uses data that already exists in taxonomy, but creates a new
	#	classification (by changing database column) with new connections via
	#	taxclass
	# => does not replace old classification, but adds a new
	# => id_change indicates version of data --> should change
	#------------------------------------------------------------------------------#
	@runs = (
		[$testF_updClassDb, 'full file', $expecClass_updatedClassDbR],
		[$testF_updClassDb_onePat, 'one patient', $expecClass_updatedClassDb_onePatR],
		[$testF_updClassDb_oneSampl, 'one sample', $expecClass_updatedClassDb_oneSamplR],
	);
	$basePath_mod = $basePath =~ s/org$/mod_class/r;
	# id_change: patient, sample, measurement, type, sequence, classification, taxclass, taxonomy
	$expecChange_modR = [
		[1, 1, 1, 1, 1, 1, 1, 1], # case sample with sequences and classifications/taxclass/taxonomy
		[1, 1, 1, 1, 1, 2, 2, 1], # case sample with sequences and classifications/taxclass/taxonomy
		[1, 1, 1, 1, undef, undef, undef, undef], # case sample without sequences and classifications/taxclass/taxonomy
		[1, 1, undef, undef, 1, 1, 1, 1], # control sample without measurement/type
		[1, 1, undef, undef, 1, 2, 2, 1], # control sample without measurement/type
		[1, 1, undef, undef, undef, undef, undef, undef] # control sample without measurement/type/sequences/classifications/taxclass/taxonomy
	];
	
	foreach my $run (@runs) {
		my ($file, $name, $tmp_expecClassR) = @{$run};

		
		#------------------------------------------------------------------------------#
		# Always initialize with Excel including classification data
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Change basePath to dir with updated classification files and Excel to file
		# with updated database. Sequences remain the same.
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqR = "";
			$resClassR = "";
			$resChangeR = "";
						
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath_mod \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqR = $dbh->selectall_arrayref(
				"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
					"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
					"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
					"order by seq.readid asc, p.alias asc"
			);
			$resClassR = $dbh->selectall_arrayref("select seq.runid, seq.barcode, seq.readid, c.program, c.database, t.name, t.rank " .
				"from sequence seq inner join classification c on c.id_sequence = seq.id left outer join taxclass tc on " . 
				"tc.id_classification = c.id left outer join taxonomy t on t.id = tc.id_taxonomy order by seq.readid asc, " .
				"c.program asc, c.database asc, " .
				"array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank) asc, " . 
				"t.name asc");
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
				"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
				"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
				"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
				"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
				"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok (1==2, 'Testing to update classification data with ->' . $name . '<- [2/3]');
		}
		finally {
			is ($err, "", 'Testing to update classification data with ->' . $name . '<- [2/3] - error msg');
			is ($resChangeR, $expecChange_modR, 'Testing to update classification data with ->' . $name . '<- [2/3] - updated?');
			is ($resR, $expecMeasureR, 'Testing to update classification data with ->' . $name . '<- [2/3] - measurements');
			is ($resDerivedR, $expecDerivedR, 'Testing to update classification data with ->' . $name . '<- [2/3] - derived measurements');
			is ($resSeqR, $expecSeqR, 'Testing to update classification data with ->' . $name . '<- [2/3] - sequences');
			is ($resClassR, $tmp_expecClassR, 'Testing to update classification data with ->' . $name . '<- [2/3] - classifications');
		};
	}
	
	
	#------------------------------------------------------------------------------#
	# Attempt to update classification data (classification).
	# => here: uses data that already exists in taxonomy, but creates a new
	#	classification (by changing program column) with new connections via
	#	taxclass
	# => does not replace old classification, but adds a new
	# => id_change indicates version of data --> should change
	#------------------------------------------------------------------------------#
	my $expecClass_updatedClassPrgrmR = dclone($expecClass_updatedClassDbR);
	my $expecClass_updatedClassPrgrm_onePatR = dclone($expecClass_updatedClassDb_onePatR);
	my $expecClass_updatedClassPrgrm_oneSamplR = dclone($expecClass_updatedClassDb_oneSamplR);
	
	# Restore database name and change program name for previously altered entries.
	foreach my $expec ($expecClass_updatedClassPrgrmR, $expecClass_updatedClassPrgrm_onePatR, $expecClass_updatedClassPrgrm_oneSamplR) {
		foreach my $ref (@{$expec}) {
			if ($ref->[4] eq "MTX") {
				$ref->[4] = "RDP";
				$ref->[3] = "Kraken2"
			}
		}
	}
	
	@runs = (
		[$testF_updClassPrgrm, 'full file', $expecClass_updatedClassPrgrmR],
		[$testF_updClassPrgrm_onePat, 'one patient', $expecClass_updatedClassPrgrm_onePatR],
		[$testF_updClassPrgrm_oneSampl, 'one sample', $expecClass_updatedClassPrgrm_oneSamplR],
	);
	$basePath_mod = $basePath =~ s/org$/mod_class/r;
	# id_change: patient, sample, measurement, type, sequence, classification, taxclass, taxonomy
	$expecChange_modR = [
		[1, 1, 1, 1, 1, 1, 1, 1], # case sample with sequences and classifications/taxclass/taxonomy
		[1, 1, 1, 1, 1, 2, 2, 1], # case sample with sequences and classifications/taxclass/taxonomy
		[1, 1, 1, 1, undef, undef, undef, undef], # case sample without sequences and classifications/taxclass/taxonomy
		[1, 1, undef, undef, 1, 1, 1, 1], # control sample without measurement/type
		[1, 1, undef, undef, 1, 2, 2, 1], # control sample without measurement/type
		[1, 1, undef, undef, undef, undef, undef, undef] # control sample without measurement/type/sequences/classifications/taxclass/taxonomy
	];
	
	foreach my $run (@runs) {
		my ($file, $name, $tmp_expecClassR) = @{$run};

		
		#------------------------------------------------------------------------------#
		# Always initialize with Excel including classification data
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};
		}
		catch {
			$err = $_;
			die "ERROR: $err"
		};
		
		
		#------------------------------------------------------------------------------#
		# Change basePath to dir with updated classification files and Excel to file
		# with updated program. Sequences remain the same.
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$resR = "";
			$resDerivedR = "";
			$resSeqR = "";
			$resClassR = "";
			$resChangeR = "";
						
			$err = qx{perl ../importSGA.pl --debug --verbose --table $file --data $basePath_mod \\
				--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
				--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
			};			
			$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
				"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
				"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
				"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
			);
			$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
				"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
				(
					'z-score',
					'z-score category',
					'z-score subcategory',
					'category of difference in body mass at delivery',
					'difference in body mass at delivery',
					'mother\'s age at delivery',
					'mother\'s pre-pregnancy BMI',
					'mother\'s pre-pregnancy BMI category'
				)	
			);
			$resSeqR = $dbh->selectall_arrayref(
				"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
					"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
					"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
					"order by seq.readid asc, p.alias asc"
			);
			$resClassR = $dbh->selectall_arrayref("select seq.runid, seq.barcode, seq.readid, c.program, c.database, t.name, t.rank " .
				"from sequence seq inner join classification c on c.id_sequence = seq.id left outer join taxclass tc on " . 
				"tc.id_classification = c.id left outer join taxonomy t on t.id = tc.id_taxonomy order by seq.readid asc, " .
				"c.program asc, c.database asc, " .
				"array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank) asc, " . 
				"t.name asc");
			$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
				"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
				"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
				"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
				"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
				"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
				"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
			);
			
			# Cleanup
			$dbh = dropDB($dbh, $schema);
			$dbh = createDB($dbh, $schema);
		}
		catch {
			$err .= $_;
			print $err;
			ok (1==2, 'Testing to update classification data with ->' . $name . '<- [3/3]');
		}
		finally {
			is ($err, "", 'Testing to update classification data with ->' . $name . '<- [3/3] - error msg');
			is ($resChangeR, $expecChange_modR, 'Testing to update classification data with ->' . $name . '<- [3/3] - updated?');
			is ($resR, $expecMeasureR, 'Testing to update classification data with ->' . $name . '<- [3/3] - measurements');
			is ($resDerivedR, $expecDerivedR, 'Testing to update classification data with ->' . $name . '<- [3/3] - derived measurements');
			is ($resSeqR, $expecSeqR, 'Testing to update classification data with ->' . $name . '<- [3/3] - sequences');
			is ($resClassR, $tmp_expecClassR, 'Testing to update classification data with ->' . $name . '<- [3/3] - classifications');
		};
	}

	
	#------------------------------------------------------------------------------#
	# Attempt to remove classification data by emptying run and barcode in Excel
	# => does not work; data is left unchanged.
	# => id_change indicates version of data --> should not change
	#------------------------------------------------------------------------------#	
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";
		$resClassR = "";
		$resChangeR = "";
		$tmp_expecChangeR = "";	
					
		# Add Excel with run and barcode
		qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		$tmp_expecChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
			"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
			"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
			"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
			"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
		);
		
		# Attempt to remove classifications by providing Excel with empty run_bar field
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_noRunBar --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resClassR = $dbh->selectall_arrayref("select seq.runid, seq.barcode, seq.readid, c.program, c.database, t.name, t.rank " .
			"from sequence seq inner join classification c on c.id_sequence = seq.id left outer join taxclass tc on " . 
			"tc.id_classification = c.id left outer join taxonomy t on t.id = tc.id_taxonomy order by seq.readid asc, " .
			"c.program asc, c.database asc, " .
			"array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank) asc, " . 
			"t.name asc");
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
			"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
			"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
			"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
			"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok(1==2, 'Testing removing existing classification data does not work [1/2]');
	}
	finally {
		is ($err, '', 'Testing removing existing classification data does not work [1/2] - error msg');
		is ($resChangeR, $tmp_expecChangeR,	'Testing removing existing classification data does not work [1/2] - new data inserted?');
		is ($resR, $expecMeasureR, 'Testing removing existing classification data does not work [1/2] - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing removing existing classification data does not work [1/2] - derived measurements');
		is ($resSeqR, $expecSeqR, 'Testing removing existing classification data does not work [1/2] - sequences');
		is ($resClassR, $expecClassR, 'Testing removing existing classification data does not work [1/2] - classifications');
	};
	
	
	#------------------------------------------------------------------------------#
	# Attempt to remove classification data by providing basePath that only
	# contains sequences and no classifications (run and barcode provided in Excel)
	# => does not work; data is left unchanged.
	# => id_change indicates version of data --> should not change
	#------------------------------------------------------------------------------#
	$basePath_mod = $basePath . "/seq";
	
	try {
		$err = "";
		$resR = "";
		$resDerivedR = "";
		$resSeqR = "";
		$resClassR = "";
		$resChangeR = "";
		$tmp_expecChangeR = "";
					
		# Correct basePath
		qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		$tmp_expecChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
			"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
			"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
			"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
			"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
		);
		
		# basePath that contains no data
		$err = qx{perl ../importSGA.pl --debug --verbose --table $testF_seq --data $basePath_mod \\
			--format xlsx --whogirls ./data/spreadsheets/whogirls.xlsx \\
			--whoboys ./data/spreadsheets/whoboys.xlsx 2>&1 1>/dev/null \\
		};
		$resR = $dbh->selectall_arrayref("select p.alias, p.accession, p.birthdate, s.createdate, " .
			"s.createdby, s.iscontrol, m.value, t.name, t.type, t.selection from patient p full " .
			"outer join sample s on p.id = s.id_patient full outer join measurement m on s.id = m.id_sample " .
			"full outer join type t on m.id_type = t.id order by accession asc, createdate asc, iscontrol asc, name asc"
		);
		$resDerivedR = $dbh->selectall_arrayref("select accession, createdate, timepoint, name, type, value " .
			"from v_measurements where name in (?, ?, ?, ?, ?, ?, ?, ?) order by accession asc, createdate asc, name asc", {},
			(
				'z-score',
				'z-score category',
				'z-score subcategory',
				'category of difference in body mass at delivery',
				'difference in body mass at delivery',
				'mother\'s age at delivery',
				'mother\'s pre-pregnancy BMI',
				'mother\'s pre-pregnancy BMI category'
			)	
		);
		$resSeqR = $dbh->selectall_arrayref(
			"select p.alias, p.accession, p.birthdate, s.createdate, case when s.iscontrol = '0' then 'f' when s.iscontrol = '1' then 't' end, " .
				"seq.readid, seq.runid, seq.barcode, seq.flowcellid, seq.callermodel, seq.nucs, seq.quality, seq.seqerr, seq.seqlen " .
				"from sequence seq left outer join sample s on s.id = seq.id_sample left outer join patient p on p.id = s.id_patient " .
				"order by seq.readid asc, p.alias asc"
		);
		$resClassR = $dbh->selectall_arrayref("select seq.runid, seq.barcode, seq.readid, c.program, c.database, t.name, t.rank " .
			"from sequence seq inner join classification c on c.id_sequence = seq.id left outer join taxclass tc on " . 
			"tc.id_classification = c.id left outer join taxonomy t on t.id = tc.id_taxonomy order by seq.readid asc, " .
			"c.program asc, c.database asc, " .
			"array_position(array['domain', 'phylum', 'class', 'subclass', 'order', 'suborder', 'family', 'genus', 'species', 'strain'], t.rank) asc, " . 
			"t.name asc");
		$resChangeR = $dbh->selectall_arrayref("select p.id_change, s.id_change, m.id_change, t.id_change, seq.id_change, c.id_change," .
			"tc.id_change, tax.id_change from patient p full outer join sample s on p.id = s.id_patient full outer join measurement m " .
			"on s.id = m.id_sample full outer join type t on m.id_type = t.id full outer join sequence seq " .
			"on s.id = seq.id_sample full outer join classification c on c.id_sequence = seq.id full outer join taxclass tc on " .
			"tc.id_classification = c.id full outer join taxonomy tax on tax.id = tc.id_taxonomy group by p.id_change, s.id_change, " .
			"m.id_change, t.id_change, seq.id_change, c.id_change, tc.id_change, tax.id_change order by p.id_change asc, s.id_change asc, " .
			"m.id_change asc, t.id_change asc, seq.id_change, c.id_change, tc.id_change, tax.id_change asc"
		);
		
		# Cleanup
		$dbh = dropDB($dbh, $schema);
		$dbh = createDB($dbh, $schema);
	}
	catch {
		$err .= $_;
		print $err;
		ok(1==2, 'Testing removing existing classification data does not work [2/2]');
	}
	finally {
		# ERROR string only contains WARNINGS about missing classification files
		ok ($err =~ m/^((WARNING: ERROR: No results for directory pattern .* and file pattern ->\.\*calc\\\.LIN\\\.txt\.\*<- at .* line \d+\.)\s+)+$/,
			'Testing removing existing classification data does not work [2/2] - error msg');
		is ($resChangeR, $tmp_expecChangeR,	'Testing removing existing classification data does not work [2/2] - new data inserted?');
		is ($resR, $expecMeasureR, 'Testing removing existing classification data does not work [2/2] - measurements');
		is ($resDerivedR, $expecDerivedR, 'Testing removing existing classification data does not work [2/2] - derived measurements');
		is ($resSeqR, $expecSeqR, 'Testing removing existing classification data does not work [2/2] - sequences');
		is ($resClassR, $expecClassR, 'Testing removing existing classification data does not work [2/2] - classifications');
	};

	
	return;
};
	

#
#--------------------------------------------------------------------------------------------------#
# Main
#--------------------------------------------------------------------------------------------------#
#
# Connect to the test database (has to be created before by user)
my $dbh = MetagDB::Db::connectDebug();

my $rand = "";
for (my $i = 0; $i <= 30; $i++) {
	my $int = int(rand(25));
	$rand .= getLetter($int);
}
my $basePath = "/tmp/$rand";

try {
	# Create the test directory
	system("mkdir $basePath") and die "ERROR: Cannot create temporary directory ->$basePath<-";
	
	# Slurp the production database schema
	my $schemaF = '../../www-intern/db/schema.sql';
	die "ERROR: Database schema ->$schemaF<- does not exist "if (not -f $schemaF);
	my $schema = "";
	{
		open(SCHEMA, "<", $schemaF) or die "Cannot read database schema: $!";
		# It is essential that change of record separator is localized!
		local $/ = undef;
		$schema = <SCHEMA>;
		close SCHEMA;
	}
	
	# Primitive check, that the file is actually a schema file.
	# Must contain at least one "create table" statement.
	if ($schema !~ m/create table [^(]+\([^;]+\)\;/i) {
		die "ERROR: File ->$schemaF<- does not represent a valid database schema"
	}
	
	# Remove comments from schema
	$schema =~ s/\/\*[^*]+\*\///g;
	
	$dbh = createDB($dbh, $schema);
	
	print "INFO: Testing measurement related workflows\n";
	my ($expecMeasureR, $expecDerivedR) = test_measures($dbh, $schema, $basePath);
	
	print "INFO: Testing sequence related workflows\n";
	test_seqs($dbh, $schema, "data/basepath/org/seq", $basePath, $expecMeasureR, $expecDerivedR);

	print "INFO: Testing classification related workflows\n";
	test_class($dbh, $schema, "data/basepath/org", $basePath, $expecMeasureR, $expecDerivedR);
	
	$dbh = dropDB($dbh, $schema);
}
catch {
	print "ERROR: $_";
	$dbh->rollback;
}
finally {
	$dbh->disconnect;
	
	done_testing();
};
