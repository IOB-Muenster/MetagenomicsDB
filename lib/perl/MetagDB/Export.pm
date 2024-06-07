package MetagDB::Export;


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
use Storable qw(dclone);

use lib "../";
use MetagDB::Helpers;


#
#--------------------------------------------------------------------------------------------------#
# Create an OTU table for export.
#
#
# INPUT:
#
#	A hash reference containing classification results for one of more samples.
#		{
#			Sample1 => {
#				Class1 => Count1_1,
#				...,
#				ClassN => CountN_1
#			},
#			...,
#			SampleN => {
#				Class1 => Count1_N,
#				...,
#				ClassN => CountN_N
#			}
#		}
#
#	A tab-delimited header string with arbitrary content. Sample names will be automatically
#	added to this. Usually, the name of the very first field should be provided in the string.
#
#
# OUTPUT:
#
# 	A string with a tab-delimited table (header may vary depending on header string)
#		#NAME	Sample1	...	SampleN
#		ID1		Count1_1 ... CountN_1
#		...
#		IDN		Count1_N ... CountN_N
#
#	A hash reference mapping IDs generated in this function to classifications
#	for mapping with taxonomy.
#--------------------------------------------------------------------------------------------------#
#
sub otuTab ($classR, $header) {
	foreach my $param ($classR, $header) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	# Empty hash or no ref
	if (not ref($classR) or not %{$classR}) {
		die "ERROR: No classifications or not a reference";
	}
	
	# Sample => classification => count
	# to
	# classification => sample => count
	my %class = %{$classR};
	my %tmps = ();
	foreach my $sample (keys(%class)) {
		die "ERROR: Invalid sample name" if (not $sample);
		die "ERROR: No classifications for sample ->$sample<-" if (not keys(%{$class{$sample}}));
		foreach my $classification (keys(%{$class{$sample}})) {
			die "ERROR: Invalid classification name" if (not $classification);
			# 0 for empty/undefined counts
			my $count = $class{$sample}->{$classification} || "0";
			if (exists $tmps{$classification}) {
				$tmps{$classification}{$sample} = $count
			}
			else {
				$tmps{$classification} = {$sample => $count}
			}
		}
	}
	
	# Rows in OTU tab
	my @classifications = sort keys(%tmps);
	# Columns in OTU tab: All samples, even those with 0 counts for particular OTUs
	my @samples = sort keys(%class);
	$header .= "\t" . join("\t", @samples);
	
	my $otuTab = $header . "\n";
	my %classIDs = ();
	for (my $i = 0; $i <= $#classifications; $i++) {
		# Map ID to classification string for taxonomy file
		my $id = "OTU" . $i;
		my $class = $classifications[$i];
		$classIDs{$id} = $class;
		
		$otuTab .= $id;
		foreach my $sample (@samples) {
			if (exists $tmps{$class}->{$sample}) {
				$otuTab .=  "\t" . $tmps{$class}->{$sample}
			}
			# Set count to 0 for OTUs not observed in a sample
			else {
				$otuTab .=  "\t" . "0"
			}			
		}
		$otuTab .= "\n";
	}
	chomp($otuTab);
	
	
	return $otuTab, \%classIDs;
}


