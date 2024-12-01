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

use Cwd qw(realpath);
use File::Temp qw(tempfile);
use Fcntl qw(F_SETFD);
use Git::Version::Compare qw(lt_git);
use IO::Handle qw(flush);

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


#
#--------------------------------------------------------------------------------------------------#
# Parse the standard Kraken2 output format and extract the classification per read.
#
# The format of the Kraken2 output is described here: https://github.com/DerrickWood/kraken2/wiki/
# Manual#output-formats; accessed 2024/11/05. The only columns that are actively processed are
# zero (classified or not) and two (taxonomy ID). In order to translate the taxonomy IDs to
# lineages containing the ranks provided by the user, TaxonKit version >= v0.19.0 is required
# (https://bioinf.shenwei.me/taxonkit/) and must be located in the PATH. In the process, a
# temporary file is created and automatically deleted by File::Temp.
# Kraken2 uses NCBI's taxonomy IDs for its standard database (https://github.com/DerrickWood/
# kraken2/wiki/Manual#standard-kraken-2-database; accessed 2024/11/05) and fake IDs for GreenGenes,
# RDP, and SILVA (https://github.com/DerrickWood/kraken2/wiki/Manual#special-databases; accessed
# 2024/11/05). Thus, the function also needs the path to the respective Kraken2 database folder
# containing the "names.dmp" and "nodes.dmp" files (taxP).
#--------------------------------------------------------------------------------------------------#
#
sub parseKraken2 ($class, $taxP, $ranksR = ["domain", "phylum", "class", "subclass", "order", "suborder", "family", "genus", "species", "strain"]) {
	#----------------------------------------------------------------------------------------------#
	# Hardcoded variables
	#----------------------------------------------------------------------------------------------#
	my $minTkVersion = "v0.19.0";
	# Translate user-provided ranks to TaxonKit ranks
	my %user2tkRanks = (
		"domain"	=>	'{superkingdom}',
		"phylum"	=>	'{phylum}',
		"class"		=>	'{class}',
		"subclass"	=>	'{subclass}',
		"order"		=>	'{order}',
		"suborder"	=>	'{suborder}',
		"family"	=>	'{family}',
		"genus"		=>	'{genus}',
		"species"	=>	'{species}',
		"strain"	=>	'{subspecies|strain}',
	);
	my $taxidIdx = 3;

	
	#----------------------------------------------------------------------------------------------#
	# Check inputs
	#----------------------------------------------------------------------------------------------#
	foreach my $param ($class, $taxP, $ranksR) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	if ($taxP !~ m/^\//) {
		$taxP = realpath($taxP) or die "ERROR: Could not get realpath for ->$taxP<-";
	}
	if (! -d $taxP) {
		die "ERROR: ->$taxP<- not a valid directory."
	}
	if (not ref($ranksR) or not @{$ranksR}) {
		die "ERROR: Ranks empty or not a reference";
	}
	
	# Check availability and version of TaxonKit dependency
	my $tkVersion = qx/taxonkit version 2>&1/ // "";
	my $rc = $? >> 8;
	
	if ($rc != 0) {
		die "ERROR: Could not execute TaxonKit ->$tkVersion<-"
	}
	my $tmp = "";
	$tmp = $1 if ($tkVersion =~ m/(v[\d\.]+)$/);
	$tkVersion = $tmp;
	die "ERROR: Could not get TaxonKit version" if (not $tkVersion);
	if (lt_git($tkVersion, $minTkVersion)) {
		die "ERROR: TaxonKit must be updated. Found version ->$tkVersion<-, but must >= ->$minTkVersion<-."
	}
	
	# Translate ranks provided by the user to TaxonKit notation.
	# Edit this part, if you want to allow any ranks provided
	# by the user.
	my $tkRankStr = "";
	my @ranks = @{$ranksR};
	foreach my $rank (@ranks) {
		die "ERROR: Found empty rank name" if (not $rank or $rank =~ m/^\s+$/);
		if (exists $user2tkRanks{$rank}){
			$tkRankStr .= ";" . $user2tkRanks{$rank};
		}
		else {
			die "ERROR: Could process ranks provided by user. Ranks must be in ->[" . 
				join(", ", keys(%user2tkRanks)). "]<-, found ->$rank<-."
		}
	}
	$tkRankStr .= "\"";
	$tkRankStr =~ s/^;/\"/;

	
	#----------------------------------------------------------------------------------------------#
	# Get unclassified reads and check Kraken2 report format
	#----------------------------------------------------------------------------------------------#
	my $classified = "";
	my %res = ();
	my @lines = @{MetagDB::Helpers::splitStr($class)};
	die "ERROR: Empty classification file" if (not @lines);
	
	foreach my $line (@lines) {
		# Keep length and kmer info fields, even if they are empty		
		my @splits = split("\t", $line, -1);
		die "ERROR: Invalid Kraken2 report format ->" . join("\t", @splits) . "<-"
			if (@splits != 5);
		my ($isClass, $readId, $taxId, $len, $kmer) = @splits;
		# TaxID 0 is possible
		die "ERROR: Invalid Kraken2 report format ->" . join("\t", @splits) . "<-"
			if (not $isClass or not $readId or $taxId eq "" or $taxId !~ m/^\d+$/);
		if ($isClass eq "U") {
			die "ERROR: Invalid Kraken2 report format ->" . join("\t", @splits) . "<-"
				if ($taxId != 0);
			die "ERROR: Read ->$readId<- marked as unclassified more than once."
				if (exists $res{$readId});
			$res{$readId} = {};
			# Unclassified = UNMATCHED in parseMetaG
			foreach my $rank (@ranks) {
				$res{$readId}->{$rank} = "UNMATCHED"
			}
		}
		elsif ($isClass eq "C") {
			die "ERROR: Invalid Kraken2 report format ->" . join("\t", @splits) . "<-"
				if ($taxId == 0);
			$classified .= $line . "\n";
		}
		else {
			die "ERROR: Invalid Kraken2 report format ->" . join("\t", @splits) . "<-";
		}
	}
	# No reads classified by Kraken2
	return \%res if ($classified =~ m/^\s*$/);
	
	
	#----------------------------------------------------------------------------------------------#
	# Assign classified reads to lineage
	#----------------------------------------------------------------------------------------------#
	# Write classified reads to temporary file. Remove file automatically.
	# Includes some File::Temp magic to allow TaxonKit to work with the filehandle
	# which is considered best practice.
	my $tmpFh = tempfile(SUFFIX => '_parseKraken2', UNLINK => 1) or die "ERROR: Cannot open temporary file";
	print $tmpFh $classified;
	$tmpFh->flush;
	fcntl($tmpFh, F_SETFD, 0) or die "ERROR: Cannot set flag";
	
	# TaxonKit will use the taxonomy information in --data-dir to translate the taxonomy IDs
	# found in the -I'th column of the temporary classification file to full lineages.
	# The ranks of the full lineage are defined by -f. Taxa with no name are called "0" (-r)
	# and unclassified ranks are left empty (-T).
	my $cmd = "taxonkit reformat2 --data-dir $taxP -I $taxidIdx -r \"0\" -T -f $tkRankStr /dev/fd/". fileno($tmpFh);
	my $classification = qx/$cmd 2>\/dev\/null/;
	$rc = $? >> 8;
	
	# Removes temporary file
	close($tmpFh);
	
	# Return code from TaxonKit
	if ($rc != 0) {
		die "ERROR: TaxonKit could not get lineage for classifications."
	}
	
	my @classifications = @{MetagDB::Helpers::splitStr($classification)};
	die "ERROR: TaxonKit returned an empty classification file" if (not @classifications);
	foreach my $class (@classifications) {
		my @splits = split("\t", $class);
		die "ERROR: TaxonKit returned an unexpected file format ->" . join("\t", @splits) . "<-"
			if (@splits != 6);
		my ($isClass, $readId, $taxId, $len, $kmer, $lineage) = @splits;
		# Unclassified reads were filtered before, so taxonomy ID may also not be "0"
		die "ERROR: TaxonKit returned an unexpected file format ->" . join("\t", @splits) . "<-"
			if (not $readId or $isClass ne "C" or not $taxId or $taxId !~ m/^\d+$/ or not $lineage);	
		# Force split to keep empty entries --> unclassified ranks
		my @lineages = split(";", $lineage, -1);
		die "ERROR: TaxonKit returned an unexpected file format ->" . join("\t", @splits) . "<-"
			if (@lineages != @ranks);
		
		die "ERROR: Read ->$readId<- classified more than once." if (exists $res{$readId});
		$res{$readId} = {};
		for (my $i = 0; $i <= $#ranks; $i++) {
			my $lin = $lineages[$i];
			# Taxon without a name
			$lin = undef if ($lin =~ m/^0$/);
			# Unclassified rank
			$lin = "UNMATCHED" if (defined $lin and not $lin);
			
			$res{$readId}->{$ranks[$i]} = $lin;
		}
	}
	return \%res;
}


1;