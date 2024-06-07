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
# Tests for MetagDB::Table module
#==================================================================================================#
# DESCRIPTION
# 
#	Test the functions in the MetagDB::Table module. Some tests that are exemplary for critical
#	operations (string compare, regex,...) are repeated for spreadsheets containing UTF-8
#	characters.
#
#
# USAGE
#
# 	./test_Table.pl
#
#					
# DEPENDENCIES
# 
#	Encode
#	MetagDB::Helpers
#	MetagDB::Table
#	Spreadsheet::Read
#	Spreadsheet::ParseODS
#	Spreadsheet::ParseXLSX
#	Spreadsheet::ParseExcel
#	Storable
#	Test2::Bundle::More
#	Test2::Tools::Compare
#	Text::CSV_XS
#	Try::Tiny
#==================================================================================================#


use strict;
use warnings;

use Encode qw(decode);
use Storable qw(dclone);
use Test2::Bundle::More qw(ok done_testing);
use Test2::Tools::Compare;
use Try::Tiny;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl/";
use MetagDB::Table;
use MetagDB::Helpers;


#
#--------------------------------------------------------------------------------------------------#
# Test the read function
#--------------------------------------------------------------------------------------------------#
#
sub test_read {
	my $err = "";
	my $data = MetagDB::Helpers::readFile("data/spreadsheets/test.xlsx");
	my %idxs = ("id" => [0], "static" => [1, 2], "timepoint" => [3], "measurement" => [4, 5]);
	my $format = "xlsx";
	my %dates = ();
	
	#------------------------------------------------------------------------------#
	# Test no table file (+ no index hash + no format + no dates)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no table');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no index hash (+ no format + no dates)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read($data)
	}
	catch {
		$err = $_;
	}
	finally{
		ok ($err =~ m/^Too few arguments/, 'Testing no index hash');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no format (+ no dates)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read($data, \%idxs)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no format');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no dates (sometimes the only date is in the timepoint column)
	#------------------------------------------------------------------------------#
	my %expecs = (
		'1' => {
			"Col2"	=>	2,
			"Col3"	=>	3,
			"_times_" =>	{
				"t1"	=>	{
					"Measure1"	=>	"M1_t1",
					"Measure2"	=>	"M2_t1"
				},
				"t2"	=>	{
					"Measure1"	=>	"M1_t2",
					"Measure2"	=>	"M2_t2"
				},
				"t3"	=>	{
					"Measure1"	=>	"M1_t3",
					"Measure2"	=>	"M2_t3"
				}
			}
		},
		'11' => {
			"Col2"	=>	22,
			"Col3"	=>	33,
			"_times_" =>	{
				"t1"	=>	{
					"Measure1"	=>	"M11_t1",
					"Measure2"	=>	"M22_t1"
				},
				"t2"	=>	{
					"Measure1"	=>	"M11_t2",
					"Measure2"	=>	"M22_t2"
				},
				"t3"	=>	{
					"Measure1"	=>	"M11_t3",
					"Measure2"	=>	"M22_t3"
				}
			}
		},
		'111' => {
			"Col2"	=>	222,
			"Col3"	=>	333,
			"_times_" =>	{
				"t1"	=>	{
					"Measure1"	=>	"M111_t1",
					"Measure2"	=>	"M222_t1"
				}
			}
		}
	);		
	is (MetagDB::Table::read($data, \%idxs, $format), \%expecs, 'Testing no dates');
	
	
	#------------------------------------------------------------------------------#
	# Test empty table file
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read("", \%idxs, $format, \%dates)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough arguments/, 'Testing empty table');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty index hash
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read($data, "", $format, \%dates)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough arguments/, 'Testing empty index hash');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test index hash not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read($data, "abc", $format, \%dates)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No indices/, 'Testing index hash not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test index hash empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read($data, {}, $format, \%dates)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No indices/, 'Testing index hash empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test incomplete index hash
	#------------------------------------------------------------------------------#
	foreach my $type (keys(%idxs)) {
		# Deep temporary copy
		my $tmpsR = dclone( \%idxs );
		delete $tmpsR->{$type};
		try {
			$err = "";
			
			MetagDB::Table::read($data, $tmpsR, $format, \%dates)
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/ERROR.*Incomplete index hash/, 'Testing incomplete index hash. Missing ->' . $type . '<-');
		};
		
	}
	
	
	#------------------------------------------------------------------------------#
	# Test empty format
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read($data, \%idxs, "", \%dates)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough arguments/, 'Testing empty format');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid format
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read($data, \%idxs, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Unsupported format/, 'Testing invalid format');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty dates
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read($data, \%idxs, $format, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough arguments/, "Testing empty dates")
	};
	

	#------------------------------------------------------------------------------#
	# Test dates not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read($data, \%idxs, $format, "abc");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Dates not a reference/, "Testing dates not a reference")
	};
	
	
	#------------------------------------------------------------------------------#
	# Test dates empty hash reference
	# (sometimes the only date is in the timepoint column)
	#------------------------------------------------------------------------------#
	is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecs, 'Testing empty dates hash reference');
	
	
	#------------------------------------------------------------------------------#
	# Test invalid column name in dates
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Table::read($data, \%idxs, $format, {"abc" => undef});
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Wrong column name/, "Testing invalid column name in dates")
	};

		
	#------------------------------------------------------------------------------#
	# Perform following tests for XLSX, XLS, ODS, and CSV
	#------------------------------------------------------------------------------#
	foreach my $table ("data/spreadsheets/test.xlsx", "data/spreadsheets/test.xls", "data/spreadsheets/test.ods", "data/spreadsheets/test.csv") {
		# Extract table format name for cleaner messages
		my $format = "";
		if ($table =~ m/\.([a-z]{3,4})/) {
			$format = $1;
		}
		else {
			die "ERROR: Unexpected file extension"
		}

		
		#------------------------------------------------------------------------------#
		# Test empty sheet
		#------------------------------------------------------------------------------#
		my $table_mod = $table =~ s/test\./test_empty\./r;
		my $data = MetagDB::Helpers::readFile($table_mod);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates)
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/ERROR.*Empty sheet/, 'Testing empty sheet with ->' . $format . '<- format');
		};
				
		
		#------------------------------------------------------------------------------#
		# Test more than one sheet (not possible for CSV)
		#------------------------------------------------------------------------------#
		if ($format ne "csv") {
			$table_mod = $table =~ s/test\./test_2sheets\./r;
			$data = MetagDB::Helpers::readFile($table_mod);
			try {
				$err = "";
				
				MetagDB::Table::read($data, \%idxs, $format, \%dates)
			}
			catch {
				$err = $_;
			}
			finally {
				ok ($err =~ m/ERROR.*sheet/, 'Testing multiple sheets with ->' . $format . '<- format');
			};
		}
		
		
		#------------------------------------------------------------------------------#
		# Test more than one sheet with UTF-8 (not possible for CSV)
		#------------------------------------------------------------------------------#
		if ($format ne "csv") {
			$table_mod = $table =~ s/test\./test_2sheets_utf8\./r;
			$data = MetagDB::Helpers::readFile($table_mod);
			try {
				$err = "";
				
				MetagDB::Table::read($data, \%idxs, $format, \%dates)
			}
			catch {
				$err = $_;
			}
			finally {
				ok ($err =~ m/ERROR.*sheet/, 'Testing multiple sheets with ->' . $format . '<- format and UTF-8');
			};
		}
		
		
		#------------------------------------------------------------------------------#
		# Test empty header fields
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_emptyHeader\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates)
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/ERROR.*Empty field/, 'Testing empty header field with ->' . $format . '<- format');
		};


		#------------------------------------------------------------------------------#
		# Test header fields only containing blanks
		#------------------------------------------------------------------------------#
		$table_mod= $table =~ s/test\./test_blanksHeader\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates)
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/ERROR.*Empty field/, 'Testing header field with only blanks and ->' . $format . '<- format');
		};
		
		
		#------------------------------------------------------------------------------#
		# Test additional header fields
		#------------------------------------------------------------------------------#
		$table_mod= $table =~ s/test\./test_addHeaderFields\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecs, 'Testing additional header fields and ->' . $format . '<- format');
		
		
		#------------------------------------------------------------------------------#
		# Test no time
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_noTime\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates)
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/ERROR.*No date/, 'Testing no time with ->' . $format . '<- format');
		};
				
		
		#------------------------------------------------------------------------------#
		# Test same time point appears twice and measurements differ
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_conflMeasures\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates)
		}
		catch {
			$err = $_
		}
		finally {
			ok ($err =~ m/ERROR.*Different values.*time/, 'Testing duplicate of time point with measurement conflict with ->' . $format . '<- format');
		};
				
		
		#------------------------------------------------------------------------------#
		# Test same time point appears twice and measurements differ and UTF-8
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_conflMeasures_utf8\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates)
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/ERROR.*Different values.*time/, 'Testing duplicate of time point with measurement conflict with ->' . $format . '<- format and UTF-8');
		};
		
				
		#------------------------------------------------------------------------------#
		# Test same time point appears twice; once empty, once not empty
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_dupMeasure_empty\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates);
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/ERROR.*Different values.*time/, 'Testing duplicate of time point (empty vs defined measure) with ->' . $format . '<- format');
		};
		
		
		#------------------------------------------------------------------------------#
		# Test same time point appears twice; once empty, once not empty and UTF-8
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_dupMeasure_empty_utf8\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates);
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/ERROR.*Different values.*time/, 'Testing duplicate of time point (empty vs defined measure) with ->' . $format . '<- format and UTF8');
		};
		
		
		#------------------------------------------------------------------------------#
		# Test same time point appears twice and measurements are the same
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_sameMeasures\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecs, 'Testing duplicate of time point with same measurement value and ->' . $format . '<- format');

		
		#------------------------------------------------------------------------------#
		# Test same time point appears twice and measurements are the same and UTF-8
		# Also id is UTF-8
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_sameMeasures_utf8\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		my %expecsUtf8 = (
			decode('UTF-8', "Ä") => {
				"Col2"	=>	2,
				"Col3"	=>	3,
				"_times_" =>	{
					"t1"	=>	{
						decode('UTF-8', "Mäsure1")	=>	decode('UTF-8', "Ü1_t1"),
						"Measure2"	=>	"M2_t1"
					},
					"t2"	=>	{
						decode('UTF-8', "Mäsure1")	=>	decode('UTF-8', "Ü1_t2"),
						"Measure2"	=>	"M2_t2"
					},
					"t3"	=>	{
						decode('UTF-8', "Mäsure1")	=>	decode('UTF-8', "Ü1_t3"),
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			decode('UTF-8', "Ö") => {
				"Col2"	=>	22,
				"Col3"	=>	33,
				"_times_" =>	{
					"t1"	=>	{
						decode('UTF-8', "Mäsure1")	=>	decode('UTF-8', "Ü11_t1"),
						"Measure2"	=>	"M22_t1"
					},
					"t2"	=>	{
						decode('UTF-8', "Mäsure1")	=>	decode('UTF-8', "Ü11_t2"),
						"Measure2"	=>	"M22_t2"
					},
					"t3"	=>	{
						decode('UTF-8', "Mäsure1")	=>	decode('UTF-8', "Ü11_t3"),
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			decode('UTF-8', "Ü") => {
				"Col2"	=>	222,
				"Col3"	=>	333,
				"_times_" =>	{
					"t1"	=>	{
						decode('UTF-8', "Mäsure1")	=>	decode('UTF-8', "Ü111_t1"),
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsUtf8, 'Testing duplicate of time point with same measurement value with ->' . $format . '<- format and UTF-8');
		
		
		#------------------------------------------------------------------------------#
		# Test empty measurement values or values that just contain blanks
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_emptyMeasures\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		my %expecsEmpty = (
			'1' => {
				"Col2"	=>	2,
				"Col3"	=>	3,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	undef,
						"Measure2"	=>	"M2_t1"
					},
					"t2"	=>	{
						"Measure1"	=>	undef,
						"Measure2"	=>	"M2_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	undef,
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	22,
				"Col3"	=>	33,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	undef,
						"Measure2"	=>	"M22_t1"
					},
					"t2"	=>	{
						"Measure1"	=>	undef,
						"Measure2"	=>	"M22_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	undef,
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	333,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	undef,
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		
		);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsEmpty, 'Testing empty measurement values with ->' . $format . '<- format');
		
		
		#------------------------------------------------------------------------------#
		# Test zero is kept as a measurement value
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_zeroMeasures\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		my %expecsZero = (
			'1' => {
				"Col2"	=>	2,
				"Col3"	=>	3,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	0,
						"Measure2"	=>	"M2_t1"
					},
					"t2"	=>	{
						"Measure1"	=>	0,
						"Measure2"	=>	"M2_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	0,
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	22,
				"Col3"	=>	33,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	0,
						"Measure2"	=>	"M22_t1"
					},
					"t2"	=>	{
						"Measure1"	=>	0,
						"Measure2"	=>	"M22_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	0,
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	333,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	0,
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		
		);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsZero, 'Testing 0 is kept as measurement value with ->' . $format . '<- format');
		
				
		#------------------------------------------------------------------------------#
		# Test static value appear multiple times and differs
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_conflStatics\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates)
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/ERROR.*Different values.*id/, 'Testing duplicate of static with conflicting values and ->' . $format . '<- format');
		};
		
		
		#------------------------------------------------------------------------------#
		# Test static value appear multiple times and differs (UTF-8)
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_conflStatics_utf8\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates)
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/ERROR.*Different values.*id/, 'Testing duplicate of static with conflicting values and ->' . $format . '<- format and UTF-8');
		};
			
		
		#------------------------------------------------------------------------------#
		# Test empty vs non-empty static values
		#------------------------------------------------------------------------------#
		$data = MetagDB::Helpers::readFile($table);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecs, 'Testing empty vs non-empty statics with ->' . $format . '<- format');
		
		
		#------------------------------------------------------------------------------#
		# Test empty vs non-empty static values (UTF-8)
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_utf8\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		%expecsUtf8 = (
			'1' => {
				"Col2"	=>	decode('UTF-8', 'ä'),
				"Col3"	=>	decode('UTF-8', 'ö'),
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	"M1_t1",
						"Measure2"	=>	"M2_t1"
					},
					"t2"	=>	{
						"Measure1"	=>	"M1_t2",
						"Measure2"	=>	"M2_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	"M1_t3",
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	decode('UTF-8', 'ää'),
				"Col3"	=>	decode('UTF-8', 'öö'),
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	"M11_t1",
						"Measure2"	=>	"M22_t1"
					},
					"t2"	=>	{
						"Measure1"	=>	"M11_t2",
						"Measure2"	=>	"M22_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	"M11_t3",
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	333,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	"M111_t1",
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsUtf8, 'Testing empty vs non-empty statics with ->' . $format . '<- format and UTF-8');
		
		
		#------------------------------------------------------------------------------#
		# Test static value appear multiple times and are the same
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_sameStatics\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecs, 'Testing duplicate of static with same value and ->' . $format . '<- format');
		
		
		#------------------------------------------------------------------------------#
		# Test static value appear multiple times and are the same (UTF-8)
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_sameStatics_utf8\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsUtf8, 'Testing duplicate of static with same value and ->' . $format . '<- format and UTF-8');
		
		
		#------------------------------------------------------------------------------#
		# Test empty static values or static values that just contain blanks
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_emptyStatics\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		%expecsEmpty = (
			'1' => {
				"Col2"	=>	2,
				"Col3"	=>	undef,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	"M1_t1",
						"Measure2"	=>	"M2_t1"
					},
					"t2"	=>	{
						"Measure1"	=>	"M1_t2",
						"Measure2"	=>	"M2_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	"M1_t3",
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	22,
				"Col3"	=>	undef,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	"M11_t1",
						"Measure2"	=>	"M22_t1"
					},
					"t2"	=>	{
						"Measure1"	=>	"M11_t2",
						"Measure2"	=>	"M22_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	"M11_t3",
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	undef,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	"M111_t1",
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		
		);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsEmpty, 'Testing empyt static values with ->' . $format . '<- format');
		
		
		#------------------------------------------------------------------------------#
		# Test 0 is kept as static value
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_zeroStatics\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		%expecsZero = (
			'1' => {
				"Col2"	=>	2,
				"Col3"	=>	0,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	"M1_t1",
						"Measure2"	=>	"M2_t1"
					},
					"t2"	=>	{
						"Measure1"	=>	"M1_t2",
						"Measure2"	=>	"M2_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	"M1_t3",
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	22,
				"Col3"	=>	0,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	"M11_t1",
						"Measure2"	=>	"M22_t1"
					},
					"t2"	=>	{
						"Measure1"	=>	"M11_t2",
						"Measure2"	=>	"M22_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	"M11_t3",
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	0,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	"M111_t1",
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		
		);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsZero, 'Testing 0 is kept as static value with ->' . $format . '<- format');
		
		
		#------------------------------------------------------------------------------#
		# Fields with arbitrary number of leading and trailing whitespaces
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_leadingTrailing\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecs, 'Testing fields with leading and trailing whitespaces ->' . $format . '<- format');
		
		
		#------------------------------------------------------------------------------#
		# Fields with arbitrary number of leading and trailing whitespaces (UTF-8)
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_leadingTrailing_utf8\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		my %expecsWhiteSpUtf8 = (
			'1' => {
				"Col2"	=>	2,
				"Col3"	=>	3,
				"_times_" =>	{
					decode('UTF-8', "ä1")	=>	{
						"Measure1"	=>	decode('UTF-8', "Ä1_t1"),
						"Measure2"	=>	decode('UTF-8', "Ü2_t1")
					},
					"t2"	=>	{
						"Measure1"	=>	"M1_t2",
						"Measure2"	=>	"M2_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	"M1_t3",
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	22,
				"Col3"	=>	33,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	"M11_t1",
						"Measure2"	=>	"M22_t1"
					},
					"t2"	=>	{
						"Measure1"	=>	"M11_t2",
						"Measure2"	=>	"M22_t2"
					},
					"t3"	=>	{
						"Measure1"	=>	"M11_t3",
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	333,
				"_times_" =>	{
					"t1"	=>	{
						"Measure1"	=>	"M111_t1",
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		
		);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsWhiteSpUtf8, 'Testing fields with leading and trailing whitespaces ->' . $format . '<- format and UTF-8');


		#------------------------------------------------------------------------------#
		# Fields with newlines
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_newLine\./r;
		
		try {
			$err = "";
			
			$data = MetagDB::Helpers::readFile($table_mod);
			is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecs, 'Testing fields with newlines ->' . $format . '<- format');
		}
		catch {
			$err = $_;
		}
		finally {
			if ($format ne "csv") {
				# Any error is unexpected
				ok (1==2, 'Testing fields with newlines ->' . $format . '<- format') if ($err);
			}
			else {
				ok ($err =~ m/ERROR.*Newlines in fields not supported for CSV/, 'Testing fields with newlines ->' . $format . '<- format')
			}
		};
		
		
		#------------------------------------------------------------------------------#
		# Fields with newlines (UTF-8)
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_newLine_utf8\./r;
		
		try {
			$err = "";
			
			$data = MetagDB::Helpers::readFile($table_mod);
			is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsWhiteSpUtf8, 'Testing fields with newlines and UTF8 ->' . $format . '<- format');
		}
		catch {
			$err = $_;
		}
		finally {
			if ($format ne "csv") {
				# Any error is unexpected
				ok (1==2, 'Testing fields with newlines and UTF8 ->' . $format . '<- format') if ($err);
			}
			else {
				ok ($err =~ m/ERROR.*Newlines in fields not supported for CSV/, 'Testing fields with newlines and UTF8 ->' . $format . '<- format')
			}
		};
		
		
		#------------------------------------------------------------------------------#
		# Fields with newlines (CRLF)
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_newLineCRLF\./r;
		
		try {
			$err = "";
			
			$data = MetagDB::Helpers::readFile($table_mod);
			is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecs, 'Testing fields with newlines (CRLF) ->' . $format . '<- format');
		}
		catch {
			$err = $_;
		}
		finally {
			if ($format ne "csv") {
				# Any error is unexpected
				ok (1==2, 'Testing fields with newlines (CRLF) ->' . $format . '<- format') if ($err);
			}
			else {
				ok ($err =~ m/ERROR.*Newlines in fields not supported for CSV/, 'Testing fields with newlines (CRLF) ->' . $format . '<- format')
			}
		};
		
		
		#------------------------------------------------------------------------------#
		# Fields with newlines (CRLF and UTF-8)
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_newLineCRLF_utf8\./r;
		
		try {
			$err = "";
			
			$data = MetagDB::Helpers::readFile($table_mod);
			is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsWhiteSpUtf8, 'Testing fields with newlines (CRLF) and UTF8 ->' . $format . '<- format');
		}
		catch {
			$err = $_;
		}
		finally {
			if ($format ne "csv") {
				# Any error is unexpected
				ok (1==2, 'Testing fields with newlines (CRLF) and UTF8 ->' . $format . '<- format') if ($err);
			}
			else {
				ok ($err =~ m/ERROR.*Newlines in fields not supported for CSV/, 'Testing fields with newlines (CRLF) and UTF8 ->' . $format . '<- format')
			}
		};

		
		#------------------------------------------------------------------------------#
		# Test dates (yyyy-mm-dd) after 1899-12-30
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_dates\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		my %expecsDates = (
			'1' => {
				"Col2"	=>	2,
				"Col3"	=>	3,
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M1_t1",
						"Measure2"	=>	"M2_t1"
					},
					"1991-11-12"	=>	{
						"Measure1"	=>	"M1_t2",
						"Measure2"	=>	"M2_t2"
					},
					"1992-11-13"	=>	{
						"Measure1"	=>	"M1_t3",
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	22,
				"Col3"	=>	33,
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M11_t1",
						"Measure2"	=>	"M22_t1"
					},
					"1991-11-12"	=>	{
						"Measure1"	=>	"M11_t2",
						"Measure2"	=>	"M22_t2"
					},
					"1992-11-13"	=>	{
						"Measure1"	=>	"M11_t3",
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	333,
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M111_t1",
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsDates, 'Testing dates and ->' . $format . '<- format');
		
		
		#------------------------------------------------------------------------------#
		# Test dates (yyyy-mm-dd) before 1899-12-30 (error with xlsx, xls)
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_dates1899\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		my %expecsDatesAncient = (
			'1' => {
				"Col2"	=>	2,
				"Col3"	=>	3,
				"_times_" =>	{
					"1111-11-11"	=>	{
						"Measure1"	=>	"M1_t1",
						"Measure2"	=>	"M2_t1"
					},
					"1112-11-12"	=>	{
						"Measure1"	=>	"M1_t2",
						"Measure2"	=>	"M2_t2"
					},
					"1113-11-13"	=>	{
						"Measure1"	=>	"M1_t3",
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	22,
				"Col3"	=>	33,
				"_times_" =>	{
					"1111-11-11"	=>	{
						"Measure1"	=>	"M11_t1",
						"Measure2"	=>	"M22_t1"
					},
					"1112-11-12"	=>	{
						"Measure1"	=>	"M11_t2",
						"Measure2"	=>	"M22_t2"
					},
					"1113-11-13"	=>	{
						"Measure1"	=>	"M11_t3",
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	333,
				"_times_" =>	{
					"1111-11-11"	=>	{
						"Measure1"	=>	"M111_t1",
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		
		);
		my $outR = "";
		try {
			$err = "";
			
			$outR = MetagDB::Table::read($data, \%idxs, $format, \%dates);
		}
		catch {
			$err = $_;
		}
		finally {
			if ($format eq "xlsx" or $format eq "xls") {
				ok($err =~ m/ERROR.*Invalid date/, 'Testing dates before 1899 with ->' . $format . '<- format')
			}
			else {
				# Automatic fail, if errors for non-Excel formats
				if ($err) {
					ok(1==2 , 'Testing dates before 1899 with ->' . $format . '<- format')
				}
				is($outR, \%expecsDatesAncient, 'Testing dates before 1899 with ->' . $format . '<- format')
			}
		};		
				
		
		#------------------------------------------------------------------------------#
		# Test dates (yyyy-mm-dd) and UTF-8 (time range does not matter)
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_dates_utf8\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		my %expecsDatesUtf8 = (
			'1' => {
				"Col2"	=>	2,
				"Col3"	=>	3,
				"_times_" =>	{
					decode('UTF-8', "11 März 1990")	=>	{
						"Measure1"	=>	"M1_t1",
						"Measure2"	=>	"M2_t1"
					},
					decode('UTF-8', "12 März 1111")	=>	{
						"Measure1"	=>	"M1_t2",
						"Measure2"	=>	"M2_t2"
					},
					decode('UTF-8', "13 März 1993")	=>	{
						"Measure1"	=>	"M1_t3",
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	22,
				"Col3"	=>	33,
				"_times_" =>	{
					decode('UTF-8', "11 März 1990")	=>	{
						"Measure1"	=>	"M11_t1",
						"Measure2"	=>	"M22_t1"
					},
					decode('UTF-8', "12 März 1111")	=>	{
						"Measure1"	=>	"M11_t2",
						"Measure2"	=>	"M22_t2"
					},
					decode('UTF-8', "13 März 1993")	=>	{
						"Measure1"	=>	"M11_t3",
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	333,
				"_times_" =>	{
					decode('UTF-8', "11 März 1990")	=>	{
						"Measure1"	=>	"M111_t1",
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates), \%expecsDatesUtf8, 'Testing dates with ->' . $format . '<- format and UTF-8');		
		
		
		#------------------------------------------------------------------------------#
		# Test illegal static name "_times_" (used internally to store timepoints)
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_illegalStatic\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates)
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/^ERROR.*Illegal static/, 'Testing illegal static name with ->' . $format . '<- format');
		};
		
		
		#------------------------------------------------------------------------------#
		# Test using column name of timepoint column (from idxs) in dates
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_dates\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		my %dates_mod  = ("Time" => undef);
		is (MetagDB::Table::read($data, \%idxs, $format, \%dates_mod), \%expecsDates, 'Testing timepoint column in dates with ->' . $format . '<- format');
		
		
		#------------------------------------------------------------------------------#
		# Test using non-existent column in dates
		#------------------------------------------------------------------------------#
		$data = MetagDB::Helpers::readFile($table_mod);
		%dates_mod = ("__FooBarColumn__" => undef);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates_mod)
		}
		catch {
			$err = $_;
		}
		finally {
			ok($err =~ m/ERROR.*Wrong column name.*in dates/, 'Testing non-existent column name in dates with ->' . $format . '<- format');
		};
		
		
		#------------------------------------------------------------------------------#
		# Test using non-existent column in dates (UTF-8)
		#------------------------------------------------------------------------------#
		$data = MetagDB::Helpers::readFile($table_mod);
		%dates_mod = (decode('UTF-8', "__FooBärColumn__") => undef);
		try {
			$err = "";
			
			MetagDB::Table::read($data, \%idxs, $format, \%dates_mod)
		}
		catch {
			$err = $_;
		}
		finally {
			ok($err =~ m/ERROR.*Wrong column name.*in dates/, 'Testing non-existent column name in dates with ->' . $format . '<- format and UTF-8');
		};

				
		#------------------------------------------------------------------------------#
		# Test existing column name in dates with date (yyyy-mm-dd) after 1899-12-30
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_addDates\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		%dates_mod = ("Col3" => undef);
		my %expecsAddDates = (
			'1' => {
				"Col2"	=>	2,
				"Col3"	=>	"1990-12-24",
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M1_t1",
						"Measure2"	=>	"M2_t1"
					},
					"1991-11-12"	=>	{
						"Measure1"	=>	"M1_t2",
						"Measure2"	=>	"M2_t2"
					},
					"1992-11-13"	=>	{
						"Measure1"	=>	"M1_t3",
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	22,
				"Col3"	=>	"1990-12-25",
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M11_t1",
						"Measure2"	=>	"M22_t1"
					},
					"1991-11-12"	=>	{
						"Measure1"	=>	"M11_t2",
						"Measure2"	=>	"M22_t2"
					},
					"1992-11-13"	=>	{
						"Measure1"	=>	"M11_t3",
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	"1990-12-26",
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M111_t1",
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		);
		is(MetagDB::Table::read($data, \%idxs, $format, \%dates_mod), \%expecsAddDates, 'Testing additional date column with ->' . $format . '<- format');
		
		
		#------------------------------------------------------------------------------#
		# Test existing column name in dates with date (yyyy-mm-dd) before 1899-12-30;
		# problem with XLSX and XLS
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_addDates1899\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		my %expecsAddDatesAncient = (
			'1' => {
				"Col2"	=>	2,
				"Col3"	=>	"1111-12-24",
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M1_t1",
						"Measure2"	=>	"M2_t1"
					},
					"1991-11-12"	=>	{
						"Measure1"	=>	"M1_t2",
						"Measure2"	=>	"M2_t2"
					},
					"1992-11-13"	=>	{
						"Measure1"	=>	"M1_t3",
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	22,
				"Col3"	=>	"1111-12-25",
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M11_t1",
						"Measure2"	=>	"M22_t1"
					},
					"1991-11-12"	=>	{
						"Measure1"	=>	"M11_t2",
						"Measure2"	=>	"M22_t2"
					},
					"1992-11-13"	=>	{
						"Measure1"	=>	"M11_t3",
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	"1111-12-26",
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M111_t1",
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		);
		$outR = "";
		try {
			$err = "";
			
			$outR = MetagDB::Table::read($data, \%idxs, $format, \%dates_mod)
		}
		catch {
			$err = $_;
		}
		finally {
			if ($format eq "xlsx" or $format eq "xls") {
				ok($err =~ m/ERROR.*Invalid date/, 'Testing additional date column with date before 1899 and ->' . $format . '<- format')
			}
			else {
				# Any error with non-Excel formats is an automatic fail
				if ($err) {
					ok (1==2, 'Testing additional date column with date before 1899 and ->' . $format . '<- format')
				}
				is($outR, \%expecsAddDatesAncient, 'Testing additional date column with date before 1899 and ->' . $format . '<- format')
			}
		};
		
		
		#------------------------------------------------------------------------------#
		# Test existing column name in dates with date (yyyy-mm-dd) and UTF-8
		# (time range does not matter)
		#------------------------------------------------------------------------------#
		$table_mod = $table =~ s/test\./test_addDates_utf8\./r;
		$data = MetagDB::Helpers::readFile($table_mod);
		my %expecsAddDatesUtf8 = (
			'1' => {
				"Col2"	=>	2,
				"Col3"	=>	decode('UTF-8', "12 März 1990"),
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M1_t1",
						"Measure2"	=>	"M2_t1"
					},
					"1991-11-12"	=>	{
						"Measure1"	=>	"M1_t2",
						"Measure2"	=>	"M2_t2"
					},
					"1992-11-13"	=>	{
						"Measure1"	=>	"M1_t3",
						"Measure2"	=>	"M2_t3"
					}
				}
			},
			'11' => {
				"Col2"	=>	22,
				"Col3"	=>	decode('UTF-8', "11 März 1111"),
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M11_t1",
						"Measure2"	=>	"M22_t1"
					},
					"1991-11-12"	=>	{
						"Measure1"	=>	"M11_t2",
						"Measure2"	=>	"M22_t2"
					},
					"1992-11-13"	=>	{
						"Measure1"	=>	"M11_t3",
						"Measure2"	=>	"M22_t3"
					}
				}
			},
			'111' => {
				"Col2"	=>	222,
				"Col3"	=>	decode('UTF-8', "13 März 1000"),
				"_times_" =>	{
					"1990-11-11"	=>	{
						"Measure1"	=>	"M111_t1",
						"Measure2"	=>	"M222_t1"
					}
				}
			}
		);
		is(MetagDB::Table::read($data, \%idxs, $format, \%dates_mod), \%expecsAddDatesUtf8, 'Testing additional date column with ->' . $format . '<- format and UTF-8');
	}
	
	
	#------------------------------------------------------------------------------#
	# Test for XLSX, XLS, ODS, CSV: Invalid table file that cannot be
	# processed by parser. Here, this is a table file which is still compressed.
	# CSV will rather unspecifically complain about count of header fields.
	#------------------------------------------------------------------------------#
	foreach my $table ("data/spreadsheets/test.xlsx.zip", "data/spreadsheets/test.xls.zip", "data/spreadsheets/test.ods.zip", "data/spreadsheets/test.csv.zip") {
		my $format = "";
		if ($table =~ m/\.([a-z]{3,4})/) {
			$format = $1;
		}
		else {
			die "ERROR: Unexpected file extension"
		}
		
		my $data = MetagDB::Helpers::readFile($table);
		try {
			$err = "";
			MetagDB::Table::read($data, \%idxs, $format, \%dates);
		}
		catch {
			$err = $_;
		}
		finally {
			if ($format ne "csv") {
				ok($err =~ m/ERROR.*Could not parse spreadsheet/, 'Testing invalid table file with ->' . $format . '<-')
			}
			else {
				ok($err =~ m/ERROR.*Too few fields in header/, 'Testing invalid table file with ->' . $format . '<-')
			}
		};
	}
	
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Main
#--------------------------------------------------------------------------------------------------#
#
# Parse spreadsheet
print "INFO: Testing parsing of spreadsheets\n";
test_read;

done_testing();