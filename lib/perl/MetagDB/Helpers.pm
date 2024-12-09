package MetagDB::Helpers;


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

use Archive::Zip qw( :ERROR_CODES );
use File::Find;
use File::Type;
use IO::Uncompress::AnyUncompress qw(anyuncompress $AnyUncompressError);
use IO::Scalar;
use Try::Tiny;


#
#--------------------------------------------------------------------------------------------------#
# Extract compressed value of variable and concatenate single archive members, if applicable.
# Resource forks (files starting with '._') in ZIP archives created on MacOS are ignored.
# Optionally supports nested archives and any combination of: ZIP, BZIP2, GZIP.
# Optionally possible to force the extraction to stop after a specified number of levels.
#--------------------------------------------------------------------------------------------------#
#
sub extractValue ($in = "", $maxLevel = -1) {	
	if (not defined $maxLevel or $maxLevel !~ m/^-?[0-9]+$/) {
		die "ERROR: Illegal value for maxLevel";
	}
	
	my $out = "";
	my $levelC = 1;
	
	# The user wants no extraction
	return $in if ($maxLevel == 0);
	
	# Empty input
	return $in if (not defined $in or $in =~ m/^\s*$/);
	
	while (1 == 1) {
		# Get file type from variable
		my $type = File::Type->new();
		$type = $type->checktype_contents($in) // "";
		
		# Only ZIP archives can include resource forks,
		# if created on MacOS ('._*' files). Skip these.
		if ($type eq "application/zip") {
			# Workaround to create a zip object from a variable
			my $zip = Archive::Zip->new;
			open (my $fh, "<", \$in) or die "ERROR: Cannot create file handle from variable";
			
			try {
				$zip->readFromFileHandle($fh);
				
				# Enforce that archive members have unique names
				my @memberNs = $zip->memberNames();
				my %uniqs = map{$_ => undef} @memberNs;
				my $memberC = $zip->numberOfMembers();
				if (scalar(keys(%uniqs)) != $memberC) {
					die "ERROR: Found ->" . scalar(keys(%uniqs)) . "<- unique member names, but expected ->$memberC<-";
				}
				
				# Extract members
				foreach my $member (@memberNs) {
					# Skip MacOS resource forks
					next if ($member =~ m/^\._/ or $member =~ m/\/\._/);
					my ($tmp, $rc) = $zip->contents($zip->memberNamed($member));
					die "ERROR: Could not extract ->$member<-" if ($rc != AZ_OK);
					$out .= $tmp;
				}
			}
			catch {
				die $_;
			}
			finally {
				close($fh);
			};
		}
		elsif ($type eq "application/x-bzip2" or $type eq "application/x-gzip") {
			# MultiStream for archives with multiple files
			anyuncompress \$in  => \$out, MultiStream => 1 or die "Uncompress failed: $AnyUncompressError\n";
		}
		# Not compressed (anymore)
		elsif ($type eq "application/octet-stream") {
			$out = $in;
			last;
		}
		else {
			die "ERROR: Unsupported type ->$type<-"
		}
				
		# Force the extraction to stop after the specified number of iterations
		last if ($levelC == $maxLevel);
		
		# Empty output after extraction: Empty files in archive, encrypted,
		# or other uncaught error.
		warn "WARNING: No content after extraction" if (not defined $out or $out =~ m/^\s*$/);
		
		$in = $out;
		$out = "";
		$levelC++;
	}
	
	return $out;
}


