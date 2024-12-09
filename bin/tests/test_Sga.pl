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
# Tests for MetagDB::Sga module
#==================================================================================================#
# DESCRIPTION
# 
#	Test the functions in the MetagDB::Sga module.
#
#
# USAGE
#
# 	./test_Sga.pl
#
#
# CAVEATS
# 	
#	This script has to insert data into relations that have the same name as the final relations
#	in the production database. To avoid overwriting important data, this script requires that a
#	test database (service name "debug" in ".pg_service.conf") is available.
#	It is your responsibility to ensure that this database is empty can be used for testing.
#	The script expects that the database schema for testing (often the schema of the production
#	database) is located under '../../www-intern/db/schema.sql' (the schema must contain at least
#	one "create table" statement). Comments are stripped from the schema, but all other
#	commands are executed without further checks. Handle with care.
#
#
# NOTE
#
#	Tests for the underlying functions in (for example) the MetagDB::Db module are not repeated here.
#	For some data there cannot be exact duplicates, due to the storage in hashes.
#
#					
# DEPENDENCIES
# 
#	DBI
#	IO::Compress::Zip
#	MetagDB::Db
#	MetagDB::Utils
#	MetagDB::Sga
# 	Posix
#	Storable
#	Test2::Bundle::More
#	Test2::Tools::Compare
#	Try::Tiny
#==================================================================================================#


use strict;
use warnings;

use DBI;
use IO::Compress::Zip qw(zip $ZipError);
use POSIX qw(strftime);
use Storable qw(dclone);
use Test2::Bundle::More qw(ok done_testing);
use Test2::Tools::Compare;
use Try::Tiny;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl/";
use MetagDB::Db;
use MetagDB::Sga;
use MetagDB::Utils;


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
# Test the parseTable function
#--------------------------------------------------------------------------------------------------#
#
sub test_parseWHO {
	my $err = "";
	
	my $girlsF = "./data/spreadsheets/test_WHO.xlsx";
	# It does not matter for the tests to have two different files
	my $boysF = $girlsF;
	
	
	#------------------------------------------------------------------------------#
	# Test no input file for girls (+ no input file for boys)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::parseWHO()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no input file for girls');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no input file for boys
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::parseWHO($girlsF)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no input file for boys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty input file for girls
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::parseWHO("", $boysF)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty input file for girls');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty input file for boys
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::parseWHO($girlsF, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty input file for boys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty sheet. File for girls as representative test.
	#------------------------------------------------------------------------------#
	my $girlsModF = $girlsF =~ s/\.xlsx$/_empty\.xlsx/r;
	
	try {
		$err = "";
		MetagDB::Sga::parseWHO($girlsModF, $boysF)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Empty sheet/, 'Testing empty sheet');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test multiple sheets. File for girls as representative test.
	#------------------------------------------------------------------------------#
	$girlsModF = $girlsF =~ s/\.xlsx$/_2sheets\.xlsx/r;
	
	try {
		$err = "";
		MetagDB::Sga::parseWHO($girlsModF, $boysF)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*More than one sheet/, 'Testing multiple sheets');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty values in relevant columns. File for girls as representative test.
	#------------------------------------------------------------------------------#
	$girlsModF = $girlsF =~ s/\.xlsx$/_emptyVal\.xlsx/r;
	
	try {
		$err = "";
		MetagDB::Sga::parseWHO($girlsModF, $boysF)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Empty value in row/, 'Testing empty values in relevant columns');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty values in additional columns.
	# File for girls as representative test.
	#------------------------------------------------------------------------------#
	$girlsModF = $girlsF =~ s/\.xlsx$/_emptyAdd\.xlsx/r;
	my @expecs = (
		['f', 0, 0.1, 0, 0],
		['f', 1, 0.1, 1, 11],
		['f', 2, 0.2, 2, 22],
		['m', 0, 0.1, 0, 0],
		['m', 1, 0.1, 1, 11],
		['m', 2, 0.2, 2, 22]
	);
	
	try {
		$err = "";
		
		my $outR = MetagDB::Sga::parseWHO($girlsModF, $boysF);
		is ($outR, \@expecs, 'Testing empty values in additional columns');
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing empty values in additional columns');
		print "ERROR: " . $err;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test duplicates in relevant columns. File for girls as representative test.
	#------------------------------------------------------------------------------#
	$girlsModF = $girlsF =~ s/\.xlsx$/_dups\.xlsx/r;
	my @expecs_mod = (
		['f', 0, 0.1, 0, 0],
		['f', 0, 0.1, 0, 0],
		['f', 2, 0.2, 2, 22],
		['m', 0, 0.1, 0, 0],
		['m', 1, 0.1, 1, 11],
		['m', 2, 0.2, 2, 22]
	);
	
	try {
		$err = "";
		
		my $outR = MetagDB::Sga::parseWHO($girlsModF, $boysF);
		is ($outR, \@expecs_mod, 'Testing duplicate values in relevant columns');
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing duplicate values in relevant columns');
		print "ERROR: " . $err;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test duplicates in additional columns. File for girls as representative test.
	#------------------------------------------------------------------------------#
	$girlsModF = $girlsF =~ s/\.xlsx$/_dupsAdd\.xlsx/r;
	
	try {
		$err = "";
		
		my $outR = MetagDB::Sga::parseWHO($girlsModF, $boysF);
		is ($outR, \@expecs, 'Testing duplicate values in additional columns');
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing duplicate values in additional columns');
		print "ERROR: " . $err;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test leading+trailing whitespaces. File for girls as representative test.
	# Previous tests already showed that additional columns are irrelevant.
	#------------------------------------------------------------------------------#
	$girlsModF = $girlsF =~ s/\.xlsx$/_leadingTrailing\.xlsx/r;
	
	try {
		$err = "";
		
		my $outR = MetagDB::Sga::parseWHO($girlsModF, $boysF);
		is ($outR, \@expecs, 'Testing leading + trailing whitespaces');
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing leading + trailing whitespaces');
		print "ERROR: " . $err;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test new lines in fields. File for girls as representative test.
	# Previous tests already showed that additional columns are irrelevant.
	#------------------------------------------------------------------------------#
	$girlsModF = $girlsF =~ s/\.xlsx$/_newLine\.xlsx/r;
	
	try {
		$err = "";
		
		my $outR = MetagDB::Sga::parseWHO($girlsModF, $boysF);
		is ($outR, \@expecs, 'Testing new lines in fields');
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing new lines in fields');
		print "ERROR: " . $err;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test new lines in fields (CRLF). File for girls as representative test.
	# Previous tests already showed that additional columns are irrelevant.
	#------------------------------------------------------------------------------#
	$girlsModF = $girlsF =~ s/\.xlsx$/_newLineCRLF\.xlsx/r;
	
	try {
		$err = "";
		
		my $outR = MetagDB::Sga::parseWHO($girlsModF, $boysF);
		is ($outR, \@expecs, 'Testing new lines (CRLF) in fields');
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing new lines (CRLF) in fields');
		print "ERROR: " . $err;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid file (compressed). File for girls as representative test.
	#------------------------------------------------------------------------------#
	$girlsModF = $girlsF =~ s/\.xlsx$/_invalid\.xlsx/r;
	
	try {
		$err = "";
		MetagDB::Sga::parseWHO($girlsModF, $boysF)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Could not parse/, 'Testing invalid file');
	};
	
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the parseTable function
#--------------------------------------------------------------------------------------------------#
#
sub test_parseTable {	
	my $err = "";
	my $inFile = "./data/spreadsheets/SGA.ods";
	
	
	#------------------------------------------------------------------------------#
	# Test no input file (+ no format)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::parseTable()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no input file');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty input file parameter (+ no format)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::parseTable("")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty input file parameter');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid file with correct extension and no format
	#------------------------------------------------------------------------------#
	my %expecs = (
		'X' => {
			'hospital code' 									=> 1234,
			'birth date'										=> '1950-01-01',
			'sex'												=> 1,
			'birth mode'										=> 1,
			'mother\'s birth date'								=> '1930-01-01',
			'maternal body mass before pregnancy'				=> 60,
			'maternal body mass at delivery'					=> 70,
			'mother\'s height'									=> 170,
			'pregnancy order'									=> 1,
			'maternal illness during pregnancy'					=> undef,
			'maternal antibiotics during pregnancy'				=> 2,
			'_times_' =>	{
				'1950-01-01' =>	{
					'body mass' 				=> 2345,
					'feeding mode'				=> 1,
					'probiotics'				=> 1,
					'antibiotics'				=> 2,
					'program'					=> 'MetaG',
					'database'					=> 'RDP',
					'number of run and barcode'	=> 'run1234_bar5678'
				}
			} 
		}
	);
	my $dataR = MetagDB::Sga::parseTable($inFile);
	is($dataR, \%expecs, 'Testing valid file with correct extension and no format');
	
	
	#------------------------------------------------------------------------------#
	# Test valid file with no extension and no format provided.
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/SGA";
	
	try {
		$err = "";
		MetagDB::Sga::parseTable($inFile)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No file format/, 'Testing valid file with no extension and no format');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid file with illegal extension and no format provided. The extension
	# is too alien to be captured by the regex that attempts to extract the format.
	# Extractable, but wrong extensions, have been already tested for the
	# underlying Table module.
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/SGA.illegalExt";
	
	try {
		$err = "";
		MetagDB::Sga::parseTable($inFile)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No file format/, 'Testing valid file with illegal extension and no format');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid file with correct extension and empty format
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/SGA.ods";
	$dataR = MetagDB::Sga::parseTable($inFile, "");
	is($dataR, \%expecs, 'Testing valid file with correct extension and empty format');
	
	
	#------------------------------------------------------------------------------#
	# Test valid file with no extension and empty format.
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/SGA";
	
	try {
		$err = "";
		MetagDB::Sga::parseTable($inFile, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No file format/, 'Testing valid file with no extension and empty format');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid file with illegal extension and empty format. The extension
	# is too alien to be captured by the regex that attempts to extract the format.
	# Extractable, but wrong extensions, have been already tested for the
	# underlying Table module.
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/SGA.illegalExt";
	
	try {
		$err = "";
		MetagDB::Sga::parseTable($inFile, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No file format/, 'Testing valid file with illegal extension and empty format');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid file with correct extension and illegal format. Proves that
	# provided format takes precedence over predicted format.
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/SGA.ods";
	
	try {
		$err = "";
		MetagDB::Sga::parseTable($inFile, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Unsupported format/, 'Testing valid file with correct extension and illegal format');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid file with illegal extension and correct format. Second proof that
	# provided format takes precedence over predicted format.
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/SGA.illegalExt";
	$dataR = MetagDB::Sga::parseTable($inFile, "ods");
	is($dataR, \%expecs, 'Testing valid file with illegal extension and correct format');
	

	foreach my $archive ("./data/spreadsheets/sgaZIP.ods.zip", "./data/spreadsheets/sgaGZ.ods.gz", "./data/spreadsheets/sgaBZ2.ods.bz2") {
		my $format = join('.', (split('\.', $archive))[-2..-1]);
		
		#------------------------------------------------------------------------------#
		# Test valid archive with no format
		#------------------------------------------------------------------------------#
		$inFile = $archive;
		$dataR = MetagDB::Sga::parseTable($inFile);
		is($dataR, \%expecs, 'Testing valid ->' . $format . '<- file with no format');
		
		
		#------------------------------------------------------------------------------#
		# Test valid archive with empty format
		#------------------------------------------------------------------------------#
		$dataR = MetagDB::Sga::parseTable($inFile, "");
		is($dataR, \%expecs, 'Testing valid ->' . $format . '<- file with empty format');
		
		
		#------------------------------------------------------------------------------#
		# Test valid archive with missing extension and format
		#------------------------------------------------------------------------------#
		$inFile =~ s/\.ods\..*$//;
		$dataR = MetagDB::Sga::parseTable($inFile, $format);
		is($dataR, \%expecs, 'Testing valid ->' . $format . '<- file with no extension, but valid format');
	}
	
	
	#------------------------------------------------------------------------------#	
	# Test nested archive with no format at the example of zip.zip. Unsupported!
	# Format guessing recognizes format as zip.zip.
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/sgaZIPzip.ods.zip.zip";
	try {
		$err = "";
		
		$dataR = MetagDB::Sga::parseTable($inFile);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Unsupported format/, 'Testing nested archive with no format');
	};
	
	
	#------------------------------------------------------------------------------#	
	# Test nested archive with empty format at the example of zip.zip. Unsupported!
	# Format guessing recognizes format as zip.zip.
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$dataR = MetagDB::Sga::parseTable($inFile, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Unsupported format/, 'Testing nested archive with empty format');
	};
	
	
	#------------------------------------------------------------------------------#	
	# Test nested archive with no extension, but format at the example of zip.zip.
	# Unsupported!
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/sgaZIPzip";
	try {
		$err = "";
		
		$dataR = MetagDB::Sga::parseTable($inFile, "ods.zip.zip");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Unsupported format/, 'Testing nested archive with no extension, but format');
	};
	
	
	#------------------------------------------------------------------------------#	
	# Test archive contains a text file that is empty
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/sgaEmpty";
	try {
		$err = "";
		
		MetagDB::Sga::parseTable($inFile, "ods.zip");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Empty table file/, 'Testing archive that contains an empty file');
	};
	
	
	#------------------------------------------------------------------------------#	
	# Test archive contains a text file that just contains blanks
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/sgaBlanks";
	try {
		$err = "";
		
		MetagDB::Sga::parseTable($inFile, "ods.zip");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Empty table file/, 'Testing archive that contains a file which just contains blanks');
	};
	
	
	#------------------------------------------------------------------------------#	
	# Test archive contains a text file that just contains a literal zero
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/sgaZero";
	try {
		$err = "";
		
		MetagDB::Sga::parseTable($inFile, "ods.zip");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Empty table file/, 'Testing archive that contains a file which just contains a literal zero');
	};
	
	
	#------------------------------------------------------------------------------#	
	# Test archive contains a text file that contains leading + trailing blanks
	#------------------------------------------------------------------------------#
	$inFile = "./data/spreadsheets/sgaLeadingTrailing";
	try {
		$err = "";
		
		MetagDB::Sga::parseTable($inFile, "ods.zip");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Could not parse spreadsheet/, 'Testing archive that contains a file with leading + trailing whitespaces');
	};
	
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the insertChange function
#--------------------------------------------------------------------------------------------------#
#
sub test_insertChange {
	my $dbh = $_[0] // "";
	my $err = "";
		
	
	#------------------------------------------------------------------------------#
	# Test no database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertChange()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no database handle');
	};


	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertChange("")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid insert (timestamp cannot be compared)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $idChange = MetagDB::Sga::insertChange($dbh);
		
		my @expecs = ($idChange, $dbh->{pg_user}, MetagDB::Utils::toSQL("127.0.0.1", "ip"));
		my $resR = $dbh->selectall_arrayref("SELECT id, username, ip FROM change");
		is ($resR, [\@expecs], 'Testing insert into change');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing insert into change');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh->rollback;
	};
		
	
	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the insertType function
#--------------------------------------------------------------------------------------------------#
#
sub test_insertType {
	my $dbh = $_[0] // "";
	
	my $isNew = 0;
	my $idChange = 1;
	my $maxRows = 2;
	my $idQuery = "name, id";
	my $err = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no id_change + no indication,
	# if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertType()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no database handle');
	};
	
		
	#------------------------------------------------------------------------------#
	# Test no id_change (+ no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertType($dbh)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no indication, if new data (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertType($dbh, $idChange)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows => Optional argument
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	my @tmps = (
		["sex", "s", ['m', 'f', 'NA'], $idChange],
		["body mass", "i", undef, $idChange],
		["birth mode", "s", ['natural', 'caesarean section'], $idChange],
		["feeding mode", "s", ['breastfed', 'formula', 'mixed', 'diet extension'], $idChange],
		["probiotics", "b", ['yes', 'no'], $idChange],
		["antibiotics", "b", ['yes', 'no'], $idChange],
		["mother's birth date", "d", undef, $idChange],
		["maternal body mass before pregnancy", "i", undef, $idChange],
		["maternal body mass at delivery", "i", undef, $idChange],
		["mother's height", "i", undef, $idChange],
		["pregnancy order", "i", undef, $idChange],
		["maternal illness during pregnancy", "s", ['diabetes', 'thyroid disease', 'hypertension',
			'diabetes + thyroid disease', 'diabetes + hypertension', 'thyroid disease + hypertension',
			'diabetes + thyroid disease + hypertension'], $idChange],
		["maternal antibiotics during pregnancy", "b", ['yes', 'no'], $idChange],
	);
	my @expecs = sort {lc($a->[0]) cmp lc($b->[0])} @tmps;
	
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		(my $keysR, $isNew) = MetagDB::Sga::insertType($dbh, $idChange, $isNew);		
		my $tmpsR = $dbh->selectall_arrayref("SELECT name, type, selection, id_change FROM type");
		my @res = sort {lc($a->[0]) cmp lc($b->[0])} @{$tmpsR};
		is (\@res, \@expecs, 'Testing no maxRows - data');
		
		my $resR = $dbh->selectall_arrayref("SELECT name, id FROM type");
		my %expecs = map {$_->[0] => $_->[1]} @{$resR};
		is ($keysR, \%expecs, 'Testing no maxRows - keys');
		is ($isNew, 1, 'Testing no maxRows - any new data inserted?');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing no maxRows');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertType("", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty id_change
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertType($dbh, "", $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty indication, if new data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertType($dbh, $idChange, "", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication if new data not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertType($dbh, $idChange, "abc", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing indication if new data not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication if new data invalid number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertType($dbh, $idChange, 2, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing indication if new data invalid number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertType($dbh, $idChange, $isNew, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing empty maxRows');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertType($dbh, $idChange, $isNew, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is zero
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertType($dbh, $idChange, $isNew, 0)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test insert with valid new data
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		(my $keysR, $isNew) = MetagDB::Sga::insertType($dbh, $idChange, $isNew, $maxRows);
		
		my $tmpsR = $dbh->selectall_arrayref("SELECT name, type, selection, id_change FROM type");
		my @res = sort {lc($a->[0]) cmp lc($b->[0])} @{$tmpsR};
		is (\@res, \@expecs, 'Testing valid new insert - data');
		
		my $resR = $dbh->selectall_arrayref("SELECT name, id FROM type");
		my %expecs = map {$_->[0] => $_->[1]} @{$resR};
		is ($keysR, \%expecs, 'Testing valid new insert - keys');
		is ($isNew, 1, 'Testing valid new insert - any new data inserted?');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing valid new insert');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test insert with valid old data
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		(my $keysR, $isNew) = MetagDB::Sga::insertType($dbh, $idChange, $isNew, $maxRows);
		
		# Reset isNew and insert the same data again
		$isNew = 0;
		($keysR, $isNew) = MetagDB::Sga::insertType($dbh, $idChange, $isNew, $maxRows);
		
		my $tmpsR = $dbh->selectall_arrayref("SELECT name, type, selection, id_change FROM type");
		my @res = sort {lc($a->[0]) cmp lc($b->[0])} @{$tmpsR};
		is (\@res, \@expecs, 'Testing valid old insert - data');
		
		my $resR = $dbh->selectall_arrayref("SELECT name, id FROM type");
		my %expecs = map {$_->[0] => $_->[1]} @{$resR};
		is ($keysR, \%expecs, 'Testing valid old insert - keys');
		is ($isNew, 0, 'Testing valid old insert - any new data inserted?');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing valid old insert');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	return $dbh;
}
	

#
#--------------------------------------------------------------------------------------------------#
# Test the insertPatient function
#--------------------------------------------------------------------------------------------------#
#
sub test_insertPatient {
	my $dbh = $_[0] // "";
	my $dataR = $_[1] // "";
	my $isNew = 0;
	my $idChange = 1;
	my $err = "";
	my $maxRows = 2;
	
	my $idQuery = "CONCAT(accession, '_', alias, '_', birthdate) AS key, id";

	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no data + no id_change + no indication, if
	# new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no data (+ no id_change + no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no data');
	};	
	
	
	#------------------------------------------------------------------------------#
	# Test no id_change (+ no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, $dataR)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no indication, if new data (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, $dataR, $idChange)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows (optional argument)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my %expecs = ("00001_p1_1900-01-01" => $idChange, "00002_p2_1900-02-02" => $idChange);
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		(my $outR, my $keysR, $isNew) = MetagDB::Sga::insertPatient($dbh, $dataR, $idChange, $isNew);
		my $tmpsR = $dbh->selectall_arrayref("SELECT CONCAT(accession, '_', alias, '_', birthdate), id_change FROM patient");
		my %inserts = map {$_->[0] => $_->[1]} @{$tmpsR};
		$tmpsR = $dbh->selectall_arrayref("SELECT $idQuery FROM patient");
		my %res = map {$_->[0] => $_->[1]} @{$tmpsR};
		
		is ($dataR, $outR, 'Testing no maxRows - data hash');
		is (\%expecs, \%inserts, 'Testing no maxRows - inserted data');
		is ($isNew, 1, 'Testing no maxRows - any new data?');
		is ($keysR, \%res, 'Testing no maxRows - foreign keys');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing no maxRows');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient("", $dataR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, "", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test data is not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, "abc", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No data/, 'Testing data not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test data empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, {}, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No data/, 'Testing data empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty id_change
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, $dataR, "", $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty indication, if new data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, $dataR, $idChange, "", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, $dataR, $idChange, "abc", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing indication, if new data not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data invalid number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, $dataR, $idChange, 2, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing indication, if new data invalid number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, $dataR, $idChange, $isNew, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing empty maxRows');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, $dataR, $idChange, $isNew, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is zero
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertPatient($dbh, $dataR, $idChange, $isNew, 0)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test insert with valid new data (none of the fields may be empty due to
	# not Null contraint in db)
	#------------------------------------------------------------------------------#	
	$isNew = 0;
	
	try {
		$err = "";
		
		my %expecs = ("00001_p1_1900-01-01" => $idChange, "00002_p2_1900-02-02" => $idChange);
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		(my $outR, my $keysR, $isNew) = MetagDB::Sga::insertPatient($dbh, $dataR, $idChange, $isNew, $maxRows);
		my $tmpsR = $dbh->selectall_arrayref("SELECT CONCAT(accession, '_', alias, '_', birthdate), id_change FROM patient");
		my %inserts = map {$_->[0] => $_->[1]} @{$tmpsR};
		$tmpsR = $dbh->selectall_arrayref("SELECT $idQuery FROM patient");
		my %res = map {$_->[0] => $_->[1]} @{$tmpsR};
		
		is ($dataR, $outR, 'Testing insert of valid data - data hash');
		is (\%expecs, \%inserts, 'Testing insert of valid data - inserted data');
		is ($isNew, 1, 'Testing insert of valid data - any new data?');
		is ($keysR, \%res, 'Testing insert of valid data - foreign keys');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing insert of valid data');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test insert of valid old data (duplicates within the data to be inserted
	# cannot occur, due to structure of dataR)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my %expecs = ("00001_p1_1900-01-01" => $idChange, "00002_p2_1900-02-02" => $idChange);
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (alias, accession, birthdate, id_change) VALUES ('p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (alias, accession, birthdate, id_change) VALUES ('p2', '00002', '1900-02-02', $idChange)");
		(my $outR, my $keysR, $isNew) = MetagDB::Sga::insertPatient($dbh, $dataR, $idChange, $isNew, $maxRows);
		my $tmpsR = $dbh->selectall_arrayref("SELECT CONCAT(accession, '_', alias, '_', birthdate), id_change FROM patient");
		my %inserts = map {$_->[0] => $_->[1]} @{$tmpsR};
		$tmpsR = $dbh->selectall_arrayref("SELECT $idQuery FROM patient");
		my %res = map {$_->[0] => $_->[1]} @{$tmpsR};
		
		is ($dataR, $outR, 'Testing insert of valid old data - data hash');
		is (\%expecs, \%inserts, 'Testing insert of valid old data - inserted data');
		is ($isNew, 0, 'Testing insert of valid old data - any new data?');
		is ($keysR, \%res, 'Testing insert of valid old data - foreign keys');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing insert of valid old data');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	

	#------------------------------------------------------------------------------#
	# Test insert into more relaxed hypothetical database schema. This is to test,
	# how the keys in the foreign keys hash behave, if they contained undef values.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my %expecs = ("_p1_" => $idChange, "_p2_" => $idChange);
		my $dataModR = dclone($dataR);
		foreach my $pat (keys(%{$dataModR})) {
			$dataModR->{$pat}->{'birth date'} = undef;
			$dataModR->{$pat}->{'hospital code'} = undef;
		}
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		# Loose not NULL constraints
		$dbh->do("ALTER TABLE patient ALTER COLUMN accession DROP NOT NULL");
		$dbh->do("ALTER TABLE patient ALTER COLUMN birthdate DROP NOT NULL");
		
		(my $outR, my $keysR, $isNew) = MetagDB::Sga::insertPatient($dbh, $dataModR, $idChange, $isNew, $maxRows);
		my $tmpsR = $dbh->selectall_arrayref("SELECT CONCAT(accession, '_', alias, '_', birthdate), id_change FROM patient");
		my %inserts = map {$_->[0] => $_->[1]} @{$tmpsR};
		$tmpsR = $dbh->selectall_arrayref("SELECT $idQuery FROM patient");
		my %res = map {$_ ->[0] => $_ ->[1]} @{$tmpsR};
		
		is ($dataModR, $outR, 'Testing insert data with NULL values - data hash');
		is (\%expecs, \%inserts, 'Testing insert data with NULL values - inserted data');
		is (\%res, $keysR, 'Testing insert data with NULL values - foreign keys');
		is ($isNew, 1, 'Testing insert data with NULL values - any new data?');
	}
	catch {
		# Always report failed test
		ok (1==2, 'Testing insert data with NULL values');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the insertSample function
#--------------------------------------------------------------------------------------------------#
#
sub test_insertSample {
	my $dbh = $_[0] // "";
	my $dataR = $_[1] // "";
	my $keysR = {
		"00001_p1_1900-01-01"	=> 1,
		"00002_p2_1900-02-02"	=> 2
	};
	my $idChange = 1;
	my $isNew = 0;
	my $maxRows = 2;
	my $err = "";
	my $idQuery = "id, CONCAT((select alias from patient p where p.id = sample.id_patient), '_', createdate, '_', iscontrol) AS key";
	
	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no data + no foreign keys + no id_change
	# + no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no database handle');
	};


	#------------------------------------------------------------------------------#
	# Test no data (+ no foreign keys + no id_change + no indication,
	# if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no data');
	};	
	
	
	#------------------------------------------------------------------------------#
	# Test no foreign keys (+ no id_change + no indication, if new data
	# + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no id_change (+ no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, $keysR)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no id_change');
	};	
	
	
	#------------------------------------------------------------------------------#
	# Test no indication, if new data (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, $keysR, $idChange)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows => optional argument
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		
		# Keys from insertPatient
		$keysR = {
			"00001_p1_1900-01-01"	=> 1,
			"00002_p2_1900-02-02"	=> 2
		};
		
		# id_patient, createdate, createdby, iscontrol, id_change in sample
		my @tmps = (
			[1, '1900-01-01', undef, 1, $idChange], [1, '1900-01-01', undef, 0, $idChange],
			[1, '1900-01-03', undef, 1, $idChange], [1, '1900-01-03', undef, 0, $idChange], 
			[2, '1900-02-02', undef, 1, $idChange], [2, '1900-02-02', undef, 0, $idChange],
			[2, '1900-02-05', undef, 1, $idChange], [2, '1900-02-05', undef, 0, $idChange]
		);
		# Sort by id_patient, date, and isControl
		my @expecs = sort ({$a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[3] <=> $b->[3]} @tmps);
				
		(my $outR, my $outKeysR, $isNew) = MetagDB::Sga::insertSample($dbh, $dataR, $keysR, $idChange, $isNew);
		my $resR = $dbh->selectall_arrayref('SELECT id_patient, createdate, createdby, iscontrol, id_change FROM sample');
		
		# Sort by id_patient, date, and isControl
		my @res = sort({$a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[3] <=> $b->[3]} @{$resR});	
		is ($dataR, $outR, 'Testing no maxRows - data hash');
		is (\@res, \@expecs, 'Testing no maxRows - data');
		
		# Get IDs in sample from database and compare to foreign keys hash
		my $tmpsR = $dbh->selectall_arrayref("SELECT $idQuery FROM sample");
		my %res = map {$_->[0] => $_->[1]} @{$tmpsR};
		
		foreach my $id (keys(%res)) {
			my $key = $res{$id};
			my ($pat, $date, $isControl) = split("_", $key, -1);
			$res{$id} = {%{$dataR->{$pat}->{"_times_"}->{$date}}, '_isControl_' => $isControl};
			
			# Add static values to first sample date
			if ($pat eq 'p1' and $date eq '1900-01-01' and $isControl eq "f") {
				$res{$id}->{'placeOfBirth'} = $dataR->{$pat}->{'placeOfBirth'}
			}
			elsif ($pat eq 'p2' and $date eq '1900-02-02' and $isControl eq "f") {
				$res{$id}->{'placeOfBirth'} = $dataR->{$pat}->{'placeOfBirth'}
			}
		}
		
		is ($outKeysR, \%res, 'Testing no maxRows - foreign keys');
		is ($isNew, 1, 'Testing no maxRows - any new data?');
	}
	catch {
		$err = $_;
		
		ok (1 == 2, 'Testing no maxRows');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample("", $dataR, $keysR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, "", $keysR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test data not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, "abc", $keysR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No data/, 'Testing data not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty data reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, {}, $keysR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No data/, 'Testing empty data reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty keys
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, "", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test keys not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, "abc", $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No data/, 'Testing keys not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty keys reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, {}, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No data/, 'Testing empty keys reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty id_change
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, $keysR, "", $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty indication, if new data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, $keysR, $idChange, "", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, $keysR, $idChange, "abc", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing indication, if new data not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data illegal number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, $keysR, $idChange, 2, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing indication, if new data illegal number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, $keysR, $idChange, $isNew, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing empty maxRows');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, $keysR, $idChange, $isNew, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is zero
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, $keysR, $idChange, $isNew, 0)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test missing patient in foreign keys
	#------------------------------------------------------------------------------#
	# Keys from insertPatient
	my $keysModR = {
		"00001_p1_1900-01-01"	=> 1
	};
	
	try {
		$err = "";
		MetagDB::Sga::insertSample($dbh, $dataR, $keysModR, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Patient.*not exist in foreign keys/, 'Testing incomplete foreign keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test insert with measurement having reserved name _isControl_
	#------------------------------------------------------------------------------#
	$isNew = 0;

	try {
		$err = "";
		
		my $dataModR = dclone($dataR);
		$dataModR->{'p1'}->{'_times_'}->{'1900-01-01'} = {'_isControl_' => undef};
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		
		MetagDB::Sga::insertSample($dbh, $dataModR, $keysR, $idChange, $isNew);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Special key.*_isControl_/, 'Testing reserved key _isControl_ in measurement');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no _times_ (and thus no samples) in data
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my $dataModR = dclone($dataR);
		delete $dataModR->{'p1'}->{'_times_'};
		delete $dataModR->{'p2'}->{'_times_'};
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		
		(my $outR, my $outKeysR, $isNew) = MetagDB::Sga::insertSample($dbh, $dataModR, $keysR, $idChange, $isNew);
		my $resR = $dbh->selectall_arrayref('SELECT id, id_patient, createdate, createdby, iscontrol, id_change FROM sample');
		is ($outR, $dataModR, 'Testing insert no samples - data hash');
		is ($resR, [], 'Testing insert no samples - data');
		is ($outKeysR, {}, 'Testing insert no samples - foreign keys');
		is ($isNew, 0, 'Testing insert no samples - any new data?');
	}
	catch {
		$err = $_;
		
		# Fail on any error
		ok (1==2, "Testing insert no samples");
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Test static name and time-dependent measurement name are the same
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my $dataModR = dclone($dataR);
		$dataModR->{'p1'}->{'height'} = 1;
		$dataModR->{'p2'}->{'height'} = 1;
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		MetagDB::Sga::insertSample($dbh, $dataModR, $keysR, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Static measurement and time-dependent.*same name/, "Testing illegal static name");
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid insert of new data
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		
		# Keys from insertPatient
		$keysR = {
			"00001_p1_1900-01-01"	=> 1,
			"00002_p2_1900-02-02"	=> 2
		};
		
		# id_patient, createdate, createdby, iscontrol, id_change in sample
		my @tmps = (
			[1, '1900-01-01', undef, 1, $idChange], [1, '1900-01-01', undef, 0, $idChange],
			[1, '1900-01-03', undef, 1, $idChange], [1, '1900-01-03', undef, 0, $idChange], 
			[2, '1900-02-02', undef, 1, $idChange], [2, '1900-02-02', undef, 0, $idChange],
			[2, '1900-02-05', undef, 1, $idChange], [2, '1900-02-05', undef, 0, $idChange]
		);
		# Sort by id_patient, date, and isControl
		my @expecs = sort ({$a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[3] <=> $b->[3]} @tmps);
				
		(my $outR, my $outKeysR, $isNew) = MetagDB::Sga::insertSample($dbh, $dataR, $keysR, $idChange, $isNew, $maxRows);
		my $resR = $dbh->selectall_arrayref('SELECT id_patient, createdate, createdby, iscontrol, id_change FROM sample');
		
		# Sort by id_patient, date, and isControl
		my @res = sort({$a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[3] <=> $b->[3]} @{$resR});	
		is ($dataR, $outR, 'Testing valid insert of new data - data hash');
		is (\@res, \@expecs, 'Testing valid insert of new data - data');
		
		# Get IDs in sample from database and compare to foreign keys hash
		my $tmpsR = $dbh->selectall_arrayref("SELECT $idQuery FROM sample");
		my %res = map {$_->[0] => $_->[1]} @{$tmpsR};
		
		foreach my $id (keys(%res)) {
			my $key = $res{$id};
			my ($pat, $date, $isControl) = split("_", $key, -1);
			$res{$id} = {%{$dataR->{$pat}->{"_times_"}->{$date}}, '_isControl_' => $isControl};
			
			# Add static values to first sample date
			if ($pat eq 'p1' and $date eq '1900-01-01' and $isControl eq "f") {
				$res{$id}->{'placeOfBirth'} = $dataR->{$pat}->{'placeOfBirth'}
			}
			elsif ($pat eq 'p2' and $date eq '1900-02-02' and $isControl eq "f") {
				$res{$id}->{'placeOfBirth'} = $dataR->{$pat}->{'placeOfBirth'}
			}
		}
		is ($outKeysR, \%res, 'Testing valid insert of new data - foreign keys');
		is ($isNew, 1, 'Testing valid insert of new data - any new data?');
	}
	catch {
		$err = $_;
		
		ok (1 == 2, 'Testing valid insert of new data');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	

	#------------------------------------------------------------------------------#
	# Test valid insert of old data (due to the structure of dataR, it is not
	# possible to have duplicates during the insert)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, '1900-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, '1900-01-03', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, '1900-01-03', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, '1900-02-02', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, '1900-02-05', NULL, 'f', $idChange)");
		
		# Keys from insertPatient
		$keysR = {
			"00001_p1_1900-01-01"	=> 1,
			"00002_p2_1900-02-02"	=> 2
		};
		
		# id_patient, createdate, createdby, iscontrol, id_change in sample
		my @tmps = (
			[1, '1900-01-01', undef, 1, $idChange], [1, '1900-01-01', undef, 0, $idChange],
			[1, '1900-01-03', undef, 1, $idChange], [1, '1900-01-03', undef, 0, $idChange], 
			[2, '1900-02-02', undef, 1, $idChange], [2, '1900-02-02', undef, 0, $idChange],
			[2, '1900-02-05', undef, 1, $idChange], [2, '1900-02-05', undef, 0, $idChange]
		);
		# Sort by id_patient, date, and isControl
		my @expecs = sort ({$a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[3] <=> $b->[3]} @tmps);
				
		(my $outR, my $outKeysR, $isNew) = MetagDB::Sga::insertSample($dbh, $dataR, $keysR, $idChange, $isNew, $maxRows);
		my $resR = $dbh->selectall_arrayref('SELECT id_patient, createdate, createdby, iscontrol, id_change FROM sample');
		
		# Sort by id_patient, date, and isControl
		my @res = sort({$a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[3] <=> $b->[3]} @{$resR});	
		is ($dataR, $outR, 'Testing valid insert of old data - data hash');
		is (\@res, \@expecs, 'Testing valid insert of old data - data');
		
		# Get IDs in sample from database and compare to foreign keys hash
		my $tmpsR = $dbh->selectall_arrayref("SELECT $idQuery FROM sample");
		my %res = map {$_->[0] => $_->[1]} @{$tmpsR};
		
		foreach my $id (keys(%res)) {
			my $key = $res{$id};
			my ($pat, $date, $isControl) = split("_", $key, -1);
			$res{$id} = {%{$dataR->{$pat}->{"_times_"}->{$date}}, '_isControl_' => $isControl};
			
			# Add static values to first sample date
			if ($pat eq 'p1' and $date eq '1900-01-01' and $isControl eq "f") {
				$res{$id}->{'placeOfBirth'} = $dataR->{$pat}->{'placeOfBirth'}
			}
			elsif ($pat eq 'p2' and $date eq '1900-02-02' and $isControl eq "f") {
				$res{$id}->{'placeOfBirth'} = $dataR->{$pat}->{'placeOfBirth'}
			}
		}
		is ($outKeysR, \%res, 'Testing valid insert of old data - foreign keys');
		is ($isNew, 0, 'Testing valid insert of old data - any new data?');
	}
	catch {
		$err = $_;
		
		ok (1 == 2, 'Testing valid insert of old data');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};

	
	#------------------------------------------------------------------------------#
	# Test first date in transaction is not the overall first date
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, '1900-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, '1900-02-02', NULL, 'f', $idChange)");
		
		# Keys from insertPatient
		$keysR = {
			"00001_p1_1900-01-01"	=> 1,
			"00002_p2_1900-02-02"	=> 2
		};
		
		# id_patient, createdate, createdby, iscontrol, id_change in sample
		my @tmps = (
			[1, '1900-01-01', undef, 1, $idChange], [1, '1900-01-01', undef, 0, $idChange],
			[1, '1900-01-03', undef, 1, $idChange], [1, '1900-01-03', undef, 0, $idChange], 
			[2, '1900-02-02', undef, 1, $idChange], [2, '1900-02-02', undef, 0, $idChange],
			[2, '1900-02-05', undef, 1, $idChange], [2, '1900-02-05', undef, 0, $idChange]
		);
		# Sort by id_patient, date, and isControl
		my @expecs = sort ({$a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[3] <=> $b->[3]} @tmps);
		
		my $data_modR = dclone($dataR);
		delete $data_modR->{"p1"}->{'_times_'}->{'1900-01-01'};
		delete $data_modR->{"p2"}->{'_times_'}->{'1900-02-02'};
				
		(my $outR, my $outKeysR, $isNew) = MetagDB::Sga::insertSample($dbh, $data_modR, $keysR, $idChange, $isNew, $maxRows);
		my $resR = $dbh->selectall_arrayref('SELECT id_patient, createdate, createdby, iscontrol, id_change FROM sample');
		
		# Sort by id_patient, date, and isControl
		my @res = sort({$a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[3] <=> $b->[3]} @{$resR});	
		is ($data_modR, $outR, 'Testing first date in transaction is not the overall first date - data hash');
		is (\@res, \@expecs, 'Testing first date in transaction is not the overall first date - data');
		
		# Get IDs in sample from database and compare to foreign keys hash
		# Only use dates that are part of current transaction.
		my $tmpsR = $dbh->selectall_arrayref("SELECT $idQuery FROM sample WHERE createdate != '1900-01-01' and createdate != '1900-02-02'");
		my %res = map {$_->[0] => $_->[1]} @{$tmpsR};
		
		foreach my $id (keys(%res)) {
			my $key = $res{$id};
			my ($pat, $date, $isControl) = split("_", $key, -1);
			$res{$id} = {%{$dataR->{$pat}->{"_times_"}->{$date}}, '_isControl_' => $isControl};
		}
		is ($outKeysR, \%res, 'Testing first date in transaction is not the overall first date - foreign keys');
		is ($isNew, 1, 'Testing first date in transaction is not the overall first date - any new data?');
	}
	catch {
		$err = $_;
		
		ok (1 == 2, 'Testing first date in transaction is not the overall first date');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test insert earlier sample date than the one in database => ERROR
	# Would require deletion of statics from previous first date and assigning
	# them to new first date. Not implemented.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, '1900-02-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, '1900-02-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, '1900-03-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, '1900-03-02', NULL, 'f', $idChange)");
		
		# Keys from insertPatient
		$keysR = {
			"00001_p1_1900-01-01"	=> 1,
			"00002_p2_1900-02-02"	=> 2
		};
		
		# id_patient, createdate, createdby, iscontrol, id_change in sample
		my @tmps = (
			[1, '1900-01-01', undef, 1, $idChange], [1, '1900-01-01', undef, 0, $idChange],
			[1, '1900-01-03', undef, 1, $idChange], [1, '1900-01-03', undef, 0, $idChange], 
			[2, '1900-02-02', undef, 1, $idChange], [2, '1900-02-02', undef, 0, $idChange],
			[2, '1900-02-05', undef, 1, $idChange], [2, '1900-02-05', undef, 0, $idChange]
		);
		# Sort by id_patient, date, and isControl
		my @expecs = sort ({$a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[3] <=> $b->[3]} @tmps);

		(my $outR, my $outKeysR, $isNew) = MetagDB::Sga::insertSample($dbh, $dataR, $keysR, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not possible to set a new first date for patient/, 'Testing insertion of new first date');
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Test with more relaxed hypothetical patient relation that allows NULL
	# values in accession. This tests, if the foreign keys hash that is input into
	# insertSample could still be processed. The birthdate has too many inter-
	# dependencies, so it is unlikely to ever be allowed to be NULL --> not tested.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my $dataModR = dclone($dataR);
		foreach my $pat (keys(%{$dataModR})) {
			$dataModR->{$pat}->{'hospital code'} = undef;
		}
		# Loose not Null constraints
		$dbh->do("ALTER TABLE patient ALTER COLUMN accession DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', NULL, '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', NULL, '1900-02-02', $idChange)");
		
		# Keys from insertPatient
		$keysR = {
			"_p1_1900-01-01"	=> 1,
			"_p2_1900-02-02"	=> 2
		};
		
		# id_patient, createdate, createdby, iscontrol, id_change in sample
		my @tmps = (
			[1, '1900-01-01', undef, 1, $idChange], [1, '1900-01-01', undef, 0, $idChange],
			[1, '1900-01-03', undef, 1, $idChange], [1, '1900-01-03', undef, 0, $idChange], 
			[2, '1900-02-02', undef, 1, $idChange], [2, '1900-02-02', undef, 0, $idChange],
			[2, '1900-02-05', undef, 1, $idChange], [2, '1900-02-05', undef, 0, $idChange]
		);
		# Sort by id_patient, date, and isControl
		my @expecs = sort ({$a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[3] <=> $b->[3]} @tmps);
				
		(my $outR, my $outKeysR, $isNew) = MetagDB::Sga::insertSample($dbh, $dataModR, $keysR, $idChange, $isNew, $maxRows);
		my $resR = $dbh->selectall_arrayref('SELECT id_patient, createdate, createdby, iscontrol, id_change FROM sample');
		
		# Sort by id_patient, date, and isControl
		my @res = sort({$a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] || $a->[3] <=> $b->[3]} @{$resR});	
		is ($dataModR, $outR, 'Testing insert with NULL data - data hash');
		is (\@res, \@expecs, 'Testing insert with NULL data - data');
		
		# Get IDs in sample from database and compare to foreign keys hash
		my $tmpsR = $dbh->selectall_arrayref("SELECT $idQuery FROM sample");
		my %res = map {$_->[0] => $_->[1]} @{$tmpsR};
		
		foreach my $id (keys(%res)) {
			my $key = $res{$id};
			my ($pat, $date, $isControl) = split("_", $key, -1);
			$res{$id} = {%{$dataR->{$pat}->{"_times_"}->{$date}}, '_isControl_' => $isControl};
			
			# Add static values to first sample date
			if ($pat eq 'p1' and $date eq '1900-01-01' and $isControl eq "f") {
				$res{$id}->{'placeOfBirth'} = $dataR->{$pat}->{'placeOfBirth'}
			}
			elsif ($pat eq 'p2' and $date eq '1900-02-02' and $isControl eq "f") {
				$res{$id}->{'placeOfBirth'} = $dataR->{$pat}->{'placeOfBirth'}
			}
		}
		is ($outKeysR, \%res, 'Testing insert with NULL data - foreign keys');
		is ($isNew, 1, 'Testing insert with NULL data - any new data?');
	}
	catch {
		$err = $_;
		
		ok (1 == 2, 'Testing insert with NULL data');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test createdate cannot be converted to timepoint (out of range)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	# Keys from insertPatient
	$keysR = {
		"00001_p1_1900-01-01"	=> 1,
		"00002_p2_1900-02-02"	=> 2
	};	
	my $dataModR = dclone($dataR);
	$dataModR->{'p1'}->{'_times_'} = {'1910-01-01' => {}};
	
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		my ($dataR, $keysSampleR, $isNew) = MetagDB::Sga::insertSample($dbh, $dataModR, $keysR, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Timepoint.*is invalid/, "Testing createdate cannot be converted to timepoint");
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test timepoints for patient not unique
	#------------------------------------------------------------------------------#
	$isNew = 0;
	# Keys from insertPatient
	$keysR = {
		"00001_p1_1900-01-01"	=> 1,
		"00002_p2_1900-02-02"	=> 2
	};
	$dataModR = dclone($dataR);
	# Fuzzy translation of createdates to timepoints:
	# 1900-01-02 and 1900-01-01 are both within the boundaries for meconium.
	$dataModR->{'p1'}->{'_times_'}->{'1900-01-02'} = {};
	
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, ts, username, ip) VALUES ($idChange, 1234, 'testuser', 123456)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		MetagDB::Sga::insertSample($dbh, $dataModR, $keysR, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Timepoint.*is invalid/, "Testing timepoints for patient not unique");
		$dbh->rollback;
	};
		
	
	return $dbh;	
}


#
#--------------------------------------------------------------------------------------------------#
# Test the insertMeasurement function
#--------------------------------------------------------------------------------------------------#
#
sub test_insertMeasurement {
	my $dbh = $_[0] // "";
	
	my $idChange = 1;
	my $isNew = 0;
	my $maxRows = 2;
	my $keysSampleR = {
		1 => { # p1: 1900-01-01 isControl: f
			'number of run and barcode'	=> 'run01_bar01',
			'height'					=> '30cm',
			'program'					=> 'MetaG',
			'database'					=> 'RDP',
			'_isControl_'				=> 'f',
			'placeOfBirth'				=> 'New York' # static
		},
		2 => { # p1: 1900-01-01 isControl: t
			'number of run and barcode'	=> 'run01_bar01',
			'height'					=> '30cm',
			'program'					=> 'MetaG',
			'database'					=> 'RDP',
			'_isControl_'				=> 't',
		},
		3 => { # p1: 1900-01-02 isControl: f
			'number of run and barcode'	=> 'run02_bar01',
			'height'					=> '31cm',
			'program'					=> 'MetaG',
			'database'					=> 'RDP',
			'_isControl_'				=> 'f',
		},
		4 => { # p1: 1900-01-02 isControl: t
			'number of run and barcode'	=> 'run02_bar01',
			'height'					=> '31cm',
			'program'					=> 'MetaG',
			'database'					=> 'RDP',
			'_isControl_'				=> 't',
		},
		5 => { # p2: 1900-02-02 isControl: f
			'number of run and barcode'	=> 'run03_bar01',
			'height'					=> '35cm',
			'program'					=> 'MetaG',
			'database'					=> 'RDP',
			'_isControl_'				=> 'f',
			'placeOfBirth'				=> 'San Francisco' # static
		},
		6 => { # p2: 1900-02-02 isControl: t
			'number of run and barcode'	=> 'run03_bar01',
			'height'					=> '35cm',
			'program'					=> 'MetaG',
			'database'					=> 'RDP',
			'_isControl_'				=> 't',
		},
		7 => { # p2: 1900-02-03 isControl: f
			'number of run and barcode'	=> 'run04_bar01',
			'height'					=> '36cm',
			'program'					=> 'MetaG',
			'database'					=> 'RDP',
			'_isControl_'				=> 'f'
		},
		8 => { # p2: 1900-02-03 isControl: t
			'number of run and barcode'	=> 'run04_bar01',
			'height'					=> '36cm',
			'program'					=> 'MetaG',
			'database'					=> 'RDP',
			'_isControl_'				=> 't'
		}
	};
	my $keysTypeR = {
		"placeOfBirth"		=> 1,
		"height"			=> 2
	};

	my $err = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no sample keys + no type keys + no id_change
	# + no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no sample keys (+ no type keys + no id_change + no indication, if
	# new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no sample keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no type keys (+ no id_change + no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no type keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no id_change (+ no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no indication, if new data (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows => optional argument
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	my @expecs = (
		[1, 1, 'New York' , $idChange],
		[1, 2, '30cm' , $idChange],
		[3, 2, '31cm' , $idChange],
		[5, 1, 'San Francisco' , $idChange],
		[5, 2, '35cm' , $idChange],
		[7, 2, '36cm' , $idChange],
	);
	
	try {
		$err = "";
		
		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, 'placeOfBirth', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, 'height', 's', NULL, $idChange)");
		
		$isNew = MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange, $isNew);
		my $dataR = $dbh->selectall_arrayref("SELECT id_sample, id_type, value, id_change FROM measurement ORDER BY id_sample, id_type asc");	
		is (\@expecs, $dataR, 'Testing no maxRows - inserted data');
		is ($isNew, 1, 'Testing no maxRows - any new data?');
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing no maxRows');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback
	};
	

	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement("", $keysSampleR, $keysTypeR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty sample keys
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, "", $keysTypeR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty sample keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test sample keys not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, "abc", $keysTypeR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No sample keys or no type keys/, 'Testing sample keys not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test sample keys empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, {}, $keysTypeR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No sample keys or no type keys/, 'Testing sample keys empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty type keys
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, "", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty type keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test type keys not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, "abc", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No sample keys or no type keys/, 'Testing type keys not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test type keys empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, {}, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No sample keys or no type keys/, 'Testing type keys empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty id_change
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, "", $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty indication, if new data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange, "", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication if new data not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange, "abc", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing indication if new data not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication if new data illegal number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange, 2, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing indication if new data illegal number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange, $isNew, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing empty maxRows');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange, $isNew, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is zero
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange, $isNew, 0)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid sample keys (no '_isControl_')
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
	
		my $keysSample_modR = dclone ($keysSampleR);
		foreach my $idSample (keys(%{$keysSample_modR})) {
			delete $keysSample_modR->{$idSample}->{"_isControl_"}
		}
		MetagDB::Sga::insertMeasurement($dbh, $keysSample_modR, $keysTypeR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid sample keys/, 'Testing invalid sample keys')
	};	
	
	
	#------------------------------------------------------------------------------#
	# Test only non-case samples (_isControl_ != f)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
	
		my $keysSample_modR = dclone ($keysSampleR);
		foreach my $idSample (keys(%{$keysSample_modR})) {
			$keysSample_modR->{$idSample}->{'_isControl_'} = undef
		}
		
		$isNew = MetagDB::Sga::insertMeasurement($dbh, $keysSample_modR, $keysTypeR, $idChange, $isNew, $maxRows);
		my $dataR = $dbh->selectall_arrayref("SELECT id_sample, id_type, value, id_change FROM measurement ORDER BY id_sample, id_type asc");	
		is ([], $dataR, 'Testing only non-case samples - inserted data');
		is ($isNew, 0, 'Testing only non-case samples - any new data?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing only non-case samples');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no measurements
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
	
		my $keysSample_modR = dclone ($keysSampleR);
		foreach my $idSample (keys(%{$keysSample_modR})) {
			foreach my $type (keys(%{$keysSample_modR->{$idSample}})) {
				# If _isControl_ would also be deleted, this would trigger
				# an error upstream
				next if ($type eq "_isControl_");
				delete $keysSample_modR->{$idSample}->{$type}
			}
		}
		
		$isNew = MetagDB::Sga::insertMeasurement($dbh, $keysSample_modR, $keysTypeR, $idChange, $isNew, $maxRows);
		my $dataR = $dbh->selectall_arrayref("SELECT id_sample, id_type, value, id_change FROM measurement ORDER BY id_sample, id_type asc");	
		is ([], $dataR, 'Testing no measurements - inserted data');
		is ($isNew, 0, 'Testing no measurements - any new data?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing no measurements');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test only empty measurements
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
	
		my $keysSample_modR = dclone ($keysSampleR);
		foreach my $idSample (keys(%{$keysSample_modR})) {
			foreach my $type (keys(%{$keysSample_modR->{$idSample}})) {
				# If _isControl_ would also be altered, this would trigger
				# an error upstream
				next if ($type eq '_isControl_');
				$keysSample_modR->{$idSample}->{$type} = undef
			}
		}
		
		$isNew = MetagDB::Sga::insertMeasurement($dbh, $keysSample_modR, $keysTypeR, $idChange, $isNew, $maxRows);
		my $dataR = $dbh->selectall_arrayref("SELECT id_sample, id_type, value, id_change FROM measurement ORDER BY id_sample, id_type asc");	
		is ([], $dataR, 'Testing only empty measurements - inserted data');
		is ($isNew, 0, 'Testing only empty measurements - any new data?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing only empty measurements');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test zero measurements are kept
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
	
		my $keysSample_modR = dclone ($keysSampleR);
		foreach my $idSample (keys(%{$keysSample_modR})) {
			foreach my $type (keys(%{$keysSample_modR->{$idSample}})) {
				# If _isControl_ would also be altered, this would trigger
				# an error upstream
				next if ($type eq '_isControl_');
				$keysSample_modR->{$idSample}->{$type} = 0
			}
		}
		
		my $expecs_modR = dclone (\@expecs);
		foreach my $ref (@{$expecs_modR}) {
			$ref->[2] = 0
		}
		
		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, 'placeOfBirth', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, 'height', 's', NULL, $idChange)");
		
		$isNew = MetagDB::Sga::insertMeasurement($dbh, $keysSample_modR, $keysTypeR, $idChange, $isNew, $maxRows);
		my $dataR = $dbh->selectall_arrayref("SELECT id_sample, id_type, value, id_change FROM measurement ORDER BY id_sample, id_type asc");	
		is ($expecs_modR, $dataR, 'Testing that zero in measurements is kept - inserted data');
		is ($isNew, 1, 'Testing that zero in measurements is kept - any new data?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing that zero in measurements is kept');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# All measurements blacklisted
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
	
		# All measurements from $sampleKeysR except "placeOfBirth" and "height" are blacklisted
		my $keysSample_modR = dclone ($keysSampleR);
		foreach my $idSample (keys(%{$keysSample_modR})) {
			delete $keysSample_modR->{$idSample}->{'placeOfBirth'};
			delete $keysSample_modR->{$idSample}->{'height'};
		}
		
		$isNew = MetagDB::Sga::insertMeasurement($dbh, $keysSample_modR, $keysTypeR, $idChange, $isNew, $maxRows);
		my $dataR = $dbh->selectall_arrayref("SELECT id_sample, id_type, value, id_change FROM measurement ORDER BY id_sample, id_type asc");	
		is ([], $dataR, 'Testing all measurements blacklisted - inserted data');
		is ($isNew, 0, 'Testing all measurements blacklisted - any new data?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing all measurements blacklisted');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test unexpected type
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $keysType_modR = dclone ($keysTypeR);
		delete $keysType_modR->{"height"};
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysType_modR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Unexpected type/, 'Testing unexpected type');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no IDs in type keys
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $keysType_modR = dclone($keysTypeR);
		foreach my $type (keys(%{$keysType_modR})) {
			$keysType_modR->{$type} = undef;
		}
		MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysType_modR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No ID for type/, 'Testing no IDs in type keys');
	};
	
		
	#------------------------------------------------------------------------------#
	# Test valid insert of new data
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, 'placeOfBirth', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, 'height', 's', NULL, $idChange)");
		
		$isNew = MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange, $isNew, $maxRows);
		my $dataR = $dbh->selectall_arrayref("SELECT id_sample, id_type, value, id_change FROM measurement ORDER BY id_sample, id_type asc");	
		is (\@expecs, $dataR, 'Testing valid insert of new data - inserted data');
		is ($isNew, 1, 'Testing valid insert of new data - any new data?');
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing valid insert of new data');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid insert of old data
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, 'placeOfBirth', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, 'height', 's', NULL, $idChange)");
		
		$isNew = MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange, $isNew, $maxRows);
		
		# Reset isNew and insert the same data again
		$isNew = 0;
		$isNew = MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange, $isNew, $maxRows);
		
		my $dataR = $dbh->selectall_arrayref("SELECT id_sample, id_type, value, id_change FROM measurement ORDER BY id_sample, id_type asc");	
		is (\@expecs, $dataR, 'Testing valid insert of old data - inserted data');
		is ($isNew, 0, 'Testing valid insert of old data - any new data?');
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing valid insert of old data');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback
	};
	
	
	#------------------------------------------------------------------------------#
	# Test translation of all measurement values
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
	
		my $keysSample_modR = dclone($keysSampleR);
		
		# Force samples 2-6 to be non-control. Control samples have no
		# measurements by definition.
		$keysSample_modR->{2}->{'_isControl_'} = 'f';
		$keysSample_modR->{4}->{'_isControl_'} = 'f';
		$keysSample_modR->{6}->{'_isControl_'} = 'f';
		
		$keysSample_modR->{1}->{'sex'} = 1; # m
		$keysSample_modR->{2}->{'sex'} = 2; # f
		$keysSample_modR->{1}->{'birth mode'} = 1; # natural
		$keysSample_modR->{2}->{'birth mode'} = 2; # caesarean section
		$keysSample_modR->{1}->{'feeding mode'} = 1; # breastfed
		$keysSample_modR->{2}->{'feeding mode'} = 2; # formula
		$keysSample_modR->{3}->{'feeding mode'} = 3; # mixed
		$keysSample_modR->{4}->{'feeding mode'} = 4; # diet extension
		$keysSample_modR->{1}->{'probiotics'} = 1; # yes
		$keysSample_modR->{2}->{'probiotics'} = 2; # no
		$keysSample_modR->{1}->{'antibiotics'} = 1; # yes
		$keysSample_modR->{2}->{'antibiotics'} = 2; # no
		$keysSample_modR->{1}->{'maternal illness during pregnancy'} = 1; # diabetes
		$keysSample_modR->{2}->{'maternal illness during pregnancy'} = 2; # thyroid disease
		$keysSample_modR->{3}->{'maternal illness during pregnancy'} = 3; # hypertention
		$keysSample_modR->{4}->{'maternal illness during pregnancy'} = 4; # diabetes + thyroid disease
		$keysSample_modR->{5}->{'maternal illness during pregnancy'} = 5; # diabetes + hypertension
		$keysSample_modR->{6}->{'maternal illness during pregnancy'} = 6; # thyroid disease + hypertension
		$keysSample_modR->{7}->{'maternal illness during pregnancy'} = 7; # diabetes + thyroid disease + hypertension
		$keysSample_modR->{1}->{'maternal antibiotics during pregnancy'} = 1; # yes
		$keysSample_modR->{2}->{'maternal antibiotics during pregnancy'} = 2; # no
		
		my $keysType_modR = dclone($keysTypeR);
		$keysType_modR->{"sex"}										= 3;
		$keysType_modR->{"birth mode"}								= 4;
		$keysType_modR->{"feeding mode"}							= 5;
		$keysType_modR->{"probiotics"}								= 6;
		$keysType_modR->{"antibiotics"}								= 7;
		$keysType_modR->{"maternal illness during pregnancy"}		= 8;
		$keysType_modR->{"maternal antibiotics during pregnancy"}	= 9;
		
		my @expecs_mod = (
			[1, 1, 'New York' , $idChange],
			[1, 2, '30cm' , $idChange],
			[1, 3, 'm' , $idChange],
			[1, 4, 'natural' , $idChange],
			[1, 5, 'breastfed' , $idChange],
			[1, 6, 'yes' , $idChange],
			[1, 7, 'yes' , $idChange],
			[1, 8, 'diabetes' , $idChange],
			[1, 9, 'yes' , $idChange],
			[2, 2, '30cm' , $idChange],
			[2, 3, 'f' , $idChange],
			[2, 4, 'caesarean section' , $idChange],
			[2, 5, 'formula' , $idChange],
			[2, 6, 'no' , $idChange],
			[2, 7, 'no' , $idChange],
			[2, 8, 'thyroid disease' , $idChange],
			[2, 9, 'no' , $idChange],
			[3, 2, '31cm' , $idChange],
			[3, 5, 'mixed' , $idChange],
			[3, 8, 'hypertension' , $idChange],
			[4, 2, '31cm' , $idChange],
			[4, 5, 'diet extension' , $idChange],
			[4, 8, 'diabetes + thyroid disease' , $idChange],
			[5, 1, 'San Francisco' , $idChange],
			[5, 2, '35cm' , $idChange],
			[5, 8, 'diabetes + hypertension' , $idChange],
			[6, 2, '35cm' , $idChange],
			[6, 8, 'thyroid disease + hypertension' , $idChange],
			[7, 2, '36cm' , $idChange],
			[7, 8, 'diabetes + thyroid disease + hypertension' , $idChange],
		);
		
		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, 'placeOfBirth', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, 'height', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, 'sex', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'birth mode', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, 'feeding mode', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, 'probiotics', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (7, 'antibiotics', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (8, 'maternal illness during pregnancy', 's', NULL, $idChange)");
		$dbh->do ("INSERT INTO type (id, name, type, selection, id_change) VALUES (9, 'maternal antibiotics during pregnancy', 's', NULL, $idChange)");
		
		$isNew = MetagDB::Sga::insertMeasurement($dbh, $keysSample_modR, $keysType_modR, $idChange, $isNew, $maxRows);
		my $dataR = $dbh->selectall_arrayref("SELECT id_sample, id_type, value, id_change FROM measurement ORDER BY id_sample, id_type asc");
		
		is (\@expecs_mod, $dataR, 'Testing translation of all measurement values - inserted data');
		is ($isNew, 1, 'Testing translation of all measurement values - any new data?');
		
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing translation of all measurement values');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback
	};
	
	
	#------------------------------------------------------------------------------#
	# Translate measurement with illegal value
	#------------------------------------------------------------------------------#
	try {
		$err = "";
	
		my $keysSample_modR = dclone($keysSampleR);
		$keysSample_modR->{5}->{'birth mode'} = 10;
		
		my $keysType_modR = dclone($keysTypeR);
		$keysType_modR->{"birth mode"} = 4;
		
		MetagDB::Sga::insertMeasurement($dbh, $keysSample_modR, $keysType_modR, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Unexpected value.*cannot be translated/, 'Testing translation of measurement with illegal value');
	};
	
	
	return $dbh;
}	


