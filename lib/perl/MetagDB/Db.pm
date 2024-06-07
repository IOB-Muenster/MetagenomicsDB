package MetagDB::Db;

# AUTHOR

# Felix Manske, felix.manske@uni-muenster.de
# Norbert Grundmann, ngrundma@uni-muenster.de

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

use v5.22;
use strict;
use warnings;

use feature 'signatures';
no warnings qw(experimental::signatures);

use DBI;
use Try::Tiny;

#
#--------------------------------------------------------------------------------------------------#
# Connect to the database and return the database handle.
#--------------------------------------------------------------------------------------------------#
#
sub connect {
	# Commit only after calling commit explicitly; print warnings; die on error and show statement text
	# with warnings/errors
	my $dbh = DBI->connect(
		"dbi:Pg:service=metagdb",
		undef,
		undef,
		{
			AutoCommit         => 0,
			PrintWarn          => 1,
			RaiseError         => 1,
			ShowErrorStatement => 1
		}
	);

	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Connect to a test database for debugging
#--------------------------------------------------------------------------------------------------#
#
sub connectDebug {
	my $dbh = "";
	try {
		# Commit only after calling commit explicitly; print warnings; die on error and show statement text
		# with warnings/errors
		$dbh = DBI->connect(
			"dbi:Pg:service=debug",
			undef,
			undef,
			{
				AutoCommit => 0,
				PrintWarn => 1,
				RaiseError => 1,
				ShowErrorStatement => 1
			}
		);
	}
	catch {
		die "ERROR: $_", "\n", "HINT: Did you create the service ->debug<- and the respective database?"
	};
	
	return $dbh;
}


#
#--------------------------------------------------------------------------------------------------#
# Excecute a statement handle using the provided bind values, if applicable. Return the statement
# handle.
#--------------------------------------------------------------------------------------------------#
#
sub execute ($sth, $valsR = []) {
	foreach my $param ($sth, $valsR) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}

	# valsR needs to be a reference
	if (not ref($valsR)) {
		die "ERROR: Values not a reference";
	}

	# Empty values need to be undef to be recognized as NULL.
	# Literal "0" should not be changed
	my @values = map {
		if (defined $_ and $_ =~ m/^\s*$/) {$_ = undef}
		else                               {$_}
	} @{$valsR};

	if (@values) {
		$sth->execute(@values);
	}
	else {
		$sth->execute();
	}

	return $sth;
}

