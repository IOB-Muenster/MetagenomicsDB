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
# Tests for MetagDB::Utils module
#==================================================================================================#
# DESCRIPTION
# 
#	Test the functions in the MetagDB::Utils module.
#
#
# USAGE
#
# 	./test_Utils.pl
#
#					
# DEPENDENCIES
# 
#	Test2::Bundle::More
#	Test2::Tools::Compare;
#	Try::Tiny
#	MetagDB::Utils
#==================================================================================================#


use strict;
use warnings;

use feature 'signatures';
no warnings qw(experimental::signatures);

use Test2::Bundle::More qw(ok done_testing);
use Test2::Tools::Compare;
use Try::Tiny;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl/";
use MetagDB::Utils;


#
#--------------------------------------------------------------------------------------------------#
# Test the toSQL function
#--------------------------------------------------------------------------------------------------#
#
sub test_toSQL {
	my $err = "";
	my $res = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no value (+ no type)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$res = "";
		
		$res = MetagDB::Utils::toSQL();
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing no value');
	}
	finally {
		ok ($res eq "null", 'Testing no value');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no type
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$res = "";
		
		$res = MetagDB::Utils::toSQL("foobar");
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing no type');
	}
	finally {
		ok ($res eq "null", 'Testing no type');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty value
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$res = "";
		
		$res = MetagDB::Utils::toSQL("", "ip");
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing empty value');
	}
	finally {
		ok ($res == 0, 'Testing empty value');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid ip
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$res = "";
		
		$res = MetagDB::Utils::toSQL("abc", "ip");
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing invalid ip');
	}
	finally {
		ok ($res == 0, 'Testing invalid ip');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid ip
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$res = "";
		
		$res = MetagDB::Utils::toSQL("127.0.0.1", "ip");
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing valid ip');
	}
	finally {
		ok ($res == 16777343, 'Testing valid ip');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty type
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$res = "";
		
		$res = MetagDB::Utils::toSQL("127.0.0.1", "");
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing empty type');
	}
	finally {
		ok ($res == 0, 'Testing empty type');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid type
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$res = "";
		
		$res = MetagDB::Utils::toSQL("127.0.0.1", "foobar");
	}
	catch {
		$err = $_;
		print $err;
		ok (1==2, 'Testing invalid type');
	}
	finally {
		ok ($res == 0, 'Testing invalid type');
	};
}


#
#--------------------------------------------------------------------------------------------------#
# Main
#--------------------------------------------------------------------------------------------------#
#
print "INFO: Testing toSQL function\n";
test_toSQL();

done_testing();