#
#--------------------------------------------------------------------------------------------------#
# Test the insertSequence function
#--------------------------------------------------------------------------------------------------#
#
sub test_insertSequence {
	my $dbh = $_[0] // "";
	my $basePath = $_[1] // "";
	
	my $keysR = {
		"1"	=> { # p1: 1900-01-01
			'number of run and barcode'	=> 'run01_bar01',
			'height'					=> '30cm',
			'_isControl_'				=> "f",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"2"	=> { # p1: 1900-01-01
			'number of run and barcode'	=> 'run01_bar01', # interpreted later as 'run01_bar99'
			'height'					=> '30cm',
			'_isControl_'				=> "t",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"3" => { # p1: 1900-01-02
			'number of run and barcode'	=> 'run02_bar01',
			'height'					=> '31cm',
			'_isControl_'				=> "f",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"4"	=> { # p1: 1900-01-02
			'number of run and barcode'	=> 'run02_bar01', # interpreted later as 'run02_bar99'
			'height'					=> '31cm',
			'_isControl_'				=> "t",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"5" => { # p2: 1900-02-02
			'number of run and barcode'	=> 'run03_bar01',
			'height'					=> '35cm',
			'_isControl_'				=> "f",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"6" => { # p2: 1900-02-02
			'number of run and barcode'	=> 'run03_bar01', # interpreted later as 'run03_bar99'
			'height'					=> '35cm',
			'_isControl_'				=> "t",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"7"	=> { # p2: 1900-02-03
			'number of run and barcode'	=> 'run04_bar01',
			'height'					=> '36cm',
			'_isControl_'				=> "f",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"8"	=> { # p2: 1900-02-03
			'number of run and barcode'	=> 'run04_bar01', # interpreted later as 'run04_bar99'
			'height'					=> '36cm',
			'_isControl_'				=> "t",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		}
	};
	
	my $outKeysR = {};
	my $idChange = 1;
	my $isNew = 0;
	my $maxRows = 2;
	my $err = "";

	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no foreign keys + no dir path + no id_change
	# + no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no database handle');
	};


	#------------------------------------------------------------------------------#
	# Test no foreign keys (+ no dir path + no id_change + no indication,
	# if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no foreign keys');
	};	
	
		
	#------------------------------------------------------------------------------#
	# Test no dir path (+ no id_change + no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, $keysR)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no dir path');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no id_change (+ no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, $keysR, $basePath)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no indication, if new data (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	my %tmps = ();
	
	try {
		$err = "";
		
		my @keys = sort {$a cmp $b} keys (%{$keysR});
		my @fastqs = (
			"\@a runid=r1 barcode=b1 flow_cell_id=f1 basecall_model_version_id=m1\nA\n\+\n!\n",
			"\@b runid=r2 barcode=b2 flow_cell_id=f2 basecall_model_version_id=m2\nAA\n\+\n!!\n",
			"\@c runid=r3 barcode=b3 flow_cell_id=f3 basecall_model_version_id=m3\nAAA\n\+\n!!!\n",
			"\@d runid=r4 barcode=b4 flow_cell_id=f4 basecall_model_version_id=m4\nAAAA\n\+\n!!!!\n",
			"\@e runid=r5 barcode=b5 flow_cell_id=f5 basecall_model_version_id=m5\nAAAAA\n\+\n!!!!!\n",
			"\@f runid=r6 barcode=b6 flow_cell_id=f6 basecall_model_version_id=m6\nAAAAAA\n\+\n!!!!!!\n",
			"\@g runid=r7 barcode=b7 flow_cell_id=f7 basecall_model_version_id=m7\nAAAAAAA\n\+\n!!!!!!!\n",
			"\@h runid=r8 barcode=b8 flow_cell_id=f8 basecall_model_version_id=m8\nAAAAAAAA\n\+\n!!!!!!!!\n"
		);
		# Expected entries in sequence:
		# 2 patients, 2 samples per patient, 2 reads per sample
		my @expecs = (
			[1, 'f1', 'r1', 'b1', 'a', 'm1', 'A', '!', 1, 1, $idChange],
			[1, 'f1', 'r1', 'b1', 'a_1', 'm1', 'A', '!', 1, 1, $idChange],
			[2, 'f2', 'r2', 'b2', 'b', 'm2', 'AA', '!!', 2, 1, $idChange],
			[2, 'f2', 'r2', 'b2', 'b_1', 'm2', 'AA', '!!', 2, 1, $idChange],
			[3, 'f3', 'r3', 'b3', 'c', 'm3', 'AAA', '!!!', 3, 1, $idChange],
			[3, 'f3', 'r3', 'b3', 'c_1', 'm3', 'AAA', '!!!', 3, 1, $idChange],
			[4, 'f4', 'r4', 'b4', 'd', 'm4', 'AAAA', '!!!!', 4, 1, $idChange],
			[4, 'f4', 'r4', 'b4', 'd_1', 'm4', 'AAAA', '!!!!', 4, 1, $idChange],
			[5, 'f5', 'r5', 'b5', 'e', 'm5', 'AAAAA', '!!!!!', 5, 1, $idChange],
			[5, 'f5', 'r5', 'b5', 'e_1', 'm5', 'AAAAA', '!!!!!', 5, 1, $idChange],
			[6, 'f6', 'r6', 'b6', 'f', 'm6', 'AAAAAA', '!!!!!!', 6, 1, $idChange],
			[6, 'f6', 'r6', 'b6', 'f_1', 'm6', 'AAAAAA', '!!!!!!', 6, 1, $idChange],
			[7, 'f7', 'r7', 'b7', 'g', 'm7', 'AAAAAAA', '!!!!!!!', 7, 1, $idChange],
			[7, 'f7', 'r7', 'b7', 'g_1', 'm7', 'AAAAAAA', '!!!!!!!', 7, 1, $idChange],
			[8, 'f8', 'r8', 'b8', 'h', 'm8', 'AAAAAAAA', '!!!!!!!!', 8, 1, $idChange],
			[8, 'f8', 'r8', 'b8', 'h_1', 'm8', 'AAAAAAAA', '!!!!!!!!', 8, 1, $idChange],
		);
		
		%tmps = ();	
		# Create the zipped FASTQs for every id_sample
		for (my $i = 0; $i <= $#keys; $i++) {
			my $key = $keys[$i];
			my $pattern = $keysR->{$key}->{'number of run and barcode'};
			if ($keysR->{$key}->{"_isControl_"} eq "t") {
				$pattern =~ s/bar[0-9]+$/bar99/
			}
			my $dir = $basePath . "/" . $pattern;
			system ("mkdir $dir") and die "ERROR: Cannot create test directory";
			
			my $fastq = $fastqs[$i];
			# Two zipped FASTQs for each sample
			zip \$fastq => $dir . "/" . $i ."_0.fastq.zip", AutoClose=> 1, Name => $i ."_0.fastq";
			# Remember readid to dir pattern for expected keys
			if ($fastq =~ m/^@([a-h]) /) {
				my $readid = $1;
				$tmps{$readid} = $pattern;
			}
			
			$fastq =~ s/(^@[a-h])/$1_1/;
			zip \$fastq => $dir . "/" . $i ."_1.fastq.zip", AutoClose=> 1, Name => $i ."_1.fastq";
			# Remember readid to dir pattern for expected keys
			if ($fastq =~ m/^@([a-h]_\d) /) {
				my $readid = $1;
				$tmps{$readid} = $pattern;
			}
		}
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, seqlen, seqerr, id_change FROM sequence ORDER BY id_sample, readid ASC");
		is ($resR, \@expecs, 'Testing no maxRows - data');
		
		# Get id, readid, id_sample from database and connect it to the expected
		# association of readid and directory pattern to get the expected outKeys
		# (cannot predict id in sequence table)
		$resR = $dbh->selectall_arrayref("SELECT id, readid, id_sample FROM sequence");
		my %expOutKeys = ();
		foreach my $rowR (@{$resR}) {
			my ($id, $readId, $idSample) = @{$rowR};
			my $pattern = $tmps{$readId};
			
			if (exists $expOutKeys{$pattern}) {
				if (exists $expOutKeys{$pattern}->{$idSample}) {
					$expOutKeys{$pattern}->{$idSample}->{$readId} = $id
				}
				else {
					$expOutKeys{$pattern}->{$idSample} = {$readId => $id};
				}
			}
			else {
				$expOutKeys{$pattern} = {$idSample => {$readId => $id}};
			}
		}
		# Compare to keysR
		is ($outKeysR, \%expOutKeys, 'Testing no maxRows - keys');
		is ($isNew, 1, 'Testing no maxRows - any new data inserted?');
	}
	catch {
		$err = $_;
		
		# Always fail on error
		ok (1==2, 'Testing no maxRows');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence("", $keysR, $basePath, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty keys
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, "", $basePath, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test keys not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, "abc", $basePath, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No keys/, 'Testing keys not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty keys reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, {}, $basePath, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No keys/, 'Testing empty keys reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty dir path
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, $keysR, "", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty dir path');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty id_change
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, "", $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty indication, if new data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, "", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, "abc", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing indication, if new data not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data illegal number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, "2", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing indication, if new data illegal number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing empty maxRows');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is zero
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew, 0)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no 'number of run and barcode' in keys
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		# Deep copy
		my $keysModR = dclone ($keysR);
		foreach my $id (keys(%{$keysModR})) {
			delete $keysModR->{$id}->{'number of run and barcode'};
		}
		($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysModR, $basePath, $idChange, $isNew, $maxRows);
		
		# Prove that no data was inserted
		my $resR = $dbh->selectall_arrayref("SELECT id FROM sequence");
		is ($resR, [], 'Testing no number of run and barcode - data');
		is ($outKeysR, {}, 'Testing no number of run and barcode - keys');
		is ($isNew, 0, 'Testing no number of run and barcode - any new data inserted?');
	}
	catch {
		$err = $_;
		
		# Fail on any error
		ok (1==2, 'Testing no number of run and barcode');
		print "ERROR: " . $err . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no _isControl_ in keys
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my $keysModR = dclone ($keysR);
		foreach my $id (keys(%{$keysModR})) {
			delete $keysModR->{$id}->{"_isControl_"};
		}
		($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysModR, $basePath, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/ERROR.*Unexpected value.*for _isControl_/, "Testing no _isControl_ in keys")
	};
	
	
	#------------------------------------------------------------------------------#
	# Test unexpected value for _isControl_ in keys
	#------------------------------------------------------------------------------#
	$isNew = 0;	
	
	try {
		$err = "";
		
		my $keysModR = dclone ($keysR);
		foreach my $id (keys(%{$keysModR})) {
			$keysModR->{$id}->{"_isControl_"} = undef;
		}
   		($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysModR, $basePath, $idChange, $isNew, $maxRows);
		
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/ERROR.*Unexpected value.*for _isControl_/, "Testing unexpected value for _isControl_ in keys")
	};
	
	
	#------------------------------------------------------------------------------#
	# Test multiple case samples share the same directory pattern
	#------------------------------------------------------------------------------#
	$isNew = 0;	
	
	try {
		$err = "";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		
		my $keysModR = dclone ($keysR);
		$keysModR->{"3"}->{"number of run and barcode"} = "run01_bar01";
		{
			# Redirect STDERR from function to suppress warnings.
	    	local *STDERR;
	    	open STDERR, ">", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysModR, $basePath, $idChange, $isNew, $maxRows);
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/ERROR.*Multiple samples share the same directory pattern/, "Testing multiple samples with same directory pattern");
		$dbh->rollback;
	};
	
	
	#	
	#------------------------------------------------------------------------------#
	# Test multiple control samples share the same directory pattern
	#------------------------------------------------------------------------------#
	#
	$isNew = 0;

	try {
		$err = "";
		
		my $keysModR = dclone ($keysR);
		$keysModR->{"4"}->{"number of run and barcode"} = "run01_bar01";
		
		
		# Expected entries in sequence:
		# 2 patients, 2 samples per patient, 2 reads per sample
		my @expecs = (
			[1, 'f1', 'r1', 'b1', 'a', 'm1', 'A', '!', 1, 1, $idChange],
			[1, 'f1', 'r1', 'b1', 'a_1', 'm1', 'A', '!', 1, 1, $idChange],
			[2, 'f2', 'r2', 'b2', 'b', 'm2', 'AA', '!!', 2, 1, $idChange],
			[2, 'f2', 'r2', 'b2', 'b_1', 'm2', 'AA', '!!', 2, 1, $idChange],
			[3, 'f3', 'r3', 'b3', 'c', 'm3', 'AAA', '!!!', 3, 1, $idChange],
			[3, 'f3', 'r3', 'b3', 'c_1', 'm3', 'AAA', '!!!', 3, 1, $idChange],
			[4, 'f2', 'r2', 'b2', 'b', 'm2', 'AA', '!!', 2, 1, $idChange],
			[4, 'f2', 'r2', 'b2', 'b_1', 'm2', 'AA', '!!', 2, 1, $idChange],
			[5, 'f5', 'r5', 'b5', 'e', 'm5', 'AAAAA', '!!!!!', 5, 1, $idChange],
			[5, 'f5', 'r5', 'b5', 'e_1', 'm5', 'AAAAA', '!!!!!', 5, 1, $idChange],
			[6, 'f6', 'r6', 'b6', 'f', 'm6', 'AAAAAA', '!!!!!!', 6, 1, $idChange],
			[6, 'f6', 'r6', 'b6', 'f_1', 'm6', 'AAAAAA', '!!!!!!', 6, 1, $idChange],
			[7, 'f7', 'r7', 'b7', 'g', 'm7', 'AAAAAAA', '!!!!!!!', 7, 1, $idChange],
			[7, 'f7', 'r7', 'b7', 'g_1', 'm7', 'AAAAAAA', '!!!!!!!', 7, 1, $idChange],
			[8, 'f8', 'r8', 'b8', 'h', 'm8', 'AAAAAAAA', '!!!!!!!!', 8, 1, $idChange],
			[8, 'f8', 'r8', 'b8', 'h_1', 'm8', 'AAAAAAAA', '!!!!!!!!', 8, 1, $idChange],
		);
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysModR, $basePath, $idChange, $isNew, $maxRows);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, seqlen, seqerr, id_change FROM sequence ORDER BY id_sample, readid ASC");
		is ($resR, \@expecs, 'Testing control samples share directory pattern - data');
		
		# Get id, readid, id_sample from database and connect it to the expected
		# association of readid and directory pattern to get the expected outKeys
		# (cannot predict id in sequence table)
		$resR = $dbh->selectall_arrayref("SELECT id, readid, id_sample FROM sequence");
		my %expOutKeys = ();
		foreach my $rowR (@{$resR}) {
			my ($id, $readId, $idSample) = @{$rowR};
			my $pattern = $tmps{$readId};
			
			if (exists $expOutKeys{$pattern}) {
				if (exists $expOutKeys{$pattern}->{$idSample}) {
					$expOutKeys{$pattern}->{$idSample}->{$readId} = $id
				}
				else {
					$expOutKeys{$pattern}->{$idSample} = {$readId => $id};
				}
			}
			else {
				$expOutKeys{$pattern} = {$idSample => {$readId => $id}};
			}
		}
		is ($outKeysR, \%expOutKeys, 'Testing control samples share directory pattern - keys');
		is ($isNew, 1, 'Testing control samples share directory pattern - any new data inserted?');	
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing control samples share directory pattern');
		
		print "ERROR: $err" ."\n";
		
	}
	finally {
		$dbh->rollback;
	};

	
	#------------------------------------------------------------------------------#
	# Test no files found
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		{
			# Redirect STDERR from function to suppress warnings.
	    	local *STDERR;
	    	open STDERR, ">", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysR, "/dev/null/", $idChange, $isNew, $maxRows);
		}
		
		# Prove that no data was inserted
		my $resR = $dbh->selectall_arrayref("SELECT id FROM sequence");
		is ($resR, [], 'Testing no files found - data');
		is ($outKeysR, {}, 'Testing no files found - keys');
		is ($isNew, 0, 'Testing no files found - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, "Testing no files found");
		print "ERROR: " . $err . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid FASTQ
	#------------------------------------------------------------------------------#
	$isNew = 0;
	my $mockF = "";
	
	try {
		$err = "";
		
		# Create a broken FASTQ
		my $fastq = "\@a\nATG\n+";
		my $pattern = $keysR->{'1'}->{'number of run and barcode'};
		$mockF =  $basePath . "/" . $pattern . "/error_0.fastq.zip";
		zip \$fastq => $mockF, AutoClose=> 1, Name => "error_0.fastq";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		{
			# Redirect STDERR from function to suppress warnings.
	    	local *STDERR;
	    	open STDERR, ">", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew, $maxRows);
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/ERROR with FASTQ file/, 'Testing invalid FASTQ file');
		system("rm $mockF") and die "ERROR: Could not remove file";
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Valid insert: Two valid FASTQ ZIPs per sample (exemplary for other archive
	# types, see tests for extractArchive)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";

		# Expected entries in sequence:
		# 2 patients, 2 samples per patient, 2 reads per sample
		my @expecs = (
			[1, 'f1', 'r1', 'b1', 'a', 'm1', 'A', '!', 1, 1, $idChange],
			[1, 'f1', 'r1', 'b1', 'a_1', 'm1', 'A', '!', 1, 1, $idChange],
			[2, 'f2', 'r2', 'b2', 'b', 'm2', 'AA', '!!', 2, 1, $idChange],
			[2, 'f2', 'r2', 'b2', 'b_1', 'm2', 'AA', '!!', 2, 1, $idChange],
			[3, 'f3', 'r3', 'b3', 'c', 'm3', 'AAA', '!!!', 3, 1, $idChange],
			[3, 'f3', 'r3', 'b3', 'c_1', 'm3', 'AAA', '!!!', 3, 1, $idChange],
			[4, 'f4', 'r4', 'b4', 'd', 'm4', 'AAAA', '!!!!', 4, 1, $idChange],
			[4, 'f4', 'r4', 'b4', 'd_1', 'm4', 'AAAA', '!!!!', 4, 1, $idChange],
			[5, 'f5', 'r5', 'b5', 'e', 'm5', 'AAAAA', '!!!!!', 5, 1, $idChange],
			[5, 'f5', 'r5', 'b5', 'e_1', 'm5', 'AAAAA', '!!!!!', 5, 1, $idChange],
			[6, 'f6', 'r6', 'b6', 'f', 'm6', 'AAAAAA', '!!!!!!', 6, 1, $idChange],
			[6, 'f6', 'r6', 'b6', 'f_1', 'm6', 'AAAAAA', '!!!!!!', 6, 1, $idChange],
			[7, 'f7', 'r7', 'b7', 'g', 'm7', 'AAAAAAA', '!!!!!!!', 7, 1, $idChange],
			[7, 'f7', 'r7', 'b7', 'g_1', 'm7', 'AAAAAAA', '!!!!!!!', 7, 1, $idChange],
			[8, 'f8', 'r8', 'b8', 'h', 'm8', 'AAAAAAAA', '!!!!!!!!', 8, 1, $idChange],
			[8, 'f8', 'r8', 'b8', 'h_1', 'm8', 'AAAAAAAA', '!!!!!!!!', 8, 1, $idChange],
		);
				
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew, $maxRows);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, seqlen, seqerr, id_change FROM sequence ORDER BY id_sample, readid ASC");
		is ($resR, \@expecs, 'Testing valid insert of two FASTQs - data');
		
		# Get id, readid, id_sample from database and connect it to the expected
		# association of readid and directory pattern to get the expected outKeys
		# (cannot predict id in sequence table)
		$resR = $dbh->selectall_arrayref("SELECT id, readid, id_sample FROM sequence");
		my %expOutKeys = ();
		foreach my $rowR (@{$resR}) {
			my ($id, $readId, $idSample) = @{$rowR};
			my $pattern = $tmps{$readId};
			
			if (exists $expOutKeys{$pattern}) {
				if (exists $expOutKeys{$pattern}->{$idSample}) {
					$expOutKeys{$pattern}->{$idSample}->{$readId} = $id
				}
				else {
					$expOutKeys{$pattern}->{$idSample} = {$readId => $id};
				}
			}
			else {
				$expOutKeys{$pattern} = {$idSample => {$readId => $id}};
			}
		}
		is ($outKeysR, \%expOutKeys, 'Testing valid insert of two FASTQs - keys');
		is ($isNew, 1, 'Testing valid insert of two FASTQs - any new data inserted?');
	}
	catch {
		$err = $_;
		
		# Always fail on error
		ok (1==2, 'Testing valid insert of two FASTQs');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Valid old insert: Two valid FASTQ ZIPs per sample (exemplary for other
	# archive types, see tests for extractArchive).
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";

		# Expected entries in sequence:
		# 2 patients, 2 samples per patient, 2 reads per sample
		my @expecs = (
			[1, 'f1', 'r1', 'b1', 'a', 'm1', 'A', '!', 1, 1, $idChange],
			[1, 'f1', 'r1', 'b1', 'a_1', 'm1', 'A', '!', 1, 1, $idChange],
			[2, 'f2', 'r2', 'b2', 'b', 'm2', 'AA', '!!', 2, 1, $idChange],
			[2, 'f2', 'r2', 'b2', 'b_1', 'm2', 'AA', '!!', 2, 1, $idChange],
			[3, 'f3', 'r3', 'b3', 'c', 'm3', 'AAA', '!!!', 3, 1, $idChange],
			[3, 'f3', 'r3', 'b3', 'c_1', 'm3', 'AAA', '!!!', 3, 1, $idChange],
			[4, 'f4', 'r4', 'b4', 'd', 'm4', 'AAAA', '!!!!', 4, 1, $idChange],
			[4, 'f4', 'r4', 'b4', 'd_1', 'm4', 'AAAA', '!!!!', 4, 1, $idChange],
			[5, 'f5', 'r5', 'b5', 'e', 'm5', 'AAAAA', '!!!!!', 5, 1, $idChange],
			[5, 'f5', 'r5', 'b5', 'e_1', 'm5', 'AAAAA', '!!!!!', 5, 1, $idChange],
			[6, 'f6', 'r6', 'b6', 'f', 'm6', 'AAAAAA', '!!!!!!', 6, 1, $idChange],
			[6, 'f6', 'r6', 'b6', 'f_1', 'm6', 'AAAAAA', '!!!!!!', 6, 1, $idChange],
			[7, 'f7', 'r7', 'b7', 'g', 'm7', 'AAAAAAA', '!!!!!!!', 7, 1, $idChange],
			[7, 'f7', 'r7', 'b7', 'g_1', 'm7', 'AAAAAAA', '!!!!!!!', 7, 1, $idChange],
			[8, 'f8', 'r8', 'b8', 'h', 'm8', 'AAAAAAAA', '!!!!!!!!', 8, 1, $idChange],
			[8, 'f8', 'r8', 'b8', 'h_1', 'm8', 'AAAAAAAA', '!!!!!!!!', 8, 1, $idChange],
		);
				
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew, $maxRows);
		
		# Reset isNew and attempt to insert the same data again
		$isNew = 0;
		($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew, $maxRows);
		
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, seqlen, seqerr, id_change FROM sequence ORDER BY id_sample, readid ASC");
		is ($resR, \@expecs, 'Testing valid old insert of two FASTQs - data');
		
		# Get id, readid, id_sample from database and connect it to the expected
		# association of readid and directory pattern to get the expected outKeys
		# (cannot predict id in sequence table)
		$resR = $dbh->selectall_arrayref("SELECT id, readid, id_sample FROM sequence");
		my %expOutKeys = ();
		foreach my $rowR (@{$resR}) {
			my ($id, $readId, $idSample) = @{$rowR};
			my $pattern = $tmps{$readId};
			
			if (exists $expOutKeys{$pattern}) {
				if (exists $expOutKeys{$pattern}->{$idSample}) {
					$expOutKeys{$pattern}->{$idSample}->{$readId} = $id
				}
				else {
					$expOutKeys{$pattern}->{$idSample} = {$readId => $id};
				}
			}
			else {
				$expOutKeys{$pattern} = {$idSample => {$readId => $id}};
			}
		}
		is ($outKeysR, \%expOutKeys, 'Testing valid old insert of two FASTQs - keys');
		is ($isNew, 0, 'Testing valid old insert of two FASTQs - any new data inserted?');
	}
	catch {
		$err = $_;
		
		# Always fail on error
		ok (1==2, 'Testing valid old insert of two FASTQs');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Valid insert with duplicate records: Two valid FASTQ ZIPs per sample
	# (exemplary for other archive types, see tests for extractArchive).
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my @keys = sort {$a cmp $b} keys (%{$keysR});
		
		my @fastqs = (
			"\@a runid=r1 barcode=b1 flow_cell_id=f1 basecall_model_version_id=m1\nA\n\+\n!\n",
			"\@b runid=r2 barcode=b2 flow_cell_id=f2 basecall_model_version_id=m2\nAA\n\+\n!!\n",
			"\@c runid=r3 barcode=b3 flow_cell_id=f3 basecall_model_version_id=m3\nAAA\n\+\n!!!\n",
			"\@d runid=r4 barcode=b4 flow_cell_id=f4 basecall_model_version_id=m4\nAAAA\n\+\n!!!!\n",
			"\@e runid=r5 barcode=b5 flow_cell_id=f5 basecall_model_version_id=m5\nAAAAA\n\+\n!!!!!\n",
			"\@f runid=r6 barcode=b6 flow_cell_id=f6 basecall_model_version_id=m6\nAAAAAA\n\+\n!!!!!!\n",
			"\@g runid=r7 barcode=b7 flow_cell_id=f7 basecall_model_version_id=m7\nAAAAAAA\n\+\n!!!!!!!\n",
			"\@h runid=r8 barcode=b8 flow_cell_id=f8 basecall_model_version_id=m8\nAAAAAAAA\n\+\n!!!!!!!!\n"
		);

		# Expected entries in sequence:
		# 2 patients, 2 samples per patient, 2 reads per sample
		my @expecs = (
			[1, 'f1', 'r1', 'b1', 'a', 'm1', 'A', '!', 1, 1, $idChange],
			[2, 'f2', 'r2', 'b2', 'b', 'm2', 'AA', '!!', 2, 1, $idChange],
			[3, 'f3', 'r3', 'b3', 'c', 'm3', 'AAA', '!!!', 3, 1, $idChange],
			[4, 'f4', 'r4', 'b4', 'd', 'm4', 'AAAA', '!!!!', 4, 1, $idChange],
			[5, 'f5', 'r5', 'b5', 'e', 'm5', 'AAAAA', '!!!!!', 5, 1, $idChange],
			[6, 'f6', 'r6', 'b6', 'f', 'm6', 'AAAAAA', '!!!!!!', 6, 1, $idChange],
			[7, 'f7', 'r7', 'b7', 'g', 'm7', 'AAAAAAA', '!!!!!!!', 7, 1, $idChange],
			[8, 'f8', 'r8', 'b8', 'h', 'm8', 'AAAAAAAA', '!!!!!!!!', 8, 1, $idChange],
		);
				
		%tmps = ();	
		# Create the zipped FASTQs for every id_sample
		for (my $i = 0; $i <= $#keys; $i++) {
			my $key = $keys[$i];
			my $pattern = $keysR->{$key}->{'number of run and barcode'};
			if ($keysR->{$key}->{"_isControl_"} eq "t") {
				$pattern =~ s/bar[0-9]+$/bar99/;
			}
			my $dir = $basePath . "/" . $pattern;

			my $fastq = $fastqs[$i];
			# Two zipped FASTQs for each sample
			zip \$fastq => $dir . "/" . $i ."_0.fastq.zip", AutoClose=> 1, Name => $i ."_0.fastq";
			# Remember readid to dir pattern for expected keys
			if ($fastq =~ m/^@([a-h]) /) {
				my $readid = $1;
				$tmps{$readid} = $pattern;
			}
			
			# Save a duplicate
			zip \$fastq => $dir . "/" . $i ."_1.fastq.zip", AutoClose=> 1, Name => $i ."_1.fastq";
			# Remember readid to dir pattern for expected keys
			if ($fastq =~ m/^@([a-h]_\d) /) {
				my $readid = $1;
				$tmps{$readid} = $pattern;
			}
		}			
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew, $maxRows);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, seqlen, seqerr, id_change FROM sequence ORDER BY id_sample, readid ASC");
		is ($resR, \@expecs, 'Testing insert with duplicate values - data');
		
		# Get id, readid, id_sample from database and connect it to the expected
		# association of readid and directory pattern to get the expected outKeys
		# (cannot predict id in sequence table)
		$resR = $dbh->selectall_arrayref("SELECT id, readid, id_sample FROM sequence");
		my %expOutKeys = ();
		foreach my $rowR (@{$resR}) {
			my ($id, $readId, $idSample) = @{$rowR};
			my $pattern = $tmps{$readId};
			
			if (exists $expOutKeys{$pattern}) {
				if (exists $expOutKeys{$pattern}->{$idSample}) {
					$expOutKeys{$pattern}->{$idSample}->{$readId} = $id
				}
				else {
					$expOutKeys{$pattern}->{$idSample} = {$readId => $id};
				}
			}
			else {
				$expOutKeys{$pattern} = {$idSample => {$readId => $id}};
			}
		}
		is ($outKeysR, \%expOutKeys, 'Testing insert with duplicate values - keys');
		is ($isNew, 1, 'Testing insert with duplicate values - any new data inserted?');
	}
	catch {
		$err = $_;
		
		# Always fail on error
		ok (1==2, 'Testing insert with duplicate values');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test with more relaxed hypothetical sequence relation that allows NULL
	# values in runid and barcode. This tests, if the duplicate detection would
	# still work.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my @keys = sort {$a cmp $b} keys (%{$keysR});
		
		# FASTQs with NULL runid and barcode
		my @fastqs = (
			"\@a flow_cell_id=f1 basecall_model_version_id=m1\nA\n\+\n!\n",
			"\@b flow_cell_id=f2 basecall_model_version_id=m2\nAA\n\+\n!!\n",
			"\@c flow_cell_id=f3 basecall_model_version_id=m3\nAAA\n\+\n!!!\n",
			"\@d flow_cell_id=f4 basecall_model_version_id=m4\nAAAA\n\+\n!!!!\n",
			"\@e flow_cell_id=f5 basecall_model_version_id=m5\nAAAAA\n\+\n!!!!!\n",
			"\@f flow_cell_id=f6 basecall_model_version_id=m6\nAAAAAA\n\+\n!!!!!!\n",
			"\@g flow_cell_id=f7 basecall_model_version_id=m7\nAAAAAAA\n\+\n!!!!!!!\n",
			"\@h flow_cell_id=f8 basecall_model_version_id=m8\nAAAAAAAA\n\+\n!!!!!!!!\n"
		);

		# Expected entries in sequence:
		# 2 patients, 2 samples per patient, 2 reads per sample
		my @expecs = (
			[1, 'f1', undef, undef, 'a', 'm1', 'A', '!', 1, 1, $idChange],
			[1, 'f1', undef, undef, 'a_1', 'm1', 'A', '!', 1, 1, $idChange],
			[2, 'f2', undef, undef, 'b', 'm2', 'AA', '!!', 2, 1, $idChange],
			[2, 'f2', undef, undef, 'b_1', 'm2', 'AA', '!!', 2, 1, $idChange],
			[3, 'f3', undef, undef, 'c', 'm3', 'AAA', '!!!', 3, 1, $idChange],
			[3, 'f3', undef, undef, 'c_1', 'm3', 'AAA', '!!!', 3, 1, $idChange],
			[4, 'f4', undef, undef, 'd', 'm4', 'AAAA', '!!!!', 4, 1, $idChange],
			[4, 'f4', undef, undef, 'd_1', 'm4', 'AAAA', '!!!!', 4, 1, $idChange],
			[5, 'f5', undef, undef, 'e', 'm5', 'AAAAA', '!!!!!', 5, 1, $idChange],
			[5, 'f5', undef, undef, 'e_1', 'm5', 'AAAAA', '!!!!!', 5, 1, $idChange],
			[6, 'f6', undef, undef, 'f', 'm6', 'AAAAAA', '!!!!!!', 6, 1, $idChange],
			[6, 'f6', undef, undef, 'f_1', 'm6', 'AAAAAA', '!!!!!!', 6, 1, $idChange],
			[7, 'f7', undef, undef, 'g', 'm7', 'AAAAAAA', '!!!!!!!', 7, 1, $idChange],
			[7, 'f7', undef, undef, 'g_1', 'm7', 'AAAAAAA', '!!!!!!!', 7, 1, $idChange],
			[8, 'f8', undef, undef, 'h', 'm8', 'AAAAAAAA', '!!!!!!!!', 8, 1, $idChange],
			[8, 'f8', undef, undef, 'h_1', 'm8', 'AAAAAAAA', '!!!!!!!!', 8, 1, $idChange],
		);
		
		# Drop not-NULL constraints
		$dbh->do("ALTER TABLE sequence ALTER COLUMN runid DROP NOT NULL");
		$dbh->do("ALTER TABLE sequence ALTER COLUMN barcode DROP NOT NULL");
		
		%tmps = ();	
		# Create the zipped FASTQs for every id_sample
		for (my $i = 0; $i <= $#keys; $i++) {
			my $key = $keys[$i];
			my $pattern = $keysR->{$key}->{'number of run and barcode'};
			if ($keysR->{$key}->{"_isControl_"} eq "t") {
				$pattern =~ s/bar[0-9]+$/bar99/;
			}
			my $dir = $basePath . "/" . $pattern;

			my $fastq = $fastqs[$i];
			# Two zipped FASTQs for each sample
			zip \$fastq => $dir . "/" . $i ."_0.fastq.zip", AutoClose=> 1, Name => $i ."_0.fastq";
			# Remember readid to dir pattern for expected keys
			if ($fastq =~ m/^@([a-h]) /) {
				my $readid = $1;
				$tmps{$readid} = $pattern;
			}
			
			$fastq =~ s/(^@[a-h])/$1_1/;
			zip \$fastq => $dir . "/" . $i ."_1.fastq.zip", AutoClose=> 1, Name => $i ."_1.fastq";
			# Remember readid to dir pattern for expected keys
			if ($fastq =~ m/^@([a-h]_\d) /) {
				my $readid = $1;
				$tmps{$readid} = $pattern;
			}
		}			
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew, $maxRows);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, seqlen, seqerr, id_change FROM sequence ORDER BY id_sample, readid ASC");
		is ($resR, \@expecs, 'Testing insert with NULL values - data');
		
		# Get id, readid, id_sample from database and connect it to the expected
		# association of readid and directory pattern to get the expected outKeys
		# (cannot predict id in sequence table)
		$resR = $dbh->selectall_arrayref("SELECT id, readid, id_sample FROM sequence");
		my %expOutKeys = ();
		foreach my $rowR (@{$resR}) {
			my ($id, $readId, $idSample) = @{$rowR};
			my $pattern = $tmps{$readId};
			
			if (exists $expOutKeys{$pattern}) {
				if (exists $expOutKeys{$pattern}->{$idSample}) {
					$expOutKeys{$pattern}->{$idSample}->{$readId} = $id
				}
				else {
					$expOutKeys{$pattern}->{$idSample} = {$readId => $id};
				}
			}
			else {
				$expOutKeys{$pattern} = {$idSample => {$readId => $id}};
			}
		}
		is ($outKeysR, \%expOutKeys, 'Testing insert with NULL values - keys');
		is ($isNew, 1, 'Testing insert with NULL values - any new data inserted?');
	}
	catch {
		$err = $_;
		
		# Always fail on error
		ok (1==2, 'Testing insert with NULL values');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Valid insert: Two valid, but empty, FASTQ ZIPs per sample (exemplary for
	# other archive types, see tests for extractArchive).
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my @keys = sort {$a cmp $b} keys (%{$keysR});
		
		%tmps = ();	
		# Create the zipped FASTQs for every id_sample
		for (my $i = 0; $i <= $#keys; $i++) {
			my $key = $keys[$i];
			my $pattern = $keysR->{$key}->{'number of run and barcode'};
			if ($keysR->{$key}->{"_isControl_"} eq "t") {
				$pattern =~ s/bar[0-9]+$/bar99/;
			}
			my $dir = $basePath . "/" . $pattern;
					
			my $fastq = "";
			# Two zipped empty FASTQs for each sample (overwriting the FASTQs from previous tests)
			zip \$fastq => $dir . "/" . $i ."_0.fastq.zip", AutoClose=> 1, Name => $i ."_0.fastq";
			zip \$fastq => $dir . "/" . $i ."_1.fastq.zip", AutoClose=> 1, Name => $i ."_1.fastq";
		}
					
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		
		# Discard warnings
		do {
    		local *STDERR;
    		open STDERR, ">", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew, $maxRows);
			
			# Get the inserted data from the database
			my $resR = $dbh->selectall_arrayref("SELECT id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change FROM sequence ORDER BY id_sample, readid ASC");
			is ($resR, [], 'Testing empty FASTQs - data');
			is ($outKeysR, {}, 'Testing empty FASTQs - keys');
			is ($isNew, 0, 'Testing empty FASTQs - any new data inserted?');
		}
	}
	catch {
		$err = $_;
		
		# Always fail on error
		ok (1==2, 'Testing empty FASTQs');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Valid insert: Two valid, FASTQ ZIPs per sample (exemplary for
	# other archive types, see tests for extractArchive) containing only
	# whitespaces.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my @keys = sort {$a cmp $b} keys (%{$keysR});
		
		%tmps = ();	
		# Create the zipped FASTQs for every id_sample
		for (my $i = 0; $i <= $#keys; $i++) {
			my $key = $keys[$i];
			my $pattern = $keysR->{$key}->{'number of run and barcode'};
			if ($keysR->{$key}->{"_isControl_"} eq "t") {
				$pattern =~ s/bar[0-9]+$/bar99/;
			}
			my $dir = $basePath . "/" . $pattern;
					
			my $fastq = "      ";
			# Two zipped empty FASTQs for each sample (overwriting the FASTQs from previous tests)
			zip \$fastq => $dir . "/" . $i ."_0.fastq.zip", AutoClose=> 1, Name => $i ."_0.fastq";
			zip \$fastq => $dir . "/" . $i ."_1.fastq.zip", AutoClose=> 1, Name => $i ."_1.fastq";
		}
					
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		
		# Discard warnings
		do {
    		local *STDERR;
    		open STDERR, ">", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysR, $basePath, $idChange, $isNew, $maxRows);
			
			# Get the inserted data from the database
			my $resR = $dbh->selectall_arrayref("SELECT id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change FROM sequence ORDER BY id_sample, readid ASC");
			is ($resR, [], 'Testing FASTQs with whitespaces - data');
			is ($outKeysR, {}, 'Testing FASTQs with whitespaces - keys');
			is ($isNew, 0, 'Testing FASTQs with whitespaces - any new data inserted?');
		}
	}
	catch {
		$err = $_;
		
		# Always fail on error
		ok (1==2, 'Testing FASTQs with whitespaces');
		print "ERROR: " . $_ . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the insertTaxonomy function
#--------------------------------------------------------------------------------------------------#
#
sub test_insertTaxonomy {
	my $dbh = $_[0] // "";
	my $basePath = $_[1] // "";
	my $taxP = $_[2] // "";
	
	# 2 patients --> 4 samples per patient --> 2 reads per sample:
	# directory pattern => id_sample => read ID => id_sequence
	my $keysSeqR = {
		'run01_bar01'	=> {
			1 => {
				'a' => 1,
				'a_1' => 2
			}
		},
		'run01_bar99'	=> {
			2 => {
				'b' => 3,
				'b_1' => 4
			}
		},
		'run02_bar01'	=> {
			3 => {
				'c' => 5,
				'c_1' => 6
			}
		},
		'run02_bar99'	=> {
			4 => {
				'd' => 7,
				'd_1' => 8
			}
		},
		'run03_bar01'	=> {
			5 => {
				'e' => 9,
				'e_1' => 10
			}
		},
		'run03_bar99'	=> {
			6 => {
				'f' => 11,
				'f_1' => 12
			}
		},
		'run04_bar01'	=> {
			7 => {
				'g' => 13,
				'g_1' => 14
			}
		},
		'run04_bar99'	=> {
			8 => {
				'h' => 15,
				'h_1' => 16
			}
		}
	};
	my $keysSampleMetaGR = {
		"1"	=> { # p1: 1900-01-01
			'number of run and barcode'	=> 'run01_bar01',
			'height'					=> '30cm',
			'_isControl_'				=> "f",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"2"	=> { # p1: 1900-01-01
			'number of run and barcode'	=> 'run01_bar01', # interpreted later as 'run01_bar99'
			'height'					=> '30cm',
			'_isControl_'				=> "t",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"3" => { # p1: 1900-01-02
			'number of run and barcode'	=> 'run02_bar01',
			'height'					=> '31cm',
			'_isControl_'				=> "f",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"4"	=> { # p1: 1900-01-02
			'number of run and barcode'	=> 'run02_bar01', # interpreted later as 'run02_bar99'
			'height'					=> '31cm',
			'_isControl_'				=> "t",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"5" => { # p2: 1900-02-02
			'number of run and barcode'	=> 'run03_bar01',
			'height'					=> '35cm',
			'_isControl_'				=> "f",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"6" => { # p2: 1900-02-02
			'number of run and barcode'	=> 'run03_bar01', # interpreted later as 'run03_bar99'
			'height'					=> '35cm',
			'_isControl_'				=> "t",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"7"	=> { # p2: 1900-02-03
			'number of run and barcode'	=> 'run04_bar01',
			'height'					=> '36cm',
			'_isControl_'				=> "f",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		},
		"8"	=> { # p2: 1900-02-03
			'number of run and barcode'	=> 'run04_bar01', # interpreted later as 'run04_bar99'
			'height'					=> '36cm',
			'_isControl_'				=> "t",
			'program'					=> 'MetaG',
			'database'					=> 'RDP'
		}
	};
	my $keysSampleKraken2R = dclone($keysSampleMetaGR);
	foreach my $id (keys(%{$keysSampleKraken2R})) {
		$keysSampleKraken2R->{$id}->{'program'} = "Kraken 2"
	}
	
	my $outKeysR = {};
	my $idChange = 1;
	my $isNew = 0;
	my $maxRows = 2;
	my $err = "";

	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no foreign seq keys + no foreign sample keys
	# + no dir path + no taxonomy path + no id_change + no indication, if new data
	# + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no database handle');
	};


	#------------------------------------------------------------------------------#
	# Test no foreign seq keys (+ no foreign sample keys + no dir path
	# + no taxonomy path + no id_change + no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no foreign seq keys');
	};	
	
	
	#------------------------------------------------------------------------------#
	# Test no foreing sample keys (+ no dir path + no taxonomy path + no id_change 
	# + no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no foreign sample keys');
	};
	
		
	#------------------------------------------------------------------------------#
	# Test no dir path (no taxonomy path + no id_change
	# + no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no dir path');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no taxonomy path (+ no id_change + no indication, if new data
	# + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no taxonomy path');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no id_change (+ no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no indication, if new data (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows with MetaG => optional argument
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	# Create taxonomy files
	# path => content
	my %taxFilesMetaG = (
		'run01_bar01/a'			=>	">a\n" .
										"domain: d_a: 1 (1)\n" .
										"phylum: p_a: 1 (1)\n" .
										"class: c_a: 1 (1)\n" .
										"subclass: sc_a: 1 (1)\n" .
										"order: o_a: 1 (1)\n" .
										"suborder: so_a: 1 (1)\n" .
										"family: f_a: 1 (1)\n" .
										"genus: g_a: 1 (1)\n" .
										"species: s_a: 1 (1)\n" .
										"strain: str_a: 1 (1)\n",
		'run01_bar01/a_1'		=>	">a_1\n" .
										"domain: d_a_1: 1 (1)\n" .
										"phylum: p_a_1: 1 (1)\n" .
										"class: c_a_1: 1 (1)\n" .
										"subclass: sc_a_1: 1 (1)\n" .
										"order: o_a_1: 1 (1)\n" .
										"suborder: so_a_1: 1 (1)\n" .
										"family: f_a_1: 1 (1)\n" .
										"genus: g_a_1: 1 (1)\n" .
										"species: s_a_1: 1 (1)\n" .
										"strain: str_a_1: 1 (1)\n",
		'run01_bar99/b'			=>	">b\n" .
										"domain: d_b: 1 (1)\n" .
										"phylum: p_b: 1 (1)\n" .
										"class: c_b: 1 (1)\n" .
										"subclass: sc_b: 1 (1)\n" .
										"order: o_b: 1 (1)\n" .
										"suborder: so_b: 1 (1)\n" .
										"family: f_b: 1 (1)\n" .
										"genus: g_b: 1 (1)\n" .
										"species: s_b: 1 (1)\n" .
										"strain: str_b: 1 (1)\n",
		'run01_bar99/b_1'		=>	">b_1\n" .
										"domain: d_b_1: 1 (1)\n" .
										"phylum: p_b_1: 1 (1)\n" .
										"class: c_b_1: 1 (1)\n" .
										"subclass: sc_b_1: 1 (1)\n" .
										"order: o_b_1: 1 (1)\n" .
										"suborder: so_b_1: 1 (1)\n" .
										"family: f_b_1: 1 (1)\n" .
										"genus: g_b_1: 1 (1)\n" .
										"species: s_b_1: 1 (1)\n" .
										"strain: str_b_1: 1 (1)\n",
		'run02_bar01/c'			=>	">c\n" .
										"domain: d_c: 1 (1)\n" .
										"phylum: p_c: 1 (1)\n" .
										"class: c_c: 1 (1)\n" .
										"subclass: sc_c: 1 (1)\n" .
										"order: o_c: 1 (1)\n" .
										"suborder: so_c: 1 (1)\n" .
										"family: f_c: 1 (1)\n" .
										"genus: g_c: 1 (1)\n" .
										"species: s_c: 1 (1)\n" .
										"strain: str_c: 1 (1)\n",
		'run02_bar01/c_1'		=>	">c_1\n" .
										"domain: d_c_1: 1 (1)\n" .
										"phylum: p_c_1: 1 (1)\n" .
										"class: c_c_1: 1 (1)\n" .
										"subclass: sc_c_1: 1 (1)\n" .
										"order: o_c_1: 1 (1)\n" .
										"suborder: so_c_1: 1 (1)\n" .
										"family: f_c_1: 1 (1)\n" .
										"genus: g_c_1: 1 (1)\n" .
										"species: s_c_1: 1 (1)\n" .
										"strain: str_c_1: 1 (1)\n",
		'run02_bar99/d'			=>	">d\n" .
										"domain: d_d: 1 (1)\n" .
										"phylum: p_d: 1 (1)\n" .
										"class: c_d: 1 (1)\n" .
										"subclass: sc_d: 1 (1)\n" .
										"order: o_d: 1 (1)\n" .
										"suborder: so_d: 1 (1)\n" .
										"family: f_d: 1 (1)\n" .
										"genus: g_d: 1 (1)\n" .
										"species: s_d: 1 (1)\n" .
										"strain: str_d: 1 (1)\n",
		'run02_bar99/d_1'		=>	">d_1\n" .
										"domain: d_d_1: 1 (1)\n" .
										"phylum: p_d_1: 1 (1)\n" .
										"class: c_d_1: 1 (1)\n" .
										"subclass: sc_d_1: 1 (1)\n" .
										"order: o_d_1: 1 (1)\n" .
										"suborder: so_d_1: 1 (1\n" .
										"family: f_d_1: 1 (1)\n" .
										"genus: g_d_1: 1 (1)\n" .
										"species: s_d_1: 1 (1)\n" .
										"strain: str_d_1: 1 (1)\n",
		'run03_bar01/e'			=>	">e\n" .
										"domain: d_e: 1 (1)\n" .
										"phylum: p_e: 1 (1)\n" .
										"class: c_e: 1 (1)\n",
		'run03_bar01/e_1'		=>	">e_1\n" .
										"domain: d_e_1: 1 (1)\n" .
										"phylum: p_e_1: 1 (1)\n" .
										"class: c_e_1: 1 (1)\n",
		'run03_bar99/f'			=>	">f\n" .
										"domain: d_f: 1 (1)\n" .
										"phylum: p_f: 1 (1)\n" .
										"class: c_f: 1 (1)\n",
		'run03_bar99/f_1'		=>	">f_1\n" .
										"domain: unclassified: 1 (1)\n" . # translates to name NULL in db
										"phylum: unclassified: 1 (1)\n" . # translates to name NULL in db
										"class: unclassified: 1 (1)\n", # translates to name NULL in db
		'run04_bar01/g'			=>	"No match for g\n",
		'run04_bar01/g_1'		=>	"No match for g_1\n",
		'run04_bar99/h'			=>	"No match for h\n",
		'run04_bar99/h_1'		=>	"No match for h_1\n",
	);
	
	my %expecsMetaG = (
		"d_a_domain" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"p_a_phylum" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"c_a_class" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"sc_a_subclass" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"o_a_order" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"so_a_suborder" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"f_a_family" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"g_a_genus" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"s_a_species" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"str_a_strain" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"d_a_1_domain" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"p_a_1_phylum" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"c_a_1_class" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"sc_a_1_subclass" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"o_a_1_order" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"so_a_1_suborder" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"f_a_1_family" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"g_a_1_genus" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"s_a_1_species" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"str_a_1_strain" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"d_b_domain" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"p_b_phylum" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"c_b_class" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"sc_b_subclass" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"o_b_order" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"so_b_suborder" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"f_b_family" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"g_b_genus" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"s_b_species" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"str_b_strain" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"d_b_1_domain" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"p_b_1_phylum" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"c_b_1_class" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"sc_b_1_subclass" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"o_b_1_order" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"so_b_1_suborder" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"f_b_1_family" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"g_b_1_genus" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"s_b_1_species" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"str_b_1_strain" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"d_c_domain" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"p_c_phylum" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"c_c_class" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"sc_c_subclass" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"o_c_order" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"so_c_suborder" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"f_c_family" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"g_c_genus" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"s_c_species" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"str_c_strain" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"d_c_1_domain" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"p_c_1_phylum" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"c_c_1_class" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"sc_c_1_subclass" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"o_c_1_order" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"so_c_1_suborder" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"f_c_1_family" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"g_c_1_genus" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"s_c_1_species" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"str_c_1_strain" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"d_d_domain" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"p_d_phylum" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"c_d_class" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"sc_d_subclass" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"o_d_order" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"so_d_suborder" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"f_d_family" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"g_d_genus" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"s_d_species" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"str_d_strain" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"d_d_1_domain" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"p_d_1_phylum" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"c_d_1_class" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"sc_d_1_subclass" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"o_d_1_order" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"so_d_1_suborder" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"f_d_1_family" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"g_d_1_genus" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"s_d_1_species" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"str_d_1_strain" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"d_e_domain" => {
			'_id_sequence_' => {
				'9' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"p_e_phylum" => {
			'_id_sequence_' => {
				'9' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"c_e_class" => {
			'_id_sequence_' => {
				'9' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"d_e_1_domain" => {
			'_id_sequence_' => {
				'10' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"p_e_1_phylum" => {
			'_id_sequence_' => {
				'10' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"c_e_1_class" => {
			'_id_sequence_' => {
				'10' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"d_f_domain" => {
			'_id_sequence_' => {
				'11' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"p_f_phylum" => {
			'_id_sequence_' => {
				'11' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"c_f_class" => {
			'_id_sequence_' => {
				'11' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"_domain" => { # unclassified taxon
			'_id_sequence_' => {
				'12' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"_phylum" => { # unclassified taxon
			'_id_sequence_' => {
				'12' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"_class" => { # unclassified taxon
			'_id_sequence_' => {
				'12' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"UNMATCHED_domain" => {
			'_id_sequence_' => {
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"UNMATCHED_phylum" => {
			'_id_sequence_' => {
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"UNMATCHED_class" => {
			'_id_sequence_' => {
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"UNMATCHED_subclass" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"UNMATCHED_order" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"UNMATCHED_suborder" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"UNMATCHED_family" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"UNMATCHED_genus" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"UNMATCHED_species" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"UNMATCHED_strain" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		}
	);	
	my @tmps = sort {$a cmp $b} keys(%expecsMetaG);
	# Add idChange
	my @expecsDataMetaG = map {$_, $idChange} @tmps;
	
	try {
		$err = "";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		
		system("mkdir $basePath/classifications") and die "ERROR: Could not create directory in /tmp";
		my %dirs = ();
		foreach my $path (keys(%taxFilesMetaG)) {
			my ($dir, $file) = split('/', $path);
			
			# Create two zipped files per directory, but only attempt to create the directory once.
			if (not exists $dirs{$dir}) {
				system ("mkdir $basePath/classifications/$dir") and die "ERROR: Could not create directory in /tmp";
				$dirs{$dir} = undef;
			}
			
			zip \$taxFilesMetaG{$path} => "$basePath/classifications/$path" . "_calc.LIN.txt.zip" , AutoClose=> 1, Name => $file ."_calc.LIN.txt";
		}
		
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataMetaG, 'Testing no maxRows with MetaG - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecs
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsMetaG{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsMetaG, 'Testing no maxRows with MetaG - keys');
		is ($isNew, 1, 'Testing no maxRows with MetaG - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing no maxRows with MetaG');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows with Kraken 2 => optional argument
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	# Create taxonomy files
	# path => content
	my %taxFilesKraken2 = (
		'run01_bar01/a'			=>	"C	a	2	1	2:1\n",
		'run01_bar01/a_1'		=>	"C	a_1	12	1	12:1\n",
		'run01_bar99/b'			=>	"C	b	22	2	22:1\n",
		'run01_bar99/b_1'		=>	"C	b_1	32	2	32:1\n",
		'run02_bar01/c'			=>	"C	c	42	3	42:1\n",
		'run02_bar01/c_1'		=>	"C	c_1	52	3	52:1\n",
		'run02_bar99/d'			=>	"C	d	62	4	62:1\n",
		'run02_bar99/d_1'		=>	"C	d_1	72	4	72:1\n",
		'run03_bar01/e'			=>	"C	e	82	5	82:1\n",
		'run03_bar01/e_1'		=>	"C	e_1	85	5	85:1\n",
		'run03_bar99/f'			=>	"C	f	88	6	88:1\n",
		'run03_bar99/f_1'		=>	"C	f_1	91	6	91:1\n",
		'run04_bar01/g'			=>	"U	g	0	7	0:1\n",
		'run04_bar01/g_1'		=>	"U	g_1	0	7	0:1\n",
		'run04_bar99/h'			=>	"U	h	0	8	0:1\n",
		'run04_bar99/h_1'		=>	"U	h_1	0	8	0:1\n"
	);
	
	my $expecsKraken2R = dclone(\%expecsMetaG);
	my %expecsKraken2 = %{$expecsKraken2R};
	foreach my $class (keys (%expecsKraken2)) {
		foreach my $id (keys (%{$expecsKraken2{$class}->{'_id_sequence_'}})) {
			$expecsKraken2{$class}->{'_id_sequence_'}->{$id}->[0] = "Kraken 2";
		}
	}
	# Kraken 2 classification may not contain a taxon with no name at the last rank
	delete $expecsKraken2{"_class"};
	$expecsKraken2{"c_f_1_class"}  = {
		'_id_sequence_' => {
			'12' => ['Kraken 2', 'RDP']
		},
		'_id_taxonomy_' => undef
	};
	
	@tmps = sort {$a cmp $b} keys(%expecsKraken2);
	# Add idChange
	my @expecsDataKraken2 = map {$_, $idChange} @tmps;
	
	try {
		$err = "";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		
		# The name of the classification directory must not contain the term kraken2. Otherwise, any file in it
		# is recognized as a classification file.
		system("mkdir $basePath/classifications_k2") and die "ERROR: Could not create directory in /tmp";
		my %dirs = ();
		foreach my $path (keys(%taxFilesKraken2)) {
			my ($dir, $file) = split('/', $path);
			
			# Create two zipped files per directory, but only attempt to create the directory once.
			if (not exists $dirs{$dir}) {
				system ("mkdir $basePath/classifications_k2/$dir") and die "ERROR: Could not create directory in /tmp";
				$dirs{$dir} = undef;
			}
			
			zip \$taxFilesKraken2{$path} => "$basePath/classifications_k2/$path" . "_kraken2.zip" , AutoClose=> 1, Name => $file ."_kraken2";
		}
		
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleKraken2R, $basePath, $taxP, $idChange, $isNew);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataKraken2, 'Testing no maxRows with Kraken 2 - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecs
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsKraken2{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsKraken2, 'Testing no maxRows with Kraken 2 - keys');
		is ($isNew, 1, 'Testing no maxRows with Kraken 2 - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing no maxRows with Kraken 2');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy("", $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty seq keys
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, "", $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty seq keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test seq keys not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, "abc", $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No keys/, 'Testing seq keys not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty seq keys reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, {}, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No keys/, 'Testing empty seq keys reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty sample keys
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, "", $basePath, $taxP, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty sample keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test sample keys not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, "abc", $basePath, $taxP, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No keys/, 'Testing sample keys not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty sample keys reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, {}, $basePath, $taxP, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No keys/, 'Testing empty sample keys reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty dir path
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, "", $taxP, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty dir path');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty taxonomy path with MetaG (allowed)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");		
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataMetaG, 'Testing empty taxonomy path with MetaG - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecs
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsMetaG{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsMetaG, 'Testing empty taxonomy path with MetaG - keys');
		is ($isNew, 1, 'Testing empty taxonomy path with MetaG - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing empty taxonomy path with MetaG');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty taxonomy path with Kraken 2 (not allowed)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleKraken2R, $basePath, "", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Taxonomy path required for/, 'Testing empty taxonomy path with Kraken 2');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty id_change
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, "", $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty indication, if new data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, "", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, "abc", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing indication, if new data not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data invalid number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, 2, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing indication, if new data invalid number');
	};


	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing empty maxRows');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is zero
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, 0)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero');
	};


	#------------------------------------------------------------------------------#
	# Test no files found
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my $tmpBase = "/dev/null";
		{
			# Redirect STDERR from function to suppress warnings.
	    	local *STDERR;
	    	open STDERR, ">", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $tmpBase, $taxP, $idChange, $isNew, $maxRows);
		}
		
		# Prove that no data was inserted
		my $resR = $dbh->selectall_arrayref("SELECT id FROM taxonomy");
		is ($resR, [], 'Testing no files found - data');
		is ($outKeysR, {}, 'Testing no files found - keys');
		is ($isNew, 0, 'Testing no files found - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing no files found');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no idSample in $keysSeqR->{$dirPattern}
	#------------------------------------------------------------------------------#
	$isNew = 0;	
		
	try {
		$err = "";
		
		my $keysSeqModR = dclone ($keysSeqR);
		# Drop id_sequence
		foreach my $dir (keys(%{$keysSeqModR})) {
			$keysSeqModR->{$dir} = undef;
		}
		
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqModR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
		
		# Prove that no data was inserted
		my $resR = $dbh->selectall_arrayref("SELECT id FROM taxonomy");
		is ($resR, [], 'Testing no idSample - data');
		is ($outKeysR, {}, 'Testing no idSample - keys');
		is ($isNew, 0, 'Testing no idSample - any new data inserted?');
	}
	catch {
		$err = $_;
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test idSample in $keysSeqR->{$dirPattern} and in $keysSampleR not matching
	#------------------------------------------------------------------------------#
	$isNew = 0;	
		
	try {
		$err = "";

		my $keysSeqModR = {
			'run01_bar01' => {
				99 => {
					'a' => 1,
					'a_1' => 2
				}
			}
		};
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqModR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Sample and sequence objects not matching/, 'Testing sample IDs not matching');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no readId in $keysSeqR->{$dirPattern}->{$idSample}
	# Perceived as no match between read IDs in taxonomy file and read IDs in
	# FASTQ.
	#------------------------------------------------------------------------------#
	$isNew = 0;	
		
	try {
		$err = "";
		
		my $keysSeqModR = dclone ($keysSeqR);
		# Drop id_sequence
		foreach my $dir (keys(%{$keysSeqModR})) {
			foreach my $idSample (keys(%{$keysSeqModR->{$dir}})) {
				$keysSeqModR->{$dir}->{$idSample} = undef;
			}
		}
		
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqModR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*read ID\(s\) do not match/, 'Testing no read ID');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no id_sequence in keys
	#------------------------------------------------------------------------------#
	$isNew = 0;	
		
	try {
		$err = "";
		
		my $keysSeqModR = dclone ($keysSeqR);
		# Drop id_sequence
		foreach my $dir (keys(%{$keysSeqModR})) {
			foreach my $idSample (keys(%{$keysSeqModR->{$dir}})) {
				foreach my $readid (keys(%{$keysSeqModR->{$dir}->{$idSample}})) {
					$keysSeqModR->{$dir}->{$idSample}->{$readid} = undef;
				}
			}
		}
		
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqModR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/Value for ->id_sequence<- missing or invalid/, "Testing no id_sequence in keys");
		$dbh->rollback;
	};
	
		
	#------------------------------------------------------------------------------#
	# Test unexpected value for id_sequence in keys
	#------------------------------------------------------------------------------#
	$isNew = 0;	
	
	try {
		$err = "";
		
		my $keysSeqModR = dclone ($keysSeqR);
		# Update id_sequence to invalid value
		foreach my $dir (keys(%{$keysSeqModR})) {
			foreach my $idSample (keys(%{$keysSeqModR->{$dir}})) {
				foreach my $readid (keys(%{$keysSeqModR->{$dir}->{$idSample}})) {
					$keysSeqModR->{$dir}->{$idSample}->{$readid} = "abc";
				}
			}
		}
		
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqModR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/Value for ->id_sequence<- missing or invalid/, "Testing unexpected value for id_sequence in keys");
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no program in keysSampleR
	#------------------------------------------------------------------------------#
	$isNew = 0;	
		
	try {
		$err = "";
		
		my $keysSampleModR = {
			1	=> { # p1: 1900-01-01
				'number of run and barcode'	=> 'run01_bar01',
				'height'					=> '30cm',
				'_isControl_'				=> "f",
				'database'					=> 'RDP'
			}	
		};
		my $keysSeqModR = {
			'run01_bar01'	=> {
				1 => {
					'a' => 1,
					'a_1' => 2
				}
			}
		};			
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqModR, $keysSampleModR, $basePath, $taxP, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/ERROR.*Mandatory value for program name not found/, "Testing no program in sample keys");
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty program name in keysSampleR
	#------------------------------------------------------------------------------#
	$isNew = 0;	
		
	try {
		$err = "";
		
		my $keysSampleModR = {
			1	=> { # p1: 1900-01-01
				'number of run and barcode'	=> 'run01_bar01',
				'height'					=> '30cm',
				'_isControl_'				=> "f",
				'program'					=> "",
				'database'					=> 'RDP'
			}	
		};
		my $keysSeqModR = {
			'run01_bar01'	=> {
				1 => {
					'a' => 1,
					'a_1' => 2
				}
			}
		};			
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqModR, $keysSampleModR, $basePath, $taxP, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/ERROR.*Mandatory value for program name not found/, "Testing empty program name in sample keys");
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test unexpected program in keysSampleR
	#------------------------------------------------------------------------------#
	$isNew = 0;	
		
	try {
		$err = "";
		
		my $keysSampleModR = {
			1	=> { # p1: 1900-01-01
				'number of run and barcode'	=> 'run01_bar01',
				'height'					=> '30cm',
				'_isControl_'				=> "f",
				'program'					=> "WindowsXP",
				'database'					=> 'RDP'
			}	
		};
		my $keysSeqModR = {
			'run01_bar01'	=> {
				1 => {
					'a' => 1,
					'a_1' => 2
				}
			}
		};	
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqModR, $keysSampleModR, $basePath, $taxP, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/ERROR.*Unknown classifier/, "Testing unexpected program in sample keys");
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Multiple programs in keysSampleR for a single number of run and barcode
	#------------------------------------------------------------------------------#
	$isNew = 0;	
		
	try {
		$err = "";
		
		my $keysSampleModR = {
			1	=> { # p1: 1900-01-01
				'number of run and barcode'	=> 'run01_bar01',
				'height'					=> '30cm',
				'_isControl_'				=> "f",
				'program'					=> "MetaG",
				'database'					=> 'RDP'
			},
			2	=> { # p1: 1900-01-01
				'number of run and barcode'	=> 'run01_bar01',
				'height'					=> '30cm',
				'_isControl_'				=> "f",
				'program'					=> "Kraken 2",
				'database'					=> 'RDP'
			}	
		};
		my $keysSeqModR = {
			'run01_bar01'	=> {
				1 => {
					'a' => 1,
					'a_1' => 2
				},
				2 => {
					'a' => 1,
					'a_1' => 2
				}
			}
		};	
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqModR, $keysSampleModR, $basePath, $taxP, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/ERROR.*Multiple classifiers.*for the same data/, "Testing multiple programs for same data");
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Valid insert for MetaG: Two valid taxonomy ZIP archives per sample
	# (exemplary for other archive types, see tests for extractArchive)
	# Includes: NULL values for taxon. Duplicates within INSERT (UNMATCHED).
	#------------------------------------------------------------------------------#
	$isNew = 0;
		
	try {
		$err = "";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataMetaG, 'Testing valid new insert with MetaG - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecs
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsMetaG{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsMetaG, 'Testing valid new insert with MetaG - keys');
	
		is ($isNew, 1, 'Testing valid new insert with MetaG - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing valid new insert with MetaG');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Valid insert for Kraken 2: Two valid taxonomy ZIP archives per sample
	# (exemplary for other archive types, see tests for extractArchive)
	# Includes: NULL values for taxon. Duplicates within INSERT (UNMATCHED).
	#------------------------------------------------------------------------------#
	$isNew = 0;
		
	try {
		$err = "";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleKraken2R, $basePath, $taxP, $idChange, $isNew, $maxRows);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataKraken2, 'Testing valid new insert with Kraken 2 - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecs
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsKraken2{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsKraken2, 'Testing valid new insert with Kraken 2 - keys');
	
		is ($isNew, 1, 'Testing valid new insert with Kraken 2 - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing valid new insert with Kraken 2');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Valid old insert with MetaG: Two valid taxonomy ZIP archives per sample
	# (exemplary for other archive types, see tests for extractArchive)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
		
		# Reset isNew and insert the same data again
		$isNew = 0;
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataMetaG, 'Testing valid old insert with MetaG - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecs
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsMetaG{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsMetaG, 'Testing valid old insert with MetaG - keys');
		is ($isNew, 0, 'Testing valid old insert with MetaG - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing valid old insert with MetaG');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Valid old insert with Kraken 2: Two valid taxonomy ZIP archives per sample
	# (exemplary for other archive types, see tests for extractArchive)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleKraken2R, $basePath, $taxP, $idChange, $isNew, $maxRows);
		
		# Reset isNew and insert the same data again
		$isNew = 0;
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleKraken2R, $basePath, $taxP, $idChange, $isNew, $maxRows);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataKraken2, 'Testing valid old insert with Kraken 2 - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecs
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsKraken2{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsKraken2, 'Testing valid old insert with Kraken 2 - keys');
		is ($isNew, 0, 'Testing valid old insert with Kraken 2 - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing valid old insert with Kraken 2');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Valid insert with MetaG, but one read in sequence file has no classification
	# => special taxon FILTERED for this read.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	# Read 16 is missing and will be assigned with the special taxon FILTERED
	my %expecsModMetaG = %{dclone(\%expecsMetaG)};
	foreach my $rank ("domain", "phylum", "class", "subclass", "order", "suborder", "family", "genus", "species", "strain") {
		delete $expecsModMetaG{"UNMATCHED_" . $rank}->{'_id_sequence_'}->{16};
		$expecsModMetaG{"FILTERED_" . $rank} = {'_id_sequence_' => {16 => ['MetaG', 'RDP']}, '_id_taxonomy_' => undef};
	}
	@tmps = sort {$a cmp $b} keys(%expecsModMetaG);
	my @expecsDataMetaGMod = map {$_, $idChange} @tmps;
		
	try {
		$err = "";
		
		# Hide classification for read 16 from detection
		system("mv $basePath/classifications/run04_bar99/h_1_calc.LIN.txt.zip $basePath/classifications/run04_bar99/h_1")
			and die "ERROR: Could not move file.";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataMetaGMod, 'Testing one filtered read with MetaG - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecs
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsModMetaG{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsModMetaG, 'Testing one filtered read with MetaG - keys');
		is ($isNew, 1, 'Testing one filtered read with MetaG - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing one filtered read with MetaG');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
		
		system("mv $basePath/classifications/run04_bar99/h_1 $basePath/classifications/run04_bar99/h_1_calc.LIN.txt.zip")
			and die "ERROR: Could not move file.";
	};
	
	
	#------------------------------------------------------------------------------#
	# Valid insert with Kraken 2, but one read in sequence file has no
	# classification => special taxon FILTERED for this read.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	# Read 16 is missing and will be assigned with the special taxon FILTERED
	my %expecsModKraken2 = %{dclone(\%expecsKraken2)};
	foreach my $rank ("domain", "phylum", "class", "subclass", "order", "suborder", "family", "genus", "species", "strain") {
		delete $expecsModKraken2{"UNMATCHED_" . $rank}->{'_id_sequence_'}->{16};
		$expecsModKraken2{"FILTERED_" . $rank} = {'_id_sequence_' => {16 => ['Kraken 2', 'RDP']}, '_id_taxonomy_' => undef};
	}
	@tmps = sort {$a cmp $b} keys(%expecsModKraken2);
	my @expecsDataKraken2Mod = map {$_, $idChange} @tmps;
		
	try {
		$err = "";
		
		# Hide classification for read 16 from detection
		system("mv $basePath/classifications_k2/run04_bar99/h_1_kraken2.zip $basePath/classifications_k2/run04_bar99/h_1")
			and die "ERROR: Could not move file.";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleKraken2R, $basePath, $taxP, $idChange, $isNew, $maxRows);
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataKraken2Mod, 'Testing one filtered read with Kraken2 - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecs
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsModKraken2{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsModKraken2, 'Testing one filtered read with Kraken 2 - keys');
		is ($isNew, 1, 'Testing one filtered read with Kraken 2 - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing one filtered read with Kraken 2');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
		
		system("mv $basePath/classifications_k2/run04_bar99/h_1 $basePath/classifications_k2/run04_bar99/h_1_kraken2.zip")
			and die "ERROR: Could not move file.";
	};


	#------------------------------------------------------------------------------#
	# Test read IDs in sequence file and taxonomy file don't match with MetaG
	# => ERROR
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	# Read h_1 is abscent from sample 8 of 'run04_bar99'. It appears in sample
	# 9 for the same directory pattern, however there, read h is missing.
	# => ERROR: Every sample needs to have matching reads, even if the directory
	#	pattern is the same.
	my $keysSeqModR = dclone($keysSeqR);
	$keysSeqModR->{'run04_bar99'}->{9}->{'h_1'} = 16;
	delete $keysSeqModR->{'run04_bar99'}->{8}->{'h_1'};
	my $keysSampleModR = dclone($keysSampleMetaGR);
	$keysSampleModR->{9} = {
		'number of run and barcode'	=> 'run04_bar01', # interpreted later as 'run04_bar99'
		'height'					=> '36cm',
		'_isControl_'				=> "t",
		'program'					=> 'MetaG',
		'database'					=> 'RDP'
	};
	
	try {
		$err = "";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (9, 2, '1900-02-04', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqModR, $keysSampleModR, $basePath, $taxP, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/ERROR.*read ID\(s\) do not match/, 'Testing not matching read IDs with MetaG');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test read IDs in sequence file and taxonomy file don't match with Kraken 2
	# => ERROR
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	# Read h_1 is abscent from sample 8 of 'run04_bar99'. It appears in sample
	# 9 for the same directory pattern, however there, read h is missing.
	# => ERROR: Every sample needs to have matching reads, even if the directory
	#	pattern is the same.
	$keysSeqModR = dclone($keysSeqR);
	$keysSeqModR->{'run04_bar99'}->{9}->{'h_1'} = 16;
	delete $keysSeqModR->{'run04_bar99'}->{8}->{'h_1'};
	$keysSampleModR = dclone($keysSampleKraken2R);
	$keysSampleModR->{9} = {
		'number of run and barcode'	=> 'run04_bar01', # interpreted later as 'run04_bar99'
		'height'					=> '36cm',
		'_isControl_'				=> "t",
		'program'					=> 'Kraken 2',
		'database'					=> 'RDP'
	};
	
	try {
		$err = "";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (9, 2, '1900-02-04', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		MetagDB::Sga::insertTaxonomy($dbh, $keysSeqModR, $keysSampleModR, $basePath, $taxP, $idChange, $isNew, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/ERROR.*read ID\(s\) do not match/, 'Testing not matching read IDs with Kraken 2');
		$dbh->rollback;
	};
	

	#------------------------------------------------------------------------------#
	# Valid insert with MetaG: Two valid, but empty, taxonomy ZIPs per sample
	# (exemplary for other archive types, see tests for extractArchive).
	# => Insert special taxon FILTERED.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	%expecsModMetaG = (
		"FILTERED_domain" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_phylum" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_class" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_subclass" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_order" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_suborder" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_family" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_genus" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_species" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_strain" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		}
	);
	@tmps = sort {$a cmp $b} keys(%expecsModMetaG);
	# Add idChange
	@expecsDataMetaGMod = map {$_, $idChange} @tmps;
	
	try {
		$err = "";
		
		# Overwrite taxonomy ZIPs with empty ZIP files
		foreach my $path (keys(%taxFilesMetaG)) {
			my ($dir, $file) = split('/', $path);
			my $data = "";
			zip \$data => "$basePath/classifications/$path" . "_calc.LIN.txt.zip" , AutoClose=> 1, Name => $file ."_calc.LIN.txt";
		}
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		
		# Don't show warnings about empty ZIPs on terminal
		do {
			local *STDERR;
    		open STDERR, ">", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
		};
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataMetaGMod, 'Testing empty taxonomy files with MetaG - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecsMod
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsModMetaG{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsModMetaG, 'Testing empty taxonomy files with MetaG - keys');
		is ($isNew, 1, 'Testing empty taxonomy files with MetaG - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing empty taxonomy files with MetaG');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Valid insert with Kraken 2: Two valid, but empty, taxonomy ZIPs per sample
	# (exemplary for other archive types, see tests for extractArchive).
	# => Insert special taxon FILTERED.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	my $expecsModKraken2R = dclone(\%expecsModMetaG);
	foreach my $class (keys(%{$expecsModKraken2R})) {
		foreach my $id (keys %{$expecsModKraken2R->{$class}->{'_id_sequence_'}}) {
			$expecsModKraken2R->{$class}->{'_id_sequence_'}->{$id}->[0] = 'Kraken 2'
		}
	};
	%expecsModKraken2 = %{$expecsModKraken2R};
	@tmps = sort {$a cmp $b} keys(%expecsModKraken2);
	# Add idChange
	@expecsDataKraken2Mod = map {$_, $idChange} @tmps;
	
	try {
		$err = "";
		
		# Overwrite taxonomy ZIPs with empty ZIP files
		foreach my $path (keys(%taxFilesKraken2)) {
			my ($dir, $file) = split('/', $path);
			my $data = "";
			zip \$data => "$basePath/classifications_k2/$path" . "_kraken2.zip" , AutoClose=> 1, Name => $file ."_kraken2.txt";
		}
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		
		# Don't show warnings about empty ZIPs on terminal
		do {
			local *STDERR;
    		open STDERR, ">", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleKraken2R, $basePath, $taxP, $idChange, $isNew, $maxRows);
		};
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataKraken2Mod, 'Testing empty taxonomy files with Kraken 2 - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecsMod
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsModKraken2{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsModKraken2, 'Testing empty taxonomy files with Kraken 2 - keys');
		is ($isNew, 1, 'Testing empty taxonomy files with Kraken 2 - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing empty taxonomy files with Kraken 2');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Valid insert with MetaG: Two valid, taxonomy ZIPs per sample (exemplary for
	# other archive types, see tests for extractArchive) containing only
	# whitespaces.
	# => Insert special taxon FILTERED
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		# Overwrite taxonomy ZIPs with empty ZIP files
		foreach my $path (keys(%taxFilesMetaG)) {
			my ($dir, $file) = split('/', $path);
			my $data = "      ";
			zip \$data => "$basePath/classifications/$path" . "_calc.LIN.txt.zip" , AutoClose=> 1, Name => $file ."_calc.LIN.txt";
		}
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		
		# Don't show warnings about empty ZIPs on terminal
		do {
			local *STDERR;
    		open STDERR, ">", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
		};
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataMetaGMod, 'Testing taxonomy files containing only whitespaces with MetaG - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecsMod
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsModMetaG{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsModMetaG, 'Testing taxonomy files containing only whitespaces with MetaG - keys');
		is ($isNew, 1, 'Testing taxonomy files containing only whitespaces with MetaG - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing taxonomy files containing only whitespaces with MetaG');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Valid insert with Kraken 2: Two valid, taxonomy ZIPs per sample (exemplary for
	# other archive types, see tests for extractArchive) containing only
	# whitespaces.
	# => Insert special taxon FILTERED
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		# Overwrite taxonomy ZIPs with empty ZIP files
		foreach my $path (keys(%taxFilesKraken2)) {
			my ($dir, $file) = split('/', $path);
			my $data = "      ";
			zip \$data => "$basePath/classifications_k2/$path" . "_kraken2.zip" , AutoClose=> 1, Name => $file ."_kraken2";
		}
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		
		# Don't show warnings about empty ZIPs on terminal
		do {
			local *STDERR;
    		open STDERR, ">", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleKraken2R, $basePath, $taxP, $idChange, $isNew, $maxRows);
		};
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataKraken2Mod, 'Testing taxonomy files containing only whitespaces with Kraken 2 - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecsMod
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsModKraken2{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsModKraken2, 'Testing taxonomy files containing only whitespaces with Kraken 2 - keys');
		is ($isNew, 1, 'Testing taxonomy files containing only whitespaces with Kraken 2 - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing taxonomy files containing only whitespaces with Kraken 2');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test missing files vs files containing whitespaces with MetaG (depends on
	# previous MetaG test to produce the whitespace files).
	# => Reads related to missing taxonomy files should not get the special
	# FILTERED taxon.
	# Since classification files within one directory pattern are merged, all
	# files for run04_bar99 were removed for this test.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	%expecsModMetaG = (
		"FILTERED_domain" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_phylum" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_class" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_subclass" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_order" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_suborder" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_family" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_genus" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_species" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		},
		"FILTERED_strain" => {
			'_id_sequence_' => {
				'1'	=> ['MetaG', 'RDP'],
				'2' => ['MetaG', 'RDP'],
				'3' => ['MetaG', 'RDP'],
				'4' => ['MetaG', 'RDP'],
				'5' => ['MetaG', 'RDP'],
				'6' => ['MetaG', 'RDP'],
				'7' => ['MetaG', 'RDP'],
				'8' => ['MetaG', 'RDP'],
				'9' => ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => undef
		}
	);
	@tmps = sort {$a cmp $b} keys(%expecsModMetaG);
	# Add idChange
	@expecsDataMetaGMod = map {$_, $idChange} @tmps;
	
	try {
		$err = "";

		# Hide two ZIPs from the algorithm
		system("mv $basePath/classifications/run04_bar99/h_calc.LIN.txt.zip $basePath/classifications/run04_bar99/h")
			and die "ERROR: Could not move file.";
		system("mv $basePath/classifications/run04_bar99/h_1_calc.LIN.txt.zip $basePath/classifications/run04_bar99/h_1")
			and die "ERROR: Could not move file.";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		
		# Don't show warnings about empty ZIPs on terminal
		do {
			local *STDERR;
    		open STDERR, ">>", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleMetaGR, $basePath, $taxP, $idChange, $isNew, $maxRows);
		};
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataMetaGMod, 'Testing missing vs file containing whitespaces with MetaG - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecsMod
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsModMetaG{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsModMetaG, 'Testing missing vs file containing whitespaces with MetaG - keys');
		is ($isNew, 1, 'Testing missing vs file containing whitespaces with MetaG - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing missing vs file containing whitespaces with MetaG');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
		
		system("mv $basePath/classifications/run04_bar99/h $basePath/classifications/run04_bar99/h_calc.LIN.txt.zip")
			and die "ERROR: Could not move file.";
		system("mv $basePath/classifications/run04_bar99/h_1 $basePath/classifications/run04_bar99/h_1_calc.LIN.txt.zip")
			and die "ERROR: Could not move file.";
	};


	#------------------------------------------------------------------------------#
	# Test missing files vs files containing whitespaces with Kraken 2 (depends
	# on previous Kraken 2 test to produce the whitespace files).
	# => Reads related to missing taxonomy files should not get the special
	# FILTERED taxon.
	# Since classification files within one directory pattern are merged, all
	# files for run04_bar99 were removed for this test.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	$expecsModKraken2R = dclone(\%expecsModMetaG);
	%expecsModKraken2 = %{$expecsModKraken2R};
	foreach my $class (keys(%expecsModKraken2)) {
		foreach my $id (keys(%{$expecsModKraken2{$class}->{'_id_sequence_'}})) {
			$expecsModKraken2{$class}->{'_id_sequence_'}->{$id}->[0] = 'Kraken 2'
		}
	}
	@tmps = sort {$a cmp $b} keys(%expecsModKraken2);
	# Add idChange
	@expecsDataKraken2Mod = map {$_, $idChange} @tmps;
	
	try {
		$err = "";

		# Hide two ZIPs from the algorithm
		system("mv $basePath/classifications_k2/run04_bar99/h_kraken2.zip $basePath/classifications_k2/run04_bar99/h")
			and die "ERROR: Could not move file.";
		system("mv $basePath/classifications_k2/run04_bar99/h_1_kraken2.zip $basePath/classifications_k2/run04_bar99/h_1")
			and die "ERROR: Could not move file.";
		
		# Create the necessary records
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		
		# Don't show warnings about empty ZIPs on terminal
		do {
			local *STDERR;
    		open STDERR, ">>", "/dev/null";
			($outKeysR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleKraken2R, $basePath, $taxP, $idChange, $isNew, $maxRows);
		};
		
		# Get the inserted data from the database
		my $resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id_change FROM taxonomy ORDER BY key ASC");
		my @res = map {$_->[0], $_->[1]} @{$resR};
		is (\@res, \@expecsDataKraken2Mod, 'Testing missing vs file containing whitespaces with Kraken 2 - data');
		
		# Get name_rank and id from database and update
		# _id_taxonomy_ in %expecsMod
		$resR = $dbh->selectall_arrayref("SELECT CONCAT(name, '_', rank) AS key, id FROM taxonomy");
		foreach my $rowR (@{$resR}) {
			my ($key, $id) = @{$rowR};
			$expecsModKraken2{$key}->{'_id_taxonomy_'} = $id
		}
		# Compare to keysR
		is ($outKeysR, \%expecsModKraken2, 'Testing missing vs file containing whitespaces with Kraken 2 - keys');
		is ($isNew, 1, 'Testing missing vs file containing whitespaces with Kraken 2 - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing missing vs file containing whitespaces with Kraken 2');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
		
		system("mv $basePath/classifications_k2/run04_bar99/h $basePath/classifications_k2/run04_bar99/h_kraken2.zip")
			and die "ERROR: Could not move file.";
		system("mv $basePath/classifications_k2/run04_bar99/h_1 $basePath/classifications_k2/run04_bar99/h_1_kraken2.zip")
			and die "ERROR: Could not move file.";
	};
	
		
	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the insertClassification function
#--------------------------------------------------------------------------------------------------#
#
sub test_insertClassification {
	my $dbh = $_[0] // "";
	
	my $keysR = {
		"d_a_domain" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 1
		},
		"p_a_phylum" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 2
		},
		"c_a_class" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 3
		},
		"sc_a_subclass" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 4
		},
		"o_a_order" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 5
		},
		"so_a_suborder" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 6
		},
		"f_a_family" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 7
		},
		"g_a_genus" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 8
		},
		"s_a_species" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 9
		},
		"str_a_strain" => {
			'_id_sequence_' => {
				'1' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 10
		},
		"d_a_1_domain" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 11
		},
		"p_a_1_phylum" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 12
		},
		"c_a_1_class" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 13
		},
		"sc_a_1_subclass" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 14
		},
		"o_a_1_order" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 15
		},
		"so_a_1_suborder" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 16
		},
		"f_a_1_family" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 17
		},
		"g_a_1_genus" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 18
		},
		"s_a_1_species" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 19
		},
		"str_a_1_strain" => {
			'_id_sequence_' => {
				'2' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 20
		},
		"d_b_domain" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 21
		},
		"p_b_phylum" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 22
		},
		"c_b_class" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 23
		},
		"sc_b_subclass" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 24
		},
		"o_b_order" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 25
		},
		"so_b_suborder" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 26
		},
		"f_b_family" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 27
		},
		"g_b_genus" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 28
		},
		"s_b_species" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 29
		},
		"str_b_strain" => {
			'_id_sequence_' => {
				'3' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 30
		},
		"d_b_1_domain" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 31
		},
		"p_b_1_phylum" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 32
		},
		"c_b_1_class" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 33
		},
		"sc_b_1_subclass" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 34
		},
		"o_b_1_order" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 35
		},
		"so_b_1_suborder" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 36
		},
		"f_b_1_family" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 37
		},
		"g_b_1_genus" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 38
		},
		"s_b_1_species" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 39
		},
		"str_b_1_strain" => {
			'_id_sequence_' => {
				'4' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 40
		},
		"d_c_domain" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 41
		},
		"p_c_phylum" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 42
		},
		"c_c_class" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 43
		},
		"sc_c_subclass" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 44
		},
		"o_c_order" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 45
		},
		"so_c_suborder" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 46
		},
		"f_c_family" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 47
		},
		"g_c_genus" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 48
		},
		"s_c_species" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 49
		},
		"str_c_strain" => {
			'_id_sequence_' => {
				'5' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 50
		},
		"d_c_1_domain" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 51
		},
		"p_c_1_phylum" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 52
		},
		"c_c_1_class" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 53
		},
		"sc_c_1_subclass" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 54
		},
		"o_c_1_order" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 55
		},
		"so_c_1_suborder" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 56
		},
		"f_c_1_family" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 57
		},
		"g_c_1_genus" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 58
		},
		"s_c_1_species" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 59
		},
		"str_c_1_strain" => {
			'_id_sequence_' => {
				'6' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 60
		},
		"d_d_domain" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 61
		},
		"p_d_phylum" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 62
		},
		"c_d_class" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 63
		},
		"sc_d_subclass" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 64
		},
		"o_d_order" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 65
		},
		"so_d_suborder" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 66
		},
		"f_d_family" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 67
		},
		"g_d_genus" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 68
		},
		"s_d_species" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 69
		},
		"str_d_strain" => {
			'_id_sequence_' => {
				'7' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 70
		},
		"d_d_1_domain" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 71
		},
		"p_d_1_phylum" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 72
		},
		"c_d_1_class" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 73
		},
		"sc_d_1_subclass" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 74
		},
		"o_d_1_order" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 75
		},
		"so_d_1_suborder" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 76
		},
		"f_d_1_family" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 77
		},
		"g_d_1_genus" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 78
		},
		"s_d_1_species" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 79
		},
		"str_d_1_strain" => {
			'_id_sequence_' => {
				'8' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 80
		},
		"d_e_domain" => {
			'_id_sequence_' => {
				'9' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 81
		},
		"p_e_phylum" => {
			'_id_sequence_' => {
				'9' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 82
		},
		"c_e_class" => {
			'_id_sequence_' => {
				'9' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 83
		},
		"d_e_1_domain" => {
			'_id_sequence_' => {
				'10' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 84
		},
		"p_e_1_phylum" => {
			'_id_sequence_' => {
				'10' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 85
		},
		"c_e_1_class" => {
			'_id_sequence_' => {
				'10' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 86
		},
		"d_f_domain" => {
			'_id_sequence_' => {
				'11' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 87
		},
		"p_f_phylum" => {
			'_id_sequence_' => {
				'11' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 88
		},
		"c_f_class" => {
			'_id_sequence_' => {
				'11' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 89
		},
		"_domain" => { # unclassified taxon
			'_id_sequence_' => {
				'12' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 90
		},
		"_phylum" => { # unclassified taxon
			'_id_sequence_' => {
				'12' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 91
		},
		"_class" => { # unclassified taxon
			'_id_sequence_' => {
				'12' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 92
		},
		"UNMATCHED_domain" => {
			'_id_sequence_' => {
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 93
		},
		"UNMATCHED_phylum" => {
			'_id_sequence_' => {
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 94
		},
		"UNMATCHED_class" => {
			'_id_sequence_' => {
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 95
		},
		"UNMATCHED_subclass" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 96
		},
		"UNMATCHED_order" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 97
		},
		"UNMATCHED_suborder" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 98
		},
		"UNMATCHED_family" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 99
		},
		"UNMATCHED_genus" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 100
		},
		"UNMATCHED_species" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 101
		},
		"UNMATCHED_strain" => {
			'_id_sequence_' => {
				'9'	=> ['MetaG', 'RDP'],
				'10' => ['MetaG', 'RDP'],
				'11' => ['MetaG', 'RDP'],
				'12' => ['MetaG', 'RDP'],
				'13' => ['MetaG', 'RDP'],
				'14' => ['MetaG', 'RDP'],
				'15' => ['MetaG', 'RDP'],
				'16' => ['MetaG', 'RDP']
			},
			'_id_taxonomy_' => 102
		}
	};
	my $idChange = 1;
	my $isNew = 0;
	my $maxRows = 2;
	my $err = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no foreign keys + no id_change + no indication,
	# if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no foreign keys (+ no id_change + no indication, if new data
	# + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no foreign keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no id_change (+ no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, $keysR)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no indication, if new data (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, $keysR, $idChange)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows => optional argument
	#------------------------------------------------------------------------------#
	my @expecs = (
		[1, 'MetaG', 'RDP', $idChange],
		[2, 'MetaG', 'RDP', $idChange],
		[3, 'MetaG', 'RDP', $idChange],
		[4, 'MetaG', 'RDP', $idChange],
		[5, 'MetaG', 'RDP', $idChange],
		[6, 'MetaG', 'RDP', $idChange],
		[7, 'MetaG', 'RDP', $idChange],
		[8, 'MetaG', 'RDP', $idChange],
		[9, 'MetaG', 'RDP', $idChange],
		[10, 'MetaG', 'RDP', $idChange],
		[11, 'MetaG', 'RDP', $idChange],
		[12, 'MetaG', 'RDP', $idChange],
		[13, 'MetaG', 'RDP', $idChange],
		[14, 'MetaG', 'RDP', $idChange],
		[15, 'MetaG', 'RDP', $idChange],
		[16, 'MetaG', 'RDP', $idChange],
	);
	
	my $tmpsR = {
		'1_MetaG_RDP' => { # read a
			1 => undef,
			2 => undef,
			3 => undef,
			4 => undef,
			5 => undef,
			6 => undef,
			7 => undef,
			8 => undef,
			9 => undef,
			10 => undef
		},
		'2_MetaG_RDP' => { # read a_1
			11 => undef,
			12 => undef,
			13 => undef,
			14 => undef,
			15 => undef,
			16 => undef,
			17 => undef,
			18 => undef,
			19 => undef,
			20 => undef
		},
		'3_MetaG_RDP' => { # read b
			21 => undef,
			22 => undef,
			23 => undef,
			24 => undef,
			25 => undef,
			26 => undef,
			27 => undef,
			28 => undef,
			29 => undef,
			30 => undef
		},
		'4_MetaG_RDP' => { # read b_1
			31 => undef,
			32 => undef,
			33 => undef,
			34 => undef,
			35 => undef,
			36 => undef,
			37 => undef,
			38 => undef,
			39 => undef,
			40 => undef
		},
		'5_MetaG_RDP' => { # read c
			41 => undef,
			42 => undef,
			43 => undef,
			44 => undef,
			45 => undef,
			46 => undef,
			47 => undef,
			48 => undef,
			49 => undef,
			50 => undef
		},
		'6_MetaG_RDP' => { # read c_1
			51 => undef,
			52 => undef,
			53 => undef,
			54 => undef,
			55 => undef,
			56 => undef,
			57 => undef,
			58 => undef,
			59 => undef,
			60 => undef
		},
		'7_MetaG_RDP' => { # read d
			61 => undef,
			62 => undef,
			63 => undef,
			64 => undef,
			65 => undef,
			66 => undef,
			67 => undef,
			68 => undef,
			69 => undef,
			70 => undef
		},
		'8_MetaG_RDP' => { # read d_1
			71 => undef,
			72 => undef,
			73 => undef,
			74 => undef,
			75 => undef,
			76 => undef,
			77 => undef,
			78 => undef,
			79 => undef,
			80 => undef
		},
		'9_MetaG_RDP' => { # read e
			81 => undef,
			82 => undef,
			83 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'10_MetaG_RDP' => { # read e_1
			84 => undef,
			85 => undef,
			86 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'11_MetaG_RDP' => { # read f
			87 => undef,
			88 => undef,
			89 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'12_MetaG_RDP' => { # read f_1
			90 => undef,
			91 => undef,
			92 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'13_MetaG_RDP' => { # read g
			93 => undef,
			94 => undef,
			95 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'14_MetaG_RDP' => { # read g_1
			93 => undef,
			94 => undef,
			95 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'15_MetaG_RDP' => { # read h
			93 => undef,
			94 => undef,
			95 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'16_MetaG_RDP' => { # read h_1
			93 => undef,
			94 => undef,
			95 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		}
	};
	
	try {
		$err = "";
		
		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'd_a', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, 'p_a', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'c_a', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'sc_a', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'o_a', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'so_a', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'f_a', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'g_a', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 's_a', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'str_a', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'd_a_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'p_a_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'c_a_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'sc_a_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'o_a_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'so_a_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'f_a_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'g_a_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 's_a_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'str_a_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'd_b', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (22, 'p_b', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (23, 'c_b', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (24, 'sc_b', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (25, 'o_b', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (26, 'so_b', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (27, 'f_b', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (28, 'g_b', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (29, 's_b', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (30, 'str_b', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (31, 'd_b_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (32, 'p_b_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (33, 'c_b_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (34, 'sc_b_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (35, 'o_b_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (36, 'so_b_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (37, 'f_b_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (38, 'g_b_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (39, 's_b_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (40, 'str_b_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (41, 'd_c', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (42, 'p_c', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (43, 'c_c', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (44, 'sc_c', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (45, 'o_c', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (46, 'so_c', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (47, 'f_c', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (48, 'g_c', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (49, 's_c', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (50, 'str_c', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (51, 'd_c_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (52, 'p_c_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (53, 'c_c_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (54, 'sc_c_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (55, 'o_c_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (56, 'so_c_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (57, 'f_c_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (58, 'g_c_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (59, 's_c_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (60, 'str_c_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (61, 'd_d', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (62, 'p_d', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (63, 'c_d', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (64, 'sc_d', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (65, 'o_d', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (66, 'so_d', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (67, 'f_d', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (68, 'g_d', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (69, 's_d', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (70, 'str_d', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (71, 'd_d_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (72, 'p_d_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (73, 'c_d_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (74, 'sc_d_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (75, 'o_d_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (76, 'so_d_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (77, 'f_d_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (78, 'g_d_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (79, 's_d_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (80, 'str_d_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (81, 'd_e', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (82, 'p_e', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (83, 'c_e', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (84, 'd_e_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (85, 'p_e_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (86, 'c_e_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (87, 'd_f', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (88, 'p_f', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (89, 'c_f', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (90, NULL, 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (91, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (92, NULL, 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (93, 'UNMATCHED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (94, 'UNMATCHED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (95, 'UNMATCHED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (96, 'UNMATCHED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (97, 'UNMATCHED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (98, 'UNMATCHED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (99, 'UNMATCHED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (100, 'UNMATCHED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (101, 'UNMATCHED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (102, 'UNMATCHED', 'strain', $idChange)");
		
		(my $outKeysR, $isNew) = MetagDB::Sga::insertClassification($dbh, $keysR, $idChange, $isNew);
		
		# Get data from database
		my $resR = $dbh->selectall_arrayref("SELECT id_sequence, program, database, id_change FROM classification ORDER BY id_sequence, program, database ASC");
		is ($resR, \@expecs, 'Testing no maxRows - data');
		
		# Get id_classification from database (cannot be predicted) and assign to expected id_taxonomies
		$resR = $dbh->selectall_arrayref("SELECT id, CONCAT(id_sequence, '_', program, '_', database) FROM classification");
		my %expecKeys = ();
		foreach my $lineR (@{$resR}) {
			my ($id, $key) = @{$lineR};
			$expecKeys{$id} = $tmpsR->{$key};
		}
		
		is ($outKeysR, \%expecKeys, 'Testing no maxRows - keys');
		is ($isNew, 1, 'Testing no maxRows - any new data inserted?');
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing no maxRows');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification("", $keysR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty foreign keys
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, "", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty foreign keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test foreign keys not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, "abc", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No keys or not a reference/, 'Testing foreign keys not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test foreign keys empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, {}, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No keys or not a reference/, 'Testing foreign keys empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty id_change
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, $keysR, "", $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty indication, if new data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, $keysR, $idChange, "", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, $keysR, $idChange, "abc", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing indication, if new data not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data illegal number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, $keysR, $idChange, 2, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing indication, if new data illegal number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, $keysR, $idChange, $isNew, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing empty maxRows');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, $keysR, $idChange, $isNew, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is zero
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertClassification($dbh, $keysR, $idChange, $isNew, 0)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid foreign keys hash; no "_id_sequence_"
	#------------------------------------------------------------------------------#
	$isNew = 0;
		
	try {
		$err = "";
		
		my $keysModR = dclone($keysR);
		foreach my $key (keys(%{$keysModR})) {
			delete $keysModR->{$key}->{'_id_sequence_'};
		}
		MetagDB::Sga::insertClassification($dbh, $keysModR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid keys hash/, 'Testing no _id_sequence_ in foreign keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty "_id_sequence_" in foreign keys
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my $keysModR = dclone($keysR);
		foreach my $key (keys(%{$keysModR})) {
			$keysModR->{$key}->{'_id_sequence_'} = {};
		}
		
		(my $outKeysR, $isNew) = MetagDB::Sga::insertClassification($dbh, $keysModR, $idChange, $isNew, $maxRows);
		
		# Prove that no data was inserted
		my $resR = $dbh->selectall_arrayref("SELECT id FROM classification");
		is ($resR, [], 'Testing empty _id_sequence_ - data');
		is ($outKeysR, {}, 'Testing empty _id_sequence_ - keys');
		is ($isNew, 0, 'Testing empty _id_sequence_ - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing empty _id_sequence_');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid foreign keys hash; no "_id_taxonomy_"
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my $keysModR = dclone($keysR);
		foreach my $key (keys(%{$keysModR})) {
			delete $keysModR->{$key}->{'_id_taxonomy_'};
		}
		MetagDB::Sga::insertClassification($dbh, $keysModR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No id_taxonomy for key/, 'Testing no _id_taxonomy_ in foreign keys');
	};
	
		
	#------------------------------------------------------------------------------#
	# Test valid new insert (includes duplicates = same id_sequence + program +
	# db)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'd_a', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, 'p_a', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'c_a', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'sc_a', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'o_a', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'so_a', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'f_a', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'g_a', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 's_a', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'str_a', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'd_a_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'p_a_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'c_a_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'sc_a_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'o_a_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'so_a_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'f_a_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'g_a_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 's_a_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'str_a_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'd_b', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (22, 'p_b', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (23, 'c_b', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (24, 'sc_b', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (25, 'o_b', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (26, 'so_b', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (27, 'f_b', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (28, 'g_b', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (29, 's_b', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (30, 'str_b', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (31, 'd_b_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (32, 'p_b_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (33, 'c_b_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (34, 'sc_b_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (35, 'o_b_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (36, 'so_b_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (37, 'f_b_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (38, 'g_b_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (39, 's_b_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (40, 'str_b_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (41, 'd_c', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (42, 'p_c', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (43, 'c_c', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (44, 'sc_c', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (45, 'o_c', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (46, 'so_c', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (47, 'f_c', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (48, 'g_c', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (49, 's_c', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (50, 'str_c', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (51, 'd_c_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (52, 'p_c_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (53, 'c_c_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (54, 'sc_c_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (55, 'o_c_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (56, 'so_c_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (57, 'f_c_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (58, 'g_c_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (59, 's_c_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (60, 'str_c_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (61, 'd_d', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (62, 'p_d', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (63, 'c_d', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (64, 'sc_d', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (65, 'o_d', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (66, 'so_d', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (67, 'f_d', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (68, 'g_d', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (69, 's_d', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (70, 'str_d', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (71, 'd_d_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (72, 'p_d_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (73, 'c_d_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (74, 'sc_d_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (75, 'o_d_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (76, 'so_d_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (77, 'f_d_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (78, 'g_d_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (79, 's_d_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (80, 'str_d_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (81, 'd_e', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (82, 'p_e', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (83, 'c_e', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (84, 'd_e_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (85, 'p_e_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (86, 'c_e_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (87, 'd_f', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (88, 'p_f', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (89, 'c_f', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (90, NULL, 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (91, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (92, NULL, 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (93, 'UNMATCHED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (94, 'UNMATCHED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (95, 'UNMATCHED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (96, 'UNMATCHED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (97, 'UNMATCHED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (98, 'UNMATCHED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (99, 'UNMATCHED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (100, 'UNMATCHED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (101, 'UNMATCHED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (102, 'UNMATCHED', 'strain', $idChange)");
		
		(my $outKeysR, $isNew) = MetagDB::Sga::insertClassification($dbh, $keysR, $idChange, $isNew, $maxRows);
		
		# Get data from database
		my $resR = $dbh->selectall_arrayref("SELECT id_sequence, program, database, id_change FROM classification ORDER BY id_sequence, program, database ASC");
		is ($resR, \@expecs, 'Testing valid insert - data');
		
		# Get id_classification from database (cannot be predicted) and assign to expected id_taxonomies
		$resR = $dbh->selectall_arrayref("SELECT id, CONCAT(id_sequence, '_', program, '_', database) FROM classification");
		my %expecKeys = ();
		foreach my $lineR (@{$resR}) {
			my ($id, $key) = @{$lineR};
			$expecKeys{$id} = $tmpsR->{$key};
		}
		
		is ($outKeysR, \%expecKeys, 'Testing valid insert - keys');
		is ($isNew, 1, 'Testing valid insert - any new data inserted?');
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing valid insert');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid old insert
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";

		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'd_a', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, 'p_a', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'c_a', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'sc_a', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'o_a', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'so_a', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'f_a', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'g_a', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 's_a', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'str_a', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'd_a_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'p_a_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'c_a_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'sc_a_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'o_a_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'so_a_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'f_a_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'g_a_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 's_a_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'str_a_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'd_b', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (22, 'p_b', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (23, 'c_b', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (24, 'sc_b', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (25, 'o_b', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (26, 'so_b', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (27, 'f_b', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (28, 'g_b', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (29, 's_b', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (30, 'str_b', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (31, 'd_b_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (32, 'p_b_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (33, 'c_b_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (34, 'sc_b_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (35, 'o_b_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (36, 'so_b_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (37, 'f_b_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (38, 'g_b_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (39, 's_b_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (40, 'str_b_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (41, 'd_c', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (42, 'p_c', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (43, 'c_c', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (44, 'sc_c', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (45, 'o_c', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (46, 'so_c', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (47, 'f_c', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (48, 'g_c', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (49, 's_c', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (50, 'str_c', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (51, 'd_c_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (52, 'p_c_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (53, 'c_c_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (54, 'sc_c_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (55, 'o_c_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (56, 'so_c_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (57, 'f_c_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (58, 'g_c_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (59, 's_c_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (60, 'str_c_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (61, 'd_d', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (62, 'p_d', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (63, 'c_d', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (64, 'sc_d', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (65, 'o_d', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (66, 'so_d', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (67, 'f_d', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (68, 'g_d', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (69, 's_d', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (70, 'str_d', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (71, 'd_d_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (72, 'p_d_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (73, 'c_d_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (74, 'sc_d_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (75, 'o_d_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (76, 'so_d_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (77, 'f_d_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (78, 'g_d_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (79, 's_d_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (80, 'str_d_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (81, 'd_e', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (82, 'p_e', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (83, 'c_e', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (84, 'd_e_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (85, 'p_e_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (86, 'c_e_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (87, 'd_f', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (88, 'p_f', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (89, 'c_f', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (90, NULL, 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (91, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (92, NULL, 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (93, 'UNMATCHED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (94, 'UNMATCHED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (95, 'UNMATCHED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (96, 'UNMATCHED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (97, 'UNMATCHED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (98, 'UNMATCHED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (99, 'UNMATCHED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (100, 'UNMATCHED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (101, 'UNMATCHED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (102, 'UNMATCHED', 'strain', $idChange)");
		(my $outKeysR, $isNew) = MetagDB::Sga::insertClassification($dbh, $keysR, $idChange, $isNew, $maxRows);
		
		# Reset isNew and insert the same data again
		$isNew = 0;
		($outKeysR, $isNew) = MetagDB::Sga::insertClassification($dbh, $keysR, $idChange, $isNew, $maxRows);
		
		# Get data from database
		my $resR = $dbh->selectall_arrayref("SELECT id_sequence, program, database, id_change FROM classification ORDER BY id_sequence, program, database ASC");
		is ($resR, \@expecs, 'Testing valid old insert - data');
		
		# Get id_classification from database (cannot be predicted) and assign to expected id_taxonomies
		$resR = $dbh->selectall_arrayref("SELECT id, CONCAT(id_sequence, '_', program, '_', database) FROM classification");
		my %expecKeys = ();
		foreach my $lineR (@{$resR}) {
			my ($id, $key) = @{$lineR};
			$expecKeys{$id} = $tmpsR->{$key};
		}
		is ($outKeysR, \%expecKeys, 'Testing valid old insert - keys');
		is ($isNew, 0, 'Testing valid old insert - any new data inserted?');
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing valid old insert');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test insert in hypothetical more relaxed database schema. This is to test,
	# if the internal key (used for duplicate detection) can be calculated, if
	# "program" and "database" are NULL.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		my $keysModR = dclone($keysR);
		# Set program and database to NULL
		foreach my $key (keys(%{$keysModR})) {
			foreach my $idSequence (keys(%{$keysModR->{$key}->{'_id_sequence_'}})) {
				$keysModR->{$key}->{'_id_sequence_'}->{$idSequence} = [undef, undef]
			}
		}
		
		@expecs = (
			[1, undef, undef, $idChange],
			[2, undef, undef, $idChange],
			[3, undef, undef, $idChange],
			[4, undef, undef, $idChange],
			[5, undef, undef, $idChange],
			[6, undef, undef, $idChange],
			[7, undef, undef, $idChange],
			[8, undef, undef, $idChange],
			[9, undef, undef, $idChange],
			[10, undef, undef, $idChange],
			[11, undef, undef, $idChange],
			[12, undef, undef, $idChange],
			[13, undef, undef, $idChange],
			[14, undef, undef, $idChange],
			[15, undef, undef, $idChange],
			[16, undef, undef, $idChange],
		);
		
		$tmpsR = {
			'1__' => { # read a
				1 => undef,
				2 => undef,
				3 => undef,
				4 => undef,
				5 => undef,
				6 => undef,
				7 => undef,
				8 => undef,
				9 => undef,
				10 => undef
			},
			'2__' => { # read a_1
				11 => undef,
				12 => undef,
				13 => undef,
				14 => undef,
				15 => undef,
				16 => undef,
				17 => undef,
				18 => undef,
				19 => undef,
				20 => undef
			},
			'3__' => { # read b
				21 => undef,
				22 => undef,
				23 => undef,
				24 => undef,
				25 => undef,
				26 => undef,
				27 => undef,
				28 => undef,
				29 => undef,
				30 => undef
			},
			'4__' => { # read b_1
				31 => undef,
				32 => undef,
				33 => undef,
				34 => undef,
				35 => undef,
				36 => undef,
				37 => undef,
				38 => undef,
				39 => undef,
				40 => undef
			},
			'5__' => { # read c
				41 => undef,
				42 => undef,
				43 => undef,
				44 => undef,
				45 => undef,
				46 => undef,
				47 => undef,
				48 => undef,
				49 => undef,
				50 => undef
			},
			'6__' => { # read c_1
				51 => undef,
				52 => undef,
				53 => undef,
				54 => undef,
				55 => undef,
				56 => undef,
				57 => undef,
				58 => undef,
				59 => undef,
				60 => undef
			},
			'7__' => { # read d
				61 => undef,
				62 => undef,
				63 => undef,
				64 => undef,
				65 => undef,
				66 => undef,
				67 => undef,
				68 => undef,
				69 => undef,
				70 => undef
			},
			'8__' => { # read d_1
				71 => undef,
				72 => undef,
				73 => undef,
				74 => undef,
				75 => undef,
				76 => undef,
				77 => undef,
				78 => undef,
				79 => undef,
				80 => undef
			},
			'9__' => { # read e
				81 => undef,
				82 => undef,
				83 => undef,
				96 => undef,
				97 => undef,
				98 => undef,
				99 => undef,
				100 => undef,
				101 => undef,
				102 => undef
			},
			'10__' => { # read e_1
				84 => undef,
				85 => undef,
				86 => undef,
				96 => undef,
				97 => undef,
				98 => undef,
				99 => undef,
				100 => undef,
				101 => undef,
				102 => undef
			},
			'11__' => { # read f
				87 => undef,
				88 => undef,
				89 => undef,
				96 => undef,
				97 => undef,
				98 => undef,
				99 => undef,
				100 => undef,
				101 => undef,
				102 => undef
			},
			'12__' => { # read f_1
				90 => undef,
				91 => undef,
				92 => undef,
				96 => undef,
				97 => undef,
				98 => undef,
				99 => undef,
				100 => undef,
				101 => undef,
				102 => undef
			},
			'13__' => { # read g
				93 => undef,
				94 => undef,
				95 => undef,
				96 => undef,
				97 => undef,
				98 => undef,
				99 => undef,
				100 => undef,
				101 => undef,
				102 => undef
			},
			'14__' => { # read g_1
				93 => undef,
				94 => undef,
				95 => undef,
				96 => undef,
				97 => undef,
				98 => undef,
				99 => undef,
				100 => undef,
				101 => undef,
				102 => undef
			},
			'15__' => { # read h
				93 => undef,
				94 => undef,
				95 => undef,
				96 => undef,
				97 => undef,
				98 => undef,
				99 => undef,
				100 => undef,
				101 => undef,
				102 => undef
			},
			'16__' => { # read h_1
				93 => undef,
				94 => undef,
				95 => undef,
				96 => undef,
				97 => undef,
				98 => undef,
				99 => undef,
				100 => undef,
				101 => undef,
				102 => undef
			}
		};
		
		# Drop not NULL contraints on program and database in classification
		$dbh->do ("ALTER TABLE classification ALTER COLUMN program DROP NOT NULL");
		$dbh->do ("ALTER TABLE classification ALTER COLUMN database DROP NOT NULL");
		
		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'd_a', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, 'p_a', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'c_a', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'sc_a', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'o_a', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'so_a', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'f_a', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'g_a', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 's_a', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'str_a', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'd_a_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'p_a_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'c_a_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'sc_a_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'o_a_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'so_a_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'f_a_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'g_a_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 's_a_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'str_a_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'd_b', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (22, 'p_b', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (23, 'c_b', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (24, 'sc_b', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (25, 'o_b', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (26, 'so_b', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (27, 'f_b', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (28, 'g_b', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (29, 's_b', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (30, 'str_b', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (31, 'd_b_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (32, 'p_b_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (33, 'c_b_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (34, 'sc_b_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (35, 'o_b_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (36, 'so_b_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (37, 'f_b_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (38, 'g_b_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (39, 's_b_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (40, 'str_b_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (41, 'd_c', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (42, 'p_c', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (43, 'c_c', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (44, 'sc_c', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (45, 'o_c', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (46, 'so_c', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (47, 'f_c', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (48, 'g_c', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (49, 's_c', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (50, 'str_c', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (51, 'd_c_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (52, 'p_c_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (53, 'c_c_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (54, 'sc_c_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (55, 'o_c_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (56, 'so_c_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (57, 'f_c_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (58, 'g_c_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (59, 's_c_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (60, 'str_c_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (61, 'd_d', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (62, 'p_d', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (63, 'c_d', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (64, 'sc_d', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (65, 'o_d', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (66, 'so_d', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (67, 'f_d', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (68, 'g_d', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (69, 's_d', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (70, 'str_d', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (71, 'd_d_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (72, 'p_d_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (73, 'c_d_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (74, 'sc_d_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (75, 'o_d_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (76, 'so_d_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (77, 'f_d_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (78, 'g_d_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (79, 's_d_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (80, 'str_d_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (81, 'd_e', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (82, 'p_e', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (83, 'c_e', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (84, 'd_e_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (85, 'p_e_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (86, 'c_e_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (87, 'd_f', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (88, 'p_f', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (89, 'c_f', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (90, NULL, 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (91, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (92, NULL, 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (93, 'UNMATCHED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (94, 'UNMATCHED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (95, 'UNMATCHED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (96, 'UNMATCHED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (97, 'UNMATCHED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (98, 'UNMATCHED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (99, 'UNMATCHED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (100, 'UNMATCHED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (101, 'UNMATCHED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (102, 'UNMATCHED', 'strain', $idChange)");
		
		(my $outKeysR, $isNew) = MetagDB::Sga::insertClassification($dbh, $keysModR, $idChange, $isNew, $maxRows);
		
		# Get data from database
		my $resR = $dbh->selectall_arrayref("SELECT id_sequence, program, database, id_change FROM classification ORDER BY id_sequence, program, database ASC");
		is ($resR, \@expecs, 'Testing insert with NULL values - data');
		
		# Get id_classification from database (cannot be predicted) and assign to expected id_taxonomies
		$resR = $dbh->selectall_arrayref("SELECT id, CONCAT(id_sequence, '_', program, '_', database) FROM classification");
		my %expecKeys = ();
		foreach my $lineR (@{$resR}) {
			my ($id, $key) = @{$lineR};
			$expecKeys{$id} = $tmpsR->{$key};
		}
		
		is ($outKeysR, \%expecKeys, 'Testing insert with NULL values - keys');
		is ($isNew, 1, 'Testing insert with NULL values - any new data inserted?');
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing insert with NULL values');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the insertTaxclass function
#--------------------------------------------------------------------------------------------------#
#
sub test_insertTaxclass {
	my $dbh = $_[0] // "";
	
	my $keysR = {
		'1' => { # class of read a
			1 => undef,
			2 => undef,
			3 => undef,
			4 => undef,
			5 => undef,
			6 => undef,
			7 => undef,
			8 => undef,
			9 => undef,
			10 => undef
		},
		'2' => { # class of read a_1
			11 => undef,
			12 => undef,
			13 => undef,
			14 => undef,
			15 => undef,
			16 => undef,
			17 => undef,
			18 => undef,
			19 => undef,
			20 => undef
		},
		'3' => { # class of read b
			21 => undef,
			22 => undef,
			23 => undef,
			24 => undef,
			25 => undef,
			26 => undef,
			27 => undef,
			28 => undef,
			29 => undef,
			30 => undef
		},
		'4' => { # class of read b_1
			31 => undef,
			32 => undef,
			33 => undef,
			34 => undef,
			35 => undef,
			36 => undef,
			37 => undef,
			38 => undef,
			39 => undef,
			40 => undef
		},
		'5' => { # class of read c
			41 => undef,
			42 => undef,
			43 => undef,
			44 => undef,
			45 => undef,
			46 => undef,
			47 => undef,
			48 => undef,
			49 => undef,
			50 => undef
		},
		'6' => { # class of read c_1
			51 => undef,
			52 => undef,
			53 => undef,
			54 => undef,
			55 => undef,
			56 => undef,
			57 => undef,
			58 => undef,
			59 => undef,
			60 => undef
		},
		'7' => { # class of read d
			61 => undef,
			62 => undef,
			63 => undef,
			64 => undef,
			65 => undef,
			66 => undef,
			67 => undef,
			68 => undef,
			69 => undef,
			70 => undef
		},
		'8' => { # class of read d_1
			71 => undef,
			72 => undef,
			73 => undef,
			74 => undef,
			75 => undef,
			76 => undef,
			77 => undef,
			78 => undef,
			79 => undef,
			80 => undef
		},
		'9' => { # class of read e
			81 => undef,
			82 => undef,
			83 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'10' => { # class of read e_1
			84 => undef,
			85 => undef,
			86 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'11' => { # class of read f
			87 => undef,
			88 => undef,
			89 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'12' => { # class of read f_1
			90 => undef,
			91 => undef,
			92 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'13' => { # class of read g
			93 => undef,
			94 => undef,
			95 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'14' => { # class of read g_1
			93 => undef,
			94 => undef,
			95 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'15' => { # class of read h
			93 => undef,
			94 => undef,
			95 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		},
		'16' => { # class of read h_1
			93 => undef,
			94 => undef,
			95 => undef,
			96 => undef,
			97 => undef,
			98 => undef,
			99 => undef,
			100 => undef,
			101 => undef,
			102 => undef
		}
	};
	my $idChange = 1;
	my $isNew = 0;
	my $maxRows = 2;
	my $err = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no foreign keys + no id_change + no indication,
	# if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no foreign keys (+ no id_change + no indication, if new data
	# + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no foreign keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no id_change (+ no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, $keysR)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no indication, if new data (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, $keysR, $idChange)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows => optional argument
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		my @tmps = ();
		foreach my $idClass (keys(%{$keysR})) {
			foreach my $idTax (keys(%{$keysR->{$idClass}})) {
				push(@tmps, [$idClass, $idTax, $idChange])
			}
		}
		my @expecs = sort{($a->[0] <=> $b->[0]) or ($a->[1] <=> $b->[1])} @tmps;
		
		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'd_a', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, 'p_a', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'c_a', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'sc_a', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'o_a', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'so_a', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'f_a', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'g_a', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 's_a', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'str_a', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'd_a_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'p_a_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'c_a_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'sc_a_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'o_a_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'so_a_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'f_a_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'g_a_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 's_a_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'str_a_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'd_b', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (22, 'p_b', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (23, 'c_b', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (24, 'sc_b', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (25, 'o_b', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (26, 'so_b', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (27, 'f_b', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (28, 'g_b', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (29, 's_b', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (30, 'str_b', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (31, 'd_b_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (32, 'p_b_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (33, 'c_b_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (34, 'sc_b_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (35, 'o_b_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (36, 'so_b_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (37, 'f_b_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (38, 'g_b_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (39, 's_b_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (40, 'str_b_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (41, 'd_c', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (42, 'p_c', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (43, 'c_c', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (44, 'sc_c', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (45, 'o_c', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (46, 'so_c', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (47, 'f_c', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (48, 'g_c', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (49, 's_c', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (50, 'str_c', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (51, 'd_c_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (52, 'p_c_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (53, 'c_c_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (54, 'sc_c_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (55, 'o_c_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (56, 'so_c_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (57, 'f_c_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (58, 'g_c_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (59, 's_c_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (60, 'str_c_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (61, 'd_d', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (62, 'p_d', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (63, 'c_d', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (64, 'sc_d', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (65, 'o_d', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (66, 'so_d', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (67, 'f_d', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (68, 'g_d', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (69, 's_d', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (70, 'str_d', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (71, 'd_d_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (72, 'p_d_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (73, 'c_d_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (74, 'sc_d_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (75, 'o_d_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (76, 'so_d_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (77, 'f_d_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (78, 'g_d_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (79, 's_d_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (80, 'str_d_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (81, 'd_e', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (82, 'p_e', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (83, 'c_e', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (84, 'd_e_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (85, 'p_e_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (86, 'c_e_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (87, 'd_f', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (88, 'p_f', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (89, 'c_f', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (90, NULL, 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (91, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (92, NULL, 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (93, 'UNMATCHED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (94, 'UNMATCHED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (95, 'UNMATCHED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (96, 'UNMATCHED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (97, 'UNMATCHED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (98, 'UNMATCHED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (99, 'UNMATCHED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (100, 'UNMATCHED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (101, 'UNMATCHED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (102, 'UNMATCHED', 'strain', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (5, 5, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (7, 7, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (8, 8, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (9, 9, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (10, 10, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (11, 11, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (12, 12, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (13, 13, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (14, 14, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (15, 15, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (16, 16, 'MetaG', 'RDP', $idChange)");
		
		$isNew = MetagDB::Sga::insertTaxclass($dbh, $keysR, $idChange, $isNew);
		
		# Get data from the database
		my $resR = $dbh->selectall_arrayref("SELECT id_classification, id_taxonomy, id_change FROM taxclass ORDER BY id_classification, id_taxonomy ASC");
		is ($resR, \@expecs, 'Testing no maxRows - data');
		is ($isNew, 1, 'Testing no maxRows - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing no maxRows');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass("", $keysR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty foreign keys
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, "", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty foreign keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test foreign keys not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, "abc", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No keys or not a reference/, 'Testing foreign keys not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test foreign keys empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, {}, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No keys or not a reference/, 'Testing foreign keys empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty id_change
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, $keysR, "", $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty indication, if new data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, $keysR, $idChange, "", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, $keysR, $idChange, "abc", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing indication, if new data not a number');
	};


	#------------------------------------------------------------------------------#
	# Test indication, if new data invalid number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, $keysR, $idChange, 2, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing indication, if new data invalid number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, $keysR, $idChange, $isNew, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing empty maxRows');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, $keysR, $idChange, $isNew, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number');
	};


	#------------------------------------------------------------------------------#
	# Test maxRows is zero
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertTaxclass($dbh, $keysR, $idChange, $isNew, 0)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero');
	};
	

	#------------------------------------------------------------------------------#
	# Test invalid foreign keys hash: No id_taxonomy
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $keysModR = dclone($keysR);
		# Delete all id_taxonomies for all id_classifications
		foreach my $idClassification (keys(%{$keysModR})) {
			$keysModR->{$idClassification} = {}
		}
		MetagDB::Sga::insertTaxclass($dbh, $keysModR, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No id_taxonomy/, 'Testing no id_taxonomy in foreign keys');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid new insert (function does not return foreign keys)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		my @tmps = ();
		foreach my $idClass (keys(%{$keysR})) {
			foreach my $idTax (keys(%{$keysR->{$idClass}})) {
				push(@tmps, [$idClass, $idTax, $idChange])
			}
		}
		my @expecs = sort{($a->[0] <=> $b->[0]) or ($a->[1] <=> $b->[1])} @tmps;
		
		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'd_a', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, 'p_a', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'c_a', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'sc_a', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'o_a', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'so_a', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'f_a', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'g_a', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 's_a', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'str_a', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'd_a_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'p_a_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'c_a_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'sc_a_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'o_a_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'so_a_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'f_a_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'g_a_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 's_a_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'str_a_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'd_b', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (22, 'p_b', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (23, 'c_b', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (24, 'sc_b', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (25, 'o_b', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (26, 'so_b', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (27, 'f_b', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (28, 'g_b', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (29, 's_b', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (30, 'str_b', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (31, 'd_b_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (32, 'p_b_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (33, 'c_b_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (34, 'sc_b_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (35, 'o_b_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (36, 'so_b_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (37, 'f_b_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (38, 'g_b_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (39, 's_b_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (40, 'str_b_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (41, 'd_c', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (42, 'p_c', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (43, 'c_c', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (44, 'sc_c', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (45, 'o_c', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (46, 'so_c', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (47, 'f_c', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (48, 'g_c', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (49, 's_c', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (50, 'str_c', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (51, 'd_c_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (52, 'p_c_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (53, 'c_c_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (54, 'sc_c_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (55, 'o_c_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (56, 'so_c_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (57, 'f_c_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (58, 'g_c_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (59, 's_c_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (60, 'str_c_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (61, 'd_d', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (62, 'p_d', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (63, 'c_d', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (64, 'sc_d', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (65, 'o_d', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (66, 'so_d', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (67, 'f_d', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (68, 'g_d', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (69, 's_d', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (70, 'str_d', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (71, 'd_d_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (72, 'p_d_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (73, 'c_d_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (74, 'sc_d_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (75, 'o_d_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (76, 'so_d_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (77, 'f_d_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (78, 'g_d_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (79, 's_d_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (80, 'str_d_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (81, 'd_e', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (82, 'p_e', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (83, 'c_e', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (84, 'd_e_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (85, 'p_e_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (86, 'c_e_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (87, 'd_f', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (88, 'p_f', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (89, 'c_f', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (90, NULL, 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (91, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (92, NULL, 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (93, 'UNMATCHED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (94, 'UNMATCHED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (95, 'UNMATCHED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (96, 'UNMATCHED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (97, 'UNMATCHED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (98, 'UNMATCHED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (99, 'UNMATCHED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (100, 'UNMATCHED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (101, 'UNMATCHED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (102, 'UNMATCHED', 'strain', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (5, 5, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (7, 7, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (8, 8, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (9, 9, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (10, 10, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (11, 11, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (12, 12, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (13, 13, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (14, 14, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (15, 15, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (16, 16, 'MetaG', 'RDP', $idChange)");
		
		$isNew = MetagDB::Sga::insertTaxclass($dbh, $keysR, $idChange, $isNew, $maxRows);
		
		# Get data from the database
		my $resR = $dbh->selectall_arrayref("SELECT id_classification, id_taxonomy, id_change FROM taxclass ORDER BY id_classification, id_taxonomy ASC");
		is ($resR, \@expecs, 'Testing valid insert - data');
		is ($isNew, 1, 'Testing valid insert - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing valid insert');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid old insert (function does not return foreign keys)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		my $idChangeMod = $idChange + 1;
		
		my @tmps = ();
		foreach my $idClass (keys(%{$keysR})) {
			foreach my $idTax (keys(%{$keysR->{$idClass}})) {
				push(@tmps, [$idClass, $idTax, $idChange])
			}
		}
		my @expecs = sort{($a->[0] <=> $b->[0]) or ($a->[1] <=> $b->[1])} @tmps;
		
		# Perform the necessary inserts
		$dbh->do ("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', 1234, 12345678)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'p1', '00001', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'p2', '00002', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-01', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1900-01-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-02', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 2, '1900-02-02', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-02-03', 'foobar', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-02-03', 'foobar', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(1, 1, 'r1', 'b1', 'A', '!', 'f1', 'a', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(2, 1, 'r1', 'b1', 'A', '!', 'f1', 'a_1', 'm1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(3, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(4, 2, 'r2', 'b2', 'AA', '!!', 'f2', 'b_1', 'm2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(5, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(6, 3, 'r3', 'b3', 'AAA', '!!!', 'f3', 'c_1', 'm3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(7, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(8, 4, 'r4', 'b4', 'AAAA', '!!!!', 'f4', 'd_1', 'm4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(9, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(10, 5, 'r5', 'b5', 'AAAAA', '!!!!!', 'f5', 'e_1', 'm5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(11, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(12, 6, 'r6', 'b6', 'AAAAAA', '!!!!!!', 'f6', 'f_1', 'm6', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(13, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(14, 7, 'r7', 'b7', 'AAAAAAA', '!!!!!!!', 'f7', 'g_1', 'm7', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(15, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h', 'm8', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, runid, barcode, nucs, quality, flowcellid, readid, callermodel, id_change) VALUES " .
			"(16, 8, 'r8', 'b8', 'AAAAAAAA', '!!!!!!!!', 'f8', 'h_1', 'm8', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'd_a', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, 'p_a', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'c_a', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'sc_a', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'o_a', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'so_a', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'f_a', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'g_a', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 's_a', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'str_a', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'd_a_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'p_a_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'c_a_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'sc_a_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'o_a_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'so_a_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'f_a_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'g_a_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 's_a_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'str_a_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'd_b', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (22, 'p_b', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (23, 'c_b', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (24, 'sc_b', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (25, 'o_b', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (26, 'so_b', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (27, 'f_b', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (28, 'g_b', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (29, 's_b', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (30, 'str_b', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (31, 'd_b_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (32, 'p_b_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (33, 'c_b_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (34, 'sc_b_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (35, 'o_b_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (36, 'so_b_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (37, 'f_b_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (38, 'g_b_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (39, 's_b_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (40, 'str_b_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (41, 'd_c', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (42, 'p_c', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (43, 'c_c', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (44, 'sc_c', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (45, 'o_c', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (46, 'so_c', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (47, 'f_c', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (48, 'g_c', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (49, 's_c', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (50, 'str_c', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (51, 'd_c_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (52, 'p_c_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (53, 'c_c_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (54, 'sc_c_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (55, 'o_c_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (56, 'so_c_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (57, 'f_c_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (58, 'g_c_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (59, 's_c_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (60, 'str_c_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (61, 'd_d', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (62, 'p_d', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (63, 'c_d', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (64, 'sc_d', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (65, 'o_d', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (66, 'so_d', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (67, 'f_d', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (68, 'g_d', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (69, 's_d', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (70, 'str_d', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (71, 'd_d_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (72, 'p_d_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (73, 'c_d_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (74, 'sc_d_1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (75, 'o_d_1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (76, 'so_d_1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (77, 'f_d_1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (78, 'g_d_1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (79, 's_d_1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (80, 'str_d_1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (81, 'd_e', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (82, 'p_e', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (83, 'c_e', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (84, 'd_e_1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (85, 'p_e_1', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (86, 'c_e_1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (87, 'd_f', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (88, 'p_f', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (89, 'c_f', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (90, NULL, 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (91, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (92, NULL, 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (93, 'UNMATCHED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (94, 'UNMATCHED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (95, 'UNMATCHED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (96, 'UNMATCHED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (97, 'UNMATCHED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (98, 'UNMATCHED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (99, 'UNMATCHED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (100, 'UNMATCHED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (101, 'UNMATCHED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (102, 'UNMATCHED', 'strain', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (5, 5, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (7, 7, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (8, 8, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (9, 9, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (10, 10, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (11, 11, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (12, 12, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (13, 13, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (14, 14, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (15, 15, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (16, 16, 'MetaG', 'RDP', $idChange)");
		
		$isNew = MetagDB::Sga::insertTaxclass($dbh, $keysR, $idChange, $isNew, $maxRows);
		
		# Reset isNew and insert the same data again
		$isNew = 0;
		$isNew = MetagDB::Sga::insertTaxclass($dbh, $keysR, $idChangeMod, $isNew, $maxRows);
		
		# Get data from the database
		my $resR = $dbh->selectall_arrayref("SELECT id_classification, id_taxonomy, id_change FROM taxclass ORDER BY id_classification, id_taxonomy ASC");
		is ($resR, \@expecs, 'Testing valid old insert - data');
		is ($isNew, 0, 'Testing valid old insert - any new data inserted?');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing valid old insert');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback
	};
	
	
	return $dbh;	
}


#
#--------------------------------------------------------------------------------------------------#
# Test the insertStandard function
#--------------------------------------------------------------------------------------------------#
#
sub test_insertStandard {
	my $dbh = $_[0] // "";
	
	my $idChange = 1;
	my $dataR = [
		['f', 0, 0.1, 0.2, 0.3],
		['f', 1, 1.1, 1.2, 1.3],
		['m', 0, 0.1, 0.2, 0.3],
		['m', 1, 1.1, 1.2, 1.3],
	];
	my $name = 'weight_for_age';
	my $isNew = 0;
	my $maxRows = 1;
	my $err = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no data + no name + no id_change + no indication,
	# if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no data (+ no name + no id_change + no indication, if new data
	# + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no name (+ no id_change + no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $dataR)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no name');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no id_change (+ no indication, if new data + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $dataR, $name)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no indication, if new data (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $dataR, $name, $idChange)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows (optional parameter)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	my $data_modR = dclone($dataR);
	my @expecs = ();
	foreach my $tmp (@{$data_modR}) {
		my @t = @{$tmp};
		splice(@t, 0, 0, $name);
		push(@t, $idChange);
		push(@expecs, \@t);
	}
	
	try {
		$dbh->do("INSERT INTO change (id, username, ip, ts) VALUES ($idChange, 'foobar', 1, 1)");
		$isNew = MetagDB::Sga::insertStandard($dbh, $dataR, $name, $idChange, $isNew);
		my $outR = $dbh->selectall_arrayref("SELECT name, sex, age, l, m, s, id_change FROM standard ORDER BY name, sex, age ASC");
		
		is ($outR, \@expecs, 'Testing no maxRows - data');
		is ($isNew, 1, 'Testing no maxRows - any new data?');
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing no maxRows');
		print "ERROR: " . $err;
	}
	finally {
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard("", $dataR, $name, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, "", $name, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test data empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, [], $name, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No data/, 'Testing data empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test data not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, "abc", $name, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No data/, 'Testing data not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty name
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $dataR, "", $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty name');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty id_change
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $dataR, $name, "", $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty id_change');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty indication, if new data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $dataR, $name, $idChange, "", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty indication, if new data');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication if new data not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $dataR, $name, $idChange, "abc", $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing indication, if new data not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication if new data invalid number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $dataR, $name, $idChange, 2, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing indication, if new data invalid number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $dataR, $name, $idChange, $isNew, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing empty maxRows');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $dataR, $name, $idChange, $isNew, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is zero
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $dataR, $name, $idChange, $isNew, 0)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test data with empty rows
	#------------------------------------------------------------------------------#
	$data_modR = [[], [], [], []];
	
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $data_modR, $name, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Empty row/, 'Testing data with empty rows');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test data with undefined value
	#------------------------------------------------------------------------------#
	$data_modR = dclone($dataR);
	$data_modR->[0]->[3] = undef;
	
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $data_modR, $name, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Undefined or empty value in row/, 'Testing data with undefined value');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test data with empty value
	#------------------------------------------------------------------------------#
	$data_modR = dclone($dataR);
	$data_modR->[0]->[3] = '';
	
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $data_modR, $name, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Undefined or empty value in row/, 'Testing data with empty value');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test data with value containing just blanks
	#------------------------------------------------------------------------------#
	$data_modR = dclone($dataR);
	$data_modR->[0]->[3] = '   ';
	
	try {
		$err = "";
		MetagDB::Sga::insertStandard($dbh, $data_modR, $name, $idChange, $isNew, $maxRows)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Undefined or empty value in row/, 'Testing data with value containing just blanks');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid insert
	#------------------------------------------------------------------------------#
	$isNew = 0;

	try {
		$dbh->do("INSERT INTO change (id, username, ip, ts) VALUES ($idChange, 'foobar', 1, 1)");
		$isNew = MetagDB::Sga::insertStandard($dbh, $dataR, $name, $idChange, $isNew, $maxRows);
		my $outR = $dbh->selectall_arrayref("SELECT name, sex, age, l, m, s, id_change FROM standard ORDER BY name, sex, age ASC");
		
		is ($outR, \@expecs, 'Testing valid insert - data');
		is ($isNew, 1, 'Testing valid insert - any new data?');
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing valid insert');
		print "ERROR: " . $err;
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test insert of valid old data
	#------------------------------------------------------------------------------#
	$isNew = 0;

	try {
		$dbh->do("INSERT INTO change (id, username, ip, ts) VALUES ($idChange, 'foobar', 1, 1)");
		$isNew = MetagDB::Sga::insertStandard($dbh, $dataR, $name, $idChange, $isNew, $maxRows);
		
		# Reset isNew and insert the same data again
		$isNew = 0;
		$isNew = MetagDB::Sga::insertStandard($dbh, $dataR, $name, $idChange, $isNew, $maxRows);
		
		my $outR = $dbh->selectall_arrayref("SELECT name, sex, age, l, m, s, id_change FROM standard ORDER BY name, sex, age ASC");
		is ($outR, \@expecs, 'Testing valid old insert - data');
		is ($isNew, 0, 'Testing valid old insert - any new data?');
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing valid old insert');
		print "ERROR: " . $err;
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test insert of duplicates
	#------------------------------------------------------------------------------#
	$isNew = 0;
	my @data_mods = @{dclone($dataR)};
	splice(@data_mods, 0, 0, ['f', '0', '0.1', '0.2', '0.3']);

	try {
		$dbh->do("INSERT INTO change (id, username, ip, ts) VALUES ($idChange, 'foobar', 1, 1)");
		$isNew = MetagDB::Sga::insertStandard($dbh, \@data_mods, $name, $idChange, $isNew, $maxRows);
		my $outR = $dbh->selectall_arrayref("SELECT name, sex, age, l, m, s, id_change FROM standard ORDER BY name, sex, age ASC");
		
		is ($outR, \@expecs, 'Testing insert of duplicates - data');
		is ($isNew, 1, 'Testing insert of duplicates - any new data?');
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing insert of duplicates');
		print "ERROR: " . $err;
	}
	finally {
		$dbh->rollback;
	};

	
	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the database function f_calczscore
#--------------------------------------------------------------------------------------------------#
#
sub test_f_calczscore {
	my $dbh = $_[0] // "";
	
	my $err = "";
	
	# First three sets are from the WHO manual (BMI for age):
	# https://www.who.int/publications/i/item/924154693X (page: 304).
	# The following 6 were randomly generated based on the expanded
	# WHO standards for weight-for-age (girls and boys) available
	# from: https://www.who.int/tools/child-growth-standards/standards/weight-for-age
	# All expected z-scores were calculated by hand according to
	# the formulas provided in the WHO manual, to avoid rounding errors.
	# The z-scores for the randomly generated patiens were also crosschecked
	# with results from the official R-package:
	# https://github.com/WorldHealthOrganization/anthro/tree/master/R
	#
	# Structure of each test set: l, m, s, value, final z-score
	my @data = (
		[-0.3067, 15.4013, 0.08115, 20.5, 3.40], # WHO: boy: age: 44 month; zscore: 3.404145
		[-0.4850, 15.8667, 0.07818, 12, -3.75], # WHO: boy: age: 28 month; zscore: -3.750762
		[-0.4488, 15.2759, 0.08380, 18.8, 2.37], # WHO: boy: age: 52 month; zscore: 2.365209
		[-0.3465, 17.499, 0.14519, 11, -3.41], # girl: age: 1702 days; zscore: -3.413221
		[-0.2696, 10.4168, 0.12314, 17, 3.84], # girl: age: 575 days; zscore: 3.842642
		[-0.3469, 17.5459, 0.14539, 18, 0.17], # girl: age: 1710 days; zscore: 0.174968
		[-0.0863, 15.0882, 0.12345, 10, -3.36], # boy: age: 1231 days; zscore: -3.357624
		[-0.0738, 14.5489, 0.1218, 17, 1.27], # boy: age: 1133 days; zscore: 1.270992
		[-0.07, 14.3886, 0.1213, 27, 5.56] # boy: age: 1104 days; zscore: 5.556196
	);
	my ($l, $m, $s, $value, $zscore) = @{$data[0]};
	
	
	#------------------------------------------------------------------------------#
	# Test no l (+ no m + no s + no value)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		# Supress error messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", "/dev/null";
			$dbh->selectall_arrayref("SELECT * from f_calczscore()");
		};
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*function f_calczscore.*does not exist", 'Testing no l');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no m (+ no s + no value)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		# Supress error messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", "/dev/null";
			$dbh->selectall_arrayref("SELECT * from f_calczscore($l)");
		};
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*function f_calczscore.*does not exist", 'Testing no m');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no s (+ no value)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		# Supress error messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", "/dev/null";
			$dbh->selectall_arrayref("SELECT * from f_calczscore($l, $m)");
		};
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*function f_calczscore.*does not exist", 'Testing no s');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no value
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		# Supress error messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", "/dev/null";
			$dbh->selectall_arrayref("SELECT * from f_calczscore($l, $m, $s)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*function f_calczscore.*does not exist", 'Testing no value');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test l is NULL
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $outR = $dbh->selectall_arrayref("SELECT * from f_calczscore(NULL, $m, $s, $value)");
		is ($outR, [[undef]], 'Testing l is NULL');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing l is NULL');
		print "ERROR: $err", "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test m is NULL
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $outR = $dbh->selectall_arrayref("SELECT * from f_calczscore($l, NULL, $s, $value)");
		is ($outR, [[undef]], 'Testing m is NULL');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing m is NULL');
		print "ERROR: $err", "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test s is NULL
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $outR = $dbh->selectall_arrayref("SELECT * from f_calczscore($l, $m, NULL, $value)");
		is ($outR, [[undef]], 'Testing s is NULL');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing s is NULL');
		print "ERROR: $err", "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test value is NULL
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $outR = $dbh->selectall_arrayref("SELECT * from f_calczscore($l, $m, $s, NULL)");
		is ($outR, [[undef]], 'Testing value is NULL');
	}
	catch {
		$err = $_;
		
		ok (1==2, 'Testing value is NULL');
		print "ERROR: $err", "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test several sets with valid input
	#------------------------------------------------------------------------------#
	for (my $i = 0; $i <= $#data; $i++) {
		try {
			$err = "";
			
			($l, $m, $s, $value, $zscore) = @{$data[$i]};
			my $outR = $dbh->selectall_arrayref("SELECT * from f_calczscore($l, $m, $s, $value)");
			is ($outR, [[$zscore]], "Testing set ->" . ($i + 1) . "/" . scalar(@data) . "<- with valid input");
		}
		catch {
			$err = $_;
			
			ok (1==2, "Testing set ->" . ($i + 1) . "/" . scalar(@data) . "<- with valid input");
			print "ERROR: $err", "\n";
		}
		finally {
			$dbh->rollback;
		};
	}
	
	
	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the database function f_calcseqerror
#--------------------------------------------------------------------------------------------------#
#
sub test_f_calcseqerror {
	my $dbh = $_[0];
	my $err = "";
	# Contains all valid characters for Sanger in random order
	my %quals = (
		q{gCJNmZstRiT+Pyzn>-,`HQvI*(jF&c[Oape_xM\{qu/whB<;]YG\60r#)8$%"KoV7Ad2\}|:EUW'=kLX!.9?@534~^S1Dlbf} => 0.05
	);
	
	
	#------------------------------------------------------------------------------#
	# Test no quality string
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		# Supress error messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", "/dev/null";
			$dbh->selectall_arrayref("SELECT * from f_calcseqerror()");
		};
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*function f_calcseqerror.*does not exist", 'Testing no quality string');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty quality string
	#------------------------------------------------------------------------------#
	my $resR = [];
	
	try {
		$err = "";
		$resR = $dbh->selectall_arrayref("SELECT * from f_calcseqerror(?)", {}, (""));
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing empty quality string');
	}
	finally {
		is ($resR, [[undef]], 'Testing empty quality string');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test quality string is NULL 
	#------------------------------------------------------------------------------#	
	try {
		$err = "";
		
		$resR = [];
		$resR = $dbh->selectall_arrayref("SELECT * from f_calcseqerror(?)", {}, (undef));
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing quality string is NULL');
	}
	finally {
		is ($resR, [[undef]], 'Testing quality string is NULL');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test quality string with invalid character (ASCII value too low)
	#------------------------------------------------------------------------------#	
	try {
		$err = "";
		
		# Supress error messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", "/dev/null";
			$dbh->selectall_arrayref("SELECT * from f_calcseqerror('" . chr(32) . "')");
		};
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Invalid quality encoding", 'Testing invalid character in quality [1/2]');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test quality string with invalid character (ASCII value too high)
	#------------------------------------------------------------------------------#	
	try {
		$err = "";
		
		# Supress error messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", "/dev/null";
			$dbh->selectall_arrayref("SELECT * from f_calcseqerror('" . chr(127) . "')");
		};
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Invalid quality encoding", 'Testing invalid character in quality [2/2]');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid quality string
	#------------------------------------------------------------------------------#	
	my $qual = (keys(%quals))[0];
	try {
		$err = "";
		
		$resR = [];
		$resR = $dbh->selectall_arrayref("SELECT * from round(f_calcseqerror(?), 2)", {}, ($qual));
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing valid quality string');
	}
	finally {
		is ($resR, [[$quals{$qual}]], 'Testing valid quality string');
		$dbh->rollback;
	};
	
	
	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the getLineages function
#--------------------------------------------------------------------------------------------------#
#
sub test_getLineages {
	my $dbh = $_[0] // "";
	
	my $idChange = 1;
	my $idsR = [1, 2, 3];
	my $metasR = {};
	my $blacklistR = [];
	my $keepCtrl = 1;
	my $maxRows = 10;
	my $err = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no ids reference + no blacklist + no keepCtrl
	# + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages();
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "Too few", 'Testing no database handle');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no ids reference (+ no blacklist + no keepCtrl + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages($dbh);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "Too few", 'Testing no ids reference');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no blacklist (optional parameter; + no keepCtrl + no maxRows)
	#------------------------------------------------------------------------------#
	my $expecResR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"D1;;C1;O1;F1;G1;S1"	=> 3
			}
		}
	};
	my $expecMetasR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"program"	=> "MetaG",
				"database" => "RDP",
				"control" => "no",
				"timepoint" => "meconium"
			}
		}
	};
	my $resR = "";
	
	try {
		$err = "";
		$resR = "";
		$metasR = {};
		
		# 1 patient with 3 samples:
		#	*)	control: f; 4 reads with classifications. Three of the reads have
		#		the same classification from phylum to species. Strains are not identical,
		#		but not considered.
		#	*)	control: t; 1 read with no classifications.
		#	*)	control: t; 1 read with classifications
		# Third sample has 1 read with classifications, but is a control sample.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1901-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (1, 1, 'foo1', 'bar1', 'foobar1', 'barfoo1', 'barbar1', 'foofoo1', 'barfoobar1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (2, 1, 'foo2', 'bar2', 'foobar2', 'barfoo2', 'barbar2', 'foofoo2', 'barfoobar2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (3, 1, 'foo3', 'bar3', 'foobar3', 'barfoo3', 'barbar3', 'foofoo3', 'barfoobar3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (4, 1, 'foo4', 'bar4', 'foobar4', 'barfoo4', 'barbar4', 'foofoo4', 'barfoobar4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (5, 2, 'foo5', 'bar5', 'foobar5', 'barfoo5', 'barbar5', 'foofoo5', 'barfoobar5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (6, 3, 'foo6', 'bar6', 'foobar6', 'barfoo6', 'barbar6', 'foofoo6', 'barfoobar6', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'D1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'C1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'SC1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'O1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'SO1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'F1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'G1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 'S1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'ST1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'NULL', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'FILTERED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'FILTERED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'FILTERED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'FILTERED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'FILTERED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'FILTERED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'FILTERED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 'FILTERED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'FILTERED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'FILTERED', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (11, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (12, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (13, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (14, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (15, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (16, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (17, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (18, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (19, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (20, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (21, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 6, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("REFRESH MATERIALIZED VIEW v_lineages");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			($resR, $metasR) = MetagDB::Sga::getLineages($dbh, $idsR);
		};
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing no blacklist');
	}
	finally {
		is ($resR, $expecResR, 'Testing no blacklist - results');
		is ($metasR, $expecMetasR, 'Testing no blacklist - metadata');
		ok ($err =~ m/WARNING:.*->2<- sample IDs were removed/, 'Testing no blacklist - warning message');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no keepCtrl (optional parameter; + no maxRows)
	#------------------------------------------------------------------------------#
	$resR = "";
	$expecResR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"D1;;C1;O1;F1;G1;S1"	=> 3,
				"FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED"	=> 1
			}
		}
	};
	
	try {
		$err = "";
		$resR = "";
		$metasR = {};
		
		# 1 patient with 3 samples:
		#	*)	control: f; 4 reads with classifications. Three of the reads have
		#		the same classification from phylum to species. Strains are not identical,
		#		but not considered.
		#	*)	control: t; 1 read with no classifications.
		#	*)	control: t; 1 read with classifications
		# Third sample has 1 read with classifications, but is a control sample.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1901-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (1, 1, 'foo1', 'bar1', 'foobar1', 'barfoo1', 'barbar1', 'foofoo1', 'barfoobar1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (2, 1, 'foo2', 'bar2', 'foobar2', 'barfoo2', 'barbar2', 'foofoo2', 'barfoobar2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (3, 1, 'foo3', 'bar3', 'foobar3', 'barfoo3', 'barbar3', 'foofoo3', 'barfoobar3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (4, 1, 'foo4', 'bar4', 'foobar4', 'barfoo4', 'barbar4', 'foofoo4', 'barfoobar4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (5, 2, 'foo5', 'bar5', 'foobar5', 'barfoo5', 'barbar5', 'foofoo5', 'barfoobar5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (6, 3, 'foo6', 'bar6', 'foobar6', 'barfoo6', 'barbar6', 'foofoo6', 'barfoobar6', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'D1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'C1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'SC1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'O1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'SO1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'F1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'G1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 'S1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'ST1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'NULL', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'FILTERED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'FILTERED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'FILTERED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'FILTERED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'FILTERED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'FILTERED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'FILTERED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 'FILTERED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'FILTERED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'FILTERED', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (11, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (12, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (13, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (14, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (15, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (16, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (17, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (18, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (19, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (20, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (21, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 6, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("REFRESH MATERIALIZED VIEW v_lineages");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			($resR, $metasR) = MetagDB::Sga::getLineages($dbh, $idsR, $blacklistR);
		};
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing no keepCtrl');
	}
	finally {
		is ($resR, $expecResR, 'Testing no keepCtrl - results');
		is ($metasR, $expecMetasR, 'Testing no keepCtrl - metadata');
		ok ($err =~ m/WARNING:.*->2<- sample IDs were removed/, 'Testing no keepCtrl - warning message');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows (optional parameter)
	#------------------------------------------------------------------------------#
	$resR = "";
	$expecResR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"D1;;C1;O1;F1;G1;S1"	=> 3,
				"FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED"	=> 1
			}
		},
		3 => {		
			"F1_1y_t_MetaG_RDP" => {
				"D1;;C1;O1;F1;G1;S1"	=> 1,
			}
		}
	};
	$expecMetasR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"program"	=> "MetaG",
				"database" => "RDP",
				"control" => "no",
				"timepoint" => "meconium"
			}
		},
		3 => {
			"F1_1y_t_MetaG_RDP" => {
				"program"	=> "MetaG",
				"database" => "RDP",
				"control" => "yes",
				"timepoint" => "1y"
			}
		}
	};
	
	try {
		$err = "";
		$resR = "";
		$metasR = {};
		
		# 1 patient with 3 samples:
		#	*)	control: f; 4 reads with classifications. Three of the reads have
		#		the same classification from phylum to species. Strains are not identical,
		#		but not considered.
		#	*)	control: t; 1 read with no classifications.
		#	*)	control: t; 1 read with classifications
		# Third sample has 1 read with classifications, but is a control sample.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1901-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (1, 1, 'foo1', 'bar1', 'foobar1', 'barfoo1', 'barbar1', 'foofoo1', 'barfoobar1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (2, 1, 'foo2', 'bar2', 'foobar2', 'barfoo2', 'barbar2', 'foofoo2', 'barfoobar2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (3, 1, 'foo3', 'bar3', 'foobar3', 'barfoo3', 'barbar3', 'foofoo3', 'barfoobar3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (4, 1, 'foo4', 'bar4', 'foobar4', 'barfoo4', 'barbar4', 'foofoo4', 'barfoobar4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (5, 2, 'foo5', 'bar5', 'foobar5', 'barfoo5', 'barbar5', 'foofoo5', 'barfoobar5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (6, 3, 'foo6', 'bar6', 'foobar6', 'barfoo6', 'barbar6', 'foofoo6', 'barfoobar6', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'D1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'C1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'SC1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'O1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'SO1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'F1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'G1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 'S1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'ST1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'NULL', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'FILTERED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'FILTERED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'FILTERED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'FILTERED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'FILTERED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'FILTERED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'FILTERED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 'FILTERED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'FILTERED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'FILTERED', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (11, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (12, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (13, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (14, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (15, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (16, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (17, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (18, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (19, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (20, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (21, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 6, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("REFRESH MATERIALIZED VIEW v_lineages");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			($resR, $metasR) = MetagDB::Sga::getLineages($dbh, $idsR, $blacklistR, $keepCtrl);
		};
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing no maxRows');
	}
	finally {
		is ($resR, $expecResR, 'Testing no maxRows - results');
		is ($metasR, $expecMetasR, 'Testing no maxRows - metadata');
		ok ($err =~ m/WARNING:.*->1<- sample IDs were removed/, 'Testing no maxRows - warning message');
		$dbh->rollback;
	};


	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages("", $idsR, $blacklistR, $keepCtrl, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Not enough", 'Testing empty database handle');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty ids reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages($dbh, "", $blacklistR, $keepCtrl, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Not enough", 'Testing empty ids reference');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test ids empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages($dbh, [], $blacklistR, $keepCtrl, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*No ids or not a reference", 'Testing ids empty reference');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test ids not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages($dbh, "abc", $blacklistR, $keepCtrl, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*No ids or not a reference", 'Testing ids not a reference');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty blacklist
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages($dbh, $idsR, "", $keepCtrl, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Not enough", 'Testing empty blacklist');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test blacklist empty reference
	#------------------------------------------------------------------------------#
	$resR = "";
	$expecResR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"D1;;C1;O1;F1;G1;S1"	=> 3,
				"FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED"	=> 1
			}
		},
		3 => {		
			"F1_1y_t_MetaG_RDP" => {
				"D1;;C1;O1;F1;G1;S1"	=> 1,
			}
		}
	};
	$expecMetasR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"program"	=> "MetaG",
				"database" => "RDP",
				"control" => "no",
				"timepoint" => "meconium"
			}
		},
		3 => {
			"F1_1y_t_MetaG_RDP" => {
				"program"	=> "MetaG",
				"database" => "RDP",
				"control" => "yes",
				"timepoint" => "1y"
			}
		}
	};
	
	try {
		$err = "";
		$resR = "";
		$metasR = {};
		
		# 1 patient with 3 samples:
		#	*)	control: f; 4 reads with classifications. Three of the reads have
		#		the same classification from phylum to species. Strains are not identical,
		#		but not considered.
		#	*)	control: t; 1 read with no classifications.
		#	*)	control: t; 1 read with classifications
		# Third sample has 1 read with classifications, but is a control sample.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1901-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (1, 1, 'foo1', 'bar1', 'foobar1', 'barfoo1', 'barbar1', 'foofoo1', 'barfoobar1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (2, 1, 'foo2', 'bar2', 'foobar2', 'barfoo2', 'barbar2', 'foofoo2', 'barfoobar2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (3, 1, 'foo3', 'bar3', 'foobar3', 'barfoo3', 'barbar3', 'foofoo3', 'barfoobar3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (4, 1, 'foo4', 'bar4', 'foobar4', 'barfoo4', 'barbar4', 'foofoo4', 'barfoobar4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (5, 2, 'foo5', 'bar5', 'foobar5', 'barfoo5', 'barbar5', 'foofoo5', 'barfoobar5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (6, 3, 'foo6', 'bar6', 'foobar6', 'barfoo6', 'barbar6', 'foofoo6', 'barfoobar6', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'D1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'C1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'SC1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'O1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'SO1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'F1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'G1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 'S1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'ST1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'NULL', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'FILTERED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'FILTERED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'FILTERED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'FILTERED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'FILTERED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'FILTERED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'FILTERED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 'FILTERED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'FILTERED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'FILTERED', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (11, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (12, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (13, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (14, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (15, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (16, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (17, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (18, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (19, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (20, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (21, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 6, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("REFRESH MATERIALIZED VIEW v_lineages");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			($resR, $metasR) = MetagDB::Sga::getLineages($dbh, $idsR, [], $keepCtrl, $maxRows);
		};
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing blacklist empty reference');
	}
	finally {
		is ($resR, $expecResR, 'Testing blacklist empty reference - results');
		is ($metasR, $expecMetasR, 'Testing blacklist empty reference - metadata');
		ok ($err =~ m/WARNING:.*->1<- sample IDs were removed/, 'Testing blacklist empty reference - warning message');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test blacklist not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages($dbh, $idsR, "abc", $keepCtrl, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Blacklist not a reference", 'Testing blacklist not a reference');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test blacklist taxon does not match
	#------------------------------------------------------------------------------#
	$resR = "";
	$expecResR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"D1;;C1;O1;F1;G1;S1"	=> 3,
				"FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED"	=> 1
			}
		},
		3 => {		
			"F1_1y_t_MetaG_RDP" => {
				"D1;;C1;O1;F1;G1;S1"	=> 1,
			}
		}
	};
	$expecMetasR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"program"	=> "MetaG",
				"database" => "RDP",
				"control" => "no",
				"timepoint" => "meconium"
			}
		},
		3 => {
			"F1_1y_t_MetaG_RDP" => {
				"program"	=> "MetaG",
				"database" => "RDP",
				"control" => "yes",
				"timepoint" => "1y"
			}
		}
	};
	
	try {
		$err = "";
		$resR = "";
		$metasR = {};
		
		# 1 patient with 3 samples:
		#	*)	control: f; 4 reads with classifications. Three of the reads have
		#		the same classification from phylum to species. Strains are not identical,
		#		but not considered.
		#	*)	control: t; 1 read with no classifications.
		#	*)	control: t; 1 read with classifications
		# Third sample has 1 read with classifications, but is a control sample.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1901-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (1, 1, 'foo1', 'bar1', 'foobar1', 'barfoo1', 'barbar1', 'foofoo1', 'barfoobar1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (2, 1, 'foo2', 'bar2', 'foobar2', 'barfoo2', 'barbar2', 'foofoo2', 'barfoobar2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (3, 1, 'foo3', 'bar3', 'foobar3', 'barfoo3', 'barbar3', 'foofoo3', 'barfoobar3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (4, 1, 'foo4', 'bar4', 'foobar4', 'barfoo4', 'barbar4', 'foofoo4', 'barfoobar4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (5, 2, 'foo5', 'bar5', 'foobar5', 'barfoo5', 'barbar5', 'foofoo5', 'barfoobar5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (6, 3, 'foo6', 'bar6', 'foobar6', 'barfoo6', 'barbar6', 'foofoo6', 'barfoobar6', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'D1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'C1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'SC1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'O1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'SO1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'F1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'G1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 'S1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'ST1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'NULL', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'FILTERED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'FILTERED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'FILTERED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'FILTERED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'FILTERED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'FILTERED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'FILTERED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 'FILTERED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'FILTERED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'FILTERED', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (11, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (12, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (13, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (14, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (15, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (16, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (17, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (18, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (19, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (20, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (21, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 6, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("REFRESH MATERIALIZED VIEW v_lineages");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			($resR, $metasR) = MetagDB::Sga::getLineages($dbh, $idsR, ["C1"], $keepCtrl, $maxRows);
		};
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing blacklist taxon does not match');
	}
	finally {
		is ($resR, $expecResR, 'Testing blacklist taxon does not match - results');
		is ($metasR, $expecMetasR, 'Testing blacklist taxon does not match - metadata');
		ok ($err =~ m/WARNING:.*->1<- sample IDs were removed/, 'Testing blacklist taxon does not match - warning message');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test multiple matching taxa on blacklist
	# => No valid classifications remaining
	#------------------------------------------------------------------------------#
	$resR = "";
	$expecResR = {};
	$expecMetasR = {};
	
	try {
		$err = "";
		$resR = "";
		$metasR = {};
		
		# 1 patient with 3 samples:
		#	*)	control: f; 4 reads with classifications. Three of the reads have
		#		the same classification from phylum to species. Strains are not identical,
		#		but not considered.
		#	*)	control: t; 1 read with no classifications.
		#	*)	control: t; 1 read with classifications
		# Third sample has 1 read with classifications, but is a control sample.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1901-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (1, 1, 'foo1', 'bar1', 'foobar1', 'barfoo1', 'barbar1', 'foofoo1', 'barfoobar1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (2, 1, 'foo2', 'bar2', 'foobar2', 'barfoo2', 'barbar2', 'foofoo2', 'barfoobar2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (3, 1, 'foo3', 'bar3', 'foobar3', 'barfoo3', 'barbar3', 'foofoo3', 'barfoobar3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (4, 1, 'foo4', 'bar4', 'foobar4', 'barfoo4', 'barbar4', 'foofoo4', 'barfoobar4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (5, 2, 'foo5', 'bar5', 'foobar5', 'barfoo5', 'barbar5', 'foofoo5', 'barfoobar5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (6, 3, 'foo6', 'bar6', 'foobar6', 'barfoo6', 'barbar6', 'foofoo6', 'barfoobar6', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'D1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'C1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'SC1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'O1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'SO1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'F1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'G1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 'S1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'ST1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'NULL', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'FILTERED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'FILTERED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'FILTERED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'FILTERED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'FILTERED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'FILTERED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'FILTERED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 'FILTERED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'FILTERED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'FILTERED', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (11, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (12, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (13, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (14, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (15, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (16, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (17, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (18, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (19, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (20, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (21, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 6, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("REFRESH MATERIALIZED VIEW v_lineages");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			($resR, $metasR) = MetagDB::Sga::getLineages($dbh, $idsR, ["D1", "FILTERED"], $keepCtrl, $maxRows);
		};
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing multiple matching blacklist taxa');
	}
	finally {
		is ($resR, $expecResR, 'Testing multiple matching blacklist taxa - results');
		is ($metasR, $expecMetasR, 'Testing multiple matching blacklist taxa - metadata');
		ok ($err =~ m/WARNING:.*->3<- sample IDs were removed/, 'Testing multiple matching blacklist taxa - warning message');
		$dbh->rollback;
	};

	
	#------------------------------------------------------------------------------#
	# Test empty keepCtrl
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages($dbh, $idsR, $blacklistR, "", $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Invalid value for keepCtrl", 'Testing empty keepCtrl');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test keepCtrl not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages($dbh, $idsR, $blacklistR, "abc", $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Invalid value for keepCtrl", 'Testing keepCtrl not a number');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test keepCtrl is zero (one already tested before)
	#------------------------------------------------------------------------------#
	$resR = "";
	$expecResR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"D1;;C1;O1;F1;G1;S1"	=> 3,
				"FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED"	=> 1
			}
		}
	};
	$expecMetasR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"program"	=> "MetaG",
				"database" => "RDP",
				"control" => "no",
				"timepoint" => "meconium"
			}
		}
	};
	
	try {
		$err = "";
		$resR = "";
		$metasR = {};
		
		# 1 patient with 3 samples:
		#	*)	control: f; 4 reads with classifications. Three of the reads have
		#		the same classification from phylum to species. Strains are not identical,
		#		but not considered.
		#	*)	control: t; 1 read with no classifications.
		#	*)	control: t; 1 read with classifications
		# Third sample has 1 read with classifications, but is a control sample.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1901-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (1, 1, 'foo1', 'bar1', 'foobar1', 'barfoo1', 'barbar1', 'foofoo1', 'barfoobar1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (2, 1, 'foo2', 'bar2', 'foobar2', 'barfoo2', 'barbar2', 'foofoo2', 'barfoobar2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (3, 1, 'foo3', 'bar3', 'foobar3', 'barfoo3', 'barbar3', 'foofoo3', 'barfoobar3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (4, 1, 'foo4', 'bar4', 'foobar4', 'barfoo4', 'barbar4', 'foofoo4', 'barfoobar4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (5, 2, 'foo5', 'bar5', 'foobar5', 'barfoo5', 'barbar5', 'foofoo5', 'barfoobar5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (6, 3, 'foo6', 'bar6', 'foobar6', 'barfoo6', 'barbar6', 'foofoo6', 'barfoobar6', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'D1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'C1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'SC1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'O1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'SO1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'F1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'G1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 'S1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'ST1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'NULL', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'FILTERED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'FILTERED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'FILTERED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'FILTERED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'FILTERED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'FILTERED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'FILTERED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 'FILTERED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'FILTERED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'FILTERED', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (11, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (12, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (13, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (14, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (15, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (16, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (17, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (18, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (19, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (20, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (21, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 6, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("REFRESH MATERIALIZED VIEW v_lineages");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			($resR, $metasR) = MetagDB::Sga::getLineages($dbh, $idsR, $blacklistR, 0, $maxRows);
		};
	}
	catch {
		print $err;
		ok (1==2, 'Testing keepCtrl is zero');
	}
	finally {
		is ($resR, $expecResR, 'Testing keepCtrl is zero - results');
		is ($metasR, $expecMetasR, 'Testing keepCtrl is zero - metadata');
		ok ($err =~ m/WARNING:.*->2<- sample IDs were removed/, 'Testing keepCtrl is zero - warning message');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages($dbh, $idsR, $blacklistR, $keepCtrl, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Invalid value for maxRows", 'Testing empty maxRows');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages($dbh, $idsR, $blacklistR, $keepCtrl, "abc");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is zero
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getLineages($dbh, $idsR, $blacklistR, $keepCtrl, 0);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid data
	#------------------------------------------------------------------------------#
	$resR = "";
	$expecResR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"D1;;C1;O1;F1;G1;S1"	=> 3,
				"FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED"	=> 1
			}
		},
		3 => {		
			"F1_1y_t_MetaG_RDP" => {
				"D1;;C1;O1;F1;G1;S1"	=> 1,
			}
		}
	};
	$expecMetasR = {
		1 => {
			"F1_meconium_f_MetaG_RDP" => {
				"program"	=> "MetaG",
				"database" => "RDP",
				"control" => "no",
				"timepoint" => "meconium"
			}
		},
		3 => {
			"F1_1y_t_MetaG_RDP" => {
				"program"	=> "MetaG",
				"database" => "RDP",
				"control" => "yes",
				"timepoint" => "1y"
			}
		}
	};
	
	try {
		$err = "";
		$resR = "";
		$metasR = {};
		
		# 1 patient with 3 samples:
		#	*)	control: f; 4 reads with classifications. Three of the reads have
		#		the same classification from phylum to species. Strains are not identical,
		#		but not considered.
		#	*)	control: t; 1 read with no classifications.
		#	*)	control: t; 1 read with classifications
		# Third sample has 1 read with classifications, but is a control sample.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1901-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (1, 1, 'foo1', 'bar1', 'foobar1', 'barfoo1', 'barbar1', 'foofoo1', 'barfoobar1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (2, 1, 'foo2', 'bar2', 'foobar2', 'barfoo2', 'barbar2', 'foofoo2', 'barfoobar2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (3, 1, 'foo3', 'bar3', 'foobar3', 'barfoo3', 'barbar3', 'foofoo3', 'barfoobar3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (4, 1, 'foo4', 'bar4', 'foobar4', 'barfoo4', 'barbar4', 'foofoo4', 'barfoobar4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (5, 2, 'foo5', 'bar5', 'foobar5', 'barfoo5', 'barbar5', 'foofoo5', 'barfoobar5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (6, 3, 'foo6', 'bar6', 'foobar6', 'barfoo6', 'barbar6', 'foofoo6', 'barfoobar6', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'D1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'C1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'SC1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'O1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'SO1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'F1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'G1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 'S1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'ST1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'NULL', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'FILTERED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'FILTERED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'FILTERED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'FILTERED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'FILTERED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'FILTERED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'FILTERED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 'FILTERED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'FILTERED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'FILTERED', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (11, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (12, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (13, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (14, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (15, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (16, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (17, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (18, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (19, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (20, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (21, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 6, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("REFRESH MATERIALIZED VIEW v_lineages");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			($resR, $metasR) = MetagDB::Sga::getLineages($dbh, $idsR, $blacklistR, $keepCtrl, $maxRows);
		};
	}
	catch {
		print $err;
		ok (1==2, 'Testing valid data');
	}
	finally {
		is ($resR, $expecResR, 'Testing valid data - results');
		is ($metasR, $expecMetasR, 'Testing valid data - metadata');
		ok ($err =~ m/WARNING:.*->1<- sample IDs were removed/, 'Testing valid data - warning message');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Invalid value for isControl in hypothetical more relaxed schema (here: NULL
	# which leads to reading in the createdate as isControl)
	#------------------------------------------------------------------------------#	
	try {
		$resR = "";
		$err = "";
		$metasR = {};
		
		# Drop NOT NULL constraint on isControl column. Views that depend
		# on column have to be dropped first and then recreated.
		$dbh->do(
			'DO $$ ' .
				"DECLARE v_samples_def text; " .
				"DECLARE v_samples_exec text; " .
				"DECLARE v_lineages_def text; " .
				"DECLARE v_lineages_exec text; " .
				"DECLARE v_taxa_def text; " .
				"DECLARE v_taxa_exec text; " .
				"DECLARE v_measurements_def text; " .
				"DECLARE v_measurements_exec text; " .
				"DECLARE v_metadata_def text; " .
				"DECLARE v_metadata_exec text; " .
			"BEGIN " .
				"v_metadata_def = pg_get_viewdef('v_metadata'); " .
				"DROP MATERIALIZED VIEW v_metadata; " .
				"v_measurements_def = pg_get_viewdef('v_measurements'); " .
				"DROP MATERIALIZED VIEW v_measurements; " .
				"v_taxa_def = pg_get_viewdef('v_taxa'); " .
				"DROP MATERIALIZED VIEW v_taxa; " .
				"v_lineages_def = pg_get_viewdef('v_lineages'); " .
				"DROP MATERIALIZED VIEW v_lineages; " .
				"v_samples_def = pg_get_viewdef('v_samples'); " .
				"DROP MATERIALIZED VIEW v_samples; " .

				"ALTER TABLE sample DROP COLUMN iscontrol; " .
				"ALTER TABLE sample ADD COLUMN iscontrol boolean; " .
				
				"v_samples_exec = format('CREATE MATERIALIZED VIEW v_samples AS %s', v_samples_def); " .
				"EXECUTE v_samples_exec; " .
				"v_lineages_exec = format('CREATE MATERIALIZED VIEW v_lineages AS %s', v_lineages_def); " .
				"EXECUTE v_lineages_exec; " .
				"v_taxa_exec = format('CREATE MATERIALIZED VIEW v_taxa AS %s', v_taxa_def); " .
				"EXECUTE v_taxa_exec; " .
				"v_measurements_exec = format('CREATE MATERIALIZED VIEW v_measurements AS %s', v_measurements_def); " .
				"EXECUTE v_measurements_exec; " .
				"v_metadata_exec = format('CREATE MATERIALIZED VIEW v_metadata AS %s', v_metadata_def); " .
				"EXECUTE v_metadata_exec; " .
			'END $$'
		);
		
		# 1 patient with 3 samples:
		#	*)	control: f; 4 reads with classifications. Three of the reads have
		#		the same classification from phylum to species. Strains are not identical,
		#		but not considered.
		#	*)	control: t; 1 read with no classifications.
		#	*)	control: t; 1 read with classifications
		# Third sample has 1 read with classifications, but is a control sample.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', NULL, $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', NULL, $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1901-12-25', 'BARFOO', NULL, $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (1, 1, 'foo1', 'bar1', 'foobar1', 'barfoo1', 'barbar1', 'foofoo1', 'barfoobar1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (2, 1, 'foo2', 'bar2', 'foobar2', 'barfoo2', 'barbar2', 'foofoo2', 'barfoobar2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (3, 1, 'foo3', 'bar3', 'foobar3', 'barfoo3', 'barbar3', 'foofoo3', 'barfoobar3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (4, 1, 'foo4', 'bar4', 'foobar4', 'barfoo4', 'barbar4', 'foofoo4', 'barfoobar4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (5, 2, 'foo5', 'bar5', 'foobar5', 'barfoo5', 'barbar5', 'foofoo5', 'barfoobar5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (6, 3, 'foo6', 'bar6', 'foobar6', 'barfoo6', 'barbar6', 'foofoo6', 'barfoobar6', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'D1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'C1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'SC1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'O1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'SO1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'F1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'G1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 'S1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'ST1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'NULL', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'FILTERED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'FILTERED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'FILTERED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'FILTERED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'FILTERED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'FILTERED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'FILTERED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 'FILTERED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'FILTERED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'FILTERED', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (11, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (12, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (13, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (14, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (15, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (16, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (17, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (18, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (19, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (20, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (21, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 6, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("REFRESH MATERIALIZED VIEW v_lineages");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			MetagDB::Sga::getLineages($dbh, $idsR, $blacklistR, $keepCtrl, $maxRows);
		};
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR:.*Unknown value.*for isControl/, 'Invalid value for isControl');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test program and database name are NULL (hypothetical more relaxed schema)
	#------------------------------------------------------------------------------#
	$expecResR = {
		1 => {
			"F1_meconium_f__" => {
				"D1;;C1;O1;F1;G1;S1"	=> 3,
				"FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED;FILTERED"	=> 1
			}
		},
		3 => {		
			"F1_1y_t__" => {
				"D1;;C1;O1;F1;G1;S1"	=> 1,
			}
		}
	};
	$expecMetasR = {
		1 => {
			"F1_meconium_f__" => {
				"program"	=> "",
				"database" => "",
				"control" => "no",
				"timepoint" => "meconium"
			}
		},
		3 => {
			"F1_1y_t__" => {
				"program"	=> "",
				"database" => "",
				"control" => "yes",
				"timepoint" => "1y"
			}
		}
	};
	
	try {
		$resR = "";
		$err = "";
		$metasR = {};
		
		# Drop NOT NULL contstraints on program and database columns. Views
		# that depend on columns have to be dropped first and then recreated.
		$dbh->do(
			'DO $$ ' .
				"DECLARE v_lineages_def text; " .
				"DECLARE v_lineages_exec text; " .
				"DECLARE v_taxa_def text; " .
				"DECLARE v_taxa_exec text; " .
				"DECLARE v_metadata_def text; " .
				"DECLARE v_metadata_exec text; " .
			"BEGIN " .
				"v_metadata_def = pg_get_viewdef('v_metadata'); " .
				"DROP MATERIALIZED VIEW v_metadata; " .
				"v_taxa_def = pg_get_viewdef('v_taxa'); " .
				"DROP MATERIALIZED VIEW v_taxa; " .
				"v_lineages_def = pg_get_viewdef('v_lineages'); " .
				"DROP MATERIALIZED VIEW v_lineages; " .

				"ALTER TABLE classification DROP COLUMN program; " .
				"ALTER TABLE classification ADD COLUMN program varchar(24); " .
				"ALTER TABLE classification DROP COLUMN database; " .
				"ALTER TABLE classification ADD COLUMN database varchar(24); " .
				
				"v_lineages_exec = format('CREATE MATERIALIZED VIEW v_lineages AS %s', v_lineages_def); " .
				"EXECUTE v_lineages_exec; " .
				"v_taxa_exec = format('CREATE MATERIALIZED VIEW v_taxa AS %s', v_taxa_def); " .
				"EXECUTE v_taxa_exec; " .
				"v_metadata_exec = format('CREATE MATERIALIZED VIEW v_metadata AS %s', v_metadata_def); " .
				"EXECUTE v_metadata_exec; " .
			'END $$'
		);
		
		# 1 patient with 3 samples:
		#	*)	control: f; 4 reads with classifications. Three of the reads have
		#		the same classification from phylum to species. Strains are not identical,
		#		but not considered.
		#	*)	control: t; 1 read with no classifications.
		#	*)	control: t; 1 read with classifications
		# Third sample has 1 read with classifications, but is a control sample.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1901-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (1, 1, 'foo1', 'bar1', 'foobar1', 'barfoo1', 'barbar1', 'foofoo1', 'barfoobar1', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (2, 1, 'foo2', 'bar2', 'foobar2', 'barfoo2', 'barbar2', 'foofoo2', 'barfoobar2', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (3, 1, 'foo3', 'bar3', 'foobar3', 'barfoo3', 'barbar3', 'foofoo3', 'barfoobar3', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (4, 1, 'foo4', 'bar4', 'foobar4', 'barfoo4', 'barbar4', 'foofoo4', 'barfoobar4', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (5, 2, 'foo5', 'bar5', 'foobar5', 'barfoo5', 'barbar5', 'foofoo5', 'barfoobar5', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change)" . 
			" VALUES (6, 3, 'foo6', 'bar6', 'foobar6', 'barfoo6', 'barbar6', 'foofoo6', 'barfoobar6', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 6, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'D1', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, NULL, 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, 'C1', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (4, 'SC1', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (5, 'O1', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (6, 'SO1', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (7, 'F1', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (8, 'G1', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (9, 'S1', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (10, 'ST1', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (11, 'NULL', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (12, 'FILTERED', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (13, 'FILTERED', 'phylum', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (14, 'FILTERED', 'class', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (15, 'FILTERED', 'subclass', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (16, 'FILTERED', 'order', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (17, 'FILTERED', 'suborder', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (18, 'FILTERED', 'family', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (19, 'FILTERED', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (20, 'FILTERED', 'species', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (21, 'FILTERED', 'strain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (11, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (12, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (13, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (14, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (15, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (16, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (17, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (18, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (19, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (20, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (21, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 4, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (4, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (5, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (6, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (7, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (8, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (9, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (10, 6, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("REFRESH MATERIALIZED VIEW v_lineages");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			($resR, $metasR) = MetagDB::Sga::getLineages($dbh, $idsR, $blacklistR, $keepCtrl, $maxRows);
		};
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing program and database are NULL');
	}
	finally {
		is ($resR, $expecResR, 'Testing program and database are NULL - results');
		is ($metasR, $expecMetasR, 'Testing program and database are NULL - metadata');
		ok ($err =~ m/WARNING:.*->1<- sample IDs were removed/, 'Testing program and database are NULL - warning message');
		$dbh->rollback;
	};
		
	
	return $dbh;	
}	


#
#--------------------------------------------------------------------------------------------------#
# Test the getMeta function
#--------------------------------------------------------------------------------------------------#
#
sub test_getMeta {
	my $dbh = $_[0] // "";
	
	my $idChange = 1;
	my $metasR = {
		"1" => {
			"F1_meconium_f_M_eta_G_RDPs_16_S" => {
				"program" => "M_eta_G",
				"database" => "RDPs_16_S",
				"control" => "no",
				"timepoint" => "meconium"
				
			}
		},
		"2" => {
			"F1_meconium_t_M_eta_G_RDPs_16_S" => {
				"program" => "M_eta_G",
				"database" => "RDPs_16_S",
				"control" => "yes",
				"timepoint" => "meconium"
			}
		}
	};
	my $maxRows = 10;
	my $err = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no metadata reference + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getMeta();
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "Too few", 'Testing no database handle');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no metadata reference (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getMeta($dbh);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "Too few", 'Testing no metadata reference');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows (optional parameter)
	#------------------------------------------------------------------------------#
	my $expecResR = {
		1 => {
			"F1_meconium_f_M_eta_G_RDPs_16_S" => {
				"antibiotics"										=>	"no",
				"birth_mode"										=>	"natural",
				"category_of_difference_in_body_mass_at_delivery"	=>	"not_enough",
				"control"											=> 	"no",
				"database"											=>	"RDPs_16_S",
				"feeding_mode"										=>	"diet_extension",
				"maternal_antibiotics_during_pregnancy"				=>	"no",
				"maternal_illness_during_pregnancy"					=>	"",
				"mothers_age_at_delivery"							=>	'20.00',
				"mothers_pre_pregnancy_BMI_category"				=>	"underweight",
				"pregnancy_order"									=>	3,
				"probiotics"										=>	"no",
				"program"											=>	"M_eta_G",
				"sex"												=>	"f",
				"timepoint"											=>	"meconium",
				"z_score_category"									=> 	"AGA",
				"z_score_subcategory"								=> 	"AGA"
				
			}
		},
		2 => {
			"F1_meconium_t_M_eta_G_RDPs_16_S" => {
				"control"											=> 	"yes",
				"database"											=>	"RDPs_16_S",
				"program"											=>	"M_eta_G",
				"timepoint"											=>	"meconium"
			}
		}
	};
	
	my $resR = dclone($metasR);
	
	try {
		$err = "";
		
		# 1 patient with 2 samples. Second sample also has no metadata.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 1, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, 'antibiotics', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, 'birth mode', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, 'mother\'\'s height', 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'feeding mode', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, 'maternal antibiotics during pregnancy', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, 'maternal illness during pregnancy', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (7, 'mother\'\'s birth date', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (8, 'maternal body mass before pregnancy', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (9, 'maternal body mass at delivery', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (10, 'pregnancy order', 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (11, 'probiotics', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (12, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (13, 'body mass', 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 'no', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 'natural', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, '170', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'diet-extension', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 'no', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 1, 7, '1880-12-24', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 1, 8, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 1, 9, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 1, 10, 3, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 1, 11, 'no', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 1, 12, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 1, 13, 2500, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		$dbh->do("REFRESH MATERIALIZED VIEW v_metadata");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			$resR = MetagDB::Sga::getMeta($dbh, $resR);
		};
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing no maxRows');
	}
	finally {
		is ($resR, $expecResR, 'Testing no maxRows - results');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getMeta("", $metasR, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Not enough", 'Testing empty database handle');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty metadata reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getMeta($dbh, "", $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Not enough", 'Testing empty metadata reference');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test metadata empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getMeta($dbh, {}, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*No metadata or not a reference", 'Testing metadata empty reference');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test metadata not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getMeta($dbh, "abc", $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*No metadata or not a reference", 'Testing metadata not a reference');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getMeta($dbh, $metasR, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ "ERROR.*Invalid value for maxRows", 'Testing empty maxRows');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getMeta($dbh, $metasR, "abc");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is zero
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Sga::getMeta($dbh, $metasR, 0);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero');
	};

	
	#------------------------------------------------------------------------------#
	# Test valid data
	#------------------------------------------------------------------------------#
	$resR = dclone($metasR);
	
	try {
		$err = "";
		
		# 1 patient with 2 samples. Second sample also has no metadata.
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foo', '123456', '123456')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'F1', 'FOOBAR1', '1900-12-24', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-12-25', 'BARFOO', 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-12-25', 'BARFOO', 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 1, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, 'antibiotics', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, 'birth mode', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, 'mother\'\'s height', 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'feeding mode', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, 'maternal antibiotics during pregnancy', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, 'maternal illness during pregnancy', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (7, 'mother\'\'s birth date', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (8, 'maternal body mass before pregnancy', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (9, 'maternal body mass at delivery', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (10, 'pregnancy order', 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (11, 'probiotics', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (12, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (13, 'body mass', 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 'no', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 'natural', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, '170', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'diet-extension', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 'no', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 1, 7, '1880-12-24', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 1, 8, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 1, 9, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 1, 10, 3, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 1, 11, 'no', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 1, 12, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 1, 13, 2500, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		$dbh->do("REFRESH MATERIALIZED VIEW v_metadata");
		
		# Supress warning messages on terminal
		do {
			local *STDERR;
			open STDERR, ">>", \$err;
			$resR = MetagDB::Sga::getMeta($dbh, $resR, $maxRows);
		};
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing valid data');
	}
	finally {
		is ($resR, $expecResR, 'Testing valid data - results');
		$dbh->rollback;
	};

	
	return $dbh;	
}


#
#--------------------------------------------------------------------------------------------------#
# Test the view v_samples
#--------------------------------------------------------------------------------------------------#
#
sub test_v_samples {
	my $dbh = $_[0] // "";
	my $idChange = 1;
	
	
	#------------------------------------------------------------------------------#
	# Test valid input
	#------------------------------------------------------------------------------#
	my $resR = "";
	my $err = "";
	my $expecsR = [
		[1, 1, 'P1', '1900-01-01', 'meconium', 'Yes', 2, 't'],
		[2, 2, 'P2', '1900-02-05', '3d', 'No', 0, 't']
	];
	
	try {
		$resR = "";
		$err = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-05', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
			
		$resR = $dbh->selectall_arrayref("SELECT * from v_samples order by id");
		is ($resR, $expecsR, 'Testing valid input');
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing valid input')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test birthdate is NULL (hypothetical more relaxed schema)
	# => Influences timepoint and should be flagged in isok
	# => No test for empty: date type cannot be empty.
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 1, 'P1', '1900-01-01', 'NA', 'Yes', 2, 'f'],
		[2, 2, 'P2', '1900-02-05', '3d', 'No', 0, 't']
	];
	
	try {
		$resR = "";
		$err = "";
		
		$dbh->do("ALTER TABLE patient ALTER COLUMN birthdate DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', NULL, $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-05', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
			
		$resR = $dbh->selectall_arrayref("SELECT * from v_samples order by id");
		is ($resR, $expecsR, 'Testing birthdate is NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing birthdate is NULL')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test createdate is NULL (hypothetical more relaxed schema)
	# => Influences timepoint and should be flagged in isok
	# => No test for empty: date type cannot be empty.
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 1, 'P1', undef, 'NA', 'Yes', 2, 'f'],
		[2, 2, 'P2', '1900-02-05', '3d', 'No', 0, 't']
	];
	
	try {
		$resR = "";
		$err = "";
		
		$dbh->do("ALTER TABLE sample ALTER COLUMN createdate DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, NULL, NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-05', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
			
		$resR = $dbh->selectall_arrayref("SELECT * from v_samples order by id");
		is ($resR, $expecsR, 'Testing createdate is NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing createdate is NULL')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test timepoint cannot be calculated: Falls between ranges.
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 1, 'P1', '1900-01-06', 'NA', 'Yes', 2, 'f'],
		[2, 2, 'P2', '1900-02-05', '3d', 'No', 0, 't']
	];
	
	try {
		$resR = "";
		$err = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-06', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-05', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
			
		$resR = $dbh->selectall_arrayref("SELECT * from v_samples order by id");
		is ($resR, $expecsR, 'Testing timepoint cannot be inferred [1/3]');
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing timepoint cannot be inferred [1/3]')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test timepoint cannot be calculated: Too low.
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 1, 'P1', '1899-12-31', 'NA', 'Yes', 2, 'f'],
		[2, 2, 'P2', '1900-02-05', '3d', 'No', 0, 't']
	];
	
	try {
		$resR = "";
		$err = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1899-12-31', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-05', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
			
		$resR = $dbh->selectall_arrayref("SELECT * from v_samples order by id");
		is ($resR, $expecsR, 'Testing timepoint cannot be inferred [2/3]');
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing timepoint cannot be inferred [2/3]')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test timepoint cannot be calculated: Too high.
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 1, 'P1', '1904-01-01', 'NA', 'Yes', 2, 'f'],
		[2, 2, 'P2', '1900-02-05', '3d', 'No', 0, 't']
	];
	
	try {
		$resR = "";
		$err = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1904-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-05', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
			
		$resR = $dbh->selectall_arrayref("SELECT * from v_samples order by id");
		is ($resR, $expecsR, 'Testing timepoint cannot be inferred [3/3]');
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing timepoint cannot be inferred [3/3]')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test timepoint collision: Calculation of timepoint from createdate is
	# deliberately fuzzy.
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 1, 'P1', '1900-01-01', 'meconium', 'Yes', 2, 'f'],
		[2, 1, 'P1', '1900-01-02', 'meconium', 'Yes', 0, 'f'],
		[3, 2, 'P2', '1900-02-05', '3d', 'No', 0, 't']
	];
	
	try {
		$resR = "";
		$err = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-05', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
			
		$resR = $dbh->selectall_arrayref("SELECT * from v_samples order by id");
		is ($resR, $expecsR, 'Testing timepoint collision');
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing timepoint collision')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test timepoint correctly assigned
	#------------------------------------------------------------------------------#
	# createdate, expected timepoint
	my @tests = (
		['1900-01-01', 'meconium'],
		['1900-01-04', '3d'],
		['1900-01-15', '2w'],
		['1900-02-15', '6w'],
		['1900-04-01', '3m'],
		['1900-07-01', '6m'],
		['1900-10-01', '9m'],
		['1901-01-01', '1y'],
		['1901-07-01', '1.5y'],
		['1902-01-01', '2y'],
		['1902-07-01', '2.5y'],
		['1903-01-01', '3y']);
		
	for (my $i = 0; $i <= $#tests; $i++) {
		my ($date, $expTimep) = @{$tests[$i]};
		
		$expecsR = [
			[1, 1, 'P1', $date, $expTimep, 'Yes', 2, 't'],
		];
		
		try {
			$resR = "";
			$err = "";
			
			$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
			$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
			$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, ?, NULL, 't', $idChange)", {}, $date);
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
			$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
				
			$resR = $dbh->selectall_arrayref("SELECT * from v_samples order by id");
			is ($resR, $expecsR, 'Testing timepoint correctly assigned [' . ($i + 1) . '/' . scalar(@tests) . ']');
		}
		catch {
			$err = $_;
			print $err;
			ok(1==2, 'Testing timepoint correctly assigned [' . ($i + 1) . '/' . scalar(@tests) . ']')
		}
		finally {
			$dbh->rollback;
		};
	}
	
	
	#------------------------------------------------------------------------------#
	# Test iscontrol is NULL (hypothetical more relaxed schema)
	# => should be translated to 'No'
	# => cannot test empty iscontrol, as boolean type cannot be empty
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 1, 'P1', '1900-01-01', 'meconium', 'Yes', 2, 't'],
		[2, 2, 'P2', '1900-02-05', '3d', 'No', 0, 't']
	];
	
	try {
		$resR = "";
		$err = "";
		
		$dbh->do("ALTER TABLE sample ALTER COLUMN iscontrol DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-05', NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
			
		$resR = $dbh->selectall_arrayref("SELECT * from v_samples order by id");
		is ($resR, $expecsR, 'Testing iscontrol is NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing iscontrol is NULL')
	}
	finally {
		$dbh->rollback;
	};
	
	
	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the view v_taxa (esp. calculation of read length / read quality scores)
#--------------------------------------------------------------------------------------------------#
#
sub test_v_taxa {
	my $dbh = $_[0] // "";
	my $idChange = 1;
	
	
	#------------------------------------------------------------------------------#
	# Test valid input for view
	# => A patient with sequences and multiple classifications per sequence
	#
	# P1 --> '1900-01-01' --> read1 --> MetaG + RDP: Bacteria + Escherichia
	#								--> MetaG + MTX: Bacteria + Escherichia
	#					  --> read2 --> MetaG + RDP: Bacteria + Escherichia
	#								--> MetaG + MTX: Bacteria + Escherichia
	#					  --> read3 --> MetaG + RDP: Null
	#
	#	 --> '1900-01-02' --> read5 --> MetaG + RDP: Bacteria + Escherichia
	#
	# => A patient with a sequence, but no entry in taxclass
	#
	# P2 --> '1900-02-02' --> read4 --> MetaG + RDP, but no taxclass
	#------------------------------------------------------------------------------#
	my $resR = "";
	my $err = "";
	my $expecsR = [
		['1_MetaG_MTX_1', 1, 1, 1, 'P1', 'meconium', 'Yes', 'MetaG', 'MTX', '2', 'Bacteria', 'domain', 1, 5, 9, 0, 3, 40],
		['1_MetaG_MTX_2', 1, 1, 2, 'P1', 'meconium', 'Yes', 'MetaG', 'MTX', '2', 'Escherichia', 'genus', 1, 5, 9, 0, 3, 40],
		['1_MetaG_RDP_1', 1, 1, 1, 'P1', 'meconium', 'Yes', 'MetaG', 'RDP', '2', 'Bacteria', 'domain', 1, 5, 9, 0, 3, 40],
		['1_MetaG_RDP_2', 1, 1, 2, 'P1', 'meconium', 'Yes', 'MetaG', 'RDP', '2', 'Escherichia', 'genus', 1, 5, 9, 0, 3, 40],
		['1_MetaG_RDP_3', 1, 1, 3, 'P1', 'meconium', 'Yes', 'MetaG', 'RDP', '1', undef, 'domain', 3, 3, 3, 5, 5, 5],
		['3_MetaG_RDP_1', 1, 3, 1, 'P1', '3d', 'No', 'MetaG', 'RDP', '1', 'Bacteria', 'domain', 3, 3, 3, 3, 3, 3],
		['3_MetaG_RDP_2', 1, 3, 2, 'P1', '3d', 'No', 'MetaG', 'RDP', '1', 'Escherichia', 'genus', 3, 3, 3, 3, 3, 3]
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-02', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-04', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'A', 'I', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(3, 1, 'f3', 'r3', 'b3', 'read3', 'c3', 'ATG', 'I!I', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(4, 2, 'f4', 'r4', 'b4', 'read4', 'c4', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(5, 3, 'f5', 'r5', 'b5', 'read5', 'c5', 'ATT', '!I', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (5, 1, 'MetaG', 'MTX', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 2, 'MetaG', 'MTX', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (7, 5, 'MetaG', 'RDP', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'Bacteria', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, 'Escherichia', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, NULL, 'domain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 5, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 5, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 7, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 7, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_taxa");
		
		$resR = $dbh->selectall_arrayref("SELECT * FROM v_taxa ORDER BY id");
		is($resR, $expecsR, 'Testing valid input');
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing valid input')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test program and database are empty (hypothetical more relaxed schema
	# that has no unique constraint on id_sequence, program and database).
	# => Affects id and also the counts of taxa (no distinction between different
	# programs/databases)
	#------------------------------------------------------------------------------#
	$expecsR = [
		['1___1', 1, 1, 1, 'P1', 'meconium', 'Yes', '', '', '4', 'Bacteria', 'domain', 1, 5, 9, 0, 3, 40],
		['1___2', 1, 1, 2, 'P1', 'meconium', 'Yes', '', '', '4', 'Escherichia', 'genus', 1, 5, 9, 0, 3, 40],
		['1___3', 1, 1, 3, 'P1', 'meconium', 'Yes', '', '', '1', undef, 'domain', 3, 3, 3, 5, 5, 5],
		['3___1', 1, 3, 1, 'P1', '3d', 'No', '', '', '1', 'Bacteria', 'domain', 3, 3, 3, 3, 3, 3],
		['3___2', 1, 3, 2, 'P1', '3d', 'No', '', '', '1', 'Escherichia', 'genus', 3, 3, 3, 3, 3, 3]
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("ALTER TABLE classification DROP CONSTRAINT classification_id_sequence_program_database_key");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-02', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-04', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'A', 'I', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(3, 1, 'f3', 'r3', 'b3', 'read3', 'c3', 'ATG', 'I!I', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(4, 2, 'f4', 'r4', 'b4', 'read4', 'c4', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(5, 3, 'f5', 'r5', 'b5', 'read5', 'c5', 'ATT', '!I', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, '', '', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, '', '', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, '', '', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, '', '', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (5, 1, '', '', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 2, '', '', $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (7, 5, '', '', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'Bacteria', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, 'Escherichia', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, NULL, 'domain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 5, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 5, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 7, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 7, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_taxa");
		
		$resR = $dbh->selectall_arrayref("SELECT * FROM v_taxa ORDER BY id");
		is($resR, $expecsR, 'Testing program and database are empty');
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing program and database are empty')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test program and database are NULL (hypothetical more relaxed schema).
	# NULLs are distinct by default, as opposed to empty strings, so no need to
	# drop the unique constraint on id_sequence, program, and database.
	# => Affects id and also the counts of taxa (no distinction between different
	# programs, databases)
	#------------------------------------------------------------------------------#
	$expecsR = [
		['1___1', 1, 1, 1, 'P1', 'meconium', 'Yes', undef, undef, '4', 'Bacteria', 'domain', 1, 5, 9, 0, 3, 40],
		['1___2', 1, 1, 2, 'P1', 'meconium', 'Yes', undef, undef, '4', 'Escherichia', 'genus', 1, 5, 9, 0, 3, 40],
		['1___3', 1, 1, 3, 'P1', 'meconium', 'Yes', undef, undef, '1', undef, 'domain', 3, 3, 3, 5, 5, 5],
		['3___1', 1, 3, 1, 'P1', '3d', 'No', undef, undef, '1', 'Bacteria', 'domain', 3, 3, 3, 3, 3, 3],
		['3___2', 1, 3, 2, 'P1', '3d', 'No', undef, undef, '1', 'Escherichia', 'genus', 3, 3, 3, 3, 3, 3]
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("ALTER TABLE classification ALTER COLUMN program DROP NOT NULL");
		$dbh->do("ALTER TABLE classification ALTER COLUMN database DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-02', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-04', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'A', 'I', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(3, 1, 'f3', 'r3', 'b3', 'read3', 'c3', 'ATG', 'I!I', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(4, 2, 'f4', 'r4', 'b4', 'read4', 'c4', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
		$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
			"(5, 3, 'f5', 'r5', 'b5', 'read5', 'c5', 'ATT', '!I', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (1, 1, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (2, 2, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (3, 3, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (4, 4, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (5, 1, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (6, 2, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO classification (id, id_sequence, program, database, id_change) VALUES (7, 5, NULL, NULL, $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (1, 'Bacteria', 'domain', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (2, 'Escherichia', 'genus', $idChange)");
		$dbh->do("INSERT INTO taxonomy (id, name, rank, id_change) VALUES (3, NULL, 'domain', $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 1, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 2, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (3, 3, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 5, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 5, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 6, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (1, 7, $idChange)");
		$dbh->do("INSERT INTO taxclass (id_taxonomy, id_classification, id_change) VALUES (2, 7, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_taxa");
		
		$resR = $dbh->selectall_arrayref("SELECT * FROM v_taxa ORDER BY id");
		is($resR, $expecsR, 'Testing program and database are NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing program and database are NULL')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test sequence and quality string are empty
	# => Violates not NULL on seqerr and seqlen
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("ALTER TABLE sequence ALTER COLUMN nucs DROP NOT NULL");
		$dbh->do("ALTER TABLE sequence ALTER COLUMN quality DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-02', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-04', NULL, 'f', $idChange)");
		
		# Don't print STDERR on terminal
		do {
    		local *STDERR;
    		open STDERR, ">", '/dev/null';
    		
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', '', '', $idChange)");
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'A', 'I', $idChange)");
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(3, 1, 'f3', 'r3', 'b3', 'read3', 'c3', 'ATG', 'I!I', $idChange)");
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(4, 2, 'f4', 'r4', 'b4', 'read4', 'c4', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(5, 3, 'f5', 'r5', 'b5', 'read5', 'c5', 'ATT', '!I', $idChange)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/violates not-null/, 'Testing sequence and quality are empty');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test sequence and quality string are NULL (hypothetical more relaxed schema).
	# => Violates not NULL on seqerr and seqlen
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("ALTER TABLE sequence ALTER COLUMN nucs DROP NOT NULL");
		$dbh->do("ALTER TABLE sequence ALTER COLUMN quality DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 2, '1900-02-02', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-01-04', NULL, 'f', $idChange)");
		
		# Don't print STDERR on terminal
		do {
    		local *STDERR;
    		open STDERR, ">", '/dev/null';
    		
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(1, 1, 'f1', 'r1', 'b1', 'read1', 'c1', NULL, NULL, $idChange)");
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(2, 1, 'f2', 'r2', 'b2', 'read2', 'c2', 'A', 'I', $idChange)");
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(3, 1, 'f3', 'r3', 'b3', 'read3', 'c3', 'ATG', 'I!I', $idChange)");
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(4, 2, 'f4', 'r4', 'b4', 'read4', 'c4', 'ATGATGTAG', '!!!!!!!!!', $idChange)");
			$dbh->do("INSERT INTO sequence (id, id_sample, flowcellid, runid, barcode, readid, callermodel, nucs, quality, id_change) VALUES " .
				"(5, 3, 'f5', 'r5', 'b5', 'read5', 'c5', 'ATT', '!I', $idChange)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/violates not-null/, 'Testing sequence and quality are NULL');
		$dbh->rollback;
	};
	

	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the view v_measurements
#
# v_measurements is in a sense special, since the measurements for each sample are rows, not
# columns. So there is little specific control over the inputs. Still, many calculations depend
# on the presence of single measurements. This will be the focus of these tests.
# Columns which are not directly used for calculations or were not calculated here are not
# tested to keep the amount of tests sane.
#--------------------------------------------------------------------------------------------------#
#
sub test_v_measurements {
	my $dbh = $_[0] // "";
	my $idChange = 1;
	

	#------------------------------------------------------------------------------#
	# Test valid insert
	#------------------------------------------------------------------------------#
	my $expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score', 'i', -0.52],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score subcategory', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[1, 'foo', '1900-01-04', '3d', 'z-score', 'i', -0.07],
		[1, 'foo', '1900-01-04', '3d', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'z-score subcategory', 's', 'AGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score', 'i', -2.95],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score subcategory', 's', 'SGA'],		
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-05', '3d', 'z-score', 'i', -2.72],
		[2, 'bar', '1900-02-05', '3d', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-05', '3d', 'z-score subcategory', 's', 'no catch-up'],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000],
		[2, 'bar', '1900-02-16', '2w', 'z-score', 'i', -1.54],
		[2, 'bar', '1900-02-16', '2w', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-16', '2w', 'z-score subcategory', 's', 'early catch-up']
	];
	my $err = "";
	my $resR = "";
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
		is ($resR, $expecsR, 'Testing valid insert');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing valid insert')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "maternal body mass before pregnancy" is empty
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		
		# Suppress error messages on terminal
		do {
    		local *STDERR;
    		open STDERR, ">>", "/dev/null";
    		
    		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
    		
			$dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'body mass', " .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s age at delivery\$\$, " .
					"\$\$mother\'s birth date\$\$, " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
					"'sex', " .
					"'z-score', " .
					"'z-score category', " .
					"'z-score subcategory'" .
				"]," .
				"name)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*invalid input syntax for type numeric/, 'Testing "maternal body mass before pregnancy" is empty');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "maternal body mass before pregnancy" is wrong data type
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 'abc', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 'def', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		
		# Suppress error messages on terminal
		do {
    		local *STDERR;
    		open STDERR, ">>", "/dev/null";
    		
    		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
    		
			$dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'body mass', " .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s age at delivery\$\$, " .
					"\$\$mother\'s birth date\$\$, " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
					"'sex', " .
					"'z-score', " .
					"'z-score category', " .
					"'z-score subcategory'" .
				"]," .
				"name)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*invalid input syntax for type numeric/, 'Testing "maternal body mass before pregnancy" has wrong data type');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "maternal body mass before pregnancy" is NULL (hypothetical more relaxed
	# schema)
	# => influences "mother's pre-pregnancy BMI" +
	#	"difference in body mass at delivery"
	# => influences "mother's pre-pregnancy BMI category" +
	#	"category of difference in body mass at delivery"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score', 'i', -0.52],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score subcategory', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[1, 'foo', '1900-01-04', '3d', 'z-score', 'i', -0.07],
		[1, 'foo', '1900-01-04', '3d', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'z-score subcategory', 's', 'AGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score', 'i', -2.95],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score subcategory', 's', 'SGA'],		
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-05', '3d', 'z-score', 'i', -2.72],
		[2, 'bar', '1900-02-05', '3d', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-05', '3d', 'z-score subcategory', 's', 'no catch-up'],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000],
		[2, 'bar', '1900-02-16', '2w', 'z-score', 'i', -1.54],
		[2, 'bar', '1900-02-16', '2w', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-16', '2w', 'z-score subcategory', 's', 'early catch-up']
	];
	
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("ALTER TABLE measurement ALTER COLUMN value DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
			
		is ($resR, $expecsR, 'Testing "maternal body mass before pregnancy" is NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "maternal body mass before pregnancy" is NULL');
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "maternal body mass before pregnancy" not present at all
	# => no "mother's pre-pregnancy BMI" +
	#	no "mother's pre-pregnancy BMI category" +
	#	no "category of difference in body mass at delivery"
	# => influences "difference in body mass at delivery"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score', 'i', -0.52],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score subcategory', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[1, 'foo', '1900-01-04', '3d', 'z-score', 'i', -0.07],
		[1, 'foo', '1900-01-04', '3d', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'z-score subcategory', 's', 'AGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score', 'i', -2.95],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score subcategory', 's', 'SGA'],		
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-05', '3d', 'z-score', 'i', -2.72],
		[2, 'bar', '1900-02-05', '3d', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-05', '3d', 'z-score subcategory', 's', 'no catch-up'],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000],
		[2, 'bar', '1900-02-16', '2w', 'z-score', 'i', -1.54],
		[2, 'bar', '1900-02-16', '2w', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-16', '2w', 'z-score subcategory', 's', 'early catch-up']
	];
	
	
	try {
		$err = "";
		$resR = "";
				
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 2, 4, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 3, 1, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 2, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 3, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 4, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 5, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 4, 4, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 5, 4, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
			
		is ($resR, $expecsR, 'Testing "maternal body mass before pregnancy" is not present');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "maternal body mass before pregnancy" is not present');
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "mother's height" is empty
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		
		# Suppress error messages on terminal
		do {
    		local *STDERR;
    		open STDERR, ">>", "/dev/null";
    		
    		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
    		
			$dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'body mass', " .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s age at delivery\$\$, " .
					"\$\$mother\'s birth date\$\$, " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
					"'sex', " .
					"'z-score', " .
					"'z-score category', " .
					"'z-score subcategory'" .
				"]," .
				"name)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*invalid input syntax for type numeric/, 'Testing "mother\'s height" is empty');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "mother's height" wrong data type
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 'abc', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 'def', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		
		# Suppress error messages on terminal
		do {
    		local *STDERR;
    		open STDERR, ">>", "/dev/null";
    		
    		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
    		
			$dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'body mass', " .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s age at delivery\$\$, " .
					"\$\$mother\'s birth date\$\$, " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
					"'sex', " .
					"'z-score', " .
					"'z-score category', " .
					"'z-score subcategory'" .
				"]," .
				"name)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*invalid input syntax for type numeric/, 'Testing "mother\'s height" has wrong data type');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "mother's height" is NULL (hypothetical more relaxed schema)
	# => influences "mother's pre-pregnancy BMI" +
	#	"mother's pre-pregnancy BMI category" +
	#	"category of difference in body mass at delivery"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score', 'i', -0.52],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score subcategory', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[1, 'foo', '1900-01-04', '3d', 'z-score', 'i', -0.07],
		[1, 'foo', '1900-01-04', '3d', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'z-score subcategory', 's', 'AGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score', 'i', -2.95],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score subcategory', 's', 'SGA'],		
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-05', '3d', 'z-score', 'i', -2.72],
		[2, 'bar', '1900-02-05', '3d', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-05', '3d', 'z-score subcategory', 's', 'no catch-up'],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000],
		[2, 'bar', '1900-02-16', '2w', 'z-score', 'i', -1.54],
		[2, 'bar', '1900-02-16', '2w', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-16', '2w', 'z-score subcategory', 's', 'early catch-up']
	];
	
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("ALTER TABLE measurement ALTER COLUMN value DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
			
		is ($resR, $expecsR, 'Testing "mother\'s height" is NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "Testing "mother\'s height" is NULL');
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test mother's height not present at all
	# => influences "mother's pre-pregnancy BMI" +
	#	"mother's pre-pregnancy BMI category" +
	#	"category of difference in body mass at delivery"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score', 'i', -0.52],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score subcategory', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[1, 'foo', '1900-01-04', '3d', 'z-score', 'i', -0.07],
		[1, 'foo', '1900-01-04', '3d', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'z-score subcategory', 's', 'AGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score', 'i', -2.95],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score subcategory', 's', 'SGA'],		
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-05', '3d', 'z-score', 'i', -2.72],
		[2, 'bar', '1900-02-05', '3d', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-05', '3d', 'z-score subcategory', 's', 'no catch-up'],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000],
		[2, 'bar', '1900-02-16', '2w', 'z-score', 'i', -1.54],
		[2, 'bar', '1900-02-16', '2w', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-16', '2w', 'z-score subcategory', 's', 'early catch-up']
	];
	
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 2, 4, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 3, 1, 40, $idChange)");;
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 2, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 3, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 4, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 5, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 4, 4, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 5, 4, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
			
		is ($resR, $expecsR, 'Testing "mother\'s height" is not present');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "mother\'s height" is not present');
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "maternal body mass at delivery" is empty
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		
		# Suppress error messages on terminal
		do {
    		local *STDERR;
    		open STDERR, ">>", "/dev/null";
    		
    		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
    		
			$dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'body mass', " .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s age at delivery\$\$, " .
					"\$\$mother\'s birth date\$\$, " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
					"'sex', " .
					"'z-score', " .
					"'z-score category', " .
					"'z-score subcategory'" .
				"]," .
				"name)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*invalid input syntax for type numeric/, 'Testing "maternal body mass at delivery" is empty');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "maternal body mass at delivery" wrong data type
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 'abc', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 'def', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		
		# Suppress error messages on terminal
		do {
    		local *STDERR;
    		open STDERR, ">>", "/dev/null";
    		
    		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
    		
			$dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'body mass', " .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s age at delivery\$\$, " .
					"\$\$mother\'s birth date\$\$, " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
					"'sex', " .
					"'z-score', " .
					"'z-score category', " .
					"'z-score subcategory'" .
				"]," .
				"name)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*invalid input syntax for type numeric/, 'Testing "maternal body mass at delivery" has wrong data type');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "maternal body mass at delivery" is NULL (hypothetical more relaxed
	# schema)
	# => influences "difference in body mass at delivery" / "category of difference
	# 	in body mass at delivery"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score', 'i', -0.52],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score subcategory', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[1, 'foo', '1900-01-04', '3d', 'z-score', 'i', -0.07],
		[1, 'foo', '1900-01-04', '3d', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'z-score subcategory', 's', 'AGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score', 'i', -2.95],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score subcategory', 's', 'SGA'],		
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-05', '3d', 'z-score', 'i', -2.72],
		[2, 'bar', '1900-02-05', '3d', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-05', '3d', 'z-score subcategory', 's', 'no catch-up'],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000],
		[2, 'bar', '1900-02-16', '2w', 'z-score', 'i', -1.54],
		[2, 'bar', '1900-02-16', '2w', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-16', '2w', 'z-score subcategory', 's', 'early catch-up']
	];
	
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("ALTER TABLE measurement ALTER COLUMN value DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
			
		is ($resR, $expecsR, 'Testing "maternal body mass at delivery" is NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "maternal body mass at delivery" is NULL');
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "maternal body mass at delivery" not present at all
	# => no "difference in body mass at delivery" + no "category of difference in
	#	body mass at delivery"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score', 'i', -0.52],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score subcategory', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[1, 'foo', '1900-01-04', '3d', 'z-score', 'i', -0.07],
		[1, 'foo', '1900-01-04', '3d', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'z-score subcategory', 's', 'AGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score', 'i', -2.95],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score subcategory', 's', 'SGA'],		
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-05', '3d', 'z-score', 'i', -2.72],
		[2, 'bar', '1900-02-05', '3d', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-05', '3d', 'z-score subcategory', 's', 'no catch-up'],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000],
		[2, 'bar', '1900-02-16', '2w', 'z-score', 'i', -1.54],
		[2, 'bar', '1900-02-16', '2w', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-16', '2w', 'z-score subcategory', 's', 'early catch-up']
	];
	
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 2, 4, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 3, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 4, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 5, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 4, 4, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 5, 4, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
			
		is ($resR, $expecsR, 'Testing "maternal body mass at delivery" is not present');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "maternal body mass at delivery" is not present');
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "sex" is empty
	# => no "z-score" + "z-score category" + "z-score subcategory"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', ''],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', ''],	
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000]
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
		is ($resR, $expecsR, 'Testing empty "sex"');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing empty "sex"')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "sex" is NULL (hypothetical more relaxed schema)
	# => no "z-score" + "z-score category" + "z-score subcategory"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', undef],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', undef],	
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000]
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("ALTER TABLE measurement ALTER COLUMN value DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
		is ($resR, $expecsR, 'Testing "sex" is NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "sex" is NULL')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "sex" is not present at all
	# => no "z-score" + "z-score category" + "z-score subcategory"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000]
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 2, 4, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 4, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 5, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 4, 4, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 5, 4, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
		is ($resR, $expecsR, 'Testing "sex" is not present');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "sex" is not present')
	}
	finally {
		$dbh->rollback;
	};
	

	#------------------------------------------------------------------------------#
	# Test "body mass" is empty
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		
		# Suppress error messages on terminal
		do {
    		local *STDERR;
    		open STDERR, ">>", "/dev/null";
    		
    		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
    		
			$dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'body mass', " .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s age at delivery\$\$, " .
					"\$\$mother\'s birth date\$\$, " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
					"'sex', " .
					"'z-score', " .
					"'z-score category', " .
					"'z-score subcategory'" .
				"]," .
				"name)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*invalid input syntax for type numeric/, 'Testing "body mass" is empty');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "body mass" wrong data type
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 'abc', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, 'def', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 'ghi', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, 'jkl', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, 'mno', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		
		# Suppress error messages on terminal
		do {
    		local *STDERR;
    		open STDERR, ">>", "/dev/null";
    		
    		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
    		
			$dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'body mass', " .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s age at delivery\$\$, " .
					"\$\$mother\'s birth date\$\$, " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
					"'sex', " .
					"'z-score', " .
					"'z-score category', " .
					"'z-score subcategory'" .
				"]," .
				"name)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*invalid input syntax for type numeric/, 'Testing "body mass" has wrong data type');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "body mass" is NULL
	# => influences z-score" + "z-score category" + "z-score subcategory"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score category', 's', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score subcategory', 's', undef],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', undef],
		[1, 'foo', '1900-01-04', '3d', 'z-score', 'i',  undef],
		[1, 'foo', '1900-01-04', '3d', 'z-score category', 's', undef],
		[1, 'foo', '1900-01-04', '3d', 'z-score subcategory', 's', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score category', 's', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score subcategory', 's', undef],		
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', undef],
		[2, 'bar', '1900-02-05', '3d', 'z-score', 'i', undef],
		[2, 'bar', '1900-02-05', '3d', 'z-score category', 's', undef],
		[2, 'bar', '1900-02-05', '3d', 'z-score subcategory', 's', undef],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', undef],
		[2, 'bar', '1900-02-16', '2w', 'z-score', 'i', undef],
		[2, 'bar', '1900-02-16', '2w', 'z-score category', 's', undef],
		[2, 'bar', '1900-02-16', '2w', 'z-score subcategory', 's', undef]
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("ALTER TABLE measurement ALTER COLUMN value DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, NULL, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
		is ($resR, $expecsR, 'Testing "body mass" is NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "body mass" is NULL')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "body mass" is not present
	# => no "z-score" + "z-score category" + "z-score subcategory"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm']
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 5, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 5, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
		is ($resR, $expecsR, 'Testing "body mass" is not present');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "body mass" is not present')
	}
	finally {
		$dbh->rollback;
	};
		

	#------------------------------------------------------------------------------#
	# Test "createdate" (sample) is NULL. Empty "createdate" not tested, as
	# date type cannot be empty.
	#	=> no "z-score" + "z-score category" + "z-score subcategory"
	#	=> timepoint cannot be inferred
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', undef, 'NA', 'body mass', 'i', 3000],
		[1, 'foo', undef, 'NA', 'body mass', 'i', 3200],
		[1, 'foo', undef, 'NA', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', undef, 'NA', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', undef, 'NA', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', undef, 'NA', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', undef, 'NA', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', undef, 'NA', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', undef, 'NA', 'mother\'s height', 'i', 1.7],
		[1, 'foo', undef, 'NA', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', undef, 'NA', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', undef, 'NA', 'sex', 's', 'f'],
		[2, 'bar', undef, 'NA', 'body mass', 'i', 2100],
		[2, 'bar', undef, 'NA', 'body mass', 'i', 2200],
		[2, 'bar', undef, 'NA', 'body mass', 'i', 3000],
		[2, 'bar', undef, 'NA', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', undef, 'NA', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', undef, 'NA', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', undef, 'NA', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', undef, 'NA', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', undef, 'NA', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', undef, 'NA', 'mother\'s height', 'i', 1.6],
		[2, 'bar', undef, 'NA', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', undef, 'NA', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', undef, 'NA', 'sex', 's', 'm']
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("ALTER TABLE sample ALTER COLUMN createdate DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, NULL, NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, NULL, NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, NULL, NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, NULL, NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, NULL, NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name), value");
		is ($resR, $expecsR, 'Testing "createdate" is NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "createdate" is NULL')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "createdate" out of range with standards in database
	#	=> no "z-score" + "z-score category" + "z-score subcategory"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1901-01-01', '1y', 'body mass', 'i', 3000],
		[1, 'foo', '1901-01-01', '1y', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1901-01-01', '1y', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1901-01-01', '1y', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1901-01-01', '1y', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1901-01-01', '1y', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1901-01-01', '1y', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1901-01-01', '1y', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1901-01-01', '1y', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1901-01-01', '1y', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1901-01-01', '1y', 'sex', 's', 'f'],
		[1, 'foo', '1901-01-04', '1y', 'body mass', 'i', 3200],
		[2, 'bar', '1901-02-02', '1y', 'body mass', 'i', 2100],
		[2, 'bar', '1901-02-02', '1y', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1901-02-02', '1y', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1901-02-02', '1y', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1901-02-02', '1y', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1901-02-02', '1y', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1901-02-02', '1y', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1901-02-02', '1y', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1901-02-02', '1y', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1901-02-02', '1y', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1901-02-02', '1y', 'sex', 's', 'm'],	
		[2, 'bar', '1901-02-05', '1y', 'body mass', 'i', 2200],
		[2, 'bar', '1901-02-16', 'NA', 'body mass', 'i', 3000]
	];
	
	try {
		$err = "";
		$resR = "";
				
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1901-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1901-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1901-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1901-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1901-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name), value");
		is ($resR, $expecsR, 'Testing "createdate" out of range');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "createdate" out of range')
	}
	finally {
		$dbh->rollback;
	};
	

	#------------------------------------------------------------------------------#
	# Test "birthdate" (sample) is NULL. Empty "birthdate" not tested, as date
	# type cannot be empty.
	#	=> no "z-score" + "z-score category" + z-score subcategory
	#	=> "timepoint" cannot be inferred
	#	=> "mother's age at delivery" cannot be inferred
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'NA', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'NA', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', 'NA', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'NA', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'NA', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'NA', 'mother\'s age at delivery', 'i', undef],
		[1, 'foo', '1900-01-01', 'NA', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'NA', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'NA', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'NA', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'NA', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-04', 'NA', 'body mass', 'i', 3200],
		[2, 'bar', '1900-02-02', 'NA', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'NA', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', 'NA', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'NA', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'NA', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'NA', 'mother\'s age at delivery', 'i', undef],
		[2, 'bar', '1900-02-02', 'NA', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'NA', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'NA', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'NA', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'NA', 'sex', 's', 'm'],	
		[2, 'bar', '1900-02-05', 'NA', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-16', 'NA', 'body mass', 'i', 3000]
	];
	
	try {
		$err = "";
		$resR = "";
				
		$dbh->do("ALTER TABLE patient ALTER COLUMN birthdate DROP NOT NULL");
				
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', NULL, $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', NULL, $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name), value");
		is ($resR, $expecsR, 'Testing "birthdate" is NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "birthdate" is NULL')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "birthdate" (patient) out of range with standards in database
	#	=> no "z-score" + "z-score category" + "z-score subcategory"
	#	=> influences "mother's age at delivery"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', '1y', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', '1y', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', '1y', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', '1y', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', '1y', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', '1y', 'mother\'s age at delivery', 'i', '29.00'],
		[1, 'foo', '1900-01-01', '1y', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', '1y', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', '1y', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', '1y', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', '1y', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-04', '1y', 'body mass', 'i', 3200],
		[2, 'bar', '1900-02-02', '1y', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', '1y', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', '1y', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', '1y', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', '1y', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', '1y', 'mother\'s age at delivery', 'i', '29.00'],
		[2, 'bar', '1900-02-02', '1y', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', '1y', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', '1y', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', '1y', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', '1y', 'sex', 's', 'm'],	
		[2, 'bar', '1900-02-05', '1y', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-16', 'NA', 'body mass', 'i', 3000]
	];
	
	try {
		$err = "";
		$resR = "";
				
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1899-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1899-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name), value");
		is ($resR, $expecsR, 'Testing "birthdate" out of range');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "birthdate" out of range')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "mother's birthdate" is empty
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		
		# Suppress error messages on terminal
		do {
    		local *STDERR;
    		open STDERR, ">>", "/dev/null";
    		
    		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
    		
			$dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'body mass', " .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s age at delivery\$\$, " .
					"\$\$mother\'s birth date\$\$, " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
					"'sex', " .
					"'z-score', " .
					"'z-score category', " .
					"'z-score subcategory'" .
				"]," .
				"name)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*invalid input syntax for type date/, 'Testing "mother\'s birthdate" is empty');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "mother's birthdate" wrong data type
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, 'abc', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, 'def', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		
		# Suppress error messages on terminal
		do {
    		local *STDERR;
    		open STDERR, ">>", "/dev/null";
    		
    		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
    		
			$dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'body mass', " .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s age at delivery\$\$, " .
					"\$\$mother\'s birth date\$\$, " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
					"'sex', " .
					"'z-score', " .
					"'z-score category', " .
					"'z-score subcategory'" .
				"]," .
				"name)");
		}
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*invalid input syntax for type date/, 'Testing "mother\'s birthdate" has wrong data type');
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "mother's birthdate" is NULL (hypothetical more relaxed schema)
	# => influences "mother's age at delivery"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', undef],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score', 'i', -0.52],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score subcategory', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[1, 'foo', '1900-01-04', '3d', 'z-score', 'i', -0.07],
		[1, 'foo', '1900-01-04', '3d', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'z-score subcategory', 's', 'AGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', undef],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score', 'i', -2.95],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score subcategory', 's', 'SGA'],		
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-05', '3d', 'z-score', 'i', -2.72],
		[2, 'bar', '1900-02-05', '3d', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-05', '3d', 'z-score subcategory', 's', 'no catch-up'],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000],
		[2, 'bar', '1900-02-16', '2w', 'z-score', 'i', -1.54],
		[2, 'bar', '1900-02-16', '2w', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-16', '2w', 'z-score subcategory', 's', 'early catch-up']
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("ALTER TABLE measurement ALTER COLUMN value DROP NOT NULL");
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
		is ($resR, $expecsR, 'Testing "mother\'s birthdate" is NULL');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "mother\'s birthdate" is NULL')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "mother's birthdate" is not present at all
	# => no "mother's age at delivery"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score', 'i', -0.52],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-01', 'meconium', 'z-score subcategory', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[1, 'foo', '1900-01-04', '3d', 'z-score', 'i', -0.07],
		[1, 'foo', '1900-01-04', '3d', 'z-score category', 's', 'AGA'],
		[1, 'foo', '1900-01-04', '3d', 'z-score subcategory', 's', 'AGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score', 'i', -2.95],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-02', 'meconium', 'z-score subcategory', 's', 'SGA'],		
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-05', '3d', 'z-score', 'i', -2.72],
		[2, 'bar', '1900-02-05', '3d', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-05', '3d', 'z-score subcategory', 's', 'no catch-up'],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000],
		[2, 'bar', '1900-02-16', '2w', 'z-score', 'i', -1.54],
		[2, 'bar', '1900-02-16', '2w', 'z-score category', 's', 'SGA'],
		[2, 'bar', '1900-02-16', '2w', 'z-score subcategory', 's', 'early catch-up']
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
		is ($resR, $expecsR, 'Testing "mother\'s birthdate" is not present');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "mother\'s birthdate" is not present')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty "name" (standard). NULL not tested, as "name" is part of primary
	# key --> cannot be NULL.
	# => no "z-score" + "z-score category" + "z-score subcategory"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],	
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000],
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
		is ($resR, $expecsR, 'Testing empty "name"');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing empty "name"')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "name" (standard) is not "weight_for_age"
	# => no "z-score" + "z-score category" + "z-score subcategory"
	#------------------------------------------------------------------------------#
	$expecsR = [
		[1, 'foo', '1900-01-01', 'meconium', 'body mass', 'i', 3000],
		[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
		[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s birth date', 'd', '1870-01-01'],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', 1.7],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 20.76],
		[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'normal weight'],
		[1, 'foo', '1900-01-01', 'meconium', 'sex', 's', 'f'],
		[1, 'foo', '1900-01-04', '3d', 'body mass', 'i', 3200],
		[2, 'bar', '1900-02-02', 'meconium', 'body mass', 'i', 2100],
		[2, 'bar', '1900-02-02', 'meconium', 'category of difference in body mass at delivery', 's', 'not enough'],
		[2, 'bar', '1900-02-02', 'meconium', 'difference in body mass at delivery', 'i', 10],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass at delivery', 'i', 50],
		[2, 'bar', '1900-02-02', 'meconium', 'maternal body mass before pregnancy', 'i', 40],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s age at delivery', 'i', '30.00'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s birth date', 'd', '1870-02-02'],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s height', 'i', 1.6],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', 15.63],
		[2, 'bar', '1900-02-02', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', 'underweight'],
		[2, 'bar', '1900-02-02', 'meconium', 'sex', 's', 'm'],	
		[2, 'bar', '1900-02-05', '3d', 'body mass', 'i', 2200],
		[2, 'bar', '1900-02-16', '2w', 'body mass', 'i', 3000],
	];
	
	try {
		$err = "";
		$resR = "";
		
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'bar', '1900-02-02', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-01-04', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 2, '1900-02-02', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 2, '1900-02-05', NULL, 't', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 2, '1900-02-16', NULL, 't', $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (4, 'sex', 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (5, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (6, \$\$mother\'s birth date\$\$, 'd', NULL, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, 1.7, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 1, 4, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 1, 5, 3000, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 1, 6, '1870-01-01', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 2, 5, '3200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 3, 1, 40, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 3, 2, 1.6, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 3, 3, 50, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 3, 4, 'm', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 3, 5, 2100, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 3, 6, '1870-02-02', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 4, 5, '2200', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 5, 5, '3000', $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('height_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('height_for_age', 'm', 0, 0.3487, 3.3464, 0.14602, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('height_for_age', 'f', 3, 0.2986, 3.2315, 0.14657, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('height_for_age', 'm', 3, 0.2959, 3.3627, 0.14647, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('height_for_age', 'm', 14, 0.2581, 3.7529, 0.14142, $idChange)");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
				"'body mass', " .
				"'category of difference in body mass at delivery', " .
				"'difference in body mass at delivery', " .
				"'maternal body mass at delivery', " .
				"'maternal body mass before pregnancy', " .
				"\$\$mother\'s age at delivery\$\$, " .
				"\$\$mother\'s birth date\$\$, " .
				"\$\$mother\'s height\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI\$\$, " .
				"\$\$mother\'s pre-pregnancy BMI category\$\$, " .
				"'sex', " .
				"'z-score', " .
				"'z-score category', " .
				"'z-score subcategory'" .
			"]," .
			"name)");
		is ($resR, $expecsR, 'Testing "name" is not "weight_for_age"');
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "name" is not "weight_for_age"')
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test "bmi category" correctly assigned
	#------------------------------------------------------------------------------#
	# height, expected bmi, expected bmi category, expected cat. of diff. in body mass at delivery
	my @tests = (
		[1.85, 17.53, 'underweight', 'not enough'],
		[1.7, 20.76, 'normal weight', 'not enough'],
		[1.5, 26.67, 'overweight', 'appropriate'],
		[1.4, 30.61, 'obesity', 'too much']
	);
	
	for (my $i = 0; $i <= $#tests; $i++) {
		my ($height, $expBMI, $expBMICat, $expDiffCat) = @{$tests[$i]};
		
		$expecsR = [
			[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', $expDiffCat],
			[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', 10],
			[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', 70],
			[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
			[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', $height],
			[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', $expBMI],
			[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', $expBMICat]
		];
		
		try {
			$err = "";
			$resR = "";
			
			$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
			$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
			$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
			$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
			$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
			$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
			$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
			$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
			$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, $height, $idChange)");
			$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, 70, $idChange)");
			$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
			
			$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$" .
				"]," .
				"name)");
			is ($resR, $expecsR, 'Testing "bmi category" assignment [' . ($i+1) . '/' . scalar(@tests) .']');
		}
		catch {
			$err = $_;
			print $err;
			ok (1==2, 'Testing "bmi category" assignment [' . ($i+1) . '/' . scalar(@tests) .']')
		}
		finally {
			$dbh->rollback;
		};
	}
	
	
	#------------------------------------------------------------------------------#
	# Test "category of difference in body mass at delivery" correctly assigned
	#------------------------------------------------------------------------------#
	# height, maternal body mass at delivery, expected bmi, expected bmi category,
	# expected difference in body mass at delivery, expected cat. of diff. in body mass at delivery
	@tests = (
		[1.85, 70, 17.53, 'underweight', 10, 'not enough'],
		[1.85, 75, 17.53, 'underweight', 15, 'appropriate'],
		[1.85, 80, 17.53, 'underweight', 20, 'too much'],
		[1.7, 70, 20.76, 'normal weight', 10, 'not enough'],
		[1.7, 75, 20.76, 'normal weight', 15, 'appropriate'],
		[1.7, 80, 20.76, 'normal weight', 20, 'too much'],
		[1.5, 65, 26.67, 'overweight', 5, 'not enough'],
		[1.5, 70, 26.67, 'overweight', 10, 'appropriate'],
		[1.5, 75, 26.67, 'overweight', 15, 'too much'],
		[1.4, 62, 30.61, 'obesity', 2, 'not enough'],
		[1.4, 68, 30.61, 'obesity', 8, 'appropriate'],
		[1.4, 70, 30.61, 'obesity', 10, 'too much'],
	);
	
	for (my $i = 0; $i <= $#tests; $i++) {
		my ($height, $weightAtBirth, $expBMI, $expBMICat, $expDiff, $expDiffCat) = @{$tests[$i]};
		
		$expecsR = [
			[1, 'foo', '1900-01-01', 'meconium', 'category of difference in body mass at delivery', 's', $expDiffCat],
			[1, 'foo', '1900-01-01', 'meconium', 'difference in body mass at delivery', 'i', $expDiff],
			[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass at delivery', 'i', $weightAtBirth],
			[1, 'foo', '1900-01-01', 'meconium', 'maternal body mass before pregnancy', 'i', 60],
			[1, 'foo', '1900-01-01', 'meconium', 'mother\'s height', 'i', $height],
			[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI', 'i', $expBMI],
			[1, 'foo', '1900-01-01', 'meconium', 'mother\'s pre-pregnancy BMI category', 's', $expBMICat]
		];
		
		try {
			$err = "";
			$resR = "";
			
			$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
			$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo', '1900-01-01', $idChange)");
			$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 't', $idChange)");
			$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
			$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$maternal body mass before pregnancy\$\$, 'i', NULL, $idChange)");
			$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$mother\'s height\$\$, 'i', NULL, $idChange)");
			$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (3, \$\$maternal body mass at delivery\$\$, 'i', NULL, $idChange)");
			$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 60, $idChange)");
			$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, $height, $idChange)");
			$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 1, 3, $weightAtBirth, $idChange)");
			$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
			
			$resR = $dbh->selectall_arrayref("SELECT * from v_measurements ORDER BY id_patient, createdate, array_position(array[" .
					"'category of difference in body mass at delivery', " .
					"'difference in body mass at delivery', " .
					"'maternal body mass at delivery', " .
					"'maternal body mass before pregnancy', " .
					"\$\$mother\'s height\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI\$\$, " .
					"\$\$mother\'s pre-pregnancy BMI category\$\$" .
				"]," .
				"name)");
			is ($resR, $expecsR, 'Testing "category of difference in body mass at delivery" assignment [' . ($i+1) . '/' . scalar(@tests) .']');
		}
		catch {
			$err = $_;
			print $err;
			ok (1==2, 'Testing "category of difference in body mass at delivery" assignment [' . ($i+1) . '/' . scalar(@tests) .']')
		}
		finally {
			$dbh->rollback;
		};
	}


	#------------------------------------------------------------------------------#
	# Test "z-score category" and "z-score subcategory" correctly assigned
	#------------------------------------------------------------------------------#
	# id_patient, createdate, name, value
	$expecsR = [
		[1, '1900-01-01', 'z-score category', 'AGA'],
		[1, '1900-01-01', 'z-score subcategory', 'AGA'],
		[1, '1900-04-01', 'z-score category', 'AGA'],
		[1, '1900-04-01', 'z-score subcategory', 'AGA'],
		[1, '1900-07-01', 'z-score category', 'AGA'],
		[1, '1900-07-01', 'z-score subcategory', 'AGA'],
		[1, '1901-01-01', 'z-score category', 'AGA'],
		[1, '1901-01-01', 'z-score subcategory', 'AGA'],
		[1, '1901-07-01', 'z-score category', 'AGA'],
		[1, '1901-07-01', 'z-score subcategory', 'AGA'],
		[1, '1902-01-01', 'z-score category', 'AGA'],
		[1, '1902-01-01', 'z-score subcategory', 'AGA'],
		[2, '1900-01-01', 'z-score category', 'SGA'],
		[2, '1900-01-01', 'z-score subcategory', 'SGA'],
		[2, '1900-04-01', 'z-score category', 'SGA'],
		[2, '1900-04-01', 'z-score subcategory', 'no catch-up'],
		[2, '1900-07-01', 'z-score category', 'SGA'],
		[2, '1900-07-01', 'z-score subcategory', 'no catch-up'],
		[2, '1901-01-01', 'z-score category', 'SGA'],
		[2, '1901-01-01', 'z-score subcategory', 'no catch-up'],
		[2, '1901-07-01', 'z-score category', 'SGA'],
		[2, '1901-07-01', 'z-score subcategory', 'no catch-up'],
		[2, '1902-01-01', 'z-score category', 'SGA'],
		[2, '1902-01-01', 'z-score subcategory', 'no catch-up'],
		[3, '1900-01-01', 'z-score category', 'SGA'],
		[3, '1900-01-01', 'z-score subcategory', 'SGA'],
		[3, '1900-04-01', 'z-score category', 'SGA'],
		[3, '1900-04-01', 'z-score subcategory', 'no catch-up'],
		[3, '1900-07-01', 'z-score category', 'SGA'],
		[3, '1900-07-01', 'z-score subcategory', 'no catch-up'],
		[3, '1901-01-01', 'z-score category', 'SGA'],
		[3, '1901-01-01', 'z-score subcategory', 'no catch-up'],
		[3, '1901-07-01', 'z-score category', 'SGA'],
		[3, '1901-07-01', 'z-score subcategory', 'no catch-up'],
		[3, '1902-01-01', 'z-score category', 'SGA'],
		[3, '1902-01-01', 'z-score subcategory', 'no catch-up'],
		[4, '1900-01-01', 'z-score category', 'SGA'],
		[4, '1900-01-01', 'z-score subcategory', 'SGA'],
		[4, '1900-04-01', 'z-score category', 'SGA'],
		[4, '1900-04-01', 'z-score subcategory', 'no catch-up'],
		[4, '1900-07-01', 'z-score category', 'SGA'],
		[4, '1900-07-01', 'z-score subcategory', 'early catch-up'],
		[4, '1901-01-01', 'z-score category', 'SGA'],
		[4, '1901-01-01', 'z-score subcategory', 'early catch-up'],
		[4, '1901-07-01', 'z-score category', 'SGA'],
		[4, '1901-07-01', 'z-score subcategory', 'early catch-up'],
		[4, '1902-01-01', 'z-score category', 'SGA'],
		[4, '1902-01-01', 'z-score subcategory', 'early catch-up'],
		[5, '1900-01-01', 'z-score category', 'SGA'],
		[5, '1900-01-01', 'z-score subcategory', 'SGA'],
		[5, '1900-04-01', 'z-score category', 'SGA'],
		[5, '1900-04-01', 'z-score subcategory', 'no catch-up'],
		[5, '1900-07-01', 'z-score category', 'SGA'],
		[5, '1900-07-01', 'z-score subcategory', 'no catch-up'],
		[5, '1901-01-01', 'z-score category', 'SGA'],
		[5, '1901-01-01', 'z-score subcategory', 'late catch-up'],
		[5, '1901-07-01', 'z-score category', 'SGA'],
		[5, '1901-07-01', 'z-score subcategory', 'late catch-up'],
		[5, '1902-01-01', 'z-score category', 'SGA'],
		[5, '1902-01-01', 'z-score subcategory', 'late catch-up']
	];	
	try {
		$err = "";
		$resR = "";
		
		# 5 patients, each with 6 samples: meconium, 3m, 6m, 1y, 1.5y, 2y
		# z-score category
		# 1)		AGA --> stays AGA
		# 2) - 5)	SGA	-->	stays SGA
		# z-score subcategory
		# 1) AGA --> stays AGA, even if z-score subsequently dips under -2
		# 2) SGA --> no catch-up, as z-score is always <= -2; max difference of z-scores >= 0.67
		# 3) SGA --> no catch-up: z-score > -2, but max difference of z-scores < 0.67
		# 4) SGA --> early catch-up; stays early catch-up, even if z-score subsequently dips under -2 or max difference in z-scores < 0.67
		# 5) SGA --> late catch-up; stays late catch-up, even if z-score subsequently dips under -2 or max difference in z-scores < 0.67
		$dbh->do("INSERT INTO change (id, username, ts, ip) VALUES ($idChange, 'foobar', '1234', '5678')");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (1, 'P1', 'foo1', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (2, 'P2', 'foo2', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (3, 'P3', 'foo3', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (4, 'P4', 'foo4', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO patient (id, alias, accession, birthdate, id_change) VALUES (5, 'P5', 'foo5', '1900-01-01', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (1, 1, '1900-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (2, 1, '1900-04-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (3, 1, '1900-07-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (4, 1, '1901-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (5, 1, '1901-07-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (6, 1, '1902-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (7, 2, '1900-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (8, 2, '1900-04-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (9, 2, '1900-07-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (10, 2, '1901-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (11, 2, '1901-07-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (12, 2, '1902-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (13, 3, '1900-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (14, 3, '1900-04-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (15, 3, '1900-07-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (16, 3, '1901-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (17, 3, '1901-07-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (18, 3, '1902-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (19, 4, '1900-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (20, 4, '1900-04-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (21, 4, '1900-07-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (22, 4, '1901-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (23, 4, '1901-07-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (24, 4, '1902-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (25, 5, '1900-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (26, 5, '1900-04-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (27, 5, '1900-07-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (28, 5, '1901-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (29, 5, '1901-07-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO sample (id, id_patient, createdate, createdby, iscontrol, id_change) VALUES (30, 5, '1902-01-01', NULL, 'f', $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (1, \$\$sex\$\$, 's', NULL, $idChange)");
		$dbh->do("INSERT INTO type (id, name, type, selection, id_change) VALUES (2, \$\$body mass\$\$, 'i', NULL, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 0, 0.3809, 3.2322, 0.14171, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 90, 0.0424, 5.8181, 0.12631, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 181, -0.0739, 7.2772, 0.12207, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 365, -0.2022, 8.9462, 0.12267, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 546, -0.2632, 10.2187, 0.12309, $idChange)");
		$dbh->do("INSERT INTO standard (name, sex, age, l, m, s, id_change) VALUES ('weight_for_age', 'f', 730, -0.294, 11.4741, 0.12389, $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (1, 1, 1, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (2, 1, 2, '3000', $idChange)"); # subcat: AGA # -0.52
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (3, 2, 2, '5100', $idChange)"); # subcat: AGA # -1.04
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (4, 3, 2, '5000', $idChange)"); # subcat: AGA # -3.11
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (5, 4, 2, '5000', $idChange)"); # subcat: AGA # -4.66
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (6, 5, 2, '5000', $idChange)"); # subcat: AGA # -5.52
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (7, 6, 2, '5000', $idChange)"); # subcat: AGA # -6.16
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (8, 7, 1, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (9, 7, 2, '2000', $idChange)"); # subcat: SGA # -3.09
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (10, 8, 2, '2000', $idChange)"); # subcat: no catch-up # -6.63
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (11, 9, 2, '2000', $idChange)"); # subcat: no catch-up # -7.78
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (12, 10, 2, '2000', $idChange)"); # subcat: no catch-up # -8.56
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (13, 11, 2, '1700', $idChange)"); # subcat: no catch-up # -9.33
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (14, 12, 2, '1100', $idChange)"); # subcat: no catch-up # -10.18
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (15, 13, 1, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (16, 13, 2, '2300', $idChange)"); # subcat: SGA # -2.25
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (17, 14, 2, '4600', $idChange)"); # subcat: no catch-up # -1.85
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (18, 15, 2, '5800', $idChange)"); # subcat: no catch-up # -1.87
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (19, 16, 2, '7100', $idChange)"); # subcat: no catch-up # -1.93
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (20, 17, 2, '8100', $idChange)"); # subcat: no catch-up # -1.95
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (21, 18, 2, '9100', $idChange)"); # subcat: no catch-up # -1.94
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (22, 19, 1, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (23, 19, 2, '2300', $idChange)"); # subcat: SGA # -2.25
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (24, 20, 2, '4600', $idChange)"); # subcat: no catch-up # -1.85
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (25, 21, 2, '6200', $idChange)"); # subcat: early catch-up # -1.32
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (26, 22, 2, '7200', $idChange)"); # subcat: early catch-up # -1.81
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (27, 23, 2, '7000', $idChange)"); # subcat: early catch-up # -3.21
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (28, 24, 2, '10000', $idChange)"); # subcat: early catch-up # -1.13
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (29, 25, 1, 'f', $idChange)");
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (30, 25, 2, '2300', $idChange)"); # subcat: SGA # -2.25
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (31, 26, 2, '4600', $idChange)"); # subcat: no catch-up # -1.85
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (32, 27, 2, '5800', $idChange)"); # subcat: no catch-up # -1.87
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (33, 28, 2, '7500', $idChange)"); # subcat: late catch-up # -1.46
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (34, 29, 2, '8300', $idChange)"); # subcat: late catch-up # -1.74
		$dbh->do("INSERT INTO measurement (id, id_sample, id_type, value, id_change) VALUES (35, 30, 2, '8000', $idChange)"); # subcat: late catch-up # -3.07
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		$dbh->do("REFRESH MATERIALIZED VIEW v_measurements");
		
		$resR = $dbh->selectall_arrayref("SELECT id_patient, createdate, name, value from v_measurements " .
			"WHERE name = 'z-score category' or name = 'z-score subcategory' ORDER BY id_patient asc, createdate, name asc");
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing "z-score category" assignment')
	}
	finally {
		is ($resR, $expecsR, 'Testing "z-score category" assignment');
		$dbh->rollback;
	};

	
	return $dbh;
}		

	
#
#--------------------------------------------------------------------------------------------------#
# Main
#--------------------------------------------------------------------------------------------------#
#
# Connect to the test database (has to be created before by user)
my $dbh = MetagDB::Db::connectDebug();

# Fake patient data after reading in the spreadsheet 
my %data = (
	'p1'	=> {
		'birth date'		=> '1900-01-01',
		'placeOfBirth'		=> 'NewYork',
		'hospital code'		=> '00001',
		'_times_'		=> {
			'1900-01-01'	=> {
				'number of run and barcode'	=> 'run01_bar01',
				'height'					=> '30cm',
				'program'					=> 'MetaG',
				'database'					=> 'RDP'
			},
			'1900-01-03'	=> {
				'number of run and barcode'	=> 'run02_bar01',
				'height'					=> '31cm',
				'program'					=> 'MetaG',
				'database'					=> 'RDP'
			}
		}
	}, 
	'p2'	=> {
		'birth date'		=> '1900-02-02',
		'placeOfBirth'		=> 'San Francisco',
		'hospital code'		=> '00002',
		'_times_'		=> {
			'1900-02-02'	=> {
				'number of run and barcode'	=> 'run03_bar01',
				'height'					=> '35cm',
				'program'					=> 'MetaG',
				'database'					=> 'RDP'
			},
			'1900-02-05'	=> {
				'number of run and barcode'	=> 'run04_bar01',
				'height'					=> '36cm',
				'program'					=> 'MetaG',
				'database'					=> 'RDP'
			}
		}
		
	}
);
my $rand = "";
for (my $i = 0; $i <= 30; $i++) {
	my $int = int(rand(25));
	$rand .= getLetter($int);
}
my $basePath = "/tmp/$rand";
my $taxP = "data/kraken2/tax/test/taxonomy";

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
			
	# Create the relations/indices in the test database
	$dbh->do($schema);
	$dbh->commit;
	
	# Parse table file
	print "INFO: Testing to parse the table file\n";
	test_parseTable();
	
	# Parse WHO growth standard
	print "INFO: Testing to parse the WHO growth standard\n";
	test_parseWHO();
	
	# Insert entry in change relation
	print "INFO: Testing insert in change\n";
	$dbh = test_insertChange($dbh);
	
	# Insert entry in type relation
	print "INFO: Testing insert in type\n";
	$dbh = test_insertType($dbh);
	
	# Insert entry in patient relation
	print "INFO: Testing insert in patient\n";
	$dbh = test_insertPatient($dbh, \%data);
	
	# Insert entry in sample relation
	print "INFO: Testing insert in sample\n";
	$dbh = test_insertSample($dbh, \%data);
	
	# Insert entry in measurement relation
	print "INFO: Testing insert in measurement\n";
	$dbh = test_insertMeasurement($dbh);
	
	# Insert entry in sequence relation
	print "INFO: Testing insert in sequence\n";
	$dbh = test_insertSequence($dbh, $basePath);
	
	# Insert entry in taxonomy relation
	print "INFO: Testing insert in taxonomy\n";
	$dbh = test_insertTaxonomy($dbh, $basePath, $taxP);
	
	# Insert entry in classification relation
	print "INFO: Testing insert in classification\n";
	$dbh = test_insertClassification($dbh);
	
	# Insert entry in taxclass relation
	print "INFO: Testing insert in taxclass\n";
	$dbh = test_insertTaxclass($dbh);
	
	# Insert entry in standard relation
	print "INFO: Testing insert in standard\n";
	$dbh = test_insertStandard($dbh);
	
	# Test database function f_calcseqerror
	print "INFO: Testing function f_calcseqerror\n";
	$dbh = test_f_calcseqerror($dbh);
	
	# Test database function f_calczscore
	print "INFO: Testing function f_calczscore\n";
	$dbh = test_f_calczscore($dbh);
	
	# Test select data from v_lineages.
	# This also checks that the view is working as intended.
	print "INFO: Testing select from v_lineages\n";
	$dbh = test_getLineages($dbh);
	
	# Test select data from v_metadata.
	# This also checks that the view is working as intended.
	print "INFO: Testing select from v_metadata\n";
	$dbh = test_getMeta($dbh);
	
	# Test v_samples
	print "INFO: Testing v_samples\n";
	$dbh = test_v_samples($dbh);
	
	# Test v_taxa
	print "INFO: Testing v_taxa\n";
	$dbh = test_v_taxa($dbh);
	
	# Test v_measurements
	print "INFO: Testing v_measurements\n";
	$dbh = test_v_measurements($dbh);
	
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
	
	@items = ();
	while ($schema =~ m/create\s+function\s+([a-zA-Z_]+)/ig) {
		push(@items, $1)
	}
	# Drop all functions
	for (my $i = $#items; $i >= 0; $i--) {
		$dbh->do("DROP FUNCTION $items[$i]");
	}
	
	@items = ();
	while ($schema =~ m/create\s+extension\s+([a-zA-Z_]+)/ig) {
		push(@items, $1)
	}
	# Drop all extensions
	for (my $i = $#items; $i >= 0; $i--) {
		$dbh->do("DROP EXTENSION $items[$i]");
	}
	$dbh->commit;
}
catch {
	print "ERROR: $_";
	$dbh->rollback;
}
finally {
	$dbh->disconnect;
	
	done_testing();
};