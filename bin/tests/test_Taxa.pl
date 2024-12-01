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
use Cwd qw(realpath);
use Env qw(PATH);

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
# Test the parseMetaG function
#--------------------------------------------------------------------------------------------------#
#
sub test_parseKraken2 {
	my $err = "";
	my $class = MetagDB::Helpers::readFile("data/kraken2/classifications/valid_greengenes");
	my $taxP = "data/kraken2/tax/greengenes/taxonomy";
	my @ranks = ("domain", "phylum", "class", "subclass", "order", "suborder", 
		"family", "genus", "species", "strain");
	my $cwd = realpath("./");
	
	my %exp_valid_greengenes = (
		'read1' => {
			'domain'	=>	'Bacteria',
			'phylum'	=>	'NKB19',
			'class'		=>	'SHAB590',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read2' => {
			'domain'	=>	'UNMATCHED',
			'phylum'	=>	'UNMATCHED',
			'class'		=>	'UNMATCHED',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read3' => {
			'domain'	=>	'Bacteria',
			'phylum'	=>	'Proteobacteria',
			'class'		=>	'Gammaproteobacteria',
			'subclass'	=>	undef,
			'order'		=>	'Xanthomonadales',
			'suborder'	=>	undef,
			'family'	=>	'Sinobacteraceae',
			'genus'		=>	'Nevskia',
			'species'	=>	'Nevskia ramosa',
			'strain'	=>	'UNMATCHED'
		},
	);
	my %exp_valid_greengenes_lessRanks = (
		'read1' => {
			'domain'	=>	'Bacteria',
			'phylum'	=>	'NKB19',
			'class'		=>	'SHAB590',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED'
		},
		'read2' => {
			'domain'	=>	'UNMATCHED',
			'phylum'	=>	'UNMATCHED',
			'class'		=>	'UNMATCHED',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED'
		},
		'read3' => {
			'domain'	=>	'Bacteria',
			'phylum'	=>	'Proteobacteria',
			'class'		=>	'Gammaproteobacteria',
			'subclass'	=>	undef,
			'order'		=>	'Xanthomonadales',
			'suborder'	=>	undef
		},
	);
	my %exp_valid_rdp = (
		'read1' => {
			'domain'	=>	'Bacteria',
			'phylum'	=>	'"Proteobacteria"',
			'class'		=>	'Alphaproteobacteria',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read2' => {
			'domain'	=>	'UNMATCHED',
			'phylum'	=>	'UNMATCHED',
			'class'		=>	'UNMATCHED',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read3' => {
			'domain'	=>	'Bacteria',
			'phylum'	=>	'"Actinobacteria"',
			'class'		=>	'Actinobacteria',
			'subclass'	=>	'Acidimicrobidae',
			'order'		=>	'Acidimicrobiales',
			'suborder'	=>	'"Acidimicrobineae"',
			'family'	=>	'Acidimicrobiaceae',
			'genus'		=>	'Acidimicrobium',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read4' => {
			'domain'	=>	'Bacteria',
			'phylum'	=>	'candidate division WPS-2',
			'class'		=>	undef,
			'subclass'	=>	undef,
			'order'		=>	undef,
			'suborder'	=>	undef,
			'family'	=>	undef,
			'genus'		=>	'WPS-2_genera_incertae_sedis',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
	);
	my %exp_valid_silva = (
		'read1' => {
			'domain'	=>	'Bacteria',
			'phylum'	=>	'Chloroflexi',
			'class'		=>	'KD4-96',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read2' => {
			'domain'	=>	'UNMATCHED',
			'phylum'	=>	'UNMATCHED',
			'class'		=>	'UNMATCHED',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read3' => {
			'domain'	=>	'Eukaryota',
			'phylum'	=>	'Phragmoplastophyta',
			'class'		=>	'Embryophyta',
			'subclass'	=>	'Tracheophyta',
			'order'		=>	'Liliopsida',
			'suborder'	=>	'Zingiberales',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read4' => {
			'domain'	=>	'Eukaryota',
			'phylum'	=>	'Peronosporomycetes',
			'class'		=>	undef,
			'subclass'	=>	undef,
			'order'		=>	undef,
			'suborder'	=>	undef,
			'family'	=>	undef,
			'genus'		=>	'Phytophthora',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
	);
	my %exp_valid_standard = (
		'read1' => {
			'domain'	=>	'Bacteria',
			'phylum'	=>	'Pseudomonadota',
			'class'		=>	'Gammaproteobacteria',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read2' => {
			'domain'	=>	'UNMATCHED',
			'phylum'	=>	'UNMATCHED',
			'class'		=>	'UNMATCHED',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read3' => {
			'domain'	=>	'Eukaryota',
			'phylum'	=>	'Chordata',
			'class'		=>	'Actinopteri',
			'subclass'	=>	'Neopterygii',
			'order'		=>	'Percopsiformes',
			'suborder'	=>	'Percopsoidei',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read4' => {
			'domain'	=>	'Bacteria',
			'phylum'	=>	undef,
			'class'		=>	undef,
			'subclass'	=>	undef,
			'order'		=>	undef,
			'suborder'	=>	undef,
			'family'	=>	undef,
			'genus'		=>	undef,
			'species'	=>	'soil isolate KBS ensemble',
			'strain'	=>	'soil isolate KBS-EC1'
		}
	);
	
		
	#------------------------------------------------------------------------------#
	# Test no input classification + no taxonomy path + no ranks
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2();
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no classification');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no taxonomy path + no ranks
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no taxonomy path');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no ranks
	#------------------------------------------------------------------------------#
	my $resR = {};
	try {
		$err = "";
		$resR = MetagDB::Taxa::parseKraken2($class, $taxP);
		is($resR, \%exp_valid_greengenes, "Testing no ranks");
	}
	catch {
		$err = $_;
		ok(1==2, "Testing no ranks");
		print "ERROR: $err" . "\n";
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty classification
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2("", $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough arguments/, 'Testing empty classification');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classification containing only whitespaces
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2("    ", $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Empty classification file/, 'Testing classification containing only whitespaces');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test classification containing only empty lines
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2("\n\n", $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Empty classification file/, 'Testing classification containing only empty lines');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty taxonomy path
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, "", \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough arguments/, 'Testing empty taxonomy path');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test taxonomy path containing only whitespaces
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, "  ", \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*not a valid directory/, 'Testing taxonomy path containing only whitespaces');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test taxonomy path not a directory (absolute path)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, "$cwd/test_Helpers.pl", \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*not a valid directory/, 'Testing taxonomy path not a directory (absolute path)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test taxonomy path not a directory (relative path)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, "test_Helpers.pl", \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*not a valid directory/, 'Testing taxonomy path not a directory (relative path)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test non-existent taxonomy path (absolute path)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, "$cwd/abcdefghijklmnopqrstuvwxyz", \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*not a valid directory/, 'Testing non-existent taxonomy path (absolute path)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test non-existent taxonomy path (relative path)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, "abcdefghijklmnopqrstuvwxyz", \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*not a valid directory/, 'Testing non-existent taxonomy path (relative path)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test taxonomy path is a valid directory, but contains the wrong data
	# (absolute path)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, "$cwd", \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit could not get lineage/, 'Testing taxonomy path with invalid data (absolute path)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test taxonomy path is a valid directory, but contains the wrong data
	# (relative path)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, "./", \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit could not get lineage/, 'Testing taxonomy path with invalid data (relative path)');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty ranks
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough arguments/, 'Testing empty ranks');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test ranks not a reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, "abc");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Ranks empty or not a reference/, 'Testing ranks not a reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test ranks empty reference
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, []);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Ranks empty or not a reference/, 'Testing ranks empty reference');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test unsupported rank requested by user
	#------------------------------------------------------------------------------#
	my $tmpRanksR = dclone(\@ranks);
	push(@{$tmpRanksR}, 'foobar');
	
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, $tmpRanksR);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Could process ranks provided by user/, 'Testing unsupported rank requested');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty rank requested by user
	#------------------------------------------------------------------------------#
	$tmpRanksR = dclone(\@ranks);
	push(@{$tmpRanksR}, '');
	
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, $tmpRanksR);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Found empty rank name/, 'Testing empty rank requested');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test rank just containing whitespaces requested by user
	#------------------------------------------------------------------------------#
	$tmpRanksR = dclone(\@ranks);
	push(@{$tmpRanksR}, '  ');
	
	try {
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, $tmpRanksR);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Found empty rank name/, 'Testing rank just containing whitespaces requested');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test less than default number of ranks requested by user (more cannot be
	# tested, as default includes all ranks that are available)
	#------------------------------------------------------------------------------#
	my @tmpRanks = @ranks[0..5];
	$resR = {};
	
	try {
		$err = "";
		$resR = MetagDB::Taxa::parseKraken2($class, $taxP, \@tmpRanks);
		is($resR, \%exp_valid_greengenes_lessRanks, 'Testing less than default ranks requested');
	}
	catch {
		$err = $_;
		ok(1==2, 'Testing less than default ranks requested');
		print "ERROR: $err" . "\n";
	};
	
	
	#------------------------------------------------------------------------------#
	# Test TaxonKit not found
	#------------------------------------------------------------------------------#
	try {
		# Assuming TaxonKit is not in $cwd
		# Automatically reset outside of try
		local $PATH = "$cwd";
		
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Could not execute TaxonKit/, 'Testing TaxonKit not found');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test TaxonKit yields no valid version (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Automatically reset outside of try
		local $PATH = "$cwd/appl/taxonkit/version/format";
		
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Could not get TaxonKit version/, 'Testing TaxonKit yields no valid version');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test TaxonKit too old (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Automatically reset outside of try
		local $PATH = "$cwd/appl/taxonkit/version/tooOld";
		
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit must be updated./, 'Testing TaxonKit too old');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid Kraken2 classification with too many columns
	#------------------------------------------------------------------------------#
	my $tmpClass = "";
	try {
		$err = "";
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/invalid_class_colCount"); 
		
		MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid Kraken2 report format/, 'Testing Kraken2 classifications - too many columns');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid Kraken2 classification empty isClass
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/invalid_class_noIsClass"); 
		
		MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid Kraken2 report format/, 'Testing Kraken2 classifications - empty isClass');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid Kraken2 classification empty read ID
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/invalid_class_noReadId"); 
		
		MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid Kraken2 report format/, 'Testing Kraken2 classifications - empty read ID');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid Kraken2 classification empty taxonomy ID
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/invalid_class_noTaxId"); 
		
		MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid Kraken2 report format/, 'Testing Kraken2 classifications - empty taxonomy ID');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid Kraken2 classification with invalid taxonomy ID
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/invalid_class_invalidTaxId"); 
		
		MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid Kraken2 report format/, 'Testing Kraken2 classifications - invalid taxonomy ID');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid Kraken2 classification empty length and kmer info which are
	# not needed for the function.
	#------------------------------------------------------------------------------#
	$resR = {};
	try {
		$err = "";
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/valid_greengenes_noLengthKmers");
		 
		$resR = MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
		is($resR, \%exp_valid_greengenes, "Testing valid input with empty length and kmer info");
	}
	catch {
		$err = $_;
		ok(1==2, "Testing valid input with empty length and kmer info");
		print "ERROR: $err" . "\n";
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid Kraken2 classification wrong taxonomy ID for unclassified read
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/invalid_class_unclassWrongTaxId"); 
		
		MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid Kraken2 report format/, 'Testing Kraken2 classifications - wrong taxonomy ID for unclassified');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid Kraken2 classification duplicate unclassified read
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/invalid_class_dupUnclass"); 
		
		MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*marked as unclassified more than once/, 'Testing Kraken2 classifications - duplicate of unclassified');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid Kraken2 classification duplicate classified read
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/invalid_class_dupClass");
		MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*classified more than once/, 'Testing TaxonKit output - duplicate of classified');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid Kraken2 classification duplicate classified + unclassified read
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/invalid_class_dupClassUnclass"); 
		MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*classified more than once/, 'Testing TaxonKit output - duplicate of classified + unclassified');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid Kraken2 classification wrong taxonomy ID for classified read
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/invalid_class_classWrongTaxId"); 

		MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid Kraken2 report format/, 'Testing Kraken2 classifications - wrong taxonomy ID for classified');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid Kraken2 classification wrong isClass
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/invalid_class_wrongIsClass"); 
		
		MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*Invalid Kraken2 report format/, 'Testing Kraken2 classifications - wrong isClass');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test TaxonKit crash reformat2 (via a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. The fake TaxonKit script will then
		# remove itself from the PATH and call the real TaxonKit with a
		# wrong command. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/error:$PATH";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit could not get lineage for classifications/, 'Testing TaxonKit crash reformat2');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid Kraken2 only unclassified reads
	#------------------------------------------------------------------------------#
	my %exp_valid_unclass = (
		'read1' => {
			'domain'	=>	'UNMATCHED',
			'phylum'	=>	'UNMATCHED',
			'class'		=>	'UNMATCHED',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read2' => {
			'domain'	=>	'UNMATCHED',
			'phylum'	=>	'UNMATCHED',
			'class'		=>	'UNMATCHED',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read3' => {
			'domain'	=>	'UNMATCHED',
			'phylum'	=>	'UNMATCHED',
			'class'		=>	'UNMATCHED',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		},
		'read4' => {
			'domain'	=>	'UNMATCHED',
			'phylum'	=>	'UNMATCHED',
			'class'		=>	'UNMATCHED',
			'subclass'	=>	'UNMATCHED',
			'order'		=>	'UNMATCHED',
			'suborder'	=>	'UNMATCHED',
			'family'	=>	'UNMATCHED',
			'genus'		=>	'UNMATCHED',
			'species'	=>	'UNMATCHED',
			'strain'	=>	'UNMATCHED'
		}
	);
	$resR = {};	
	
	try {
		$err = "";

		$tmpClass = MetagDB::Helpers::readFile("data/kraken2/classifications/valid_class_onlyUnclass"); 
		$resR = MetagDB::Taxa::parseKraken2($tmpClass, $taxP, \@ranks);
		is ($resR, \%exp_valid_unclass, 'Testing valid input - only unclassified');
	}
	catch {
		$err = $_;
		ok (1==2, 'Testing valid input - only unclassified');
		print "ERROR: $err" . "\n";
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output which is empty (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/empty";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an empty classification file/, 'Testing TaxonKit output - empty file');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output containing only whitespaces
	# (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/whitespaces";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an empty classification file/, 'Testing TaxonKit output - only whitespaces');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output containing only newlines (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/newlines";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an empty classification file/, 'Testing TaxonKit output - only newlines');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output with unexpected number of columns
	# (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/colCount";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an unexpected file format/, 'Testing TaxonKit output - unexpected number of columns');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output with empty read ID (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/noReadId";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an unexpected file format/, 'Testing TaxonKit output - empty read ID');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output with empty lineage (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/noLineage";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an unexpected file format/, 'Testing TaxonKit output - empty lineage');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output with empty isClass (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/noIsClass";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an unexpected file format/, 'Testing TaxonKit output - empty isClass');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output with unexpected isClass (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/wrongIsClass";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an unexpected file format/, 'Testing TaxonKit output - unexpected isClass');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output with empty taxonomy ID (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/noTaxId";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an unexpected file format/, 'Testing TaxonKit output - empty taxonomy ID');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output with unexpected taxonomy ID
	# (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/unexpTaxId";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an unexpected file format/, 'Testing TaxonKit output - unexpected taxonomy ID');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output with invalid taxonomy ID
	# (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/invalidTaxId";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an unexpected file format/, 'Testing TaxonKit output - invalid taxonomy ID');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test TaxonKit output with empty length and kmer info which is not needed
	# (using a fake program)
	#------------------------------------------------------------------------------#
	$resR = {};
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/noLengthKmer";
		$err = "";
		 
		$resR = MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
		is($resR, \%exp_valid_greengenes, "Testing TaxonKit output with empty length and kmer info");
	}
	catch {
		$err = $_;
		ok(1==2, "Testing TaxonKit output with empty length and kmer info");
		print "ERROR: $err" . "\n";
	};
	
	
	#------------------------------------------------------------------------------#
	# Test invalid TaxonKit output with too few ranks (using a fake program)
	#------------------------------------------------------------------------------#
	try {
		# Intercept call to TaxonKit. PATH reset after try.
		local $PATH = "$cwd/appl/taxonkit/output/tooFewRanks";
		$err = "";
		MetagDB::Taxa::parseKraken2($class, $taxP, \@ranks);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^ERROR.*TaxonKit returned an unexpected file format/, 'Testing TaxonKit output - too few ranks');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test valid input for four major databases (GreenGenes, RDP, SILVA, and
	# "standard")
	#
	# Test up to four different scenarios:
	#	*) Read unclassified after class level
	#	*) Fully unclassified read
	#	*) Fully classified read (depending on max. taxonomic level supported by
	#		the individual database) with taxon name for suborder and -class for
	#		databases supporting these ranks.
	#	*) Many ranks with taxa that don't have a name (if possible)
	#------------------------------------------------------------------------------#
	my %tests = (
		"greengenes"	=>	[\%exp_valid_greengenes, "$cwd/data/kraken2/classifications/valid_greengenes", "$cwd/data/kraken2/tax/greengenes/taxonomy"],
		"rdp"			=>	[\%exp_valid_rdp, "$cwd/data/kraken2/classifications/valid_rdp", "$cwd/data/kraken2/tax/rdp/taxonomy"],
		"silva"			=>	[\%exp_valid_silva, "$cwd/data/kraken2/classifications/valid_silva", "$cwd/data/kraken2/tax/silva/taxonomy"],
		"standard"		=>	[\%exp_valid_standard, "$cwd/data/kraken2/classifications/valid_standard", "$cwd/data/kraken2/tax/standard"],
	);	
	
	foreach my $db (keys(%tests)) {
		my $expR = $tests{$db}->[0];
		$tmpClass = MetagDB::Helpers::readFile($tests{$db}->[1]);
		my $tmpTaxP = $tests{$db}->[2];
		$resR = {};
		
		try {
			$err = "";
			
			$resR = MetagDB::Taxa::parseKraken2($tmpClass, $tmpTaxP, \@ranks);
			is($resR, $expR, "Testing valid input for ->$db<- database");
		}
		catch {
			$err = $_;
			ok(1==2, "Testing valid input for ->$db<- database");
			print "ERROR: $err" . "\n";
		};
	}
}


#
#--------------------------------------------------------------------------------------------------#
# Main
#--------------------------------------------------------------------------------------------------#
#
# Parsing of MetaG classification file
print "INFO: Testing parseMetaG function\n";
test_parseMetaG;

# Parsing of Kraken2 classification file
print "INFO: Testing parseKraken2 function\n";
test_parseKraken2;

done_testing;