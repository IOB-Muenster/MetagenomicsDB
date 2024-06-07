package MetagDB::Taxa;


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

use lib "../";
use MetagDB::Helpers;

#
#--------------------------------------------------------------------------------------------------#
# Parse the calc.LIN.txt file from MetaG and extract the classification per read.
#
# Classifications for each read by MetaG are in this format: A line provides the read ID
# preceeded by a ">". The following lines provide the taxonomic classification for all ranks.
# Ideally, as many as the user expects (usually 10).
#
#	> read0
#	domain: abc: 1(1)
#	phylum: def: 1(1)
#	...
#
# If there are less ranks than expected, this means that MetaG could not classify the read
# to that taxonomic rank and beyond. In this case, the remaining expected ranks will be
# filled up with the special taxon "UNMATCHED".
#
#	>read1
#	domain: abc: 1(1)
#
# This is also the case, if a read was filtered/not classified at all. In that case, only a single
# line belongs to that read and looks like this:
#
#	No matches for read2*.
#
# When no taxon name was provided at a specific rank ("unclassified" in MetaG notation), it will be
# set to undef --> NULL in database
#
#	>read3
#	domain: abc: 1(1)
#	phylum: unclassified: 1(1)
#	....
#
# Basic checks are performed to verify that the expected ranks provided by the user match the
# ranks observed in the calc.LIN.txt file: Error, if too few ranks provided. Error, if
# wrong names. No error, if too many ranks provided --> will be filled up with UNMATCHED.
#--------------------------------------------------------------------------------------------------#
#
sub parseMetaG ($class, $ranksR = ["domain", "phylum", "class", "subclass", "order", "suborder", "family", "genus", "species", "strain"]) {	
	foreach my $param ($class, $ranksR) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	if (not ref($ranksR) or not @{$ranksR}) {
		die "ERROR: Ranks empty or not a reference";
	}
	my @ranks = @{$ranksR};	
	
	my %res = ();
	my @lines = @{MetagDB::Helpers::splitStr($class)};
	die "ERROR: Empty taxonomy file" if (not @lines);

	my $readId = undef;
	my $i = 0;
	
	while(@lines) {
		my $line = $lines[0];
		# Get the read ID for classified reads
		if ($line =~ m/^>/) {
			# Previous read (if applicable):
			# Missing ranks in classification (relative to provided ranks) mean that the
			# read could not be classified at that rank. Assign special taxon "UNMATCHED"
			# to all missing ranks
			if ($i >= 0 and $i <= $#ranks and defined $readId) {
				for (my $j = $i; $j <= $#ranks; $j++) {
					my $rank = $ranks[$j];
					if (exists $res{$readId}) {
						if (exists $res{$readId}->{$rank}) {
							die "ERROR: ->$rank<- provided more than once in given rank list. Read ID ->$readId<-"
						}
						else {
							$res{$readId}->{$rank} = "UNMATCHED";
						}
					}
					else {
						die "ERROR: No classification for ->$readId<-"
					}
				}
			}
			$readId = $line =~ s/^>//r;
			die "ERROR: Read ->$readId<- has been classified twice" if (exists $res{$readId});
			$i = 0;
		}
		# Unclassified reads
		elsif ($line =~ m/^No match for/) {
			# Previous read (if applicable):
			# Missing ranks in classification  (relative to provided ranks) mean that the
			# read could not be classified at that rank. Assign special taxon "UNMATCHED"
			# to all missing ranks
			if ($i >= 0 and $i <= $#ranks and defined $readId) {
				for (my $j = $i; $j <= $#ranks; $j++) {
					my $rank = $ranks[$j];
					if (exists $res{$readId}) {
						if (exists $res{$readId}->{$rank}) {
							die "ERROR: ->$rank<- provided more than once in given rank list. Read ID ->$readId<-"
						}
						else {
							$res{$readId}->{$rank} = "UNMATCHED";
						}
					}
					else {
						die "ERROR: No classification for ->$readId<-"
					}
				}
			}
			
			if ($line =~ m/^No match for ([a-zA-Z0-9\-_]+)/) {
				$readId = $1;
			}
			
			# Can only catch problems with the very first classification
			# For all following, the previous readId would be seen.
			die "ERROR: No read ID for unclassified read" if (not defined $readId or not $readId);
			
			die "ERROR: Read ->$readId<- has been classified twice" if (exists $res{$readId});
			
			# Unclassified read --> all ranks have special taxon "UNMATCHED"
			foreach my $rank (@ranks) {
				if (exists $res{$readId}->{$rank}) {
					die "ERROR: ->$rank<- provided more than once in given rank list. Read ID ->$readId<-"
				}
				else {
					$res{$readId}->{$rank} = "UNMATCHED"
				}
			}
			# Switch to skip addition of "missing ranks" in loops
			$i = $#ranks + 1;
		}
		# In theory, MetaG could output this, but this is not normal
		elsif ($line =~ m/^No matches for ([a-zA-Z0-9\-_]+)/) {
			die "ERROR: Statement ->$line<- should not appear in classification file"
		}
		# Parse classification of read
		else {
			# Can only catch problems with the very first classification
			# For all following, the previous readId would be seen.
			die "ERROR: No read ID for classification" if (not defined $readId or not $readId);
			
			my $rank = $ranks[$i] // "";
			die "ERROR: Too few ranks provided. Read ->$readId<-" if (not $rank);
			
			my ($r, $taxon, $rest) = split(': ', $line);
			# The user provided a wrong list of ranks for the classification file
			die "ERROR: Rank ->$r<- in classification file does not match provided rank ->$rank<-. Read ->$readId<-" if ($r ne $rank);
			
			# Encode missing names for taxa as undef --> NULL in database
			$taxon = undef if ($taxon eq "unclassified");
			
			if (exists $res{$readId}) {
				if (exists $res{$readId}->{$rank}) {
					die "ERROR: Read ->$readId<- has been classified twice at rank ->$rank<-"
				}
				else {
					$res{$readId}->{$rank} = $taxon;
				}
			}
			else {
				$res{$readId} = {$rank => $taxon}
			}
			$i++;
		}
		
		
		splice(@lines, 0, 1);
	}
	
	
	# Last classification in file:
	# Missing ranks in classification mean that the read was unclassified
	# Assign all missing ranks with the special taxon "UNMATCHED"
	if ($i >= 0 and $i <= $#ranks and defined $readId) {
		for (my $j = $i; $j <= $#ranks; $j++) {
			my $rank = $ranks[$j];
			if (exists $res{$readId}) {
				if (exists $res{$readId}->{$rank}) {
					die "ERROR: ->$rank<- provided more than once in given rank list. Read ID ->$readId<-"
				}
				else {
					$res{$readId}->{$rank} = "UNMATCHED";
				}
			}
			else {
				die "ERROR: No classification for ->$readId<-"
			}
		}
	}
	
	
	return \%res;
}


1;