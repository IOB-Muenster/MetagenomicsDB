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
# Tests for MetagDB::Taxa module
#==================================================================================================#
# DESCRIPTION
# 
#	Test the functions in the MetagDB::Taxa module.
#
#
# USAGE
#
# 	./test_Fastq.pl
#
#					
# DEPENDENCIES
#
#	MetagDB::Helpers
#	MetagDB::Taxa
#	Storable
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
use MetagDB::Helpers;
use MetagDB::Taxa;


#
#--------------------------------------------------------------------------------------------------#
# Test the parseMetaG function
#--------------------------------------------------------------------------------------------------#
#
sub test_parseMetaG {
	my $err = "";
	my $class = ">read_a\ndomain: 1: 1 (1)\nphylum: 2: 1 (1)\nclass: 3: 1 (1)\nsubclass: 4: 1 (1)\n" .
		"order: 5: 1 (1)\nsuborder: 6: 1 (1)\nfamily: 7: 1 (1)\ngenus: 8: 1 (1)\nspecies: 9: 1 (1)\n" .
		"strain: 10: 1 (1)\nNo match for read_b and chosen cutoff.";
	my @ranks = ("domain", "phylum", "class", "subclass", "order", "suborder", 
		"family", "genus", "species", "strain");
	
		
	#------------------------------------------------------------------------------#
	# Test no input classification + no ranks
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG();
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no classification');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no ranks
	#------------------------------------------------------------------------------#
	my %expecs = (
		'read_a' => {
			'domain'	=> 1,
			'phylum'	=> 2,
			'class'		=> 3,
			'subclass'	=> 4,
			'order'		=> 5,
			'suborder'	=> 6,
			'family'	=> 7,
			'genus'		=> 8,
			'species'	=> 9,
			'strain'	=> 10
		},
		'read_b' => {
			'domain'	=> 'UNMATCHED',
			'phylum'	=> 'UNMATCHED',
			'class'		=> 'UNMATCHED',
			'subclass'	=> 'UNMATCHED',
			'order'		=> 'UNMATCHED',
			'suborder'	=> 'UNMATCHED',
			'family'	=> 'UNMATCHED',
			'genus'		=> 'UNMATCHED',
			'species'	=> 'UNMATCHED',
			'strain'	=> 'UNMATCHED'
		}
	);
	my $resR = MetagDB::Taxa::parseMetaG($class);
	is ($resR, \%expecs, 'Testing no ranks');
	
	
	#------------------------------------------------------------------------------#
	# Test empty input classification
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG("", \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough/, 'Testing empty classification');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classification containing only whitespaces
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG("    ", \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Empty taxonomy file/, 'Testing classification containing only whitespaces');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classification containing only empty lines
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG("\n\n", \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Empty taxonomy file/, 'Testing classification containing only empty lines');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty ranks
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG($class, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough/, 'Testing empty ranks');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test ranks not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG($class, "abc");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Ranks empty or not a reference/, 'Testing ranks not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test ranks empty array reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG($class, []);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Ranks empty or not a reference/, 'Testing ranks empty array reference');
	};
	
	
		
	#------------------------------------------------------------------------------#
	# Test invalid format: No read ID for very first classification
	#------------------------------------------------------------------------------#
	my $classMod = "domain: 1: 1 (1)\nphylum: 2: 1 (1)\nclass: 3: 1 (1)\nsubclass: 4: 1 (1)\n" .
		"order: 5: 1 (1)\nsuborder: 6: 1 (1)\nfamily: 7: 1 (1)\ngenus: 8: 1 (1)\nspecies: 9: 1 (1)\n" .
		"strain: 10: 1 (1)\nNo match for read_b and chosen cutoff.";
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG($classMod, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No read ID for classification/, 'Testing invalid format: No read ID for classification (very first entry)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid format: No read ID for unclassified read (very first entry)
	#------------------------------------------------------------------------------#
	$classMod = "No match for\n>read_a\ndomain: 1: 1 (1)\nphylum: 2: 1 (1)\nclass: 3: 1 (1)\n" .
		"subclass: 4: 1 (1)\norder: 5: 1 (1)\nsuborder: 6: 1 (1)\nfamily: 7: 1 (1)\ngenus: 8: 1 (1)\n" .
		"species: 9: 1 (1)\nstrain: 10: 1 (1)\n";
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG($classMod, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*No read ID for unclassified read/, 'Testing invalid format: No read ID for unclassified read (very first entry)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid format: No matches for => Implicit MetaG error
	#------------------------------------------------------------------------------#
	$classMod = "No matches for read_b and chosen cutoff.";
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG($classMod, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Statement.*should not appear/, 'Testing invalid format: Implicit MetaG error');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test duplicate read (2 x unclassified)
	#------------------------------------------------------------------------------#
	$classMod = "No match for read_b and chosen cutoff.\nNo match for read_b and chosen cutoff.";
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG($classMod, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Read.*has been classified twice/, 'Testing duplicate reads (2x unclassified)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test duplicate read (2 x classified)
	#------------------------------------------------------------------------------#
	$classMod = ">read_a\ndomain: 1: 1 (1)\nphylum: 2: 1 (1)\nclass: 3: 1 (1)\nsubclass: 4: 1 (1)\n" .
		"order: 5: 1 (1)\nsuborder: 6: 1 (1)\nfamily: 7: 1 (1)\ngenus: 8: 1 (1)\nspecies: 9: 1 (1)\n" .
		"strain: 10: 1 (1)\n>read_a\ndomain: 1: 1 (1)";
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG($classMod, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Read.*has been classified twice/, 'Testing duplicate reads (2x classified)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test duplicate read (classified + unclassified)
	#------------------------------------------------------------------------------#
	$classMod = ">read_a\ndomain: 1: 1 (1)\nphylum: 2: 1 (1)\nclass: 3: 1 (1)\nsubclass: 4: 1 (1)\n" .
		"order: 5: 1 (1)\nsuborder: 6: 1 (1)\nfamily: 7: 1 (1)\ngenus: 8: 1 (1)\nspecies: 9: 1 (1)\n" .
		"strain: 10: 1 (1)\nNo match for read_a and chosen cutoff.";
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG($classMod, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Read.*has been classified twice/, 'Testing duplicate reads (classified + unclassified)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test duplicate read (unclassified + classified)
	#------------------------------------------------------------------------------#
	$classMod = "No match for read_a and chosen cutoff.\n" .
		">read_a\ndomain: 1: 1 (1)\nphylum: 2: 1 (1)\nclass: 3: 1 (1)\n" .
		"subclass: 4: 1 (1)\norder: 5: 1 (1)\nsuborder: 6: 1 (1)\nfamily: 7: 1 (1)\n" .
		"genus: 8: 1 (1)\nspecies: 9: 1 (1)\nstrain: 10: 1 (1)";
	try {
		$err = "";
		MetagDB::Taxa::parseMetaG($classMod, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Read.*has been classified twice/, 'Testing duplicate reads (unclassified + classified)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Loop over all possible classification combinations of one and two reads
	# as some of the processing in the function can be affected by the order of
	# reads.
	#
	#	*) unclassified
	#	*) classified
	#	*) partially unclassified
	#
	#	*) unclassified + classified
	#	*) classified + unclassified
	#	*) unclassified + unclassified
	#	*) unclassified + partially unclassified
	#	*) partially unclassified + unclassified
	#
	#	*) classified + classified
	#	*) classified + partially unclassified
	#	*) partially unclassified + classified
	#
	#	*) partially unclassified + partially unclassified
	#-----------------------------------------------------------------------------
	print "INFO: Testing several combinations of classification results\n";
	
	my $class1 = ">class_1\ndomain: 1: 1 (1)\nphylum: 2: 1 (1)\nclass: 3: 1 (1)\nsubclass: 4: 1 (1)\n" .
		"order: 5: 1 (1)\nsuborder: 6: 1 (1)\nfamily: 7: 1 (1)\ngenus: 8: 1 (1)\nspecies: 9: 1 (1)\n" .
		"strain: 10: 1 (1)";
	my %exp_class1 = (
		'class_1' => {
			'domain'	=> 1,
			'phylum'	=> 2,
			'class'		=> 3,
			'subclass'	=> 4,
			'order'		=> 5,
			'suborder'	=> 6,
			'family'	=> 7,
			'genus'		=> 8,
			'species'	=> 9,
			'strain'	=> 10
		},
	);
	my $class2 = ">class_2\ndomain: 11: 1 (1)\nphylum: 22: 1 (1)\nclass: 33: 1 (1)\nsubclass: 44: 1 (1)\n" .
		"order: 55: 1 (1)\nsuborder: 66: 1 (1)\nfamily: 77: 1 (1)\ngenus: 88: 1 (1)\nspecies: 99: 1 (1)\n" .
		"strain: 1010: 1 (1)";
	my %exp_class2 = (
		'class_2' => {
			'domain'	=> 11,
			'phylum'	=> 22,
			'class'		=> 33,
			'subclass'	=> 44,
			'order'		=> 55,
			'suborder'	=> 66,
			'family'	=> 77,
			'genus'		=> 88,
			'species'	=> 99,
			'strain'	=> 1010
		},
	);
	
	my $unclass1 = "No match for unclass_1 and chosen cutoff.";
	my %exp_unclass1 = (
		'unclass_1' => {
			'domain'	=> 'UNMATCHED',
			'phylum'	=> 'UNMATCHED',
			'class'		=> 'UNMATCHED',
			'subclass'	=> 'UNMATCHED',
			'order'		=> 'UNMATCHED',
			'suborder'	=> 'UNMATCHED',
			'family'	=> 'UNMATCHED',
			'genus'		=> 'UNMATCHED',
			'species'	=> 'UNMATCHED',
			'strain'	=> 'UNMATCHED'
		}
	);
	my $unclass2 = "No match for unclass_2 and chosen cutoff.";
	my %exp_unclass2 = (
		'unclass_2' => {
			'domain'	=> 'UNMATCHED',
			'phylum'	=> 'UNMATCHED',
			'class'		=> 'UNMATCHED',
			'subclass'	=> 'UNMATCHED',
			'order'		=> 'UNMATCHED',
			'suborder'	=> 'UNMATCHED',
			'family'	=> 'UNMATCHED',
			'genus'		=> 'UNMATCHED',
			'species'	=> 'UNMATCHED',
			'strain'	=> 'UNMATCHED'
		}
	);
	
	my $partUnclass1 = ">partUnclass_1\ndomain: 1: 1 (1)\nphylum: 2: 1 (1)\nclass: 3: 1 (1)\nsubclass: 4: 1 (1)\n" .
		"order: 5: 1 (1)\nsuborder: 6: 1 (1)\nfamily: 7: 1 (1)\ngenus: 8: 1 (1)";
	my %exp_partUnclass1 = (
		'partUnclass_1' => {
			'domain'	=> 1,
			'phylum'	=> 2,
			'class'		=> 3,
			'subclass'	=> 4,
			'order'		=> 5,
			'suborder'	=> 6,
			'family'	=> 7,
			'genus'		=> 8,
			'species'	=> 'UNMATCHED',
			'strain'	=> 'UNMATCHED'
		},
	);
	my $partUnclass2 = ">partUnclass_2\ndomain: 11: 1 (1)\nphylum: 22: 1 (1)";
	my %exp_partUnclass2 = (
		'partUnclass_2' => {
			'domain'	=> 11,
			'phylum'	=> 22,
			'class'		=> 'UNMATCHED',
			'subclass'	=> 'UNMATCHED',
			'order'		=> 'UNMATCHED',
			'suborder'	=> 'UNMATCHED',
			'family'	=> 'UNMATCHED',
			'genus'		=> 'UNMATCHED',
			'species'	=> 'UNMATCHED',
			'strain'	=> 'UNMATCHED'
		},
	);
	
	# Input classification => expected output
	my %combos = (
		"unclassified"										=>	[$unclass1, \%exp_unclass1],
		"classified"										=>	[$class1, \%exp_class1],
		"partially classified"								=>	[$partUnclass1, \%exp_partUnclass1],
		"unclassified + classified"							=>	["$unclass1\n$class1", {%exp_unclass1, %exp_class1}],
		"classified + unclassified"							=>	["$class1\n$unclass1", {%exp_class1, %exp_unclass1}],
		"unclassified + unclassified"						=>	["$unclass1\n$unclass2", {%exp_unclass1, %exp_unclass2}],
		"unclassified + partially unclassified"				=>	["$unclass1\n$partUnclass1", {%exp_unclass1, %exp_partUnclass1}],
		"partially unclassified + unclassified"				=>	["$partUnclass1\n$unclass1", {%exp_partUnclass1, %exp_unclass1}],
		"classified + classified"							=>	["$class1\n$class2", {%exp_class1, %exp_class2}],
		"classified + partially unclassified"				=>	["$class1\n$partUnclass1", {%exp_class1, %exp_partUnclass1}],
		"partially unclassified + classified"				=>	["$partUnclass1\n$class1", {%exp_partUnclass1, %exp_class1}],
		"partially unclassified + partially unclassified"	=>	["$partUnclass1\n$partUnclass2", {%exp_partUnclass1, %exp_partUnclass2}],
	);
	
	foreach my $combo (keys(%combos)) {
		$class = $combos{$combo}->[0];
		%expecs = %{$combos{$combo}->[1]};		
		print "INFO: Testing classification(s) ->$combo<- in classification file\n";

	
		#------------------------------------------------------------------------------#
		# Test too few ranks
		#------------------------------------------------------------------------------#
		# Unclassified reads will use whatever ranks they can find.
		# Partially unclassified are classified deep enough, so that the
		# error is triggered in this specific case.
		if ($combo ne "unclassified + unclassified" and $combo ne "unclassified") {
			try {
				$err = "";
				MetagDB::Taxa::parseMetaG($class, ["domain"]);
			}
			catch {
				$err = $_;
			}
			finally {
				ok ($err =~ m/^ERROR.*Too few ranks/, 'Testing too few ranks');
			};
		}
		
		
		#------------------------------------------------------------------------------#
		# Test too many ranks => No error, filled up with "UNMATCHED"
		#------------------------------------------------------------------------------#
		my $expecsModR = dclone(\%expecs);
		foreach my $key (keys(%{$expecsModR})) {
			$expecsModR->{$key}->{'fictional_rank'} = 'UNMATCHED';
		}
		$resR = MetagDB::Taxa::parseMetaG($class, [@ranks, 'fictional_rank']);
		is ($resR, $expecsModR, 'Testing too many ranks');
		
		
		#------------------------------------------------------------------------------#
		# Test wrong ranks
		#------------------------------------------------------------------------------#
		# Unclassified reads will use whatever ranks they can find.
		# Partially unclassified are classified deep enough, so that the
		# error is triggered in this specific case.
		if ($combo ne "unclassified + unclassified" and $combo ne "unclassified") {
			try {
				$err = "";
				MetagDB::Taxa::parseMetaG($class, ["fictional_rank"]);
			}
			catch {
				$err = $_;
			}
			finally {
				ok ($err =~ m/^ERROR.*Rank.*in classification file does not match provided rank/, 'Testing wrong ranks');
			};
		}
		
		
		#------------------------------------------------------------------------------#
		# Test duplicate ranks: Additional ranks that don't appear in classification
		# file
		#------------------------------------------------------------------------------#
		try {
			$err = "";
			MetagDB::Taxa::parseMetaG($class, [@ranks, "fictional_rank", "fictional_rank"]);
		}
		catch {
			$err = $_;
		}
		finally {
			ok ($err =~ m/^ERROR.*provided more than once in given rank list/, 'Testing duplicates in additonal ranks');
		};
			
		
		#------------------------------------------------------------------------------#
		# Test taxon name "unclassified" translated to undef
		#------------------------------------------------------------------------------#
		# Introduce unclassified taxa into *_1 reads (domain and strain)
		$classMod = $class =~ s/ 1\:/ unclassified\:/gr;
		$classMod =~ s/ 10\:/ unclassified\:/g;
		
		$expecsModR = dclone(\%expecs);
		
		# The classifications 1 and 10 that were changed belong to domain and species,
		# respectively
		foreach my $key (keys(%{$expecsModR})) {
			if (exists $expecsModR->{$key}->{'domain'}) {
				if ($expecsModR->{$key}->{'domain'} eq "1") {
					$expecsModR->{$key}->{'domain'} = undef;
				}
			}
			if (exists $expecsModR->{$key}->{'strain'}) {
				if ($expecsModR->{$key}->{'strain'} eq "10") {
					$expecsModR->{$key}->{'strain'} = undef;
				}
			}
		}
		$resR = MetagDB::Taxa::parseMetaG($classMod);
		is ($resR, $expecsModR, 'Testing translation of taxon name "unclassified"');
		
		
		#------------------------------------------------------------------------------#
		# Test duplicate ranks in classification file
		#------------------------------------------------------------------------------#
		my $ranksModR = dclone(\@ranks);
		# A completely unclassified read in any combination will trigger a different
		# error, which should not be tested here
		if ($combo !~ m/^unclassified/ and $combo !~ m/\+ unclassified$/) {
			$classMod = $class =~ s/phylum\:/domain\:/gr;
			try {
				$err = "";
				
				# To avoid error with given rank not matching observed rank in file
				$ranksModR->[1] = "domain";
				
				MetagDB::Taxa::parseMetaG($classMod, $ranksModR);
			}
			catch {
				$err = $_;
			}
			finally {
				ok ($err =~ m/^ERROR.*Read.*has been classified twice at rank/, 'Testing duplicate ranks in classification');
			};
		}
		
		
		#------------------------------------------------------------------------------#
		# Test invalid format: ">read ID", but no classification
		#------------------------------------------------------------------------------#
		# Only makes sense, if at least one read is at least partially classified
		if ($combo ne "unclassified + unclassified" and $combo ne "unclassified") {
			try {
				$err = "";
				
				# Delete all rank->taxon assignments
				$classMod = $class =~ s/\n[a-z]+\:.*?\)+//gr;
				
				MetagDB::Taxa::parseMetaG($classMod, \@ranks);
			}
			catch {
				$err = $_;
			}
			finally {
				ok ($err =~ m/^ERROR.*No classification for/, 'Testing invalid format: No classification');
			};
		}
	}
	
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Main
#--------------------------------------------------------------------------------------------------#
#
# Parsing of MetaG classification file
print "INFO: Testing parseMetaG function\n";
test_parseMetaG;

done_testing;