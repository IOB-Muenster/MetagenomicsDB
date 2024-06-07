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
# Tests for MetagDB::Db module
#==================================================================================================#
# DESCRIPTION
# 
#	Test the functions in the MetagDB::Db module.
#
#
# USAGE
#
# 	./test_Db.pl
#
#
# CAVEATS
# 	
#	In order to test the functions in the MetagDB::Db module that write data to a database, this
#	script expects that a database as defined in MetagDB::Db::connect exists. It will try to
#	create a test relation "foobar" in that database, so a connection error will influence most
#	subsequent tests.
#
#					
# DEPENDENCIES
# 
#	Test2::Bundle::More
#	Test2::Tools::Compare;
#	Try::Tiny
#	MetagDB::Db
#==================================================================================================#


use strict;
use warnings;

use feature 'signatures';
no warnings qw(experimental::signatures);

use Encode qw(decode encode);
use Storable qw(dclone);
use Test2::Bundle::More qw(ok done_testing);
use Test2::Tools::Compare;
use Try::Tiny;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl/";
use MetagDB::Db;


#
#--------------------------------------------------------------------------------------------------#
# Test the prepCheck function
#--------------------------------------------------------------------------------------------------#
#
sub test_connect {
	try {
		my $dbh = MetagDB::Db::connect();
		$dbh->disconnect;
		ok (1 == 1, 'Testing connect to database')
	}
	catch {
		# Always report error
		ok (1 == 2, 'Testing connect to database');
		print "ERROR: ", $_, "\n";
	};
}


