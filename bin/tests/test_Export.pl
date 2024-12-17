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
# Tests for MetagDB::Export module
#==================================================================================================#
# DESCRIPTION
# 
#	Test the functions in the MetagDB::Export module.
#
#
# USAGE
#
# 	./test_Export.pl
#
#					
# DEPENDENCIES
#
#	MetagDB::Export
#	Test2::Bundle::More
#	Test2::Tools::Compare
#	Try::Tiny
#==================================================================================================#


use strict;
use warnings;

use Storable qw(dclone);
use Test2::Bundle::More qw(ok done_testing);
use Test2::Tools::Compare;
use Try::Tiny;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl/";
use MetagDB::Export;


#
#--------------------------------------------------------------------------------------------------#
# Test the otuTab function
#--------------------------------------------------------------------------------------------------#
#
sub test_otuTab {
	my $err = "";
	
	my $classR = {
		"S1"	=>	{
			"C1"	=> 1,
			"C2"	=> 0,
			"C11"	=> 11
		},
		"S2"	=> {
			"C1"	=> 0,
			"C2"	=> 2,
			"C22"	=> 22
		}
	};
	my $header = "#NAME";
	
	#------------------------------------------------------------------------------#
	# Test no classification reference (and no header)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::otuTab();
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no classification reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no header
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::otuTab($classR);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no header');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty classification reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::otuTab("", $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty classification reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classification empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::otuTab({}, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No classifications or not a reference/, 'Testing classification empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classification not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::otuTab("abc", $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No classifications or not a reference/, 'Testing classification not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty header
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::otuTab($classR, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty header');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid input
	#------------------------------------------------------------------------------#
	my $expecsTab = $header . "\tS1\tS2\nOTU0\t1\t0\nOTU1\t11\t0\nOTU2\t0\t2\nOTU3\t0\t22";
	my $expecsIDsR = {
		"OTU0"	=> "C1",
		"OTU1"	=> "C11",
		"OTU2"	=> "C2",
		"OTU3"	=> "C22"
	};
	my $resTab = "";
	my $resIDsR = {};
	
	try {
		$err = "";
		$resTab = "";
		$resIDsR = {};
		($resTab, $resIDsR) = MetagDB::Export::otuTab($classR, $header);
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, "Testing valid input");
	}
	finally {
		is ($resTab, $expecsTab, 'Testing valid input - OTU table');
		is ($resIDsR, $expecsIDsR, 'Testing valid input - ID mapping');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty sample name
	#------------------------------------------------------------------------------#
	my $classModR = dclone($classR);
	$classModR->{""} = {"C1" => 0};
	
	try {
		$err = "";
		MetagDB::Export::otuTab($classModR, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid sample name/, 'Testing empty sample name');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no classifications for sample
	#------------------------------------------------------------------------------#
	$classModR = dclone($classR);
	$classModR->{"S1"} = {};

	try {
		$err = "";
		MetagDB::Export::otuTab($classModR, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No classifications/, 'Testing no classifications for sample');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty classification name for sample
	#------------------------------------------------------------------------------#
	$classModR->{"S1"} = {"" => 0};

	try {
		$err = "";
		MetagDB::Export::otuTab($classModR, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid classification name/, 'Testing empty classification name');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classification empty count
	#------------------------------------------------------------------------------#
	$classModR = dclone($classR);
	$classModR->{"S2"}->{"C1"} = "";

	try {
		$err = "";
		$resTab = "";
		$resIDsR = {};
		($resTab, $resIDsR) = MetagDB::Export::otuTab($classModR, $header);
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, "Testing classification empty count");
	}
	finally {
		is ($resTab, $expecsTab, 'Testing classification empty count - OTU table');
		is ($resIDsR, $expecsIDsR, 'Testing classification empty count - ID mapping');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classification undefined count
	#------------------------------------------------------------------------------#
	$classModR->{"S2"}->{"C1"} = undef;

	try {
		$err = "";
		$resTab = "";
		$resIDsR = {};
		($resTab, $resIDsR) = MetagDB::Export::otuTab($classModR, $header);
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, "Testing classification undefined count");
	}
	finally {
		is ($resTab, $expecsTab, 'Testing classification undefined count - OTU table');
		is ($resIDsR, $expecsIDsR, 'Testing classification undefined count - ID mapping');
	};
	
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Test taxonomy function
#--------------------------------------------------------------------------------------------------#
#
sub test_taxonomy {
	my $err = "";
	
	my $mapsR = {
		"OTU0"	=> "K0;P0;C0;;F0;G0;S0",
		"OTU1"	=> "K1;P1;C1;O1;F1;G1;S1",
		"OTU2"	=> "K2;P2;C2;O2;F2;G2;S2",
		"OTU3"	=> "K3;P3;UNMATCHED;UNMATCHED;UNMATCHED;UNMATCHED;UNMATCHED"
	};
	my $header = "#TAXONOMY\tKingdom\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies";
	
	
	#------------------------------------------------------------------------------#
	# Test no mapping reference (and no header)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::taxonomy();
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no mapping reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no header
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::taxonomy($mapsR);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no header');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty mapping reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::taxonomy("", $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty mapping reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test mapping empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::taxonomy({}, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No mappings or not a reference/, 'Testing mappings empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test mappings not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::taxonomy("abc", $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No mappings or not a reference/, 'Testing mappings not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty header
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::taxonomy($mapsR, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty header');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test header too short
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::taxonomy($mapsR, "#TAXONOMY");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Header only contains/, 'Testing header too short');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid input
	#------------------------------------------------------------------------------#
	my $expec = $header . "\n" .
		"OTU0\tK0\tP0\tC0\tNoName\tF0\tG0\tS0\n" .
		"OTU1\tK1\tP1\tC1\tO1\tF1\tG1\tS1\n" .
		"OTU2\tK2\tP2\tC2\tO2\tF2\tG2\tS2\n" .
		"OTU3\tK3\tP3\tNA\tNA\tNA\tNA\tNA";
	my $res = "";	
		
	try {
		$err = "";
		$res = "";
		$res = MetagDB::Export::taxonomy($mapsR, $header);
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing valid input');
	}
	finally {
		is ($res, $expec, 'Testing valid input');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid ID
	#------------------------------------------------------------------------------#
	my $mapsModR = dclone($mapsR);
	$mapsModR->{""} = "K1";
	
	try {
		$err = "";
		MetagDB::Export::taxonomy($mapsModR, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid ID/, 'Testing invalid ID');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty classification for ID
	#------------------------------------------------------------------------------#
	$mapsModR = dclone($mapsR);
	$mapsModR->{"OTU0"} = "";
	
	try {
		$err = "";
		MetagDB::Export::taxonomy($mapsModR, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough ranks/, 'Testing empty classification for IDs');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test undefined classification for ID
	#------------------------------------------------------------------------------#
	$mapsModR->{"OTU0"} = undef;
	
	try {
		$err = "";
		MetagDB::Export::taxonomy($mapsModR, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough ranks/, 'Testing empty classification for IDs');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test too few ranks in classification
	#------------------------------------------------------------------------------#
	$mapsModR->{"OTU0"} = "K1";
	
	try {
		$err = "";
		MetagDB::Export::taxonomy($mapsModR, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough ranks/, 'Testing too few ranks in classification');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test extract less ranks than available
	#------------------------------------------------------------------------------#
	my $headerMod = "#TAXONOMY\tKingdom";
	my $expecMod = $headerMod . "\n" .
		"OTU0\tK0\n" .
		"OTU1\tK1\n" .
		"OTU2\tK2\n" .
		"OTU3\tK3";
		
	try {
		$err = "";
		$res = "";
		$res = MetagDB::Export::taxonomy($mapsR, $headerMod);
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing extract less ranks than available');
	}
	finally {
		is ($res, $expecMod, 'Testing extract less ranks than available');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty classification translated to NoName
	#------------------------------------------------------------------------------#
	$mapsModR->{"OTU0"} = "";
	$headerMod = "#TAXONOMY\tKingdom";
	$expecMod = $headerMod . "\n" .
		"OTU0\tNoName\n" .
		"OTU1\tK1\n" .
		"OTU2\tK2\n" .
		"OTU3\tK3";
		
	try {
		$err = "";
		$res = "";
		$res = MetagDB::Export::taxonomy($mapsModR, $headerMod);
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing empty classification translated to NoName');
	}
	finally {
		is ($res, $expecMod, 'Testing empty classification translated to NoName');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test undefined classification translated to NoName
	#------------------------------------------------------------------------------#
	$mapsModR->{"OTU0"} = undef;
	$headerMod = "#TAXONOMY\tKingdom";
	$expecMod = $headerMod . "\n" .
		"OTU0\tNoName\n" .
		"OTU1\tK1\n" .
		"OTU2\tK2\n" .
		"OTU3\tK3";
		
	try {
		$err = "";
		$res = "";
		$res = MetagDB::Export::taxonomy($mapsModR, $headerMod);
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing undefined classification translated to NoName');
	}
	finally {
		is ($res, $expecMod, 'Testing undefined classification translated to NoName');
	};
	
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Test metadata function
#--------------------------------------------------------------------------------------------------#
#
sub test_metadata {
	my $err = "";
	
	my $metasR = {
		"S1"	=> {
			"M1" => "V1",
			"M11" => "V11",
			"z_score_category" => "SGA"
		},
		"S2"	=> {
			"M1" => "V1",
			"M11" => "V11",
			"M2" => "V2",
			"z_score_category" => "AGA"
		},
		"S3"	=> {
			"M3" => "V3",
		},
		"S4"	=> {
			"z_score_category" => ""
		}
	};
	my $header = "#NAME";
	
	
	#------------------------------------------------------------------------------#
	# Test no metadata reference (and no header)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::metadata();
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no metadata reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no header
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::metadata($metasR);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no header');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty metadata reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::metadata("", $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty metadata reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test metadata empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::metadata({}, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No metadata or not a reference/, 'Testing metadata empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test metadata not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::metadata("abc", $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No metadata or not a reference/, 'Testing metadata not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty header
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::metadata($metasR, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough/, 'Testing empty header');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid input (incl. missing metadata and completely missing)
	#------------------------------------------------------------------------------#
	my $res = "";
	my $expec = "$header\tz_score_category\tM1\tM11\tM2\tM3\n" .
		"S1\tSGA\tV1\tV11\tNA\tNA\n" .
		"S2\tAGA\tV1\tV11\tV2\tNA\n" .
		"S3\tNA\tNA\tNA\tNA\tV3\n" .
		"S4\tNA\tNA\tNA\tNA\tNA";
	
	try {
		$err = "";
		$res = "";
		$res = MetagDB::Export::metadata($metasR, $header);
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing valid input');
	}
	finally {
		is ($res, $expec, 'Testing valid input')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test translate empty and/or undefined metadata values to "NA"
	#------------------------------------------------------------------------------#
	my $metasModR = dclone($metasR);
	# z_score_category was previously empty
	$metasModR->{"S4"} = {"M1" => "", "M11" => "", "M2" => undef, "z_score_category" => undef};
	
	try {
		$err = "";
		$res = "";
		$res = MetagDB::Export::metadata($metasModR, $header);
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing handling of empty/undefined metadata values');
	}
	finally {
		is ($res, $expec, 'Testing handling of empty/undefined metadata values')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid sample name
	#------------------------------------------------------------------------------#
	$metasModR = dclone($metasR);
	$metasModR->{""} = {"M1" => "V1"};
	
	try {
		$err = "";
		MetagDB::Export::metadata($metasModR, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid sample name/, 'Testing invalid sample name');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid metadata name
	#------------------------------------------------------------------------------#
	$metasModR = dclone($metasR);
	$metasModR->{"S1"}->{""} = "V1";
	
	try {
		$err = "";
		MetagDB::Export::metadata($metasModR, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid metadata name/, 'Testing invalid metadata name');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no metadata
	#------------------------------------------------------------------------------#
	$metasModR = dclone($metasR);
	foreach my $sample (keys(%{$metasModR})) {
		$metasModR->{$sample} = {};	
	}
	
	try {
		$err = "";
		MetagDB::Export::metadata($metasModR, $header);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*No metadata/, 'Testing no metadata');
	};
	
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Test metadata function
#--------------------------------------------------------------------------------------------------#
#
sub test_webVis {
	my $err = "";
	
	
	my $classR = {
		1 => {
			"S1"	=>	{
				"K1;P1;C1;O1;F1;G1;S1"	=> 1,
				"K2;P2;C2;O2;F2;G2;S2"	=> 0,
				"K11;P11;C11;O11;F11;G11;S11"	=> 11
			}
		},
		2 => {
			"S2"	=> {
				"K1;P1;C1;O1;F1;G1;S1"	=> 0,
				"K2;P2;C2;O2;F2;G2;S2"	=> 2,
				"K22;P22;C22;O22;F22;G22;S22"	=> 22
			}
		},
		3 => {
			"S3"	=> {
				"K1;P1;C1;O1;F1;G1;S1"	=> 3,
				"K2;P2;C2;O2;F2;G2;S2"	=> 0,
				"K33;P33;C33;O33;F33;G33;S33"	=> 33
			}
		},
	};
	my $metasR = {
		1 => {
			"S1"	=> {
				"M1" => "V1",
				"M11" => "V11",
				"z_score_category" => "SGA"
			}
		},
		2 => {
			"S2"	=> {
				"M1" => "V1",
				"M11" => "V11",
				"M2" => "V2",
				"z_score_category" => "AGA"
			}
		},
		3 => {
			"S3"	=> {
				"z_score_category" => ""
			}
		}
	};
	my $tool = "MicrobiomeAnalyst";
	
	
	#------------------------------------------------------------------------------#
	# Test no classification reference (and no metadata reference + no tool)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::webVis();
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no classification reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no metadata reference (and no tool)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::webVis($classR);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no metadata reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no tool
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::webVis($classR, $metasR);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no tool');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty classification reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::webVis("", $metasR, $tool);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough arguments/, 'Testing empty classification reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classification empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::webVis({}, $metasR, $tool);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Classifications.*empty or not a reference/, 'Testing classification empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classification not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::webVis("abc", $metasR, $tool);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Classifications.*empty or not a reference/, 'Testing classification not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classifications invalid format: More than one sample name for ID
	#------------------------------------------------------------------------------#
	my $classModR = dclone($classR);
	$classModR->{"1"} = {"foobar" => {}, "barfoo" => {}};
	
	try {
		$err = "";
		MetagDB::Export::webVis($classModR, $metasR, $tool);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Each ID in classifications/, 'Testing classifications invalid format [1/2]');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classifications invalid format: Sample names not unique
	#------------------------------------------------------------------------------#
	$classModR->{"1"} = {"foobar" => {}};
	$classModR->{"2"} = {"foobar" => {}};
	
	try {
		$err = "";
		MetagDB::Export::webVis($classModR, $metasR, $tool);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Sample names in classifications not unique/, 'Testing classifications invalid format [2/2]');
	};

	
	#------------------------------------------------------------------------------#
	# Test empty metadata reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::webVis($classR, "", $tool);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough arguments/, 'Testing empty metadata reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test metadata empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::webVis($classR, {}, $tool);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*metadata.*empty or not a reference/, 'Testing metadata empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test metadata not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::webVis($classR, "abc", $tool);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*metadata.*empty or not a reference/, 'Testing metadata not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test metadata invalid format: More than one sample name for ID
	#------------------------------------------------------------------------------#
	my $metasModR = dclone($metasR);
	$metasModR->{"1"} = {"foobar" => {}, "barfoo" => {}};
	
	try {
		$err = "";
		MetagDB::Export::webVis($classR, $metasModR, $tool);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Each ID in metadata/, 'Testing metadata invalid format [1/2]');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test metadata invalid format: Sample names not unique
	#------------------------------------------------------------------------------#
	$metasModR->{"1"} = {"foobar" => {}};
	$metasModR->{"2"} = {"foobar" => {}};
	
	try {
		$err = "";
		MetagDB::Export::webVis($classR, $metasModR, $tool);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Sample names in metadata not unique/, 'Testing metadata invalid format [2/2]');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test sample names in metadata and classification not matching
	#------------------------------------------------------------------------------#
	$metasModR = dclone($metasR);
	$metasModR->{"1"} = {"foobar" => {}};
	
	try {
		$err = "";
		MetagDB::Export::webVis($classR, $metasModR, $tool);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Classifications and metadata must have the same sample names/, 'Testing sample names not matching');
	};
	
		
	#------------------------------------------------------------------------------#
	# Test empty tool name
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::webVis($classR, $metasR, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough arguments/, 'Testing empty tool name');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test unsupported tool
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Export::webVis($classR, $metasR, "foobar");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Unrecognized tool/, 'Testing unsupported tool');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid input (MicrobiomeAnalyst)
	#------------------------------------------------------------------------------#
	my $expecOTU = "#NAME\tS1\tS2\tS3\n" .
		"OTU0\t11\t0\t0\n" .
		"OTU1\t1\t0\t3\n" .
		"OTU2\t0\t22\t0\n" .
		"OTU3\t0\t2\t0\n" .
		"OTU4\t0\t0\t33";
	my $expecTax = "#TAXONOMY\tKingdom\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\n" .
		"OTU0\tK11\tP11\tC11\tO11\tF11\tG11\tS11\n" .
		"OTU1\tK1\tP1\tC1\tO1\tF1\tG1\tS1\n" .
		"OTU2\tK22\tP22\tC22\tO22\tF22\tG22\tS22\n" .
		"OTU3\tK2\tP2\tC2\tO2\tF2\tG2\tS2\n" .
		"OTU4\tK33\tP33\tC33\tO33\tF33\tG33\tS33";
	my $expecMeta = "#NAME\tz_score_category\tM1\tM11\tM2\n" .
		"S1\tSGA\tV1\tV11\tNA\n" .
		"S2\tAGA\tV1\tV11\tV2\n" .
		"S3\tNA\tNA\tNA\tNA";

	my ($resOTU, $resTax, $resMeta) = ("") x 3;
	
	try {
		$err = "";
		($resOTU, $resTax, $resMeta) = ("") x 3;
		($resOTU, $resTax, $resMeta) = MetagDB::Export::webVis($classR, $metasR, "MicrobiomeAnalyst");
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing MicrobiomeAnalyst');
	}
	finally {
		is ($resOTU, $expecOTU, 'Testing MicrobiomeAnalyst - OTU');
		is ($resTax, $expecTax, 'Testing MicrobiomeAnalyst - taxonomy');
		is ($resMeta, $expecMeta, 'Testing MicrobiomeAnalyst - metadata');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid input (Namco). This will just change the headers.
	#------------------------------------------------------------------------------#
	my $expecOTUmod = $expecOTU =~ s/^\#[a-zA-Z]*\t/Name\t/r;
	my $expecMetamod = $expecMeta =~ s/^\#[a-zA-Z]*\t/Name\t/r;
	my $expecTaxmod = $expecTax =~ s/^\#[a-zA-Z]*\t/Taxa\t/r;
	
	
	try {
		$err = "";
		($resOTU, $resTax, $resMeta) = ("") x 3;
		($resOTU, $resTax, $resMeta) = MetagDB::Export::webVis($classR, $metasR, "Namco");
	}
	catch {
		$err = $_;
		print $err;
		ok(1==2, 'Testing Namco');
	}
	finally {
		is ($resOTU, $expecOTUmod, 'Testing Namco - OTU');
		is ($resTax, $expecTaxmod, 'Testing Namco - taxonomy');
		is ($resMeta, $expecMetamod, 'Testing Namco - metadata');
	};
	
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Main
#--------------------------------------------------------------------------------------------------#
#
print "INFO: Testing to create the OTU table\n";
test_otuTab;

print "INFO: Testing to create the taxonomy table\n";
test_taxonomy;

print "INFO: Testing to create the metadata table\n";
test_metadata;

print "INFO: Testing to run one full export\n";
test_webVis;

done_testing();