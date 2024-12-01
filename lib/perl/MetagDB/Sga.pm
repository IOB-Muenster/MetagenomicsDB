package MetagDB::Sga;


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

use v5.22;
use strict;
use warnings;

use feature 'signatures';
no warnings qw(experimental::signatures);

use Data::Dumper;
use Spreadsheet::Read;
use Storable qw(dclone);
use Try::Tiny;

use lib '../';
use MetagDB::Db;
use MetagDB::Fastq;
use MetagDB::Helpers;
use MetagDB::Utils;
use MetagDB::Table;
use MetagDB::Taxa;


#
#-------------------------------------------------------------------------------------------------#
# Parse expanded tables of z-scores and extract age, l, m, and s. Tested with weight for age.
#
# *) https://cdn.who.int/media/docs/default-source/child-growth/child-growth-standards/indicators/
#		weight-for-age/expanded-tables/wfa-girls-zscore-expanded-tables.xlsx
# *) https://cdn.who.int/media/docs/default-source/child-growth/child-growth-standards/indicators/
#		weight-for-age/expanded-tables/wfa-boys-zscore-expanded-tables.xlsx
#-------------------------------------------------------------------------------------------------#
#
sub parseWHO ($girlsF, $boysF) {
	foreach my $param ($girlsF, $boysF) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	
	my $girlsData = MetagDB::Helpers::readFile($girlsF);
	my $boysData = MetagDB::Helpers::readFile($boysF);
		
	my @out = ();
	foreach my $sex ('f', 'm') {
		my $sheetR = "";
		try {
			if ($sex eq 'f') {
				$sheetR = ReadData(\$girlsData, parser=>'xlsx', strip=>3); 
			}
			else {
				$sheetR = ReadData(\$boysData, parser=>'xlsx', strip=>3);
			}
		}
		catch {
			die "ERROR: Could not parse spreadsheet ->$_<-";	
		};
		die "ERROR: Could not parse spreadsheet" if (not $sheetR);
		die "ERROR: More than one sheet found" if (@{$sheetR} > 2);
		
		my $maxRow = $sheetR->[1]->{'maxrow'};
		die "ERROR: Empty sheet" if (not $maxRow or $maxRow == 0);
		
		# Loop over all rows and extract the formatted values.
		# Skip header and any columns holding additional values
		for (my $i = 2; $i<=$maxRow; $i++) {
			my @tmps = (Spreadsheet::Read::row($sheetR->[1], $i))[0..3];
			foreach my $tmp (@tmps) {
				if (not defined $tmp or $tmp =~ m/^\s*$/) {
					die "ERROR: Empty value in row ->" . Dumper(\@tmps) . "<-"
				}
			}			
			push (@out, [$sex, @tmps]);
		}
	}	
	return \@out;
}


#
#-------------------------------------------------------------------------------------------------#
# Read table file with the patient metadata
#
# If provided, format must include an extension for the archive type, if applicable.
# E.g. zipped XLSX => format = "xlsx.zip"
#-------------------------------------------------------------------------------------------------#
#
sub parseTable ($tableFile, $format = "" ) {
	if (not $tableFile or not defined $tableFile) {
		die "ERROR: Not enough arguments"
	}
		
	# Try to guess the format from the file extension, if needed
	if (not $format) {
		$format = $1 if ($tableFile =~ m/\.(([a-z]{0}|[0-9a-z]{2,4})\.??[0-9a-z]{2,4})$/);
	}
	die "ERROR: No file format provided and guessing failed" if (not $format);
	
	# Indices of fields that should be extracted from the table file
	my %targetFields = (
		"id"			=>	[0],
		"timepoint"		=>	[5],
		"static"		=>	[1, 2, 3, 9, 13, 15, 16, 17, 22, 23, 24],
		"measurement"	=>	[6, 10, 11, 12, 25, 26, 27]
	);
	
	# Column names that contain dates, aside from the timepoint column
	my %dates = (
		'birth date' => undef,
		'mother\'s birth date'  => undef,
	);
	
	# Slurp the file. Error handling, e.g. missing file done here.
	my $cont = "";
	$cont = MetagDB::Helpers::readFile($tableFile);
	
	# Check, if file is compressed. UNIX file command has issues with
	# Excel vs ZIP files. Thus, checking the file extension/provided
	# format is a workaround.
	if ($format =~ m/\.gz$/ or $format =~ m/\.zip$/ or $format =~ m/\.bz2$/) {
		# No nested archives! Excel + ODS files are themselves compressed, but should not
		# be extracted.
		$cont = MetagDB::Helpers::extractValue($cont, 1);
		
		# Remove last file extension, so format is correctly
		# recognized by Table::read
		$format =~ s/\.gz$|\.zip$|\.bz2$//
	}
	# Also block contents containing just a literal 0
	die "ERROR: Empty table file." if (not $cont or $cont =~ m/^\s+$/);	
	
	# Extract the relevant data
	my $dataR = MetagDB::Table::read($cont, \%targetFields, $format, \%dates);
	
	
	return $dataR;
}


#
#--------------------------------------------------------------------------------------------------#
# Insert a record into the change relation.
#--------------------------------------------------------------------------------------------------#
#
sub insertChange ($dbh) {
	die "ERROR: Not enough arguments" if (not $dbh or not defined $dbh);
	
	my @row = $dbh->selectrow_array("INSERT INTO change (username, ts, ip) VALUES (?,?,?) RETURNING id", {},
		($dbh->{pg_user}, time, MetagDB::Utils::toSQL("127.0.0.1", "ip")));
	die "ERROR: Registration of change ID failed" if (not @row);
	my $idChange = $row[0];
	

	return $idChange;
}


