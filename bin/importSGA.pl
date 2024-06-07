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

use Archive::Extract;
use Cwd qw(realpath);
use File::Spec qw(splitpath);
use File::Type;
use FindBin;
use Getopt::Long;
use Try::Tiny;

use lib "$FindBin::Bin/../lib/perl/";
use MetagDB::Fastq;
use MetagDB::Db;
use MetagDB::Helpers;
use MetagDB::Sga;
use MetagDB::Table;

# Disable log buffering.
$| = 1;


#
#-------------------------------------------------------------------------------------------------#
# Parse CLI arguments
#-------------------------------------------------------------------------------------------------#
#
my $tableFile = "";
my $format = "";
my $basePath = "";
my $whoGirlsF = "";
my $whoBoysF = "";
my $isVerbose = 0;
my $isDebug = 0;
my $isHelp = 0;
my $helpMsg = <<'EOF';
#==========================================================================================#
#					importSGA.pl
#------------------------------------------------------------------------------------------#

DESCRIPTION

	Import patient data from the "small for gestational age" (SGA)
	project into the database.
	
	
USAGE

	Connects to the database provided in ".pg_service.conf" (service name: "metagdb") and
	synchronizes the input data with it. Optionally, the program connects to a debug
	database (service name: "debug"), instead of the production database.

	./importSGA.pl --table TABLEFILE --data BASEDIR \
		[--format FORMATSTR] [--whogirls] [--whoboys] [--verbose] [--debug] [--help]

			OR	
	
	./importSGA.pl -t TABLEFILE -d BASEDIR \
		[-f FORMATSTR] [--whogirls] [--whoboys] [-v] [-d] [-h]
	
	
	Arguments:
		
		--table|-t		FILE: Relative or absolute path
						to a spreadsheet (can be compressed)
						containing the patient, sample, and
						measurement data.
						
		--data|-da		DIR: Relative or absolute path
						to a base directory which contains
						the sequence and classification data.
						The directory may be a single ZIP or TAR
						archive (nested archives not allowed).
						
		--format|-f		OPTIONAL: Format of the table
						file. Must be one of "xlsx", "xls",
						"ods", "sxc", or "csv". If the spreadsheet
						is compressed one of the following
						extensions MUST be added to the format
						string: ".gz" for gzipped archives,
						".zip" for ZIP archives, or ".bz2" for
						spreadsheets compressed with the bzip2
						program. If the format is not provided,
						it is guessed from the file extension.
						
		--whogirls		OPTIONAL FILE: Relative or absolute path
						to the uncompressed extendend WHO standard
						for girls. This has to be a file in XLSX
						format. If provided, --whoboys needs to be
						given, too. Typically only used for
						initialization of the database.
						
		--whoboys		OPTIONAL FILE: Relative or absolute path
						to the uncompressed extendend WHO standard
						for boys. This has to be a file in XLSX
						format. If provided, --whogirls needs to be
						given, too. Typically only used for
						initialization of the database.
						
		--verbose|-v	OPTIONAL: Print verbose status
						messages. Off by default.
						
		--debug|-de		OPTIONAL: Connect to a debugging database,
						instead of the production database using the
						service "debug" in ".pg_service.conf".
						
		--help|-h		OPTIONAL: Print this help message
						and exit. 	

		
DEPENDENCIES
	
	Archive::Extract
	File::Type
	Try::Tiny
	MetagDB (custom modules)
	

CAVEATS

	The list of materialized views in the database is hardcoded as @matViews.


AUTHOR

	Felix Manske (felix.manske@uni-muenster.de)
#==========================================================================================#
EOF

GetOptions ("table=s"		=> \$tableFile,
            "data=s"		=> \$basePath,
            "format=s"		=> \$format,
            "whogirls:s"	=> \$whoGirlsF,
            "whoboys:s"		=> \$whoBoysF,
            "verbose"		=> \$isVerbose,
            "debug"			=> \$isDebug,
            "help"			=> \$isHelp)
or die("Error in command line arguments\n");