#
#--------------------------------------------------------------------------------------------------#
# Test the prepGetId function.
# The field id_change is always ignored.
#--------------------------------------------------------------------------------------------------#
#
sub test_prepGetId ($dbh_mod) {
	my $dbh = "a";
	my $tableN = "b";
	my $fieldNsR = ["f1", "f2", "id_change"];
	my $valuesR = ["v1", '', 1234];
	my $idQuery = "id2";
	my $err = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no table name + no field names + no values
	# + no query)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId();
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no database handle');
	};
	

	#------------------------------------------------------------------------------#
	# Test no table name (+ no field names + no values + no query)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no table name')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no field names (+ no values + no query)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, $tableN);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no values (+ no query)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, $tableN, $fieldNsR);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no values')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no idQuery (optional argument)
	#------------------------------------------------------------------------------#
	my $sth = undef;
	my $nonNullsR = [];
	try {
		$err = "";
		
		($sth, $nonNullsR) = MetagDB::Db::prepGetId($dbh_mod, $tableN, $fieldNsR, $valuesR);
		is ($sth->{'Statement'}, 'SELECT id FROM b WHERE (f1=? AND f2 is Null)', 'Testing no query - statement');
		is ($nonNullsR, ["v1"], 'Testing no query - values that are not NULL');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing no query');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId("", $tableN, $fieldNsR, $valuesR, $idQuery);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*arguments/, 'Testing empty database handle')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty table name
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, "", $fieldNsR, $valuesR, $idQuery);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*arguments/, 'Testing empty table name')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty field names
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, $tableN, "", $valuesR, $idQuery);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*arguments/, 'Testing empty field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test field names not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, $tableN, "abc", $valuesR, $idQuery);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No field names/, 'Testing field names not a reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test field names empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, $tableN, [], $valuesR, $idQuery);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No field names/, 'Testing field names empty reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty values
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, $tableN, $fieldNsR, "", $idQuery);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*arguments/, 'Testing empty values')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test values not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, $tableN, $fieldNsR, "abc", $idQuery);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No values/, 'Testing values not a reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test values empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, $tableN, $fieldNsR, [], $idQuery);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No values/, 'Testing values empty reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test values cannot be evenly divided by field names
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, $tableN, [1, 2], [1], $idQuery);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*must be multiples of field names/, 'Testing values cannot be evenly divided by field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty idQuery
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, $tableN, $fieldNsR, $valuesR, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*arguments/, 'Testing empty idQuery')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid db handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepGetId($dbh, $tableN, $fieldNsR, $valuesR, $idQuery);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/^Can't locate object method/, 'Testing invalid database handle')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid db handle.
	# For prepare it does not matter, if the table exists or not. One value empty.
	#------------------------------------------------------------------------------#
	$sth = undef;
	$nonNullsR = [];
	try {
		$err = "";
		
		($sth, $nonNullsR) = MetagDB::Db::prepGetId($dbh_mod, $tableN, $fieldNsR, $valuesR, $idQuery);
		is ($sth->{'Statement'}, 'SELECT id2 FROM b WHERE (f1=? AND f2 is Null)', 'Testing valid db handle - statement');
		is ($nonNullsR, ["v1"], 'Testing valid db handle - values that are not NULL');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing valid db handle');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid db handle.
	# For prepare it does not matter, if the table exists or not.
	# One value is literally zero => should not be interpreted as NULL. 
	#------------------------------------------------------------------------------#
	$sth = undef;
	$nonNullsR = [];
	my $values_modR = dclone($valuesR);
	$values_modR->[1] = 0;
	
	try {
		$err = "";

		($sth, $nonNullsR) = MetagDB::Db::prepGetId($dbh_mod, $tableN, $fieldNsR, $values_modR, $idQuery);
		is ($sth->{'Statement'}, 'SELECT id2 FROM b WHERE (f1=? AND f2=?)', 'Testing one value is zero - statement');
		is ($nonNullsR, ["v1", 0], 'Testing one value is zero - values that are not NULL');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing one value is zero');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid db handle.
	# For prepare it does not matter, if the table exists or not.
	# One value just contains blanks => should be interpreted as NULL. 
	#------------------------------------------------------------------------------#
	$sth = undef;
	$nonNullsR = [];
	$values_modR = dclone($valuesR);
	$values_modR->[1] = '   ';
	
	try {
		$err = "";

		($sth, $nonNullsR) = MetagDB::Db::prepGetId($dbh_mod, $tableN, $fieldNsR, $values_modR, $idQuery);
		is ($sth->{'Statement'}, 'SELECT id2 FROM b WHERE (f1=? AND f2 is Null)', 'Testing one value only contains blanks - statement');
		is ($nonNullsR, ["v1"], 'Testing one value only contains blanks - values that are not NULL');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing one value only contains blanks');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid db handle.
	# For prepare it does not matter, if the table exists or not.
	# One value contains leading + trailing blanks => should be left untouched. 
	#------------------------------------------------------------------------------#
	$sth = undef;
	$nonNullsR = [];
	$values_modR = dclone($valuesR);
	$values_modR->[1] = ' v2 ';
	
	try {
		$err = "";

		($sth, $nonNullsR) = MetagDB::Db::prepGetId($dbh_mod, $tableN, $fieldNsR, $values_modR, $idQuery);
		is ($sth->{'Statement'}, 'SELECT id2 FROM b WHERE (f1=? AND f2=?)', 'Testing one value contains leading + trailing blanks - statement');
		is ($nonNullsR, ["v1", ' v2 '], 'Testing one value contains leading + trailing blanks - values that are not NULL');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing one value contains leading + trailing blanks');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid db handle.
	# For prepare it does not matter, if the table exists or not.
	# One value is undefined. 
	#------------------------------------------------------------------------------#
	$sth = undef;
	$nonNullsR = [];
	$values_modR = dclone($valuesR);
	$values_modR->[1] = undef;
	
	try {
		$err = "";

		($sth, $nonNullsR) = MetagDB::Db::prepGetId($dbh_mod, $tableN, $fieldNsR, $values_modR, $idQuery);
		is ($sth->{'Statement'}, 'SELECT id2 FROM b WHERE (f1=? AND f2 is Null)', 'Testing one value is undefined - statement');
		is ($nonNullsR, ["v1"], 'Testing one value is undefined - values that are not NULL');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing one value is undefined');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the prepInsert function
#--------------------------------------------------------------------------------------------------#
#
sub test_prepInsert ($dbh_mod) {
	my $dbh = "a";
	my $tableN = "b";
	my $uniqFieldNsR = ["f1", "f2"];
	my $fieldNsR = ["f1", "f2", "f3", "id_change"];
	my $maxRows = 2;
	my $err = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no table name + no unique field names
	# + no field names + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert();
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no database handle');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no table name (+ no unique field names + no field names + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no table name')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no unique field names (+ no field names + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no unique field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no field names (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN, $uniqFieldNsR);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows (optional argument)
	#------------------------------------------------------------------------------#
	my $sth = undef;
	
	try {
		$err = "";

		$sth = MetagDB::Db::prepInsert($dbh_mod, $tableN, $uniqFieldNsR, $fieldNsR);
		is ($sth->{'Statement'}, 'INSERT INTO b (f1,f2,f3,id_change) VALUES (?,?,?,?) ON CONFLICT (f1,f2) ' .
			'DO UPDATE SET f3 = EXCLUDED.f3,id_change = EXCLUDED.id_change WHERE COALESCE(b.f3::text, \'\') ' .
			'!= COALESCE(EXCLUDED.f3::text, \'\') RETURNING id_change', 'Testing no maxRows');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing no maxRows');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert("", $tableN, $uniqFieldNsR, $fieldNsR, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*arguments/, 'Testing empty database handle')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty table name
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, "", $uniqFieldNsR, $fieldNsR, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*arguments/, 'Testing empty table name')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty unique field names
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN, "", $fieldNsR, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*arguments/, 'Testing empty unique field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test unique field names not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN, "abc", $fieldNsR, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No unique field names/, 'Testing unique field names not a reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test unique field names empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN, [], $fieldNsR, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No unique field names/, 'Testing unique field names empty reference')
	};

	
	#------------------------------------------------------------------------------#
	# Test empty field names
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN, $uniqFieldNsR, "", $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*arguments/, 'Testing empty field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test field names not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN, $uniqFieldNsR, "abc", $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No field names/, 'Testing field names not a reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test field names empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN, $uniqFieldNsR, [], $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No field names/, 'Testing field names empty reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN, $uniqFieldNsR, $fieldNsR, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid value for maxRows/, 'Testing empty maxRows')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN, $uniqFieldNsR, $fieldNsR, "abc");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is 0
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN, $uniqFieldNsR, $fieldNsR, 0);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid db handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::prepInsert($dbh, $tableN, $uniqFieldNsR, $fieldNsR, $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Can't locate object method/, 'Testing invalid db handle');
	};


	#------------------------------------------------------------------------------#
	# Test valid db handle
	#------------------------------------------------------------------------------#
	$sth = "";
	try {
		$err = "";
		
		$sth = MetagDB::Db::prepInsert($dbh_mod, $tableN, $uniqFieldNsR, $fieldNsR, $maxRows);
		is ($sth->{'Statement'}, 'INSERT INTO b (f1,f2,f3,id_change) VALUES (?,?,?,?),(?,?,?,?) ON CONFLICT (f1,f2) DO ' .
			'UPDATE SET f3 = EXCLUDED.f3,id_change = EXCLUDED.id_change WHERE COALESCE(b.f3::text, \'\') ' .
			'!= COALESCE(EXCLUDED.f3::text, \'\') RETURNING id_change', 'Testing valid db handle');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing valid db handle');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};


	#------------------------------------------------------------------------------#
	# Test only possible change is id_change, as all other columns belong to
	# the unique field names.
	# => Never update
	#------------------------------------------------------------------------------#
	$sth = "";
	try {
		$err = "";
		
		my $uniqFieldNs_modR = dclone($uniqFieldNsR);
		push(@{$uniqFieldNs_modR}, 'f3');
		$sth = MetagDB::Db::prepInsert($dbh_mod, $tableN, $uniqFieldNs_modR, $fieldNsR, $maxRows);
		is ($sth->{'Statement'}, 'INSERT INTO b (f1,f2,f3,id_change) VALUES (?,?,?,?),(?,?,?,?) ON CONFLICT DO ' .
			'NOTHING RETURNING id_change', 'Testing no update');
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing no update');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	

	return;
}	


#
#--------------------------------------------------------------------------------------------------#
# Test the execute function
#--------------------------------------------------------------------------------------------------#
#
sub test_execute ($dbh) {
	my $sth = "";
	my @vals = ();
	my $err = "";
	
	#------------------------------------------------------------------------------#
	# Test no statement handle (+ no bind values)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::execute();
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no statement handle')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty statement handle (+ no bind values)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::execute($sth);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/^ERROR.*arguments/, 'Testing empty statement handle')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid statement handle (+ no bind values)
	#------------------------------------------------------------------------------#
	$sth = "a";
	try {
		$err = "";
		
		MetagDB::Db::execute($sth);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/^Can't locate object method/, 'Testing invalid statement handle')
	};

	
	#------------------------------------------------------------------------------#
	# Test bind values not a reference (+ invalid statement handle)
	#------------------------------------------------------------------------------#
	$sth = "a";
	try {
		$err = "";
		
		MetagDB::Db::execute($sth, "abc");
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*not a reference/, 'Testing bind values not a reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test INSERT in non-existent table
	#------------------------------------------------------------------------------#
	my $sthIns = "";
	@vals = ("_test_", '');
	try {
		$err = "";
		
		{
			# Redirect STDERR from function to suppress error message.
	    	local *STDERR;
	    	open STDERR, ">", "/dev/null";
	    	
			$sthIns = $dbh->prepare("INSERT INTO foobar (x,y) VALUES (?,?)");
			MetagDB::Db::execute($sthIns, \@vals);
		}
	}
	catch {
		$err = $_;
	}
	finally {
		$dbh->rollback;
		
		ok($err =~ m/relation.*does not exist/, 'Testing INSERT in non-existent table');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test SELECT from non-existent table
	#------------------------------------------------------------------------------#
	my $sthSel = "";
	try {
		$err = "";

		{
			# Redirect STDERR from function to suppress error message.
	    	local *STDERR;
	    	open STDERR, ">", "/dev/null";
	    	
			$sthSel = $dbh->prepare("SELECT * FROM foobar WHERE x = ? and y = ?");
			MetagDB::Db::execute($sthSel, \@vals);
		}
	}
	catch {
		$err = $_;
	}
	finally {
		$dbh->rollback;
		
		ok($err =~ m/relation.*does not exist/, 'Testing SELECT from non-existent table');
	};
	
	
	#------------------------------------------------------------------------------#
	# Testing
	#	INSERT: valid statement handle and valid number of bind values (one empty)
	#	SELECT: valid statement handle (+ no bind values)
	# For checking the encoding of the values, it does not matter with which
	# statement handle they are associated.
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$dbh->do("CREATE TABLE foobar (id serial primary key, x varchar(6), y int)");
		$sthIns = $dbh->prepare("INSERT INTO foobar (x,y) VALUES (?,?)");
		$sthSel = $dbh->prepare("SELECT x,y FROM foobar WHERE x = '_test_'");
		
		# Insert the data first
		MetagDB::Db::execute($sthIns, \@vals);
		
		# Now try to retrieve it.
		$sthSel = MetagDB::Db::execute($sthSel);
		my $resR = $sthSel->fetchall_arrayref;
		is ($resR, [["_test_", undef]], "Testing valid statement and valid number of bind values");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing valid statement and valid number of bind values');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Testing
	#	INSERT: valid statement handle and valid number of bind values (one empty)
	#	SELECT: valid statement handle (+ empty bind values)
	# For checking the encoding of the values, it does not matter with which
	# statement handle they are associated.
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$dbh->do("CREATE TABLE foobar (id serial primary key, x varchar(6), y int)");
		$sthIns = $dbh->prepare("INSERT INTO foobar (x,y) VALUES (?,?)");
		$sthSel = $dbh->prepare("SELECT x,y FROM foobar WHERE x = '_test_'");
		
		# Insert the data first
		MetagDB::Db::execute($sthIns, \@vals);
		
		# Now try to retrieve it.
		$sthSel = MetagDB::Db::execute($sthSel, []);
		my $resR = $sthSel->fetchall_arrayref;
		is ($resR, [["_test_", undef]], "Testing valid statement with empty bind values");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing valid statement with empty bind values');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh->rollback;
	};
	
		
	#------------------------------------------------------------------------------#
	# Testing
	#	INSERT: valid statement handle and valid number of bind values with UTF-8
	#	SELECT: valid statement handle and valid number of bind values with UTF-8
	#------------------------------------------------------------------------------#
	my $resR = "";
	@vals = (decode('UTF-8', "ąĄĆćęĘłŁńŃóÓśŚźŹżŻöÖäÄüÜß"), 11);
	
	try {
		$err = "";
		
		$dbh->do("CREATE TABLE foobar (id serial primary key, x varchar(26), y int)");
		$sthIns = $dbh->prepare("INSERT INTO foobar (x,y) VALUES (?,?)");
		$sthSel = $dbh->prepare("SELECT x,y FROM foobar WHERE x = ?");
				
		# Insert the data first
		MetagDB::Db::execute($sthIns, \@vals);
		
		# Now try to retrieve it.
		$sthSel = MetagDB::Db::execute($sthSel, [$vals[0]]);
		$resR = $sthSel->fetchall_arrayref;
		is ($resR, [\@vals], "Testing valid statement with UTF-8");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing valid statement with UTF-8');
		print "ERROR: ", encode('UTF-8', $_), "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Testing
	#	INSERT: valid statement handle and valid number of bind values. One value
	#			is literally zero. => Should not be translated to NULL.
	#	SELECT: valid statement handle and valid number of bind values
	# For checking the encoding of the values, it does not matter with which
	# statement handle they are associated.
	#------------------------------------------------------------------------------#
	$resR = "";
	@vals = ('foobar', 0);
	
	try {
		$err = "";

		$dbh->do("CREATE TABLE foobar (id serial primary key, x varchar(26), y int)");
		$sthIns = $dbh->prepare("INSERT INTO foobar (x,y) VALUES (?,?)");
		$sthSel = $dbh->prepare("SELECT x,y FROM foobar WHERE x = ?");
				
		# Insert the data first
		MetagDB::Db::execute($sthIns, \@vals);
		
		# Now try to retrieve it.
		$sthSel = MetagDB::Db::execute($sthSel, [$vals[0]]);
		$resR = $sthSel->fetchall_arrayref;
		is ($resR, [\@vals], "Testing valid statement with one value that is zero");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing valid statement with one value that is zero');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};	
	
	
	#------------------------------------------------------------------------------#
	# Testing
	#	INSERT: valid statement handle and valid number of bind values. One value
	#			contains only blanks. => Should be translated to NULL.
	#	SELECT: valid statement handle and valid number of bind values
	# For checking the encoding of the values, it does not matter with which
	# statement handle they are associated.
	#------------------------------------------------------------------------------#
	$resR = "";
	@vals = ('foobar', '   ');
	
	try {
		$err = "";
		
		$dbh->do("CREATE TABLE foobar (id serial primary key, x varchar(26), y varchar(26))");
		$sthIns = $dbh->prepare("INSERT INTO foobar (x,y) VALUES (?,?)");
		$sthSel = $dbh->prepare("SELECT x,y FROM foobar WHERE x = ?");
				
		# Insert the data first
		MetagDB::Db::execute($sthIns, \@vals);
		
		# Now try to retrieve it.
		$sthSel = MetagDB::Db::execute($sthSel, [$vals[0]]);
		$resR = $sthSel->fetchall_arrayref;
		is ($resR, [['foobar', undef]], "Testing valid statement with one value that contains only blanks");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing valid statement with one value that contains only blanks');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Testing
	#	INSERT: valid statement handle and valid number of bind values. One value
	#			contains trailing + leading blanks. => Should not be altered.
	#	SELECT: valid statement handle and valid number of bind values
	# For checking the encoding of the values, it does not matter with which
	# statement handle they are associated.
	#------------------------------------------------------------------------------#
	$resR = "";
	@vals = ('foobar', '  barfoo  ');
	
	try {
		$err = "";
		
		$dbh->do("CREATE TABLE foobar (id serial primary key, x varchar(26), y varchar(26))");
		$sthIns = $dbh->prepare("INSERT INTO foobar (x,y) VALUES (?,?)");
		$sthSel = $dbh->prepare("SELECT x,y FROM foobar WHERE x = ?");
				
		# Insert the data first
		MetagDB::Db::execute($sthIns, \@vals);
		
		# Now try to retrieve it.
		$sthSel = MetagDB::Db::execute($sthSel, [$vals[0]]);
		$resR = $sthSel->fetchall_arrayref;
		is ($resR, [\@vals], "Testing valid statement with one value that contains leading + trailing blanks");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing valid statement with one value that contains leading + trailing blanks');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Testing
	#	INSERT: valid statement handle and valid number of bind values. One value
	#			is undefined => should be encoded as NULL.
	#	SELECT: valid statement handle and valid number of bind values
	# For checking the encoding of the values, it does not matter with which
	# statement handle they are associated.
	#------------------------------------------------------------------------------#
	$resR = "";
	@vals = ('foobar', undef);
	
	try {
		$err = "";
		
		$dbh->do("CREATE TABLE foobar (id serial primary key, x varchar(26), y varchar(26))");
		$sthIns = $dbh->prepare("INSERT INTO foobar (x,y) VALUES (?,?)");
		$sthSel = $dbh->prepare("SELECT x,y FROM foobar WHERE x = ?");
				
		# Insert the data first
		MetagDB::Db::execute($sthIns, \@vals);
		
		# Now try to retrieve it.
		$sthSel = MetagDB::Db::execute($sthSel, [$vals[0]]);
		$resR = $sthSel->fetchall_arrayref;
		is ($resR, [\@vals], "Testing valid statement with one undefined value");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing valid statement with one undefined value');
		print "ERROR: $err" . "\n";
	}
	finally {
		$dbh->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test too few bind values
	#------------------------------------------------------------------------------#
	my @valsMod = ($vals[0]);
	try {
		$err = "";
		
		$dbh->do("CREATE TABLE foobar (id serial primary key, x varchar(6), y int)");
		$sthIns = $dbh->prepare("INSERT INTO foobar (x,y) VALUES (?,?)");
		
		{
			# Redirect STDERR from function to avoid error messages showing up. $_ still set.
	    	local *STDERR;
	    	open STDERR, ">", "/dev/null";
			MetagDB::Db::execute($sthIns, \@valsMod);
		}
	}
	catch {
		$err = $_;
	}
	finally {
		$dbh->rollback;
		ok ($err =~ m/failed.*called with 1 bind variable/, 'Testing too few bind values');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test too many bind values
	#------------------------------------------------------------------------------#
	@valsMod = (@vals, 2);	
	try {
		$err = "";
		
		$dbh->do("CREATE TABLE foobar (id serial primary key, x varchar(6), y int)");
		$sthIns = $dbh->prepare("INSERT INTO foobar (x,y) VALUES (?,?)");
		{
			# Redirect STDERR from function to avoid error messages showing up. $_ still set.
	    	local *STDERR;
	    	open STDERR, ">", "/dev/null";
			MetagDB::Db::execute($sthIns, \@valsMod);
		}
	}
	catch {
		$err = $_;
	}
	finally {
		$dbh->rollback;
		ok ($err =~ m/failed.*called with 3 bind variables/, 'Testing too many bind values');
	};
	

	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the insert function
#--------------------------------------------------------------------------------------------------#
#
sub test_insert ($dbh_mod) { 
	my ($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows) 
		= ("a", "b", [1, 2, 3, 1, 11, 22, undef, 1], [1, 2, 11, 22], ['a', 'b', 'c', 'id_change'], ['a', 'b'], 0, "id, CONCAT(a, '_', b)", 2);
	my $err = "";
	
	#------------------------------------------------------------------------------#
	# Test no database handle (+ no relation name + no values + no unique values +
	# no field names + no unique field names + no indicator for a new insert + no
	# id query + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert();
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no database handle')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no relation name (+ no values + no unique values + no field names + no
	# unique field names + no indicator for a new insert + no id query + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no relation name')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no values (+ no unique values + no field names + no unique field names
	# + no indicator for a new insert + no id query + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no values')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no unique values (+ no field names + no unique field names
	# + no indicator for a new insert + no id query + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no unique values')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no field names (+ no unique field names + no indicator for a new insert
	# + no id query + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no unique field names (+ no indicator for a new insert + no id query
	# + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no unique field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no indicator for a new insert (+ no id query + no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no indicator for a new insert')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no id query (+ no maxRows)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/Too few arguments/, 'Testing no query for id')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no maxRows (optional value)
	#------------------------------------------------------------------------------#
	$relation = "foobar";
	$isNew = 0;
	
	try {
		$err = "";
		
		my $expecsR = [[1, 2, 3, 1], [11, 22, undef, 1]];
		$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), c varchar(26), id_change int, unique(a, b))");
		(my $keysR, $isNew) = MetagDB::Db::insert($dbh_mod, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery);
		
		# Now try to retrieve it.
		my $sthSel = $dbh_mod->prepare("SELECT $idQuery FROM foobar");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $tmpsR = $sthSel->fetchall_arrayref;
		my %res = map{$_->[0] => $_->[1]} @{$tmpsR};
		
		$sthSel = $dbh_mod->prepare("SELECT a, b, c, id_change FROM foobar order by a asc");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $insertsR = $sthSel->fetchall_arrayref;
		
		is (\%res, $keysR, "Testing no maxRows - foreign keys");
		is ($expecsR, $insertsR, 'Testing no maxRows - inserted data');
		is ($isNew, 1, "Testing no maxRows - indicator for novel insert");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, 'Testing no maxRows');
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty database handle
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert("", $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty database handle')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty relation name
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, "", $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty relation name')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty values
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, "", $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty values')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test values not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, "abc", $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*No values/, 'Testing values not a reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test values empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, [], $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*No values/, 'Testing values empty reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty uniques
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, "", $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty uniques')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test uniques not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, "abc", $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*No unique/, 'Testing uniques not a reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test uniques empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, [], $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*No unique/, 'Testing uniques empty reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty field names
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, "", $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test field names not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, "abc", $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*No field names/, 'Testing field names not a reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test field names empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, [], $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*No field names/, 'Testing field names empty reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test too few field names (row count > row count unique fields)
	# The check tested here is rather relaxed. A more precise check is performed
	# by the prep* functions.
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, [1, 2, 3], $uniqsR, [1], $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*must represent the same number of records/, 'Testing too few field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test too many field names (row count < row count unique fields)
	# The check tested here is rather relaxed. A more precise check is performed
	# by the prep* functions.
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, [1], $uniqsR, [1, 2, 3], $uniqFieldNsR, $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*must represent the same number of records/, 'Testing too many field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty unique field names
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, "", $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty unique field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test unique field names not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, "abc", $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*No unique field names/, 'Testing unique field names not a reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test unique field names empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, [], $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*No unique field names/, 'Testing unique field names empty reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test too few unique field names (row count unique fields > row count)
	# The check tested here is rather relaxed. A more precise check is performed
	# by the prep* functions.
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, [1, 2, 3], $fieldNsR, [1], $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*must represent the same number of records/, 'Testing too few unique field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test too many unique field names (row count unique fields < row count)
	# The check tested here is rather relaxed. A more precise check is performed
	# by the prep* functions.
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, [1], $fieldNsR, [1, 2, 3], $isNew, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*must represent the same number of records/, 'Testing too many unique field names')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty indication, if new data
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, "", $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for isNew/, 'Testing empty indication, if new data')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, "abc", $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for isNew/, 'Testing indication, if new data, not a number')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test indication, if new data illegal number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, 2, $idQuery, $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid value for isNew/, 'Testing indication, if new data illegal number')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty id query
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, "", $maxRows);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty id query')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test illegal id_query (non-existent column)
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	try {
		$err = "";
		
		# Suppress error message in terminal
		local *STDERR;
		open STDERR, ">>", "/dev/null";
		
		$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), c varchar(26), id_change int, unique(a, b))");
		MetagDB::Db::insert($dbh_mod, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, "barfoo", $maxRows);
	}
	catch {
		$err = $_;
	}
	finally {
		$dbh_mod->rollback;		
		ok ($err =~ m/ERROR.*column.*does not exist/, 'Testing illegal id_query');
	};


	#------------------------------------------------------------------------------#
	# Test empty maxRows
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid value for maxRows/, 'Testing empty maxRows')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, "abc");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid value for maxRows/, 'Testing maxRows not a number')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxRows is 0
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Db::insert($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, 0);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid value for maxRows/, 'Testing maxRows is zero')
	};
	
	
	# Test the following for all data types in the schema
	my %values = (
		'varchar'	=>	'abc',
		'char'		=>	'a',
		'smallint'	=>	1,
		'integer'	=>	10,
		'numeric'	=>	10.1,
		'boolean'	=>	0,
		'date'		=>	'1900-01-01',
		'integer[]'	=>	'{10}',
	);
	foreach my $type (keys(%values)) {
		my $value = $values{$type};
		my $expec = $value;
		# Convert from PostgreSQL array notation to Perl array notation
		$expec = [$1] if ($value =~ m/^\{(.*)\}$/);
		my $values_modR = [1, 2, $value, 1, 11, 22, undef, 1];
		
		
		#------------------------------------------------------------------------------#
		# Test valid new insert
		# => no similarity to existing data
		#------------------------------------------------------------------------------#
		$isNew = 0;
		
		try {
			$err = "";
			
			my $expecsR = [[1, 2, $expec, 1], [1, 'a', $expec, 2], [11, 22, undef, 1]];
			$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), c $type, id_change int, unique(a, b))");
			$dbh_mod->do("INSERT INTO $relation (a, b, c, id_change) VALUES (1, 'a', ?, 2)", {}, ($value));
			my ($keysR, $isNew) = MetagDB::Db::insert($dbh_mod, $relation, $values_modR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
			
			# Now try to retrieve it. Skip old entry.
			my $sthSel = $dbh_mod->prepare("SELECT $idQuery FROM foobar where id_change = 1");
			$sthSel = MetagDB::Db::execute($sthSel);
			my $tmpsR = $sthSel->fetchall_arrayref;
			my %res = map{$_->[0] => $_->[1]} @{$tmpsR};
			
			$sthSel = $dbh_mod->prepare("SELECT a, b, c, id_change FROM foobar order by a,b asc");
			$sthSel = MetagDB::Db::execute($sthSel);
			my $insertsR = $sthSel->fetchall_arrayref;
			
			is (\%res, $keysR, "Testing new insert with ->$type<- - foreign keys");
			is ($expecsR, $insertsR, "Testing new insert with ->$type<- - inserted data");
			is ($isNew, 1, "Testing new insert with ->$type<- - indicator for novel insert");
		}
		catch {
			$err = $_;
			
			# Always report failed test
			ok (1==2, "Testing new insert with ->$type<-");
			print "ERROR: ", $_, "\n";
		}
		finally {
			$dbh_mod->rollback;
		};
		
		
		#------------------------------------------------------------------------------#
		# Test duplicate data in the same statement
		# => change in special column id_change does not trigger update
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			
			my $expecsR = [[1, 2, $expec, 1], [11, 22, undef, 1]];
			$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), c $type, id_change int, unique(a, b))");
			
			# Create duplicate records, but change id_change
			my @values_mod = (@{$values_modR}) x 2;
			$values_mod[11] = 2;
			$values_mod[15] = 2;
			my @uniqs_mod = (@{$uniqsR}) x 2;
			my ($keysR, $isNew) = MetagDB::Db::insert($dbh_mod, $relation, \@values_mod, \@uniqs_mod, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
			
			# Now try to retrieve them.
			my $sthSel = $dbh_mod->prepare("SELECT $idQuery FROM foobar");
			$sthSel = MetagDB::Db::execute($sthSel);
			my $tmpsR = $sthSel->fetchall_arrayref;
			my %res = map{$_->[0] => $_->[1]} @{$tmpsR};
			
			$sthSel = $dbh_mod->prepare("SELECT a, b, c, id_change FROM foobar order by a asc");
			$sthSel = MetagDB::Db::execute($sthSel);
			my $insertsR = $sthSel->fetchall_arrayref;
			
			is (\%res, $keysR, "Testing duplicate data in the same statement with ->$type<- - foreign keys");
			is ($expecsR, $insertsR, "Testing duplicate data in the same statement with ->$type<- - inserted data");
			is ($isNew, 1, "Testing duplicate data in the same statement with ->$type<- - indicator for novel insert");
		}
		catch {
			$err = $_;
			
			# Always report failed test
			ok (1==2, "Testing duplicate data in the same statement with ->$type<-");
			print "ERROR: ", $_, "\n";
		}
		finally {
			$dbh_mod->rollback;
		};
	
	
		#------------------------------------------------------------------------------#
		# Test duplicate data across statements
		# => change in special column id_change does not trigger update
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$isNew = 0;
			
			my $expecsR = [[1, 2, $expec, 2], [11, 22, undef, 2]];
			$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), c $type, id_change int, unique(a, b))");
			$dbh_mod->do("INSERT INTO $relation (id, a, b, c, id_change) VALUES (1, 1, 2, ?, 2), (2, 11, 22, NULL, 2)", {}, $value);
			my ($keysR, $isNew) = MetagDB::Db::insert($dbh_mod, $relation, $values_modR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
			
			# Now try to retrieve it.
			my $sthSel = $dbh_mod->prepare("SELECT $idQuery FROM foobar");
			$sthSel = MetagDB::Db::execute($sthSel);
			my $tmpsR = $sthSel->fetchall_arrayref;
			my %res = map{$_->[0] => $_->[1]} @{$tmpsR};
			
			$sthSel = $dbh_mod->prepare("SELECT a, b, c, id_change FROM foobar order by a asc");
			$sthSel = MetagDB::Db::execute($sthSel);
			my $insertsR = $sthSel->fetchall_arrayref;
			
			is (\%res, $keysR, "Testing duplicate data across statements with ->$type<- - foreign keys");
			is ($expecsR, $insertsR, "Testing duplicate data across statements with ->$type<- - inserted data");		
			is ($isNew, 0, "Testing duplicate data across statements with ->$type<- - indicator for novel insert");
		}
		catch {
			$err = $_;
			
			# Always report failed test
			ok (1==2, "Testing duplicate data across statements with ->$type<-");
			print "ERROR: ", $_, "\n";
		}
		finally {
			$dbh_mod->rollback;
		};
		
		
		#------------------------------------------------------------------------------#
		# Test update of existing data
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$isNew = 0;
			
			my $expecsR = [[1, 2, undef, 2], [11, 22, undef, 2]];
			$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), c $type, id_change int, unique(a, b))");
			$dbh_mod->do("INSERT INTO $relation (id, a, b, c, id_change) VALUES (1, 1, 2, ?, 1), (2, 11, 22, ?, 1)", {}, ($value)x2);
			
			# Should set column c to NULL
			my ($keysR, $isNew) = MetagDB::Db::insert($dbh_mod, $relation, [1, 2, undef, 2, 11, 22, undef, 2], [1, 2, 11, 22],
				['a', 'b', 'c', 'id_change'], ['a', 'b'], $isNew, $idQuery, $maxRows);
			
			# Now try to retrieve it.
			my $sthSel = $dbh_mod->prepare("SELECT $idQuery FROM foobar");
			$sthSel = MetagDB::Db::execute($sthSel);
			my $tmpsR = $sthSel->fetchall_arrayref;
			my %res = map{$_->[0] => $_->[1]} @{$tmpsR};
			
			$sthSel = $dbh_mod->prepare("SELECT a, b, c, id_change FROM foobar order by a asc");
			$sthSel = MetagDB::Db::execute($sthSel);
			my $insertsR = $sthSel->fetchall_arrayref;
			
			is (\%res, $keysR, "Testing insert of updated data with ->$type<- - foreign keys");
			is ($expecsR, $insertsR, "Testing insert of updated data with ->$type<- - inserted data");		
			is ($isNew, 1, "Testing insert of updated data with ->$type<- - indicator for novel insert");
		}
		catch {
			$err = $_;
			
			# Always report failed test
			ok (1==2, "Testing insert of updated data with ->$type<-");
			print "ERROR: ", $_, "\n";
		}
		finally {
			$dbh_mod->rollback;
		};
		
		
		#------------------------------------------------------------------------------#
		# Test update within the same statement
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			$isNew = 0;
			
			my $expecsR = [[1, 2, $expec, 2], [11, 22, $expec, 2]];
			$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), c $type, id_change int, unique(a, b))");
			my ($keysR, $isNew) = MetagDB::Db::insert($dbh_mod, $relation, [1, 2, undef, 1, 11, 22, undef, 1, 1, 2, $value, 2, 11, 22, $value, 2],
				[1, 2, 11, 22, 1, 2, 11, 22], ['a', 'b', 'c', 'id_change'], ['a', 'b'], $isNew, $idQuery, $maxRows);
			
			# Now try to retrieve it.
			my $sthSel = $dbh_mod->prepare("SELECT $idQuery FROM foobar");
			$sthSel = MetagDB::Db::execute($sthSel);
			my $tmpsR = $sthSel->fetchall_arrayref;
			my %res = map{$_->[0] => $_->[1]} @{$tmpsR};
			
			$sthSel = $dbh_mod->prepare("SELECT a, b, c, id_change FROM foobar order by a asc");
			$sthSel = MetagDB::Db::execute($sthSel);
			my $insertsR = $sthSel->fetchall_arrayref;
			
			is (\%res, $keysR, "Testing update within same statement with ->$type<- - foreign keys");
			is ($expecsR, $insertsR, "Testing update within same statement with ->$type<- - inserted data");		
			is ($isNew, 1, "Testing update within same statement with ->$type<- - indicator for novel insert");
		}
		catch {
			$err = $_;
			
			# Always report failed test
			ok (1==2, "Testing update within same statement with ->$type<-");
			print "ERROR: ", $_, "\n";
		}
		finally {
			$dbh_mod->rollback;
		};
	}
	

	#------------------------------------------------------------------------------#
	# Test valid new insert with special column id_change
	# => If the only column that's not in a unique constraint is id_change, only
	# inserts are allowed.
	# => Same applies, if all columns are in a unique constraint (not tested)
	# => Data type does not matter here.
	#------------------------------------------------------------------------------#
	$isNew = 0;
	
	# Remove c column
	my $values_modR = dclone($valuesR);
	splice(@{$values_modR}, 2, 1);
	splice(@{$values_modR}, 5, 1);
	my $fieldNs_modR = dclone($fieldNsR);
	splice(@{$fieldNs_modR}, 2, 1);
	
	try {
		$err = "";
		
		my $expecsR = [[1, 2, 1], [1, 'a', 2], [11, 22, 1]];
		$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), id_change int, unique(a, b))");
		$dbh_mod->do("INSERT INTO $relation (a, b, id_change) VALUES (1, 'a', 2)");
		
		my ($keysR, $isNew) = MetagDB::Db::insert($dbh_mod, $relation, $values_modR, $uniqsR, $fieldNs_modR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
		
		# Now try to retrieve it. Skip old entry.
		my $sthSel = $dbh_mod->prepare("SELECT $idQuery FROM foobar where id_change = 1");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $tmpsR = $sthSel->fetchall_arrayref;
		my %res = map{$_->[0] => $_->[1]} @{$tmpsR};
		
		$sthSel = $dbh_mod->prepare("SELECT a, b, id_change FROM foobar order by a,b asc");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $insertsR = $sthSel->fetchall_arrayref;
		
		is (\%res, $keysR, "Testing new insert, ignore any change - foreign keys");
		is ($expecsR, $insertsR, "Testing new insert, ignore any change - inserted data");
		is ($isNew, 1, "Testing new insert, ignore any change - indicator for novel insert");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, "Testing new insert, ignore any change");
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test duplicate data in the same statement with special column id_change
	# => If the only column that's not in a unique constraint is id_change, only
	# inserts are allowed.
	# => Same applies, if all columns are in a unique constraint (not tested)
	# => Data type does not matter here.
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $expecsR = [[1, 2, 1], [11, 22, 1]];
		$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), id_change int, unique(a, b))");
		
		# Create duplicate records
		my @values_mod = (@{$values_modR}) x 2;
		my @uniqs_mod = (@{$uniqsR}) x 2;
		my ($keysR, $isNew) = MetagDB::Db::insert($dbh_mod, $relation, \@values_mod, \@uniqs_mod, $fieldNs_modR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
		
		# Now try to retrieve them.
		my $sthSel = $dbh_mod->prepare("SELECT $idQuery FROM foobar");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $tmpsR = $sthSel->fetchall_arrayref;
		my %res = map{$_->[0] => $_->[1]} @{$tmpsR};
		
		$sthSel = $dbh_mod->prepare("SELECT a, b, id_change FROM foobar order by a asc");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $insertsR = $sthSel->fetchall_arrayref;
		
		is (\%res, $keysR, "Testing duplicate data in the same statement, ignore any change - foreign keys");
		is ($expecsR, $insertsR, "Testing duplicate data in the same statement, ignore any change - inserted data");
		is ($isNew, 1, "Testing duplicate data in the same statement, ignore any change - indicator for novel insert");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, "Testing duplicate data in the same statement, ignore any change");
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};


	#------------------------------------------------------------------------------#
	# Test duplicate data across statements with special column id_change
	# => If the only column that's not in a unique constraint is id_change, only
	# inserts are allowed.
	# => Same applies, if all columns are in a unique constraint (not tested)
	# => Data type does not matter here.
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$isNew = 0;
		
		my $expecsR = [[1, 2, 1], [11, 22, 1]];
		$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), id_change int, unique(a, b))");
		$dbh_mod->do("INSERT INTO $relation (id, a, b, id_change) VALUES (1, 1, 2, 1), (2, 11, 22, 1)");
		
		my ($keysR, $isNew) = MetagDB::Db::insert($dbh_mod, $relation, $values_modR, $uniqsR, $fieldNs_modR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
		
		# Now try to retrieve it.
		my $sthSel = $dbh_mod->prepare("SELECT $idQuery FROM foobar");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $tmpsR = $sthSel->fetchall_arrayref;
		my %res = map{$_->[0] => $_->[1]} @{$tmpsR};
		
		$sthSel = $dbh_mod->prepare("SELECT a, b, id_change FROM foobar order by a asc");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $insertsR = $sthSel->fetchall_arrayref;
		
		is (\%res, $keysR, "Testing duplicate data across statements, ignore any change - foreign keys");
		is ($expecsR, $insertsR, "Testing duplicate data across statements, ignore any change - inserted data");		
		is ($isNew, 0, "Testing duplicate data across statements, ignore any change - indicator for novel insert");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, "Testing duplicate data across statements, ignore any change");
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Attempt update of existing data with special column id_change
	# => If the only column that's not in a unique constraint is id_change, only
	# inserts are allowed.
	# => Same applies, if all columns are in a unique constraint (not tested)
	# => Data type does not matter here.
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$isNew = 0;
		
		my $expecsR = [[1, 2, 2], [11, 22, 2]];
		$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), id_change int, unique(a, b))");
		$dbh_mod->do("INSERT INTO $relation (id, a, b, id_change) VALUES (1, 1, 2, 2), (2, 11, 22, 2)");
		
		# Should set column c to NULL
		my ($keysR, $isNew) = MetagDB::Db::insert($dbh_mod, $relation, $values_modR, $uniqsR, $fieldNs_modR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
		
		# Now try to retrieve it.
		my $sthSel = $dbh_mod->prepare("SELECT $idQuery FROM foobar");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $tmpsR = $sthSel->fetchall_arrayref;
		my %res = map{$_->[0] => $_->[1]} @{$tmpsR};
		
		$sthSel = $dbh_mod->prepare("SELECT a, b, id_change FROM foobar order by a asc");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $insertsR = $sthSel->fetchall_arrayref;
		
		is (\%res, $keysR, "Attempt to insert updated data, ignore any change - foreign keys");
		is ($expecsR, $insertsR, "Attempt to insert updated data, ignore any change - inserted data");		
		is ($isNew, 0, "Attempt to insert updated data, ignore any change - indicator for novel insert");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, "Attempt to insert updated data, ignore any change");
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Attempt update within the same statement with special column id_change
	# => If the only column that's not in a unique constraint is id_change, only
	# inserts are allowed.
	# => Same applies, if all columns are in a unique constraint (not tested)
	# => Data type does not matter here.
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$isNew = 0;
		
		my $expecsR = [[1, 2, 1], [11, 22, 1]];
		$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), id_change int, unique(a, b))");
		my ($keysR, $isNew) = MetagDB::Db::insert($dbh_mod, $relation, [1, 2, 1, 11, 22, 1, 1, 2, 2, 11, 22, 2],
			[1, 2, 11, 22, 1, 2, 11, 22], ['a', 'b', 'id_change'], ['a', 'b'], $isNew, $idQuery, $maxRows);
		
		# Now try to retrieve it.
		my $sthSel = $dbh_mod->prepare("SELECT $idQuery FROM foobar");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $tmpsR = $sthSel->fetchall_arrayref;
		my %res = map{$_->[0] => $_->[1]} @{$tmpsR};
		
		$sthSel = $dbh_mod->prepare("SELECT a, b, id_change FROM foobar order by a asc");
		$sthSel = MetagDB::Db::execute($sthSel);
		my $insertsR = $sthSel->fetchall_arrayref;
		
		is (\%res, $keysR, "Attempt to update within same statement, ignore any change - foreign keys");
		is ($expecsR, $insertsR, "Attempt to update within same statement, ignore any change - inserted data");		
		is ($isNew, 1, "Attempt to update within same statement, ignore any change - indicator for novel insert");
	}
	catch {
		$err = $_;
		
		# Always report failed test
		ok (1==2, "Attempt to update within same statement, ignore any change");
		print "ERROR: ", $_, "\n";
	}
	finally {
		$dbh_mod->rollback;
	};
	
	
	#------------------------------------------------------------------------------#
	# Test use non-existent unique constraint with update
	# => error
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$dbh_mod->do("CREATE TABLE $relation (id serial primary key, a varchar(26), b varchar(26), c varchar(26), id_change int)");
		
		# Don't show errors on terminal
		do {
			local *STDERR;
			open STDERR, ">> /dev/null";			
			MetagDB::Db::insert($dbh_mod, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows);
		};
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*there is no unique or exclusion constraint matching/, 'Testing non-existent unique constraint with update');
		$dbh_mod->rollback;
	};
	
	
	return;
}	


#
#--------------------------------------------------------------------------------------------------#
# Main
#--------------------------------------------------------------------------------------------------#
#
print "INFO: Testing connect function\n";
test_connect();

my $dbh = MetagDB::Db::connectDebug();

print "INFO: Testing prepGetId function\n";
test_prepGetId($dbh);

print "INFO: Testing prepInsert function\n";
test_prepInsert($dbh);

print "INFO: Testing execute function\n";
test_execute($dbh);

print "INFO: Testing insert function\n";
test_insert($dbh);

$dbh->disconnect();

done_testing();