#
#-------------------------------------------------------------------------------------------------#
# Insert into patient relation.
#-------------------------------------------------------------------------------------------------#
#
sub insertPatient ($dbh, $dataR, $idChange, $isNew, $maxRows = 1) {	
	foreach my $param ($dbh, $dataR, $idChange) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	if (not defined $isNew or $isNew !~ m/^[0,1]$/) {
		die "ERROR: Not enough arguments."
	}
	# Empty hash or no ref
	if (not ref($dataR) or not %{$dataR}) {
		die "ERROR: No data or not a reference";
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") ."<-";
	}
		
	my $relation = "patient";	
	my @fieldNs = (
		'alias',
		'accession',
		'birthdate',
		'id_change'
	);
	my @uniqFieldNs = (
		'alias',
		'accession',
		'birthdate'
	);
	
	# Prepare data for insert
	my @values = ();
	
	# Values for fields that uniquely identify each record
	my @uniqs = ();
	
	my %dups = ();
	foreach my $pat (keys(%{$dataR})) {
		my $accession = $dataR->{$pat}->{'hospital code'};
		my $birthdate = $dataR->{$pat}->{'birth date'};
		my $key = ($accession // "") . "_" . $pat . "_" . ($birthdate // "");
		
		# Skip records that will be inserted in the current session
		if (exists $dups{$key}) {
			next;
		}
		else {
			push (@uniqs, $pat);
			push (@uniqs, $dataR->{$pat}->{'hospital code'} // undef);
			push (@uniqs, $dataR->{$pat}->{'birth date'} // undef);
			
			push (@values, $pat);
			push (@values, $dataR->{$pat}->{'hospital code'} // undef);
			push (@values, $dataR->{$pat}->{'birth date'} // undef);
			push (@values, $idChange);

			$dups{$key} = undef;
		}
	}
	
	# Insert data and get foreign keys
	my $idQuery = "CONCAT(accession, '_', alias, '_', birthdate) AS key, id";
	(my $keysR, $isNew) = MetagDB::Db::insert($dbh, $relation, \@values, \@uniqs, \@fieldNs, \@uniqFieldNs, $isNew, $idQuery, $maxRows);
	
	# Sanity check: The number of foreign keys that are returned should equal
	# the number of unique records
	die "ERROR: Number of foreign keys does not equal the number of unique records" if (scalar(keys(%{$keysR})) != scalar(keys(%dups)));
	
	return $dataR, $keysR, $isNew;
}


#
#-------------------------------------------------------------------------------------------------#
# Insert into sample relation.
#-------------------------------------------------------------------------------------------------#
#
sub insertSample ($dbh, $dataR, $keysR, $idChange, $isNew, $maxRows = 1) {
	foreach my $param ($dbh, $dataR, $keysR, $idChange) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	# Empty hash or no ref
	foreach my $param ($dataR, $keysR) {
		if (not ref($param) or not %{$param}) {
			die "ERROR: No data or no keys";
		}
	}
	if (not defined $isNew or $isNew !~ m/^[0,1]$/) {
		die "ERROR: Not enough arguments."
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") ."<-";
	}
	
	my $relation = "sample";	
	my @fieldNs = (
		'id_patient',
		'createdate',
		'iscontrol',
		'id_change'
	);
	my @uniqFieldNs = (
		'id_patient',
		'createdate',
		'iscontrol',
	);
	
	# Prepare data for insert
	my @values = ();
	
	# Values for fields that uniquely identify each record
	my @uniqs = ();
	
	# First sample date for each patient
	my %firstDate = ();
	
	my %dups = ();
	foreach my $pat (keys(%{$dataR})) {
		my $accession = $dataR->{$pat}->{'hospital code'};
		my $birthdate = $dataR->{$pat}->{'birth date'};
		my $key = ($accession // "") . "_" . $pat . "_" . ($birthdate // "");
		
		# Get the foreign key
		my $idPat = $keysR->{$key} || undef;
		die "ERROR: Patient ->$key<- does not exist in foreign keys hash" if (not defined $idPat);
		
		foreach my $sample (keys (%{$dataR->{$pat}->{"_times_"}})) {
			# Store the earliest sample date for each patient
			if (not exists $firstDate{$key}) {
				$firstDate{$key} = $sample;
			}
			else {
				if ($sample lt $firstDate{$key}) {
					$firstDate{$key} = $sample
				}
			}
						
			foreach my $isControl ("f", "t") {
				die "ERROR: Special key ->_isControl_<- may not be used as measurement name" if (exists $dataR->{$pat}->{"_times_"}->{$sample}->{'_isControl_'});
		
				my $key = $idPat . "_" . $sample . "_" . $isControl;
				# Skip records that were inserted in the current session
				if (exists $dups{$key}) {
					next;
				}
				else {
					push (@uniqs, $idPat);
					push (@uniqs, $sample);
					push (@uniqs, $isControl);
					
					push (@values, $idPat);
					push (@values, $sample);
					push (@values, $isControl);
					push (@values, $idChange);
		
					$dups{$key} = undef;
				}
			}
		}
	}
	
	my $keysSampleR = {};
	if (@values) {
		# Insert data and get foreign keys
		my $idQuery = "id, CONCAT_WS('_', (SELECT CONCAT_WS('_', COALESCE(accession, ''), COALESCE(alias, ''), COALESCE(birthdate::varchar, '')) " .
			"FROM patient p WHERE p.id = $relation.id_patient), createdate, iscontrol) AS key";
		
		# Check, if the first sample date in current transaction is the overall first sample date
		# => later assign static measurement to first date in current transaction only,
		# if it is the overall first date.
		my @pats = keys(%firstDate);
		my $bind = join(',', (('?') x scalar(@pats)));
		my $resR = $dbh->selectall_arrayref(
			"WITH tmp (key, createdate) AS (SELECT CONCAT_WS('_', COALESCE(accession, ''), COALESCE(alias, ''), COALESCE(birthdate::varchar, '')), " .
				"createdate FROM patient p INNER JOIN sample s ON p.id = s.id_patient WHERE iscontrol = 'f')" .
				"SELECT DISTINCT ON (key) key, createdate FROM tmp WHERE key IN (" . $bind . ") ORDER BY key ASC, createdate ASC", {}, keys(%firstDate));
				
		foreach my $rowR (@{$resR}) {
			my ($alias, $date) = @{$rowR};
			if (exists $firstDate{$alias}) {
				# This assumes that, if the patient is in the database, the date
				# in the db is the very first one. It is not possible to add an earlier date
				# in subsequent transactions, as this would require to move the static measurements
				# from the previously first date to the current first date which is currently not
				# supported.
				die "ERROR: Not possible to set a new first date for patient ->$alias<-" if ($date gt $firstDate{$alias});				
				delete $firstDate{$alias} if($firstDate{$alias} ne $date);
			}
			else {
				die "ERROR: Internal error."
			}
		}
		
		($keysSampleR, $isNew) = MetagDB::Db::insert($dbh, $relation, \@values, \@uniqs, \@fieldNs, \@uniqFieldNs, $isNew, $idQuery, $maxRows);

		# Store additional metadata in keys hash
		foreach my $id (keys(%{$keysSampleR})) {
			my ($accession, $alias, $birthdate, $sample, $isControl) = split ("_", $keysSampleR->{$id});
			$keysSampleR->{$id} = {%{$dataR->{$alias}->{"_times_"}->{$sample}}, '_isControl_' => $isControl};
			my $pid = $accession . "_" . $alias . "_" . $birthdate;
			
			# Assign static measurements (e.g. mother's birth date) arbitrarily to first sample date of a case sample.
			# A patient is not in firstDate, if its overall first sample date is not part of this transaction.
			if (exists $firstDate{$pid} and $firstDate{$pid} eq $sample and $isControl eq 'f') {
				foreach my $key (keys(%{$dataR->{$alias}})) {
					next if ($key eq '_times_' or $key eq 'hospital code' or $key eq 'birth date');
					if (exists $keysSampleR->{$id}->{$key}) {
						die "ERROR: Static measurement and time-dependent measurement have the same name ->$key<-"
					}
					else {
						$keysSampleR->{$id}->{$key} = $dataR->{$alias}->{$key}
					}
				}
			}
		}
		
		# Sanity check: The number of foreign keys that are returned should equal
		# the number of unique records
		die "ERROR: Number of foreign keys does not equal the number of unique records" if (scalar(keys(%{$keysSampleR})) != scalar(keys(%dups)));
	}
	
	
	# Sanity check the generation of timepoint strings from createdates in v_samples.
	# The problem is that timepoint strings have to be fuzzy.
	# There is a special "isok" column in the view v_samples which is 'f' on error.
	my @ids = keys(%{$keysSampleR});
	if (@ids) {
		my $isErr = 0;
		my $errMsg = "";
		my $bind = join(", ", ("?") x scalar(@ids));
		
		$dbh->do("REFRESH MATERIALIZED VIEW v_samples");
		my $tmpsR = $dbh->selectall_arrayref("SELECT timepoint, alias, createdate, iscontrol FROM v_samples WHERE isok = 'f' AND id IN ($bind)", {}, @ids);
		foreach my $rowR (@{$tmpsR}) {
			if (@{$rowR}) {
				$errMsg .= "ERROR: Timepoint ->" . ($rowR->[0] // "") . "<- for patient ->" . ($rowR->[1] // "") .
					"<-, create date ->" . ($rowR->[2] // "") . "<-, and iscontrol ->" . ($rowR->[3] // "") . "<- is invalid or not unique\n";
				$isErr = 1;
			}
		}
		die $errMsg if ($isErr == 1);
	}
	
	
	return $dataR, $keysSampleR, $isNew;
}


#
#-------------------------------------------------------------------------------------------------#
# Insert into type relation.
#-------------------------------------------------------------------------------------------------#
#
sub insertType ($dbh, $idChange, $isNew, $maxRows = 1) {
	foreach my $param ($dbh, $idChange) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	if (not defined $isNew or $isNew !~ m/^[0,1]$/) {
		die "ERROR: Not enough arguments."
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") ."<-";
	}
	
	my $relation = "type";
	
	# name => [type, [selection opts.]]
	# types: i = integer, s = string, d = date, b = boolean
	my %types = (
		"sex"									=> ['s', '{m, f, NA}'],
		"body mass"								=> ['i', undef],
		"birth mode"							=> ['s', '{natural, caesarean section}'],
		"feeding mode"							=> ['s', '{breastfed, formula, mixed, diet extension}'],
		"probiotics"							=> ['b', '{yes, no}'],
		"antibiotics"							=> ['b', '{yes, no}'],
		"mother's birth date"					=> ['d', undef],
		"maternal body mass before pregnancy"	=> ['i', undef],
		"maternal body mass at delivery"		=> ['i', undef],
		"mother's height"						=> ['i', undef],
		"pregnancy order"						=> ['i', undef],
		"maternal illness during pregnancy"		=> ['s',
			'{diabetes, thyroid disease, hypertension, diabetes + thyroid disease, diabetes + hypertension, ' .
			'thyroid disease + hypertension, diabetes + thyroid disease + hypertension}'],
		"maternal antibiotics during pregnancy"	=> ['b', '{yes, no}']		
	);
	
	my @values = map {$_, @{$types{$_}}, $idChange} keys(%types);
	my @uniqs = keys(%types);
	my @fieldNs = ("name", "type", "selection", "id_change");
	my @uniqFieldNs = ("name");
	my $idQuery = "name, id";
	
	(my $keysR, $isNew) = MetagDB::Db::insert($dbh, $relation, \@values, \@uniqs, \@fieldNs, \@uniqFieldNs, $isNew, $idQuery, $maxRows);
	
	return $keysR, $isNew;
}


#
#-------------------------------------------------------------------------------------------------#
# Insert into measurement relation.
#-------------------------------------------------------------------------------------------------#
#
sub insertMeasurement ($dbh, $keysSampleR, $keysTypeR, $idChange, $isNew, $maxRows = 1) {
	foreach my $param ($dbh, $keysSampleR, $keysTypeR, $idChange) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	# Empty hash or no ref
	foreach my $param ($keysSampleR, $keysTypeR) {
		if (not ref($param) or not %{$param}) {
			die "ERROR: No sample keys or no type keys";
		}
	}
	if (not defined $isNew or $isNew !~ m/^[0,1]$/) {
		die "ERROR: Not enough arguments."
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") ."<-";
	}
	
	my $relation = "measurement";
	
	# Measurements that should be ignored for this relation
	my %blacklist = (
		'_isControl_'				=> undef,
		'program'					=> undef,
		'database'					=> undef,
		'number of run and barcode'	=> undef,
	);
	
	# Dictionary to translate selected measurement values
	my %dict = (
		"sex"	=>	{
			1	=>	"m",
			2	=>	"f"
		},
		"birth mode"	=>	{
			1	=>	"natural",
			2	=>	"caesarean section"
		},
		"feeding mode"	=>	{
			1	=>	"breastfed",
			2	=>	"formula",
			3	=>	"mixed",
			4	=>	"diet extension"
		},
		"probiotics"	=>	{
			1	=>	"yes",
			2	=>	"no"
		},
		"antibiotics"	=>	{
			1	=>	"yes",
			2	=>	"no"
		},
		"maternal illness during pregnancy"	=>	{
			1	=>	"diabetes",
			2	=>	"thyroid disease",
			3	=>	"hypertension",
			4	=>	"diabetes + thyroid disease",
			5 	=>	"diabetes + hypertension",
			6 	=>	"thyroid disease + hypertension",
			7	=>	"diabetes + thyroid disease + hypertension"
		},
		"maternal antibiotics during pregnancy"	=>	{
			1	=>	"yes",
			2	=>	"no"
		}
	);
	
	# Only needed to comply with Db::insert .
	# Data not used afterwards.
	my $idQuery = "id, id";
	my $keysR = "";
	
	my @values = ();
	my @uniqs = ();
	my @fieldNs = ('id_sample', 'id_type', 'value', 'id_change');
	my @uniqFieldNs = ('id_sample', 'id_type');
	foreach my $idSample (keys(%{$keysSampleR})) {
		# Skip control samples. Controls only relevant for sequencing data.
		die "ERROR: Invalid sample keys" if (not exists $keysSampleR->{$idSample}->{'_isControl_'});
		next if (($keysSampleR->{$idSample}->{'_isControl_'} // "") ne "f");
		
		foreach my $type (keys %{$keysSampleR->{$idSample}}) {
			# Skip empty measurements, but don't skip 0 implicitly
			my $value = $keysSampleR->{$idSample}->{$type};
			next if (not defined $value or $value =~ m/^\s*$/);
			
			# Skip internal types or types associated with other relations
			next if (exists $blacklist{$type});
			
			my $idType = undef; 
			if (exists $keysTypeR->{$type}) {
				$idType = $keysTypeR->{$type};
			}
			else {
				die "ERROR: Unexpected type ->" . $type . "<- in sample keys"
			}
			
			if (not defined $idType or not $idType) {
				die "ERROR: No ID for type ->" . $type . "<-"
			}
			
			# Translate values, if applicable
			if (exists $dict{$type}) {
				if (exists $dict{$type}->{$value}) {
					$value = $dict{$type}->{$value}
				}
				else {
					die "ERROR: Unexpected value ->$value<- for type ->$type<- cannot be translated"
				}
			}
			
			# Duplicates are not possible => no check for duplicates	
			push (@values, $idSample, $idType, $value, $idChange);
			push (@uniqs, $idSample, $idType);			
		}
	}
	if (@values) {
		($keysR, $isNew) = MetagDB::Db::insert($dbh, $relation, \@values, \@uniqs, \@fieldNs, \@uniqFieldNs, $isNew, $idQuery, $maxRows);	
	}
	
	return $isNew;
}


#
#-------------------------------------------------------------------------------------------------#
# Insert into sequence relation.
#-------------------------------------------------------------------------------------------------#
#
sub insertSequence ($dbh, $keysR, $basePath, $idChange, $isNew, $maxRows = 1) {
	foreach my $param ($dbh, $keysR, $basePath, $idChange) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	# Empty hash or no ref
	if (not ref($keysR) or not %{$keysR}) {
		die "ERROR: No keys or not a reference";
	}
	if (not defined $isNew or $isNew !~ m/^[0,1]$/) {
		die "ERROR: Not enough arguments."
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") ."<-";
	}
		
	my $relation = "sequence";
	my $filePattern = '\.fastq.*';
	my @fieldNs = (
		'id_sample',
		'id_change',
		'runid',
		'barcode',
		'nucs',
		'quality',
		'flowcellid',
		'readid',
		'callermodel',
	);
	# Fields that uniquely identify each record
	my @uniqFieldNs = (
		'id_sample',
		'runid',
		'barcode',
		'readid'
	);
	my %metadataFields = (
		"runid"						=> undef,
		"barcode"					=> undef,
		"flow_cell_id"				=> undef,
		"basecall_model_version_id"	=> undef
	);
	
	# Foreign keys
	my %keysSeq = ();
	
	# Store dirPattern => idSample
	my %samples = ();
	
	# The key for dups includes the id_sample. Thus the hash
	# can be defined here
	my %dups = ();
	
	# Counter for foreign keys
	my $keyC = 0;
	foreach my $idSample (keys (%{$keysR})) {
		#----------------------------------------------------------------------------------#			
		# Get the file location.
		#----------------------------------------------------------------------------------#
		my $dirPattern = $keysR->{$idSample}->{'number of run and barcode'} // "";
		my $isControl = $keysR->{$idSample}->{'_isControl_'} // "";
		
		next if (not $dirPattern);
		
		# Water control FASTQ
		if ($isControl eq "t") {
			$dirPattern =~ s/bar[0-9]+$/bar99/;
		}
		# Not case FASTQ
		elsif ($isControl ne "f") {
			die "ERROR: Unexpected value ->$isControl<- for _isControl_"
		}
		
		# In the database, multiple samples could have the same runid and barcode (and readid).
		# Despite the same naming for run, barcode, and read, it is expected that the actual
		# sequences are different (maybe produced on different machines/by different labs).
		# Within one insert transaction, allowing multiple samples to have the same
		# runid and barcode, would mean that the sequences are also the same: The basePath
		# (contains runid and barcode) does not change and all reads that are present in the found
		# FASTQ(s) are expected to belong to the given sample. This does not make sense for case
		# samples and is thus forbidden. For control samples, however, this is OK: Typically,
		# there is one control per run which provides a baseline for multiple barcodes of that
		# specific run.
		if (exists $samples{$dirPattern}) {
			die "ERROR: Multiple samples share the same directory pattern ->$dirPattern<-" if ($samples{$dirPattern} != $idSample and $isControl ne "t");
		}
		else {
			$samples{$dirPattern} = $idSample;
		}
		
		
		#----------------------------------------------------------------------------------#
		# Detect files.
		#----------------------------------------------------------------------------------#
		my $data = "";
		my @files = ();
		try {
			@files = @{MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern)};
		}
		catch {
			warn "WARNING: $_";
		};
		
		next if (not @files);
		foreach my $file (@files) {	
			# Slurp the file
			my $tmp = MetagDB::Helpers::readFile($file);
			# If the file is binary, it needs to be extracted
			if (-B $file) {
				$data .= MetagDB::Helpers::extractValue($tmp);
			}
			else {
				$data .= $tmp
			}
		}
		
		
		#----------------------------------------------------------------------------------#			
		#  Extract relevant metadata from sequence files
		#----------------------------------------------------------------------------------#
		# Also block data that just contains a literal zero
		next if (not $data or $data =~ m/^\s+$/);
		
		my $seqsR = {};
		try {
			$seqsR = MetagDB::Fastq::process($data, \%metadataFields);
		}
		catch {
			die "ERROR with FASTQ file(s) in ->" . $dirPattern .
				"<-. Encountered exception ->" . $_ . "<-";
		};
		
		# Prepare data for insert
		my @values = ();
		
		# Values for fields that uniquely identify each record.
		my @uniqs = ();
		foreach my $seq (keys(%{$seqsR})) {			
			my $runId = $seqsR->{$seq}->{'runid'};
			my $barcode = $seqsR->{$seq}->{'barcode'};
			my $key = $idSample . "_" . ($runId // "") . "_" . ($barcode // "") . "_" . $seq;

			if (exists $dups{$key}) {
				next;
			}
			else {
				push (@uniqs, $idSample);
				push (@uniqs, $runId);
				push (@uniqs, $barcode);
				push (@uniqs, $seq);
				
				push (@values, $idSample);
				push (@values, $idChange);
				push (@values, $runId);
				push (@values, $barcode);
				push (@values, $seqsR->{$seq}->{'_seq_'});
				push (@values, $seqsR->{$seq}->{'_qual_'});
				push (@values, $seqsR->{$seq}->{'flow_cell_id'});
				push (@values, $seq);
				push (@values, $seqsR->{$seq}->{'basecall_model_version_id'});
	
				$dups{$key} = undef;
			}
		}
		
		# Insert data and get foreign keys
		my $idQuery = "readid, id";	
		(my $tmpsR, $isNew) = MetagDB::Db::insert($dbh, $relation, \@values, \@uniqs, \@fieldNs, \@uniqFieldNs, $isNew, $idQuery, $maxRows);
		
		# Store foreign keys as
		# dirPattern => { id_sample => { read ID in FASTQ => Database ID }}
		if (exists $keysSeq{$dirPattern}) {
			if (exists $keysSeq{$dirPattern}->{$idSample}) {
				foreach my $readId (keys(%{$tmpsR})) {
					# Skip records that were inserted in the current session
					if (exists $keysSeq{$dirPattern}->{$idSample}->{$readId}) {
						next;
					}
					else {
						$keysSeq{$dirPattern}->{$idSample}->{$readId} = $tmpsR->{$readId};
						$keyC++;
					}
				}
				
			}
			else {
				# Deep copy of hash ref
				$keysSeq{$dirPattern}->{$idSample} = dclone($tmpsR);
				$keyC += scalar(keys(%{$tmpsR}));
			}
		}
		else {
			# Deep copy of hash ref
			$keysSeq{$dirPattern} = { $idSample => dclone($tmpsR)};
			$keyC += scalar(keys(%{$tmpsR}));
		}				
	}
	
	# Sanity check: The number of foreign keys that are returned should equal
	# the number of unique records
	die "ERROR: Number of foreign keys does not equal the number of unique records" if ($keyC != scalar(keys(%dups)));
	
	return \%keysSeq, $isNew;
}


#
#-------------------------------------------------------------------------------------------------#
# Insert into taxonomy relation.
#-------------------------------------------------------------------------------------------------#
#
sub insertTaxonomy ($dbh, $keysSeqR, $keysSampleR, $basePath, $taxP, $idChange, $isNew, $maxRows = 1) {
	# $taxP is not needed for MetaG and can thus stay empty
	foreach my $param ($dbh, $keysSeqR, $keysSampleR, $basePath, $idChange) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	if (not defined $isNew or $isNew !~ m/^[0,1]$/) {
		die "ERROR: Not enough arguments."
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") ."<-";
	}
	
	# Empty hash or no ref
	foreach my $param ($keysSeqR, $keysSampleR) {
		if (not ref($param) or not %{$param}) {
			die "ERROR: No keys or not a reference";
		}
	}
	
	my $relation = "taxonomy";
	my @fieldNs = (
		'name',
		'rank',
		'id_change'
	);
	my @uniqFieldNs = (
		'name',
		'rank'
	);
	
	# Foreign keys; also used to filter duplicates
	my %keysTax = ();
	
	# Number of foreign keys
	my $keyC = 0;
	foreach my $dirPattern (keys(%{$keysSeqR})) {
		#----------------------------------------------------------------------------------#
		# Get the classifier ("program").
		#----------------------------------------------------------------------------------#
		my $classN = "";
		foreach my $idSample (keys(%{$keysSeqR->{$dirPattern}})) {
			die "ERROR: Sample and sequence objects not matching" if (not exists $keysSampleR->{$idSample});
			my $tmp = $keysSampleR->{$idSample}->{'program'} || "";
			die "ERROR: Mandatory value for program name not found" if (not $tmp);
			die "ERROR: Multiple classifiers ->" . $tmp . "<- and ->" . $classN . "<- for the same data ->" .
				$dirPattern . "<-" if ($classN and $tmp ne $classN);
			$classN = $tmp;
		}
		
		
		#----------------------------------------------------------------------------------#
		# Detect files depending on program.
		#----------------------------------------------------------------------------------#
		my $data = "";
		my @files = ();
		my $filePattern = "";
		if ($classN =~ m/metag/i) { 
			$filePattern = '.*calc\.LIN\.txt.*';
		}
		elsif ($classN =~ m/kraken2/i) {
			die "ERROR: Taxonomy path required for ->$classN<-" if (not $taxP or not defined $taxP);
			$filePattern = '.*kraken2.*';
		}
		else {
			die "ERROR: Unknown classifier ->" . $classN . "<-";
		}
		
		try {
			@files = @{MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern)};
		}
		catch {
			warn "WARNING: $_";
		};
		
		next if (not @files);
		foreach my $file (@files) {
			# Slurp the file
			my $tmp = MetagDB::Helpers::readFile($file);
			# If the file is binary, it needs to be extracted
			if (-B $file) {
				$data .= MetagDB::Helpers::extractValue($tmp);
			}
			else {
				$data .= $tmp
			}
		}
		

		#----------------------------------------------------------------------------------#			
		#  Extract relevant metadata from sequence files
		#----------------------------------------------------------------------------------#
		my @ranks = ("domain", "phylum", "class", "subclass", "order", "suborder", "family", "genus", "species", "strain");
		my $taxaR = {};
		
		# Block empty data, data just containing whitespaces.
		# Triggers use of special taxon below.
		if ($data and $data !~ m/^\s+$/) {			
			if ($classN =~ m/metag/i){
				$taxaR = MetagDB::Taxa::parseMetaG($data, \@ranks);
			}
			elsif ($classN =~ m/kraken2/i){
				$taxaR = MetagDB::Taxa::parseKraken2($data, $taxP, \@ranks);
			}
		}
		
		my @values = ();
		
		# Values for fields that uniquely identify each record
		my @uniqs = ();
				
		# Multiple control samples can share the same sequences
		foreach my $idSample (keys(%{$keysSeqR->{$dirPattern}})) {
			my $matchedC = 0;
			foreach my $readId (keys(%{$keysSeqR->{$dirPattern}->{$idSample}})) {
				my $idSeq = $keysSeqR->{$dirPattern}->{$idSample}->{$readId} // "";
				die "ERROR: Value for ->id_sequence<- missing or invalid" if ($idSeq eq "" or $idSeq !~ m/^\d+$/);
				
				my $program = $keysSampleR->{$idSample}->{'program'};
				my $database = $keysSampleR->{$idSample}->{'database'};
				if (exists $taxaR->{$readId}) {
					$matchedC++;				
					foreach my $rank (keys(%{$taxaR->{$readId}})) {
						my $taxon = $taxaR->{$readId}->{$rank};		
						my $key = ($taxon // "") . "_" . $rank;
						
						# Don't insert taxonomy that was already inserted in the current transaction.
						# Nevertheless, record associated id_sequence.
						if (exists $keysTax{$key}) {
							$keysTax{$key}->{'_id_sequence_'}->{$idSeq} = [$program, $database]
						}
						else {
							$keysTax{$key} = {'_id_sequence_' => {$idSeq => [$program, $database]}};
							
							push (@uniqs, $taxon);
							push (@uniqs, $rank);
							
							push (@values, $taxon);
							push (@values, $rank);
							push (@values, $idChange);
						}
					}
				}
				# Use special taxon "FILTERED" for reads that appear in keysSeqR, but not in
				# taxaR
				else {
					foreach my $rank (@ranks) {
						my $taxon = "FILTERED";		
						my $key = $taxon . "_" . $rank;
						
						# Don't insert taxonomy that was already inserted in the current transaction.
						# Nevertheless, record associated id_sequence.
						if (exists $keysTax{$key}) {
							$keysTax{$key}->{'_id_sequence_'}->{$idSeq} = [$program, $database]
						}
						else {
							$keysTax{$key} = {'_id_sequence_' => {$idSeq => [$program, $database]}};
							
							push (@uniqs, $taxon);
							push (@uniqs, $rank);
							
							push (@values, $taxon);
							push (@values, $rank);
							push (@values, $idChange);
						}
					}
				}
			}
			# It is OK to have more reads in sequence file than in classification file => filtered reads.
			# It is not OK to have reads in classification file that don't appear in sequence file.
			if ($matchedC != scalar(keys(%{$taxaR}))) {
				die "ERROR: ->" . (scalar(keys(%{$taxaR})) - $matchedC) . "<- read ID(s) do not match between taxonomy file and FASTQ" . 
					"  for directory pattern ->$dirPattern<- and taxonomy file pattern ->$filePattern<-\n"
			}
		}
		next if (not @values);
		
		
		# Insert data and get foreign keys
		my $idQuery = "CONCAT(name, '_', rank), id";
		(my $tmpsR, $isNew) = MetagDB::Db::insert($dbh, $relation, \@values, \@uniqs, \@fieldNs, \@uniqFieldNs, $isNew, $idQuery, $maxRows);
		
		# Store foreign keys as
		# name_rank => { '_id_sequence_' => { DB ID sequence => [program, database]}, '_id_taxonomy_' => DB ID taxonomy }
		foreach my $key (keys(%{$tmpsR})) {
			if (exists $keysTax{$key}) {
				$keysTax{$key}->{'_id_taxonomy_'} = $tmpsR->{$key};
				$keyC++;
			}
			else {
				die "ERROR: Unexpected key returned ->$key<- by database"
			}
		}
	}
	
	# Sanity check: The number of foreign keys that are returned should equal
	# the number of unique records
	die "ERROR: Number of foreign keys does not equal the number of unique records" if ($keyC != scalar(keys(%keysTax)));
		
	return \%keysTax, $isNew;
}


#
#-------------------------------------------------------------------------------------------------#
# Insert into classification relation.
#-------------------------------------------------------------------------------------------------#
#
sub insertClassification ($dbh, $keysR, $idChange, $isNew, $maxRows = 1) {
	foreach my $param ($dbh, $keysR, $idChange) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	if (not defined $isNew or $isNew !~ m/^[0,1]$/) {
		die "ERROR: Not enough arguments."
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") ."<-";
	}
	# Empty hash or no ref
	if (not ref($keysR) or not %{$keysR}) {
		die "ERROR: No keys or not a reference";
	}
	
	my $relation = "classification";
	my @fieldNs = (
		'id_sequence',
		'program',
		'database',
		'id_change'
	);
	my @uniqFieldNs = (
		'id_sequence',
		'program',
		'database'
	);
	
	# Foreign keys
	my %keysClass = ();
	
	my @values = ();
	
	# Values of fields that uniquely identify each record
	my @uniqs = ();
	
	my %dups = ();
	foreach my $keyTax (keys(%{$keysR})) {
		die "ERROR: Invalid keys hash" if (not exists $keysR->{$keyTax}->{'_id_sequence_'});
		foreach my $idSequence (keys(%{$keysR->{$keyTax}->{'_id_sequence_'}})) {
			my $program = $keysR->{$keyTax}->{'_id_sequence_'}->{$idSequence}->[0];
			my $db = $keysR->{$keyTax}->{'_id_sequence_'}->{$idSequence}->[1];
			my $idTaxonomy = $keysR->{$keyTax}->{'_id_taxonomy_'} // "";
			
			die "ERROR: No id_taxonomy for key ->$keyTax<-" if (not $idTaxonomy);
			
			my $key = $idSequence . "_" . ($program // "") . "_" . ($db // "");
			
			# Don't insert records that were already inserted in the current session,
			# but store connection to taxonomy
			if (exists $dups{$key}) {
				$dups{$key}->{$idTaxonomy} = undef;
			}
			else {						
				push(@uniqs, $idSequence);
				push(@uniqs, $program);
				push(@uniqs, $db);
				
				push(@values, $idSequence);
				push(@values, $program);
				push(@values, $db);
				push(@values, $idChange);
				
				$dups{$key} = {$idTaxonomy => undef};
			}
		}
	}
	
	if (@values) {
		my $idQuery = "CONCAT(id_sequence, '_', program, '_', database), id";
		(my $tmpsR, $isNew) = MetagDB::Db::insert($dbh, $relation, \@values, \@uniqs, \@fieldNs, \@uniqFieldNs, $isNew, $idQuery, $maxRows);
		
		# Store foreign keys as id_classification => { id_taxonomy => undef }
		foreach my $key (keys(%{$tmpsR})) {
			if (exists $dups{$key}) {
				$keysClass{$tmpsR->{$key}} = $dups{$key};
			}
			else {
				die "ERROR: Unexpected key returned ->$key<- by database"
			}
		}
		
		# Sanity check: The number of foreign keys that are returned should equal
		# the number of unique records
		die "ERROR: Number of foreign keys does not equal the number of unique records" if (scalar(keys(%{$tmpsR})) != scalar(keys(%dups)));
	}
		
	return \%keysClass, $isNew;
}


#
#-------------------------------------------------------------------------------------------------#
# Insert into taxclass relation.
# Does not return foreign keys!
#-------------------------------------------------------------------------------------------------#
#
sub insertTaxclass ($dbh, $keysR, $idChange, $isNew, $maxRows = 1) {
	foreach my $param ($dbh, $keysR, $idChange) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	if (not defined $isNew or $isNew !~ m/^[0,1]$/) {
		die "ERROR: Not enough arguments."
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") ."<-";
	}
	# Empty hash or no ref
	if (not ref($keysR) or not %{$keysR}) {
		die "ERROR: No keys or not a reference";
	}
	
	my $relation = "taxclass";
	
	# Store rows for insert
	my @inserts = ();
	my $rowC = 1;

	# Attempt multirow insert
	foreach my $idClassification (keys(%{$keysR})) {
		die "ERROR: No id_taxonomy for id_classification ->$idClassification<-" if (not keys(%{$keysR->{$idClassification}}));
		foreach my $idTaxonomy (keys(%{$keysR->{$idClassification}})) {
			if ($rowC < $maxRows) {
				# Without binding for improved speed. Values are all coming from DB and should be safe.
				push(@inserts, "(" . $dbh->quote($idTaxonomy) . "," . $dbh->quote($idClassification) . "," . $dbh->quote($idChange) . ")");
				$rowC++;
			}
			else {
				# Without binding for improved speed. Values are all coming from DB and should be safe.
				push(@inserts, "(" . $dbh->quote($idTaxonomy) . "," . $dbh->quote($idClassification) . "," . $dbh->quote($idChange) . ")");
				$dbh->do("INSERT INTO $relation (id_taxonomy, id_classification, id_change) VALUES " . join(", ", @inserts) . " ON CONFLICT DO NOTHING");

				@inserts = ();
				$rowC = 1;
			}
		}
	}
	# Attempt to insert the remaining records
	if (@inserts) {
		$dbh->do("INSERT INTO $relation (id_taxonomy, id_classification, id_change) VALUES " . join(", ", @inserts) . " ON CONFLICT DO NOTHING");
	}
	
	# Check if a new entry has actually been inserted
	my @news = $dbh->selectrow_array("SELECT id_change FROM $relation WHERE id_change = ? LIMIT 1", {}, $idChange);
	if (@news) {
		$isNew = 1;
	}
	
	return $isNew;
}


#
#--------------------------------------------------------------------------------------------------#
# Insert a record into the standard relation.
#--------------------------------------------------------------------------------------------------#
#
sub insertStandard ($dbh, $dataR, $name, $idChange, $isNew, $maxRows = 1) {
	foreach my $param ($dbh, $dataR, $name, $idChange) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	if (not defined $isNew or $isNew !~ m/^[0,1]$/) {
		die "ERROR: Not enough arguments."
	}
	# Empty array or no ref
	if (not ref($dataR) or not @{$dataR}) {
		die "ERROR: No data or not a reference";
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") ."<-";
	}
		
	my $relation = "standard";	
	my @fieldNs = (
		'name',
		'sex',
		'age',
		'l',
		'm',
		's',
		'id_change'
	);
	my @uniqFieldNs = (
		'name',
		'sex',
		'age'
	);
	

	# Prepare data for insert
	my @values = ();
	
	# Values for fields that uniquely identify each record
	my @uniqs = ();
	
	my %dups = ();
	foreach my $row (@{$dataR}) {
		die "ERROR: Empty row" if (not @{$row});
		foreach my $val (@{$row}) {
			die "ERROR: Undefined or empty value in row ->" . Dumper($row) . "<-" if (not defined $val or $val =~ m/^\s*$/);
		}
		my ($sex, $age, $l, $m, $s) = @{$row};
		my $key = $name . "_" . $sex . "_" . $age;
		
		# Skip records that will be inserted in the current session
		if (exists $dups{$key}) {
			next;
		}
		else {
			push (@uniqs, $name);
			push (@uniqs, $sex);
			push (@uniqs, $age);
			
			push (@values, $name);
			push (@values, $sex);
			push (@values, $age);
			push (@values, $l);
			push (@values, $m);
			push (@values, $s);
			push (@values, $idChange);

			$dups{$key} = undef;
		}
	}
	
	# Place holder query. Foreign keys not needed
	my $idQuery = "CONCAT(name, '_', sex, '_', age), id_change";
	(my $keysR, $isNew) = MetagDB::Db::insert($dbh, $relation, \@values, \@uniqs, \@fieldNs, \@uniqFieldNs, $isNew, $idQuery, $maxRows);
	
	# Sanity check: The number of foreign keys that are returned should equal
	# the number of unique records
	die "ERROR: Number of foreign keys does not equal the number of unique records" if (scalar(keys(%{$keysR})) != scalar(keys(%dups)));
	
	
	return $isNew;
}


#
#--------------------------------------------------------------------------------------------------#
# Extract lineages and counts for a set of samples ids. Skip lineages starting with taxa
# from blacklist. Control samples are skipped by default.
#--------------------------------------------------------------------------------------------------#
#
sub getLineages ($dbh, $idsR, $blacklistR = ["FILTERED"], $keepCtrl = 0, $maxRows = 1) {
	foreach my $param ($dbh, $idsR, $blacklistR) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	# Empty array or no ref
	if (not ref($idsR) or not @{$idsR}) {
		die "ERROR: No ids or not a reference";
	}
	if (not ref($blacklistR)) {
		die "ERROR: Blacklist not a reference";
	}
	if (not defined $keepCtrl or $keepCtrl !~ /^[0,1]$/) {
		die "ERROR: Invalid value for keepCtrl ->" . ($keepCtrl // "") ."<-";
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") ."<-";
	}
	my @ids = @{$idsR};
	my $orgIdsR = dclone(\@ids);
	my @orgIds = @{$orgIdsR};
	my $metasR = {};
	
	# Exclude lineages based on blacklisted taxa
	my $where = "";
	$where = ' AND class[1] NOT IN (' .
		join(', ', ('?') x scalar(@{$blacklistR})) . ')' if (@{$blacklistR});
		
	my $rowCount = scalar(@ids);
	my %res = ();	
	
	# Too many records --> select in batches
	if ($rowCount > $maxRows) {
		my @tmps = ();
		while (@ids) {
			@tmps = splice(@ids, 0, $maxRows);
		
			# Take the remainder (less rows than maxRows) and put it back to ids
			# --> indicates separate select
			if (scalar(@tmps) < $maxRows) {
				@ids = @tmps;
				last;
			}
			
			my $bind = join(", ", ('?') x $maxRows);

			push(@tmps, @{$blacklistR});
			# The database contains too many ranks and counts need to be recalculated from
			# strain to species.
			my $st = "WITH lin (id, sample, class, count) AS (" .
				"SELECT id, CONCAT_WS('_', samplename, COALESCE(program, ''), COALESCE(database, '')), " .
				"ARRAY_TO_STRING(class[\\:3] || class[5] || class[7\\:9], ';'), count FROM v_lineages " .
				"WHERE id IN ($bind)";
			$st .= $where if ($where);
			$st .= "), time (id, timepoint) AS (" .
				"SELECT id, timepoint FROM v_samples) " .
				"SELECT l.id, l.sample, t.timepoint, l.class, sum(l.count) " .
				"FROM lin l INNER JOIN time t on t.id = l.id GROUP BY l.id, l.sample, t.timepoint, l.class";	
			my $sth = $dbh->prepare($st);
			$sth = MetagDB::Db::execute($sth, \@tmps);
			my $tmpsR = $sth->fetchall_arrayref();
			
			foreach my $rowR (@{$tmpsR}) {
				my ($id, $sample, $timepoint, $class, $count) = @{$rowR};
				my @splits = split("_", $sample, -1);
				my ($isControl, $program, $db) = @splits[($#splits - 2)..$#splits];
				if ($isControl eq 't') {
					next if ($keepCtrl == 0);
					$isControl = 'yes' 
				}
				elsif ($isControl eq 'f') {
					$isControl = 'no' 
				}
				else {
					die "ERROR: Unknown value ->$isControl<- for isControl"
				}
			
				# There is only one sample per id
				if (exists $res{$id}) {
					$res{$id}->{$sample}->{$class} = $count
				}
				else {
					$res{$id} = {$sample => {$class => $count}}
				}
				if (exists $metasR->{$id}) {
					$metasR->{$id}->{$sample}->{'program'} = $program;
					$metasR->{$id}->{$sample}->{'database'} = $db;
					$metasR->{$id}->{$sample}->{'control'} = $isControl;
					$metasR->{$id}->{$sample}->{'timepoint'} = $timepoint;
				}
				else {
					$metasR->{$id} = {
						$sample => {
							'program' => $program,
							'database' => $db,
							'control' => $isControl,
							'timepoint' => $timepoint
						}
					}
				}
			}
		}
	}
	# SELECT (the rest) at once
	if (@ids) {		
		my $bind = join(", ", ('?') x scalar(@ids));
		
		push(@ids, @{$blacklistR});
		# The database contains too many ranks and counts need to be recalculated from
		# strain to species.			
		my $st = "WITH lin (id, sample, class, count) AS (" .
			"SELECT id, CONCAT_WS('_', samplename, COALESCE(program, ''), COALESCE(database, '')), " .
			"ARRAY_TO_STRING(class[\\:3] || class[5] || class[7\\:9], ';'), count FROM v_lineages " .
			"WHERE id IN ($bind)";
		$st .= $where if ($where);
		$st .= "), time (id, timepoint) AS (" .
			"SELECT id, timepoint FROM v_samples) " .
			"SELECT l.id, l.sample, t.timepoint, l.class, sum(l.count) " .
			"FROM lin l INNER JOIN time t on t.id = l.id GROUP BY l.id, l.sample, t.timepoint, l.class";	
		my $sth = $dbh->prepare($st);
		$sth = MetagDB::Db::execute($sth, \@ids);
		my $tmpsR = $sth->fetchall_arrayref();
		
		foreach my $rowR (@{$tmpsR}) {
			my ($id, $sample, $timepoint, $class, $count) = @{$rowR};			
			my @splits = split("_", $sample, -1);
			my ($isControl, $program, $db) = @splits[($#splits -2)..$#splits];
			if ($isControl eq 't') {
				next if ($keepCtrl == 0);
				$isControl = 'yes' 
			}
			elsif ($isControl eq 'f') {
				$isControl = 'no' 
			}
			else {
				die "ERROR: Unknown value ->$isControl<- for isControl"
			}
			
			# There is only one sample per id
			if (exists $res{$id}) {
				$res{$id}->{$sample}->{$class} = $count
			}
			else {
				$res{$id} = {$sample => {$class => $count}}
			}
			if (exists $metasR->{$id}) {
				$metasR->{$id}->{$sample}->{'program'} = $program;
				$metasR->{$id}->{$sample}->{'database'} = $db;
				$metasR->{$id}->{$sample}->{'control'} = $isControl;
				$metasR->{$id}->{$sample}->{'timepoint'} = $timepoint;
			}
			else {
				$metasR->{$id} = {
					$sample => {
						'program' => $program,
						'database' => $db,
						'control' => $isControl,
						'timepoint' => $timepoint
					}
				}
			}
		}
	}
	
	if (scalar(@orgIds) > scalar(keys(%{$metasR}))) {
		my @warns = ();
		foreach my $id (@orgIds) {
			if (not exists $metasR->{$id}) {
				push(@warns, $id)
			}
		}
		warn "WARNING: ->" . scalar(@warns). "<- sample IDs were removed."
	}
	
	return \%res, $metasR;
}


#
#--------------------------------------------------------------------------------------------------#
# Extract metadata for a set of sample IDs
#--------------------------------------------------------------------------------------------------#
#
sub getMeta ($dbh, $metasR, $maxRows = 1) {
	foreach my $param ($dbh, $metasR) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	# Empty array or no ref
	if (not ref($metasR) or not %{$metasR}) {
		die "ERROR: No metadata or not a reference";
	}
	if (not defined $maxRows or $maxRows !~ /^\d+$/ or $maxRows < 1) {
		die "ERROR: Invalid value for maxRows ->" . ($maxRows // "") ."<-";
	}		
	my @ids = keys(%{$metasR});

	my $rowCount = scalar(@ids);
	my %res = ();
	
	# Interesting metadata
	my $name = '$$antibiotics$$, $$birth mode$$, $$category of difference in body mass at delivery$$, $$feeding mode$$, '.
		'$$maternal antibiotics during pregnancy$$, $$maternal illness during pregnancy$$, $$mother\'s age at delivery$$,' .
		'$$mother\'s pre-pregnancy BMI category$$, $$pregnancy order$$, $$probiotics$$, $$sex$$, $$z-score category$$,' .
		'$$z-score subcategory$$';
	
	# Too many records --> select in batches
	if ($rowCount > $maxRows) {
		my @tmps = ();
		while (@ids) {
			@tmps = splice(@ids, 0, $maxRows);
			
			# Take the remainder (less rows than maxRows) and put it back to ids
			# --> indicates separate select
			if (scalar(@tmps) < $maxRows) {
				@ids = @tmps;
				last;
			}
			
			my $bind = join(", ", ('?') x $maxRows);			
			my $sth = $dbh->prepare("SELECT id_sample, name, value FROM v_metadata WHERE id_sample IN ($bind) AND name IN ($name)");
			$sth = MetagDB::Db::execute($sth, \@tmps);
			my $tmpsR = $sth->fetchall_arrayref();
			
			foreach my $rowR (@{$tmpsR}) {
				my ($id, $metaN, $value) = @{$rowR};
				if (exists $res{$id}) {
					$res{$id}->{$metaN} = $value
				}
				else {
					$res{$id} = {$metaN => $value}
				}
			}
		}
	}
	# SELECT (the rest) at once
	if (@ids) {		
		my $bind = join(", ", ('?') x scalar(@ids));			
		my $sth = $dbh->prepare("SELECT id_sample, name, value FROM v_metadata WHERE id_sample IN ($bind) AND name IN ($name)");
		$sth = MetagDB::Db::execute($sth, \@ids);
		my $tmpsR = $sth->fetchall_arrayref();
		
		foreach my $rowR (@{$tmpsR}) {
			my ($id, $metaN, $value) = @{$rowR};
			if (exists $res{$id}) {
				$res{$id}->{$metaN} = $value
			}
			else {
				$res{$id} = {$metaN => $value}
			}
		}
	}
		
	# Add metadata about measurements
	foreach my $id (keys(%{$metasR})) {
		foreach my $sampleN (keys(%{$metasR->{$id}})){
			# A sample with metadata --> case sample
			if (exists $res{$id}) {
				foreach my $metaN (keys(%{$res{$id}})) {
					my $n = $metaN =~ s/ /_/gr;
					$n =~ s/-/_/g;
					$n =~ s/\'//g;
					my $v = $res{$id}->{$metaN};
					$v =~ s/ /_/g;
					$v =~ s/-/_/g;
					$v =~ s/\'//g;
					
					$metasR->{$id}->{$sampleN}->{$n} = $v
				}
			}
			# A sample without metadata --> control or case sample in future
			else {
				next;
			}
		}	
	}

	
	return $metasR;
}


1;