#
#--------------------------------------------------------------------------------------------------#
# Insert records (if necessary) and indicate, if records were already present in the database.
# Returns a hash with foreign keys of the records that were requested to be inserted (including
# those already present in the database).
# valuesR and fieldNsR relate to all fields that should be inserted for each record.
# uniqsR and uniqFieldNsR relate to fields that uniquely identify each record to retrieve its
# id and further metadata via the idQuery. They can be identical to the inserted fields, but
# performance is improved, if large fields that are not necessary for the id query are not part
# of the uniq*.
#--------------------------------------------------------------------------------------------------#
#
sub insert ($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $isNew, $idQuery, $maxRows = 1) {
	foreach my $param ($dbh, $relation, $valuesR, $uniqsR, $fieldNsR, $uniqFieldNsR, $idQuery) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	if (not ref($valuesR) or not @{$valuesR}) {
		die "ERROR: No values or not a reference";
	}
	if (not ref($uniqsR) or not @{$uniqsR}) {
		die "ERROR: No unique values or not a reference";
	}
	if (not ref($fieldNsR) or not @{$fieldNsR}) {
		die "ERROR: No field names or not a reference";
	}
	if (not ref($uniqFieldNsR) or not @{$uniqFieldNsR}) {
		die "ERROR: No unique field names or not a reference";
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") . "<-";
	}
	if (not defined $isNew or $isNew !~ m/^[0,1]$/) {
		die "ERROR: Invalid value for isNew ->" . ($isNew // "") . "<-";
	}

	my @values      = @{$valuesR};
	my @fieldNs     = @{$fieldNsR};
	my @uniqs       = @{$uniqsR};
	my @uniqFieldNs = @{$uniqFieldNsR};

	my $sthIns        = "";
	my $sthSel        = "";
	my $rowCount      = scalar(@values) / scalar(@fieldNs);
	my $maxFields     = $maxRows * scalar(@fieldNs);
	my $rowCountUniq  = scalar(@uniqs) / scalar(@uniqFieldNs);
	my $maxFieldsUniq = $maxRows * scalar(@uniqFieldNs);
	my $nonNullsR     = {};
	my $keysR         = {};

	die "ERROR: Values for unique fields and values for fields must represent the same number of records"
	  if ($rowCount != $rowCountUniq);

	# Too many records --> insert in batches
	if ($rowCount > $maxRows) {
		$sthIns = MetagDB::Db::prepInsert($dbh, $relation, \@uniqFieldNs, \@fieldNs, $maxRows);
		my @tmps     = ();
		my @tmpUniqs = ();
		while (@values) {
			@tmps     = splice(@values, 0, $maxFields);
			@tmpUniqs = splice(@uniqs,  0, $maxFieldsUniq);

			# Take the remainder (less rows than maxRows) and put it back to values/uniqs
			# --> indicates separate insert
			if (scalar(@tmps) < $maxFields) {
				@values = @tmps;
				@uniqs  = @tmpUniqs;
				last;
			}

			$sthIns = MetagDB::Db::execute($sthIns, \@tmps);

			# Just fetch one row. Enough to see, if any new record
			# was inserted or not.
			my $return = $sthIns->fetchrow_arrayref || undef;

			# If an insert happened, an ID is returned
			if (defined $return) {
				$isNew = 1 if ($return->[0]);
			}

			# Fetch foreign keys. Has to be prepared everytime, as NULLs need special treatment
			# in WHERE.
			($sthSel, $nonNullsR) = MetagDB::Db::prepGetId($dbh, $relation, \@uniqFieldNs, \@tmpUniqs, $idQuery);
			$sthSel = MetagDB::Db::execute($sthSel, $nonNullsR);
			my $resR = $sthSel->fetchall_arrayref;
			foreach my $rowR (@{$resR}) {
				$keysR->{$rowR->[0]} = $rowR->[1];
			}
		}
	}

	# Insert (the rest) at once
	if (@values) {
		$rowCount = scalar(@values) / scalar(@fieldNs);
		$sthIns   = MetagDB::Db::prepInsert($dbh, $relation, \@uniqFieldNs, \@fieldNs, $rowCount);
		$sthIns   = MetagDB::Db::execute($sthIns, \@values);

		# Just fetch one row. Enough to see, if any new record
		# was inserted or not.
		my $return = $sthIns->fetchrow_arrayref || undef;

		# If an insert happened, an ID is returned
		if (defined $return) {
			$isNew = 1 if ($return->[0]);
		}

		# Fetch foreign keys
		($sthSel, $nonNullsR) = MetagDB::Db::prepGetId($dbh, $relation, \@uniqFieldNs, \@uniqs, $idQuery);
		$sthSel = MetagDB::Db::execute($sthSel, $nonNullsR);
		my $resR = $sthSel->fetchall_arrayref;
		foreach my $rowR (@{$resR}) {
			$keysR->{$rowR->[0]} = $rowR->[1];
		}
	}

	return $keysR, $isNew;
}

#
#--------------------------------------------------------------------------------------------------#
# Prepare a statement handle to get information ($getQuery) for one or multiple record(s) from the
# database. Returns the handle with placeholders and an array reference of values that are not NULL.
#--------------------------------------------------------------------------------------------------#
#
sub prepGetId ($dbh, $tableN, $fieldNsR, $valuesR, $getQuery = "id") {
	foreach my $param ($dbh, $tableN, $fieldNsR, $valuesR, $getQuery) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	if (not ref($fieldNsR) or not @{$fieldNsR}) {
		die "ERROR: No field names or not a reference";
	}
	if (not ref($valuesR) or not @{$valuesR}) {
		die "ERROR: No values or not a reference";
	}

	my @fieldNs  = @{$fieldNsR};
	my @values   = @{$valuesR};
	my @nonNulls = ();

	if (scalar(@values) % scalar(@fieldNs) != 0) {
		die "ERROR: Values must be multiples of field names. Found ->"
		  . scalar(@values)
		  . "<- vs ->"
		  . scalar(@fieldNs) . "<-";
	}

	# Empty values must be encoded as "is Null" in where
	my $where = "";
	while (@values) {
		my $tmp = "(";
		for (my $i = 0 ; $i <= $#fieldNs ; $i++) {

			# Skip id_change
			if ($fieldNs[$i] eq "id_change") {
				next;
			}

			my $val = $values[$i];

			# Literal "0" should not be encoded as NULL
			if (defined $val and $val =~ m/^\s*$/) {
				$val = undef;
			}
			if (not defined $val) {
				$tmp .= $fieldNs[$i] . " is Null AND ";
			}
			else {
				$tmp .= $fieldNs[$i] . "=? AND ";
				push(@nonNulls, $values[$i]);
			}
		}
		$tmp =~ s/ AND $/) OR /;
		$where .= $tmp;
		splice(@values, 0, scalar(@fieldNs));
	}
	$where =~ s/ OR $//;
	my $statement = "SELECT $getQuery FROM $tableN WHERE $where";
	my $sth       = $dbh->prepare($statement);

	return $sth, \@nonNulls;
}