die $helpMsg if ($isHelp == 1);
$format = lc($format);

# Number of records per statement (INSERT and SELECT)
# Numbers were set after benchmarking, so edit carefully.
# Some advice: More is not always better, especially for
# large records (e.g. sequence relation). Nevertheless,
# if you choose too few records, that is also slow :)
# => There is a sweet spot.
my $maxRows = 80;

# A list of all materialized views
# currently in the database
my @matViews = (
	"v_samples",
	"v_lineages",
	"v_taxa",
	"v_measurements",
	"v_metadata"
);


#
#-------------------------------------------------------------------------------------------------#
# Measure elapsed time
#-------------------------------------------------------------------------------------------------#
#
sub getDuration {
	my $start = $_[0];
	my $now = time;
	my $duration = $now - $start;
	return $duration, $now;
}


#
#-------------------------------------------------------------------------------------------------#
# Profiling
#-------------------------------------------------------------------------------------------------#
#
my $start = time;
my $now = "";
my $duration = "";


#
#-------------------------------------------------------------------------------------------------#
# Convert relative to absolute paths, if necessary
#-------------------------------------------------------------------------------------------------#
#
if ($tableFile !~ m/^\//) {
	$tableFile = realpath($tableFile) or die "ERROR: Could not get realpath for ->$tableFile<-";
}
if ($basePath !~ m/^\//) {
	$basePath = realpath($basePath) or die "ERROR: Could not get realpath for ->$basePath<-";
}
if ($whoGirlsF and $whoGirlsF !~ m/^\//) {
	$whoGirlsF = realpath($whoGirlsF) or die "ERROR: Could not get realpath for ->$whoGirlsF<-";
}
if ($whoBoysF and $whoBoysF !~ m/^\//) {
	$whoBoysF = realpath($whoBoysF) or die "ERROR: Could not get realpath for ->$whoBoysF<-";
}


#
#-------------------------------------------------------------------------------------------------#
# Extract value for basePath, if necessary.
# Does not skip resource forks in ZIPs created on MacOS. However, files from the basePath will
# later be selected by the MetagDB::Helpers::findFile function which ignores resource forks.
#-------------------------------------------------------------------------------------------------#
#
print "DEBUG: Checking, if ->$basePath<- needs to be extracted\n" if ($isVerbose == 1);
if (! -d $basePath) {
	# If the basePath dir is compressed, it will be unpacked
	if (-B $basePath) {
		# Archive::Extract uses file extension to determine archive type.
		# If that does not work, fall back to mime types.
		my $type = Archive::Extract::type_for($basePath) // "";
		if (not $type) {
			my $ft = File::Type->new();
			$type = $ft->checktype_filename($basePath);
			
			if ($type eq "application/zip") {
				$type = "zip"
			}
			elsif ($type eq "application/x-gtar") {
				$type = "tar"
			}
			else {
				die "ERROR: Unsupported file type ->$type<- for --data";
			}
		}
		print "DEBUG: --data is a ->$type<- archive\n" if ($isVerbose == 1);
		
		# Prefer CLI tools --> lower RAM usage
		$Archive::Extract::PREFER_BIN = 1;
		my $archive = Archive::Extract->new(archive => $basePath, type => $type);
		my ($vol, $dir, $file) = File::Spec->splitpath($basePath);
		$archive->extract(to => $dir) or die "ERROR: $archive->error";
		
		$basePath = $archive->extract_path;
		$dir =~ s/\/$//;
		# Supposedly extracted directory (see extract_path) is still a file
		die "ERROR: Data not a directory after one extraction" if ($dir eq $basePath or ! -d $basePath);
	}
	else {
		die "ERROR: Value for --data must be a directory or an archive"
	}
}
($duration, $now) = getDuration($start);
print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);


