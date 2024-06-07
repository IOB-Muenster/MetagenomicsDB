package MetagDB::Table;


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

use Encode qw(encode decode);
use Spreadsheet::Read;
use Try::Tiny;


#
#--------------------------------------------------------------------------------------------------#
# Parse a spread sheet with UTF-8 support.
#
#
# Expected input:
# 	*) spreadsheet (ODS, XLS, XLSX, or CSV [comma-separated]) from STDIN with header in first row
#	*) reference to an index hash (see below)
#	*) spreadsheet format (one of "ods" ("sxc"), "xls", "xlsx", or "csv")
# 	*) reference to a date column hash (see below)
#
# The spreadsheet (single sheet) is assumed to contain four different column types:
#	*) id: uniquely identifies each patient. Must be repeated in all rows, otherwise skipped.
#	*) static: doesn't change over time, e.g. birthdate; reserved name "_times_" may not be used
#	*) timepoint: time when a non-static measurement was done
#	*) measurement: the value for a non-static measurement, e.g. weight --> assigned to time point
#
# The column indices for these column types are provided in the index hash [array ref]. There may
# only be one "id" and one "timepoint" column per document. Generally, duplicate values for
# static+id and timepoint+measurement+id are merged, if the static values/measurement values are the
# same. Otherwise, an error is raised. However, the values of a static for an id may or may not
# have a value without raising an error.
# E.g.:
#	id		static		time			measurement1
#	1		"abc"		2022-01-20		4m
#	1		"abc"		2022-01-21		4.1m
#	=> OK
#
#	id		static		time			measurement1
#	1		"abc"		2022-01-20		4m
#	1		"abc"		2022-01-21		
#	=> OK: empty measurement at one (or multiple) timepoint(s)
#
#	id		static		time			measurement1
#	1					2022-01-20		4m
#	1					2022-01-21		4.1m
#	=> OK: empty static
#
#	id		static		time			measurement1
#	1		"abc"		2022-01-20		4m
#	1					2022-01-21		4.1m
#	=> OK: static is assumed to be always "abc" until a new id is seen.
#
#	id		static		time			measurement1
#	1		"abc"		2022-01-20		4m
#	1					2022-01-20		4m
#	=> OK: Duplictates for id+timepoint+measurement are merged,
#			if they have the same value
#
#	id		static		time			measurement1
#	1		"abc"		2022-01-20		4m
#	1					2022-01-20		4.1m
#	=> ERROR: Duplicates in measurement have different values
#
#	id		static		time			measurement1
#	1		"abc"		2022-01-20		4m
#	1		"def"		2022-01-21		4.1m
#	=> ERROR: Duplicates in static have different values
#		
#	id		static		time			measurement1
#	1		"abc"		2022-01-20		4m
#	1					2022-01-20		
#	=> ERROR: Duplicates with empty values not allowed in measurement
#
#	id		static		time			measurement1
#	1		"abc"		2022-01-20		4m
#	1									4.1m
#	=> ERROR: Measurement without timepoint
#
# While dates in yyyy-mm-dd format should be parsed correctly, they tend to make problems with
# XLS and XLSX formats. Dates before 1899-12-30 are output as negative integers without raising
# an error. To catch this, the timepoint column is automatically scanned for negative integers and
# an error is raised, if one is found. Further date columns can be also checked (e.g. a static
# birthdate) by specifying the column name in the date column hash. The name must be identical to
# the column name in the header. The hash can be empty, if no columns except the timepoint column
# should be checked.
#
# Returns a hash like
#		(id1 => {	static1 => value1,
#					static2 => value2,
#						... ,
#					_times_ =>	{
#									t1 =>	{
#												measure1 => value1,
#													...
#											},
#									t2 =>	{
#												measure1 => value1,
#													...
#											},
#										...
#								} 
#				},
#		...)
#
# Caveats
#	Newlines in fields are not supported for CSV files. ODS files created by Excel cause
#	unspecific errors. ODS files created by LibreOffice (on Windows and Linux) don't cause
#	problemes.
#	Dates before March 1900 can cause problemes with XLSX format, as the day is off by
#	one. ODS and CSV files are processed as expected.
#
# Dependencies:
# 	Encode
#	Spreadsheet::Read
#	Spreadsheet::ParseODS
#	Spreadsheet::ParseXLSX
#	Spreadsheet::ParseExcel
#	Text::CSV_XS
#--------------------------------------------------------------------------------------------------#
#
sub read ($data, $idxR, $format, $datesR = {}) {
	foreach my $param ($data, $idxR, $format, $datesR) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	# Index hash reference cannot be empty and has to be a genuine reference
	if (not ref($idxR) or not %{$idxR}) {
		die "ERROR: No indices or not a reference";
	}
	if (not exists $idxR->{"id"} or not exists $idxR->{"static"} or 
		not exists $idxR->{"timepoint"} or not exists $idxR->{"measurement"}) {
			die "ERROR: Incomplete index hash";
	}
	# Dates reference can be empty, but has to be a reference
	if (not ref($datesR)) {
		die "ERROR: Dates not a reference";
	}
	# Check and translate format
	my %suppFormats = ("xlsx" => undef, "xls" => undef, "ods" => "sxc", "csv" => undef, "sxc" => undef);
	die "ERROR: Unsupported format ->$format<-" if (not exists $suppFormats{$format});
	$format = $suppFormats{$format} if (defined $suppFormats{$format});


	#------------------------------------------------------------------------------#
	# Read the spreadsheet
	#------------------------------------------------------------------------------#
	# strip gets rid off any leading + trailing whitespaces (incl. newlines)
	# parser decodes to UTF-8
	my $sheetR  = "";
	try {
		if ($format eq "sxc") {
			$sheetR = ReadData($data, parser=>$format, strip=>3);
		}
		else {
			# Newlines not supported for csv
			my $tmp = decode('UTF-8', $data);
			die "ERROR: Newlines in fields not supported for CSV" if ($tmp =~ m/".*\r?\n.*"/ and $format eq "csv");
			$sheetR = ReadData(\$data, parser=>$format, strip=>3);
		}
	}
	catch {
		die "ERROR: Could not parse spreadsheet ->$_<-";	
	};
	# Spreadsheet::ParseODS does not report an error in all cases
	die "ERROR: Could not parse spreadsheet" if (not $sheetR);
	
	die "ERROR: More than one sheet found" if (@{$sheetR} > 2);
	
	my @rows = ();
	my $maxRow = $sheetR->[1]->{'maxrow'};
	die "ERROR: Empty sheet" if (not $maxRow or $maxRow == 0);
	# Loop over all rows and extract the formatted values.
	# Formatted with xls/xlsx means that the date was converted
	# from an int to yyyy-mm-dd. However, conversion with negative
	# integers (dates before 1899-12-30) fails silently. --> checked later!
	for (my $i = 1; $i<=$maxRow; $i++) {
		push(@rows, [Spreadsheet::Read::row($sheetR->[1], $i)]);
	}
	my @headers = @{$rows[0]};
	die "ERROR: Empty field in header" if (grep(!defined, @headers) or grep(/^\s*$/, @headers));
	
	# Count of fields in header should at least match the count of fields
	# that should be extracted ($idxR). If fields in the header are missing
	# relative to the other rows, they are set to undef by the parsers. Meaning
	# the header field count indicates the maximum field count in the current sheet.
	# Problems here usually indicate invalid files; especially with CSVs where the
	# parser is very relaxed.
	my $expFieldC = scalar(map{@{$_}} values(%{$idxR}));
	my $headerC = scalar(@headers);
	die "ERROR: Too few fields in header. Expected: ->$expFieldC<-; found: ->$headerC<-" if ($expFieldC > $headerC);
	
	splice(@rows, 0, 1);


	#------------------------------------------------------------------------------#
	# Loop over all rows (except header) and extract the data
	#------------------------------------------------------------------------------#
	my $id = "";
	my %data = ();
	foreach my $rowR (@rows) {
		$id = $rowR->[$idxR->{"id"}->[0]];
		# Skip empty rows
		next if (not defined $id or not $id);
			
		my $time = $rowR->[$idxR->{"timepoint"}->[0]] // "";
		# Negative integer in a column that should contain a date
		# indicates a conversion error
		if ($time and $time =~ m/^-[0-9]+$/) {
			die "ERROR: Invalid date ->$time<-."
		}
		elsif (not $time) {
			die "ERROR: No date."
		}
		
		# Extract measurement name and measurement value based on column index.
		# Empty cells (or cells with just blanks) will be undef.
		my %measures = map {
			my $tmp = $rowR->[$_];
			$tmp = undef if (defined $tmp and $tmp =~ m/^\s*$/);
			$headers[$_] => $tmp
		} @{$idxR->{"measurement"}};
		# Extract static name and static value based on column index.
		# Empty cells (or cells with just blanks) will be undef.
		my %statics = map {
			my $tmp = $rowR->[$_];
			$tmp = undef if (defined $tmp and $tmp =~ m/^\s*$/);
			$headers[$_] => $tmp
		} @{$idxR->{"static"}};
		# _times_ is used internally to store the time points
		# and cannot be the name of a static value
		if (exists $statics{"_times_"}) {
			die "ERROR: Illegal static name _times_";
		}
		# Check that dates were formatted correctly in the expected
		# columns. If a negative integer is found in one of these
		# columns, raise an error. XLS and XLSX make problemes
		# with dates before 1899-12-30.
		if ($datesR) {
			foreach my $dateCol (keys(%{$datesR})) {
				my %tmps = (%measures, %statics);
				if (exists $tmps{$dateCol}) {
					my $tmp = $tmps{$dateCol};
					if ($tmp and $tmp =~ m/^-[0-9]+$/) {
						die "ERROR: Invalid date ->$tmp<-."
					}
				}
				# Already checked the timepoint column
				elsif ($dateCol eq $headers[$idxR->{"timepoint"}->[0]]) {
					next;
				}
				else {
					die "ERROR: Wrong column name ->" . encode('UTF-8', $dateCol) . "<- in dates"
				}
			}
		}
		
		if (not exists $data{$id}) {
			$data{$id} = {"_times_" => {$time => \%measures}, %statics};
		}
		else {
			# It is OK, if a time point appears multiple times.
			# However, all occurences need to have the same measurement values.
			if (exists $data{$id}->{"_times_"}) {
				if (exists $data{$id}->{"_times_"}->{$time}) {
					foreach my $measure (keys (%measures)) {
						if (exists $data{$id}->{"_times_"}->{$time}->{$measure}) {
							my $storedMeasure = $data{$id}->{"_times_"}->{$time}->{$measure};
							# Undef vs defined is a conflict for measures at the same time point.
							if (not defined $storedMeasure) {
								if (defined $measures{$measure}) {
									die "ERROR: Different values for ->" . encode('UTF-8', $measure) . "<- at time ->" . encode('UTF-8', $time) . "<-";
								}
							}
							else {
								# Defined vs undef is a conflict for measures at the same time point.
								if (not defined $measures{$measure}) {
									die "ERROR: Different values for ->" . encode('UTF-8', $measure) . "<- at time ->" . encode('UTF-8', $time) . "<-";
								}
								# If both values are defined they need to be the same.
								else {
									if ($storedMeasure ne $measures{$measure}) {
										die "ERROR: Different values for ->" . encode('UTF-8', $measure) . "<- at time ->" . encode('UTF-8', $time) . "<-";
									}
								}
							}
						}
						else {
							$data{$id}->{"_times_"}->{$time}->{$measure} = $measures{$measure}
						}
					}
				}
				else {
					$data{$id}->{"_times_"}->{$time} = \%measures
				}
			}
			else {
				$data{$id}->{"_times_"} = {$time => \%measures};
			}
			# It is OK, if a static value appears multiple times.
			# However, all occurences need to have the same values.
			foreach my $static (keys (%statics)) {
				if (exists $data{$id}->{$static}) {
					# Handle empty cells corretly
					if (not defined $data{$id}->{$static}) {
						# Empty vs non-empty value is NOT a conflict for statics
						$data{$id}->{$static} = $statics{$static}
					}
					else {
						# Handle empty cells corretly
						# Empty vs non-empty value is NOT a conflict for statics
						if (not defined $statics{$static}) {
							next;
						}
						else{
							if ($data{$id}->{$static} ne $statics{$static}) {
								die "ERROR: Different values for ->" . encode('UTF-8', $static) . "<- for id ->" . encode('UTF-8', $id) . "<-";
							}
						}
					}
				}
				else {
					$data{$id}->{$static} = $statics{$static}
				}
			}
		}
	}

	
	return \%data;
}


1;