#
#--------------------------------------------------------------------------------------------------#
# Prepare a statement handle to insert one or multiple record(s) into the database.
# If the record exists and there are changes, it is automatically updated.
# Returns the handle with placeholders.
#
# Drawback: Cannot use indices that enforce uniqueness using COALESCE
# as conflict targets for ON CONFLICT DO UPDATE. This is relevant for columns
# which can contain NULLs on versions prior to PostgreSQL version 15.
#--------------------------------------------------------------------------------------------------#
#
sub prepInsert ($dbh, $tableN, $uniqFieldNsR, $fieldNsR, $maxRows = 1) {
	foreach my $param ($dbh, $tableN, $uniqFieldNsR, $fieldNsR) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	if (not ref($uniqFieldNsR) or not @{$uniqFieldNsR}) {
		die "ERROR: No unique field names or not a reference";
	}
	if (not ref($fieldNsR) or not @{$fieldNsR}) {
		die "ERROR: No field names or not a reference";
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") . "<-";
	}

	my @fieldNs  = @{$fieldNsR};
	my @uniqFieldNs = @{$uniqFieldNsR};
	my @bindsRow = ("?") x @fieldNs;

	# Binds for multirow insert
	my @bindsTotal = ("(" . join(",", @bindsRow) . ")") x $maxRows;
	
	# Only keep column names that don't appear in uniqFieldNs
	# to create the list of columns to be updated and the list
	# of columns that must be different for an update to happen.
	my %uniqs = map {$_ => undef} @uniqFieldNs;
	my @updates = ();
	my @wheres = ();
	foreach my $fN (@fieldNs) {
		next if (exists $uniqs{$fN});
		push (@updates, $fN . ' = EXCLUDED.' . $fN);
		# Don't use special column id_change in WHERE, but should be
		# updated.
		next if ($fN eq 'id_change');
		# NULL values in WHERE are problematic --> set to ''.
		# Convert field values temporarily to 'text', so expression works with
		# all data types
		push (@wheres, 'COALESCE(' . $tableN . '.' . $fN . '::text, \'\') != COALESCE(EXCLUDED.' . $fN . '::text, \'\')');
	}

	# Will insert a new record, if the values in the columns that uniquely
	# identify each record (@uniqFieldNs) are different from any other record in
	# the database. If a match is found,the record is only updated, if at least
	# one value in one field is different.
	# Will return at least one id_change, if changes were made (insert, update) and
	# undef, if all records already appear in the database.
	# -> Easy way to check, if there was at least one new record.
	my $statement = "";
	
	# All but the id_change is the same --> never update.
	# No conflict target indicates that all available
	# constraints should be used.
	if (not @wheres) {
		$statement =
			"INSERT INTO $tableN ("
		  . join(",", @fieldNs)
		  . ") VALUES "
		  . join(",", @bindsTotal)
		  . " ON CONFLICT DO NOTHING RETURNING id_change";
	}
	else {
		$statement =
			"INSERT INTO $tableN ("
		  . join(",", @fieldNs)
		  . ") VALUES "
		  . join(",", @bindsTotal)
		  . " ON CONFLICT ("
		  . join(",", @uniqFieldNs)
		  . ") DO UPDATE SET "
		  . join(",", @updates)
		  . " WHERE "
		  . join(" OR ", @wheres)
		  . " RETURNING id_change";
	}
	my $sth = $dbh->prepare($statement);

	return $sth;
}

1;