#
#-------------------------------------------------------------------------------------------------#
# Main
#-------------------------------------------------------------------------------------------------#
#
my $lock = 42;
my $dbh = "";
if ($isDebug == 1) {
	print "INFO: Connecting to debug database\n";
	$dbh = MetagDB::Db::connectDebug();
}
else {
	$dbh = MetagDB::Db::connect();
	print "DEBUG: Connecting to ->" . $dbh->{pg_db} . "<- on ->" .
		$dbh->{pg_host} . "<- as user ->" . $dbh->{pg_user} . "<-\n" if ($isVerbose == 1);
}

# Attempt to aquire transaction-level advisory lock --> released automatically
# after transaction
my @locks = $dbh->selectrow_array("SELECT pg_try_advisory_xact_lock(?)", {}, $lock);

# The lock is already in use --> another instance of this script writes to db
die "ERROR: Another instance is already running" if ($locks[0] == 0);


#-------------------------------------------------------------------------------------------------#
# Extract information from patient table file
#-------------------------------------------------------------------------------------------------#
print "DEBUG: Extracting information from table file ->$tableFile<-\n" if ($isVerbose == 1);
my $dataR = MetagDB::Sga::parseTable($tableFile, $format);
($duration, $now) = getDuration($now);
print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);


#-------------------------------------------------------------------------------------------------#
# Extract information from WHO growth standards (optional)
#-------------------------------------------------------------------------------------------------#
my $standardsR = undef;
if ($whoGirlsF and not $whoBoysF) {
	die "ERROR: Providing standards is optional, but if present, both need to be specified";
}
elsif (not $whoGirlsF and $whoBoysF) {
	die "ERROR: Providing standards is optional, but if present, both need to be specified";
}
elsif ($whoGirlsF and $whoBoysF) {
	print "DEBUG: Extracting information from WHO standards ->$whoGirlsF<- and ->$whoBoysF<-\n" if ($isVerbose == 1);
	$standardsR = MetagDB::Sga::parseWHO($whoGirlsF, $whoBoysF);
	($duration, $now) = getDuration($now);
	print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);	
}


