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


use strict;
use warnings;

use FindBin;
use Getopt::Long;
use IO::Compress::Zip qw(zip $ZipError :zip_method);
use Try::Tiny;

use lib "$FindBin::Bin/../lib/perl/";
use MetagDB::Db;
use MetagDB::Export;
use MetagDB::Sga;


#
#-------------------------------------------------------------------------------------------------#
# Parse CLI arguments
#-------------------------------------------------------------------------------------------------#
#
my $format = "";
my $ids = "";
my $blacklist = "FILTERED";
my $keepCtrl = 0;
my $isHelp = 0;
my $helpMsg = <<'EOF';
#==========================================================================================#
#									exportSGA.pl
#------------------------------------------------------------------------------------------#

DESCRIPTION

	Given a set of sample IDs, print a string with a ZIP archive containing an OTU -,
	a taxonomy - and a metadata file. Files can be used to visualize the data in the
	database in other web services. Optionally, classifications starting with one of
	the taxa from the blacklist are excluded. Control samples are not exported
	by default.
	
	
USAGE

	./exportSGA.pl --format microbiomeanalyst|namco --ids SAMPLEIDS
		[--blacklist TAXA] [--keepctrl] [--help]

			OR	
	
	./exportSGA.pl -f microbiomeanalyst|namco -i SAMPLEIDS [-b TAXA] [-k] [-h]
	
	
	Arguments:
		
		--format|-f		A string providing the format for the output
						files. One of "microbiomeanalyst" or "namco".
						
		--ids|-i		A string with a set of sample IDs in the
						database, delimited by ",". Data for these IDs
						is exported from the database.
						
		--blacklist|-b	OPTIONAL: A string with a set of taxon names,
						delimited by ",". Classifications starting with
						one of these taxa will not be exported from the
						database.
						
		--keepctrl|-k	OPTIONAL: If provided, control samples will not
						be removed from the output.
						
		--help|-h		OPTIONAL: Print this help message and exit. 	

		
DEPENDENCIES
	
	Try::Tiny
	MetagDB (custom modules)


AUTHOR

	Felix Manske (felix.manske@uni-muenster.de)
#==========================================================================================#
EOF

GetOptions ("format=s"		=> \$format,
            "ids=s"			=> \$ids,
            "blacklist:s"	=> \$blacklist,
            "keepctrl"		=> \$keepCtrl,
            "help"			=> \$isHelp)
or die("Error in command line arguments\n");

die $helpMsg if ($isHelp == 1);

# Number of records per SELECT statement. 
my $maxRows = 80;


#
#-------------------------------------------------------------------------------------------------#
# Main
#-------------------------------------------------------------------------------------------------#
#
my $dbh = "";


try {
	$dbh = MetagDB::Db::connect();
	
	
	#-------------------------------------------------------------------------------------------------#
	# Check CLI arguments
	#-------------------------------------------------------------------------------------------------#
	$format = lc($format);
	if (not $format) {
		die "ERROR: No format"
	}
	elsif ($format ne "microbiomeanalyst" and $format ne "namco") {
		die "ERROR: Unknown format ->$format<-"
	}
	
	my @ids = ();
	if (not $ids) {
		die "ERROR: No IDs"
	}
	else {
		@ids = split(",", $ids)
	}
	foreach my $id (@ids) {
		if ($id !~ m/^\d+$/) {
			die "ERROR: ID ->$id<- is not a number. IDs must be separated by ','"
		}
	}
	
	my @ignoreList = ();
	if ($blacklist) {
		my @tmps = split(",", $blacklist);
		# NA in export is UNMATCHED in database
		@ignoreList = map {$_ =~ s/^NA$/UNMATCHED/; $_} @tmps;
		
	}
	
	#-------------------------------------------------------------------------------------------------#
	# Export classifications and sample metadata from the database 
	#-------------------------------------------------------------------------------------------------#
	# Warnings should not be written to STDOUT...
	my $warn = "";
	my $classR = {};
	my $metasR = {};
	do {
		local *STDERR;
		open STDERR, ">>", \$warn;
		# Loose samples that did not have a classification, control samples,
		# and optionally blacklisted classifications
		($classR, $metasR) = MetagDB::Sga::getLineages($dbh, \@ids, \@ignoreList, $keepCtrl, $maxRows);
		if (keys(%{$metasR})) {
			$metasR = MetagDB::Sga::getMeta($dbh, $metasR, $maxRows);
		}
	};
	# ..., but errors should be captured.
	die $warn if ($warn and $warn !~ m/^WARNING:[^:]+?(WARNING:[^:]+?)*?$/);
	# Sanitize warnings for end users
	$warn =~ s/at \/[^\n]*//g;
	
	
	#-------------------------------------------------------------------------------------------------#
	# Create and zip the files
	#-------------------------------------------------------------------------------------------------#
	my ($otuTab, $tax, $meta) = ("", "", "");
	if (keys(%{$metasR})) {
		($otuTab, $tax, $meta) = MetagDB::Export::webVis($classR, $metasR, $format);
	}
	
	my $compressed = "";
	my $archive = IO::Compress::Zip->new(\$compressed, Name => "microbiomeanalyst_otu.txt", Method => ZIP_CM_STORE)
		or die "ERROR: $ZipError";
	$archive->print($otuTab) or die "ERROR: $ZipError";
	$archive->newStream(Name => "microbiomeanalyst_tax.txt", Method => ZIP_CM_STORE) or die "ERROR: $ZipError";
	$archive->print($tax) or die "ERROR: $ZipError";
	$archive->newStream(Name => "microbiomeanalyst_meta.txt", Method => ZIP_CM_STORE) or die "ERROR: $ZipError";
	$archive->print($meta) or die "ERROR: $ZipError";
	# Create special file with warnings, if necessary.
	if ($warn) {
		$archive->newStream(Name => "microbiomeanalyst_WARNINGS.txt", Method => ZIP_CM_STORE) or die "ERROR: $ZipError";
		$archive->print($warn) or die "ERROR: $ZipError";
	}
	$archive->close or die "ERROR: $ZipError";

	print $compressed;
}
catch {
	print "-";
	print STDERR $_;
}
finally {
	# Disconnect from db
	$dbh->disconnect;
};