#
#--------------------------------------------------------------------------------------------------#
# Create a taxonomy table for export.
#
#
# INPUT:
#
#	A hash reference containing mappings from classification IDs to classification strings.
#		{
#			ID1 => Class1,
#			...,
#			IDN => ClassN
#		}
#	Ranks in classifications must be separated by semicolon.
#
#	A tab-delimited header string. The first field contains an arbitrary string. Following
#	fields contain ranks.
#
#
# OUTPUT:
#
# 	A string with a tab-delimited table (header may vary, depending on header string)
#		#TAXONOMY	Kingdom	Phylum	Class	Order	Family	Genus	Species
#		ID1			NameK_1	NameP_1	NameC_1	NameO_1	NameF_1	NameG_1	NameS_1
#		...
#		IDN			NameK_N	NameP_N	NameC_N	NameO_N	NameF_N	NameG_N	NameS_N
#	Empty taxon names are replaced with "NoName"; "UNMATCHED" is assumed to indicate
#	unclassified taxa. These are replaced with "NA" which is recognized by
#	MicrobiomeAnalyst.
#
#
# CAVEATS:
#
#	It is assumed that the classification strings contain all necessary ranks in the correct
#	order. The function will only extract the first N ranks where N is the number of ranks
#	in the header.
#	Currently, the following ranks are supported by MicrobiomeAnalyst and Namco:
#	Kingdom, Phylum, Class, Order, Family, Genus, Species.
#	If your ranks are called differently, the analyses in MicrobiomeAnalyst (but not in Namco!)
#	will still work fine, but your custom rank names in the header will not be displayed in the
#	dropdown menues of the website. Instead, the aforementioned names will be given.
#--------------------------------------------------------------------------------------------------#
#
sub taxonomy($mapsR, $header) {
	foreach my $param ($mapsR, $header) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	# Empty hash or no ref
	if (not ref($mapsR) or not %{$mapsR}) {
		die "ERROR: No mappings or not a reference";
	}
	
	my @headers = split("\t", $header);
	die "ERROR: Header only contains one field. Must contain at least 2." if (scalar(@headers) < 2);
	my @ranks = @headers[1..$#headers];
	my $rankIdx = scalar(@ranks) - 1;
	
	my $tax = $header . "\n"; 
	foreach my $id (sort keys(%{$mapsR})) {
		die "ERROR: Invalid ID" if (not $id);
		# Empty or undefined classifications are renamed to NoName which indicates a taxon
		# without a name.
		my @tmps = split(";", $mapsR->{$id} || "NoName", -1);
		
		# Only extract as many ranks from classifications as there are in the header.
		die "ERROR: Not enough ranks in classification" if (scalar(@tmps) < $rankIdx + 1);
		my @class = @tmps[0..$rankIdx];
		# Rename taxa with no name to "NoName" and "UNMATCHED" (unclassified at this
		# and following ranks) to "NA" which is recognized by MicrobiomeAnalyst.
		@tmps = ();
		foreach my $c (@class) {
			if (not $c) {
				push(@tmps, "NoName")
			}
			elsif ($c eq "UNMATCHED") {
				push(@tmps, "NA")
			}
			else {
				push(@tmps, $c)
			}
		}
		@class = @tmps;
		
		$tax .= $id . "\t" . join("\t", @class) . "\n";
	}
	chomp($tax);
	
	
	return $tax;	
}


#
#--------------------------------------------------------------------------------------------------#
# Create a metadata table for export.
#
#
# INPUT:
#
#	A hash reference containing sample names, metadata names, and values. The primary metadata
#	that is expected to divide samples into groups is "z_score_category".
#		{
#			Sample1 => {
#				Meta1 => MetaValue1_1,
#				...,
#				MetaN => MetaValueN_1
#			},
#			...,
#			SampleN => {
#				Meta1 => MetaValue1_N,
#				...,
#				MetaN => MetaValueN_N
#			}
#		}
#
#	A header string with arbitrary content. Names of metadata will be automatically
#	added to this. Usually, the name of the very first field should be provided in the string.
#
#
# OUTPUT:
#
#	A string with a tab-delimited table (header may vary depending on header string). Columns
#	with missing metadata are filled up with "NA". The second column will be the primary metadata.
#		#NAME		z_score_category		Meta1	...	MetaN
#		Sample1		SGA						Value1_1 ... ValueN_1
#		...
#		SampleN		AGA						Value1_N ... ValueN_N
#--------------------------------------------------------------------------------------------------#
#
sub metadata($metasR, $header) {
	foreach my $param ($metasR, $header) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	# Empty hash or no ref
	if (not ref($metasR) or not %{$metasR}) {
		die "ERROR: No metadata or not a reference";
	}
	my %metas = %{$metasR};
	
	my $primeMeta = "z_score_category";
	my $primePattern = qr/$primeMeta/;
	
	# Get all unique metadata names => later: Fill-up missing
	# metadata for single samples
	my %metaNames = ();
	foreach my $sample (keys(%metas)) {
		die "ERROR: Invalid sample name" if (not $sample);
		die "ERROR: No metadata" if (not keys(%{$metas{$sample}}));
		foreach my $metaName (keys(%{$metas{$sample}})) {
			die "ERROR: Invalid metadata name" if (not $metaName);
			next if ($metaName =~ m/^$primePattern$/i);
			$metaNames{$metaName} = undef;
		}
	}
		
	# Rows in metadata tab: All samples, even those with incomplete metadata
	my @samples = sort keys(%metas);
	# Columns in metadata tab: All metadata.
	my @metaNs = sort keys(%metaNames);
	
	# Add primary metadata as first metadata column
	$header .= "\t" . $primeMeta . "\t" . join("\t", @metaNs);
	my $metaTab = $header . "\n";
	foreach my $sample (@samples) {
		$metaTab .= $sample . "\t" . ($metas{$sample}->{$primeMeta} || "NA");
		foreach my $metaN (@metaNs) {
			if (exists $metas{$sample}->{$metaN}) {
				# NA for empty/undefined metadata value
				$metaTab .= "\t" . ($metas{$sample}->{$metaN} || "NA");
			}
			else {
				$metaTab .= "\tNA";
			}
		}
		$metaTab .= "\n";
	}
	chomp($metaTab);
	
	
	return $metaTab;
}


#
#--------------------------------------------------------------------------------------------------#
# Export data for visualization in online tools. Currently supports:
#	*) MicrobiomeAnalyst 2.0's (https://new.microbiomeanalyst.ca/) "Marker Data Profiling" module.
#	*) NAMCO (https://exbio.wzw.tum.de/namco/)
#
#
# INPUT:
#
#	A hash reference containing classification results for one of more samples. Both sample IDs
#	(id*) and sample names (Sample*) must be unique.
#
#		{
#			id1 =>	{
#				Sample1 => {
#					Class1 => Count1_1,
#					...,
#					ClassN => CountN_1
#				},
#			},
#			...,
#			idN => {
#				SampleN => {
#					Class1 => Count1_N,
#					...,
#					ClassN => CountN_N
#				}
#			}
#		}
#	Ranks in classifications must be separated by semicolon.
#
#	A hash reference containing sample ids, sample names, metadata names, and values. Sample names
#	must match names in classification reference. Again, both sample IDs (id*) and sample names
#	(Sample*) must be unique.
#
#		{
#			id1 =>	{
#				Sample1 => {
#					Meta1 => MetaValue1,
#					...,
#					MetaN => MetaValueN
#				}
#			},
#			...,
#			idN => {
#				SampleN => {
#					Meta1 => MetaValue1,
#					...,
#					MetaN => MetaValueN
#				}
#			}
#		}
#
#	The name of the webtool that should be used for visualizations: Either "namco" or
#	"microbiomeanalyst".
#
#
# OUTPUT:
#
#	Three strings containing tab-delimited tables for OTU, taxonomy, and metadata files in
#	the formats described in the otuTab, taxonomy, and metadata functions.
#
#
# CAVEATS:
#
#	MicrobiomeAnalyst and Namco currently only support the ranks kingdom, phylum, class, order,
#	family, genus, and species. It is assumed that the classification strings contain all
#	necessary ranks in the correct order. Only the first N ranks will be extracted where
#	N is the number of ranks supported by both tools (7).
#--------------------------------------------------------------------------------------------------#
#
sub webVis ($classR, $metasR, $tool) {
	foreach my $param ($classR, $metasR, $tool) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	# Empty hash or no ref
	foreach my $param ($classR, $metasR) {
		die "ERROR: Classifications or metadata empty or not a reference" if (not ref($param) or not %{$param})
	}
	
	# The header line for the tables depends on the tool
	$tool = lc($tool);
	my ($headerOTU, $headerMeta, $headerTax) = ("", "", "");
	if ($tool eq "microbiomeanalyst") {
		$headerOTU = '#NAME';
		$headerMeta = '#NAME';
		$headerTax = "#TAXONOMY\tKingdom\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies";
	}
	elsif ($tool eq "namco") {
		$headerOTU = 'Name';
		$headerMeta = 'Name';
		$headerTax = "Taxa\tKingdom\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies";
	}
	else {
		die "ERROR: Unrecognized tool ->$tool<-"
	}
		
	my %class = %{$classR};
	my %metas = %{$metasR};
		
	# Restructure metadata and classifications hashes
	# Remove the sample ID and just keep the inner hashes with
	# the sample name and the data.
	my %classNew = ();
	my %metasNew = ();
	foreach my $id (keys(%class)) {
		die "ERROR: Each ID in classifications must have exactly one sample name"
			if (scalar (keys %{$class{$id}}) != 1);
		foreach my $name (keys %{$class{$id}}) {
			$classNew{$name} = $class{$id}->{$name}
		}
	}
	foreach my $id (keys(%metas)) {
		die "ERROR: Each ID in metadata must have exactly one sample name"
			if (scalar (keys %{$metas{$id}}) != 1);
		foreach my $name (keys %{$metas{$id}}) {
			$metasNew{$name} = $metas{$id}->{$name}
		}
	}
	die "ERROR: Sample names in classifications not unique" if (scalar(keys(%class)) != scalar(keys(%classNew)));
	die "ERROR: Sample names in metadata not unique" if (scalar(keys(%metas)) != scalar(keys(%metasNew)));
	
	# Sanity check: Metadata should contain the same samples as classifications
	my $tmp = join("\t", sort keys(%classNew));
	my $tmp2 = join("\t", sort keys(%metasNew));
	die "ERROR: Classifications and metadata must have the same sample names" if ($tmp ne $tmp2);
	
	# Create the table strings
	my ($otuTab, $classIDsR) = otuTab(\%classNew, $headerOTU);
	my $tax = taxonomy($classIDsR, $headerTax);
	my $meta = metadata(\%metasNew, $headerMeta);
	
	
	return $otuTab, $tax, $meta
}


1;