#-------------------------------------------------------------------------------------------------#
# Insert the data into the database
#-------------------------------------------------------------------------------------------------#
try {
	#-------------------------------------------------------------------------------------------------#
	# Create an entry in change relation. If no data will be inserted (all data already present),
	# this will be rolled back and no change is made to the change relation, except incrementing
	# the id column
	#-------------------------------------------------------------------------------------------------#
	print "DEBUG: Adding entry in change\n" if ($isVerbose == 1);
	my $idChange = MetagDB::Sga::insertChange($dbh);
	($duration, $now) = getDuration($now);
	print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);
	
	# New data inserted?
	my $isNew = 0;
	
	
	#-------------------------------------------------------------------------------------------------#
	# Add an entry to patient
	#-------------------------------------------------------------------------------------------------#
	print "DEBUG: Adding patients\n" if ($isVerbose == 1);
	($dataR, my $keysPatR, $isNew) = MetagDB::Sga::insertPatient($dbh, $dataR, $idChange, $isNew, $maxRows);
	($duration, $now) = getDuration($now);
	print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);


	#-------------------------------------------------------------------------------------------------#
	# Add sample per patient
	#-------------------------------------------------------------------------------------------------#
	print "DEBUG: Adding samples\n" if ($isVerbose == 1);
	($dataR, my $keysSampleR, $isNew) = MetagDB::Sga::insertSample($dbh, $dataR, $keysPatR, $idChange, $isNew, $maxRows);
	($duration, $now) = getDuration($now);
	print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);
	
	
	#-------------------------------------------------------------------------------------------------#
	# Add measurements types
	#-------------------------------------------------------------------------------------------------#
	print "DEBUG: Adding measurement types \n" if ($isVerbose == 1);
	(my $keysTypeR, $isNew) = MetagDB::Sga::insertType($dbh, $idChange, $isNew, $maxRows);
	($duration, $now) = getDuration($now);
	print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);

	
	#-------------------------------------------------------------------------------------------------#
	# Add measurement values
	#-------------------------------------------------------------------------------------------------#	
	print "DEBUG: Adding measurements \n" if ($isVerbose == 1);
	$isNew = MetagDB::Sga::insertMeasurement($dbh, $keysSampleR, $keysTypeR, $idChange, $isNew, $maxRows);
	($duration, $now) = getDuration($now);
	print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);


	#-------------------------------------------------------------------------------------------------#
	# Add reads per sample
	#-------------------------------------------------------------------------------------------------#	
	# From local directory
	print "DEBUG: Adding sequences\n" if ($isVerbose == 1);
	(my $keysSeqR, $isNew) = MetagDB::Sga::insertSequence($dbh, $keysSampleR, $basePath, $idChange, $isNew, $maxRows);
	($duration, $now) = getDuration($now);
	print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);
	
	# Not a single read found in basePath or no dirPattern in table file
	# => don't try to insert taxonomy
	if (%{$keysSeqR}) {
		#-------------------------------------------------------------------------------------------------#
		# Add taxonomy
		#-------------------------------------------------------------------------------------------------#	
		print "DEBUG: Adding taxonomy\n" if ($isVerbose == 1);
		$maxRows = 350;
		(my $keysTaxR, $isNew) = MetagDB::Sga::insertTaxonomy($dbh, $keysSeqR, $keysSampleR, $basePath, $idChange, $isNew, $maxRows);
		($duration, $now) = getDuration($now);
		print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);
		
		if (%{$keysTaxR}) {
			#-------------------------------------------------------------------------------------------------#
			# Add classification per read
			#-------------------------------------------------------------------------------------------------#	
			print "DEBUG: Adding classifications\n" if ($isVerbose == 1);
			(my $keysClassR, $isNew) = MetagDB::Sga::insertClassification ($dbh, $keysTaxR, $idChange, $isNew, $maxRows);
			($duration, $now) = getDuration($now);
			print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);
		
			
			#-------------------------------------------------------------------------------------------------#
			# Connect classification to taxonomy (taxclass)
			#-------------------------------------------------------------------------------------------------#	
			print "DEBUG: Connecting classification and taxonomy\n" if ($isVerbose == 1);
			$maxRows = 100000;
			$isNew = MetagDB::Sga::insertTaxclass ($dbh, $keysClassR, $idChange, $isNew, $maxRows);
			($duration, $now) = getDuration($now);
			print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);
		}
	}	

	
	#-------------------------------------------------------------------------------------------------#
	# Add WHO standard (optional)
	#-------------------------------------------------------------------------------------------------#	
	if (defined $standardsR) {
		print "DEBUG: Adding WHO standards\n" if ($isVerbose == 1);
		my $tmp_maxRows = 250;
		$isNew = MetagDB::Sga::insertStandard ($dbh, $standardsR, 'weight_for_age', $idChange, $isNew, $tmp_maxRows);
		($duration, $now) = getDuration($now);
		print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);
	}
	
	
	#-------------------------------------------------------------------------------------------------#
	# Check if new data was inserted (isNew == 1).
	# If no record was inserted, rollback the reserved entry in change relation
	#-------------------------------------------------------------------------------------------------#
	if ($isNew == 1) {
		#-------------------------------------------------------------------------------------------------#
		# Update the materialized views
		#-------------------------------------------------------------------------------------------------#
		print "DEBUG: Updating materialized views\n" if ($isVerbose == 1);
		foreach my $matView (@matViews) {
			$dbh->do("REFRESH MATERIALIZED VIEW $matView");
		}
		($duration, $now) = getDuration($now);
		print "DEBUG: ->$duration<- secs\n" if ($isVerbose == 1);
		
		$dbh->commit;
		print "INFO: Insert successful\n";
	}
	else {
		$dbh->rollback;
		print "INFO: Nothing to insert\n";
	}
}
catch {
	$dbh->rollback;
	warn "ERROR: Rolling back due to ->$_<-\n";
}
finally {
	# Disconnect from db
	$dbh->disconnect;
};


($duration, $now) = getDuration($start);
print "INFO: Finished in ->$duration<- seconds\n";

print "\nDONE\n"