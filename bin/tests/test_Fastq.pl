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
# Tests for MetagDB::Fastq module
#==================================================================================================#
# DESCRIPTION
# 
#	Test the functions in the MetagDB::Fastq module.
#
#
# USAGE
#
# 	./test_Fastq.pl
#
#					
# DEPENDENCIES
#
#	MetagDB::Fastq
#	Test2::Bundle::More
#	Test2::Tools::Compare
#	Try::Tiny
#==================================================================================================#


use strict;
use warnings;

use Test2::Bundle::More qw(ok done_testing);
use Test2::Tools::Compare;
use Try::Tiny;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl/";
use MetagDB::Fastq;


#
#--------------------------------------------------------------------------------------------------#
# Test the process function
#--------------------------------------------------------------------------------------------------#
#
sub test_process {
	my $err = "";
	my %targetFields = ("barcode" => undef, "channel" => undef);
	
	#------------------------------------------------------------------------------#
	# Test no FASTQ + no target metadata
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Fastq::process();
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no FASTQ');
	};
	
	
	#------------------------------------------------------------------------------#
	# Invalid FASTQ (=> FASTA-like), but line count divisible by 4
	#------------------------------------------------------------------------------#
	my $fastq = "\@abc\nATGC\n\@def\nTACG";
	try {
		$err = "";
		MetagDB::Fastq::process($fastq, \%targetFields)
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid FASTQ format/, 'Testing invalid FASTA-like: line count divisible by 4')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty FASTQ
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Fastq::process("", \%targetFields)
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty FASTQ')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test FASTQ containing only whitespaces
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Fastq::process("    ", \%targetFields)
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid FASTQ.*lines/, 'Testing FASTQ containing only whitespaces')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test FASTQ containing only empty lines
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Fastq::process("\n\n\n\n", \%targetFields)
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid FASTQ.*lines/, 'Testing FASTQ containing only empty lines')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty target fields (+ invalid FASTQ)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Fastq::process($fastq, "")
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty target fields')
	};
	
	
	#------------------------------------------------------------------------------#
	# Test target fields not a reference (+ invalid FASTQ)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Fastq::process($fastq, "abc")
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Fields not a reference/, 'Testing target fields not a reference')
	};
	
	
	#------------------------------------------------------------------------------#
	# Invalid FASTQ (=> FASTA-like), but line count not divisible by 4
	#------------------------------------------------------------------------------#
	$fastq = "\@abc\nATGC\n\@def\nTACG\n\@ghi\nTTTT";
	try {
		$err = "";
		MetagDB::Fastq::process($fastq, \%targetFields)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid FASTQ.*lines/, 'Testing invalid FASTA-like: line count not divisible by 4')
	};
	
	
	#------------------------------------------------------------------------------#
	# Invalid FASTQ with wrong header
	#------------------------------------------------------------------------------#
	$fastq = ">abc\nATGC\n+\n!!!!\n>def\nTACG\n+\n1!!!\n>ghi\nTTTT\n+\n11!!";
	try {
		$err = "";
		MetagDB::Fastq::process($fastq, \%targetFields)
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Invalid FASTQ header/, 'Testing invalid FASTQ wrong header');
	};
		
	
	#------------------------------------------------------------------------------#
	# Valid FASTQ with no metadata in header
	#------------------------------------------------------------------------------#
	$fastq = "\@abc\nATGC\n\+\n!!!!\n\@def\nTACG\n\+\n1!!!\n\@ghi\nTTTT\n\+\n11!!";
	my %expecs = (
		"abc" => {"_seq_" => "ATGC", "_qual_" => "!!!!", "barcode" => undef, "channel" => undef},
		"def" => {"_seq_" => "TACG", "_qual_" => "1!!!", "barcode" => undef, "channel" => undef},
		"ghi" => {"_seq_" => "TTTT", "_qual_" => "11!!", "barcode" => undef, "channel" => undef},
	);
	my $resR = MetagDB::Fastq::process($fastq, \%targetFields);
	is ($resR, \%expecs, 'Testing FASTQ no metadata');
	
	
	#------------------------------------------------------------------------------#
	# Valid FASTQ with necessary metadata + other metadata in header
	#------------------------------------------------------------------------------#
	$fastq = "\@abc barcode=01 channel=A1 testmeta=test\nATGC\n\+\n!!!!\n\@def barcode=02 channel=A2\nTACG\n\+\n1!!!\n\@ghi barcode=03 channel=A3\nTTTT\n\+\n11!!";
	%expecs = (
		"abc" => {"_seq_" => "ATGC", "_qual_" => "!!!!", "barcode" => "01", "channel" => "A1"},
		"def" => {"_seq_" => "TACG", "_qual_" => "1!!!", "barcode" => "02", "channel" => "A2"},
		"ghi" => {"_seq_" => "TTTT", "_qual_" => "11!!", "barcode" => "03", "channel" => "A3"},
	);
	$resR = MetagDB::Fastq::process($fastq, \%targetFields);
	is ($resR, \%expecs, 'Testing FASTQ with metadata');
	
	
	#------------------------------------------------------------------------------#
	# Test no target fields
	#------------------------------------------------------------------------------#
	%expecs = (
		"abc" => {"_seq_" => "ATGC", "_qual_" => "!!!!"},
		"def" => {"_seq_" => "TACG", "_qual_" => "1!!!"},
		"ghi" => {"_seq_" => "TTTT", "_qual_" => "11!!"},
	);
	$resR = MetagDB::Fastq::process($fastq);
	is ($resR, \%expecs, 'Testing no target fields');
	
	
	#------------------------------------------------------------------------------#
	# Test empty target fields hash reference
	#------------------------------------------------------------------------------#
	$resR = MetagDB::Fastq::process($fastq, {});
	is ($resR, \%expecs, 'Testing empty target fields hash reference');
	
	
	#------------------------------------------------------------------------------#
	# Valid FASTQ with invalid metadata in header which is also requested by user
	#------------------------------------------------------------------------------#
	$fastq = "\@abc _seq_=ATGC\nATGC\n\+\n!!!!\n\@def _qual_=1!!!\nTACG\n\+\n1!!!\n\@ghi _seq_=TTTT _qual_=11!!\nTTTT\n\+\n11!!";
	%targetFields = ("barcode" => undef, "channel" => undef, "_seq_" => undef, "_qual_" => undef);
	try {
		$err = "";
		MetagDB::Fastq::process($fastq, \%targetFields)
	}
	catch {
		$err = $_	
	}
	finally {
		ok ($err =~ m/ERROR.*Header metadata/, 'Testing FASTQ invalid metadata requested');
	};
	
	
	#------------------------------------------------------------------------------#
	# Valid FASTQ with invalid metadata in header which is not requested by user
	#------------------------------------------------------------------------------#
	$fastq = "\@abc _seq_=ATGC\nATGC\n\+\n!!!!\n\@def _qual_=1!!!\nTACG\n\+\n1!!!\n\@ghi _seq_=TTTT _qual_=11!!\nTTTT\n\+\n11!!";
	%targetFields = ("barcode" => undef, "channel" => undef);
	%expecs = (
		"abc" => {"_seq_" => "ATGC", "_qual_" => "!!!!", "barcode" => undef, "channel" => undef},
		"def" => {"_seq_" => "TACG", "_qual_" => "1!!!", "barcode" => undef, "channel" => undef},
		"ghi" => {"_seq_" => "TTTT", "_qual_" => "11!!", "barcode" => undef, "channel" => undef},
	);
	$resR = MetagDB::Fastq::process($fastq, \%targetFields);
	is ($resR, \%expecs, 'Testing FASTQ invalid metadata not requested');
	
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Main
#--------------------------------------------------------------------------------------------------#
#
print "INFO: Testing processing of FASTQ\n";
test_process;

done_testing();