#
#--------------------------------------------------------------------------------------------------#
# Read file from disk. Maximum file size is 3GB by default.
#--------------------------------------------------------------------------------------------------#
#
sub readFile ($inF, $maxFileSize =  3 * 1024 ** 3) {
	foreach my $param ($inF, $maxFileSize) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	die "ERROR: maxFileSize not a number" if ($maxFileSize !~ m/^\d+$/);
	
	my $cont = "";
	
	# Check existence of file and file size
	if (-e $inF) {
		if ((stat($inF))[7] > $maxFileSize) {
			die "ERROR: Input file is bigger than the file size limit (->$maxFileSize<- bytes)"
		}
	}
	else {
		die "ERROR: Input file ->$inF<- does not exist"
	}
	
	# By setting the input record separator to undef, the whole file is slurped into
	# the cont variable
	open(IN, "<", $inF) or die "ERROR: Could not open input file ->$inF<-";
	local $/ = undef;
	$cont = <IN>;
	close(IN);
	
	return $cont;
}


#
#--------------------------------------------------------------------------------------------------#
# Find a file using a base path, a directory pattern (has to match end of directory name)
# and a file pattern.
# Returns a sorted array reference with absolute paths of all matching files.
# MacOS resource forks (defined as starting with '._') are ignored.
#--------------------------------------------------------------------------------------------------#
#
sub findFile ($baseDir, $dirPattern, $filePattern) {
	foreach my $param ($baseDir, $dirPattern, $filePattern) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	
	my @files = ();
	my %tmps = ();
	my %dirs = ();
	
	# Anonymous subroutine is necessary, so variables between outer
	# and inner routine stay in sync
	my $wanted = sub {
		return if ($File::Find::dir !~ m/$dirPattern$/);
		# Ignore MacOS resource forks
		return if ($File::Find::name !~ m/$filePattern/ or $_ =~ m/^\.\_/);
		push(@files, $File::Find::name);
		
		# Downstream it is expected that all files found are distinct.
		# It is not OK, to have the same file name (and thus probably
		# the same content), but a different file extension.
		# a.gz and a.zip => not OK
		# a.gz and b.zip => OK
		# In principle, this allows file duplicates in different dirs,
		# but only one dir is allowed to match (see below).
		# Regex keeps hidden files (starting with dot) intact, but
		# removes any number of extensions.
		my $basename = $_ =~ s/(.+?)(\.[a-zA-Z0-9]+)+$/$1/r;
		$basename = $File::Find::dir . "/" . $basename;
		if (exists $tmps{$basename}) {
			die "ERROR: Found possible duplicate with different extension ->$basename<-"
		}
		else {
			$tmps{$basename} = undef;
		}
		
		$dirs{$File::Find::dir} = undef;
	};
	
	find($wanted, $baseDir);
	
	# If more than one directory matches the pattern, then it is too unspecific
	my @dirs = keys(%dirs);
	if (@dirs > 1) {
		die "ERROR: Directory pattern ->$dirPattern<- too unspecific. Matches: " . join ("; ", @dirs)
	}
	elsif (@dirs == 0) {
		die "ERROR: No results for directory pattern ->$dirPattern<- and file pattern ->$filePattern<-"
	}
	else {
		return [sort(@files)];
	}
}


#
#--------------------------------------------------------------------------------------------------#
# Split a string into lines. Automatically detect, if line separator is \n or \r\n (CRLF).
#--------------------------------------------------------------------------------------------------#
#
sub splitStr ($str) {
	return [] if (not $str or not defined $str);
	return [] if ($str =~ m/^\s*$/);
	
	my @tmps = ();
	
	# "Windows" record separator \r\n?
	my $isCRLF = 0;
	$isCRLF = 1 if ($str =~ m/\r\n/);
	
	if ($isCRLF == 1) {
		$str =~ s/\r\n$//;
		@tmps = split(/\r\n/, $str);
	}
	else {
		$str =~ s/\n$//;
		@tmps = split(/\n/, $str);
	}
	
	# Delete empty lines and lines consisting only of whitespaces
	my @lines = ();
	for (my $i = 0; $i <=$#tmps; $i++) {
		if ($tmps[$i] !~ m/^\s*$/) {
			push(@lines, $tmps[$i]);
		}
	}
	
	
	return \@lines;
}


1;
