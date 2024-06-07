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
# Tests for MetagDB::Helpers module
#==================================================================================================#
# DESCRIPTION
# 
#	Test the functions in the MetagDB::Helpers module.
#
#
# USAGE
#
# 	./test_Helpers.pl
#					
#
# DEPENDENCIES
# 
#	MetagDB::Helpers
#	Test2::Bundle::More
#	Test2::Tools::Compare
#	Try::Tiny
#==================================================================================================#


use strict;
use warnings;

use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Compress::Zip qw(zip $ZipError :zip_method);
use IO::Compress::Bzip2 qw(bzip2 $Bzip2Error);
use Test2::Bundle::More qw(ok done_testing);
use Test2::Tools::Compare;
use Try::Tiny;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl/";
use MetagDB::Helpers;


#
#--------------------------------------------------------------------------------------------------#
# Internal function to extract a letter based on its position in the alphabet.
#--------------------------------------------------------------------------------------------------#
#
sub getLetter  {
	my $int = int($_[0]);
	my $alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	
	if ($int >= length($alphabet)) {
		die "ERROR: Integer is too large";
	}
	else {
		return substr($alphabet, $int, 1);
	}
}


#
#--------------------------------------------------------------------------------------------------#
# Test the extractValue function with single or nested archives (gzip, zip, bzip2) with one file.
# Extraction of a zip archive with multiple files is also tested.
#--------------------------------------------------------------------------------------------------#
#
sub test_extractValue {
	my $raw = ">abc\nATGATGC\n";
	my $rawTwo = ">def\nTACTACG\n";
	
	# Multiple target files per archive.
	# gzip only works for single files, the same for bzip2
	my %algosMult = (
		"zip" => [
			sub {my $archive = IO::Compress::Zip->new(\$_[0], Name => $_[1], Method => ZIP_CM_STORE); return $archive},
			sub {$_[0]->newStream(Name => $_[1], Method => ZIP_CM_STORE); return $_[0]}
			],
	);
	
	# One target file per archive
	my %algos = (
		"gzip"	=>	sub {gzip \$_[0] => \$_[1]},
		"zip"	=>	sub {zip \$_[0] => \$_[1]},
		"bzip2"	=>	sub {bzip2 \$_[0] => \$_[1]},
		'zip (MacOS)' => $algosMult{"zip"}
	);
	
	# Only for naming of archive members for zip (MacOS)
	my %suffixes = (
		'gzip'			=>	'.gz',
		'zip'			=>	'.zip',
		'bzip2'			=>	'.bz2',
		'zip (MacOS)'	=>	'.zip'
	);
	
	my $err = "";
	my $zipped = "";
	$algos{'zip'}->($raw, $zipped);
	
	
	#------------------------------------------------------------------------------#
	# Test no input data (and no maxLevel)
	#------------------------------------------------------------------------------#
	is (MetagDB::Helpers::extractValue(), "", 'Testing no input data');
	
	#------------------------------------------------------------------------------#
	# Test no maxLevel
	#------------------------------------------------------------------------------#
	is (MetagDB::Helpers::extractValue($zipped), $raw, 'Testing no maxLevel');
	
	
	#------------------------------------------------------------------------------#
	# Test empty input data
	#------------------------------------------------------------------------------#
	is (MetagDB::Helpers::extractValue("", -1), "", 'Testing empty input data');
	
	
	#------------------------------------------------------------------------------#
	# Test input data contains only blanks
	#------------------------------------------------------------------------------#
	is (MetagDB::Helpers::extractValue('    ', -1), '    ', 'Testing input data contains only blanks');
	
	
	#------------------------------------------------------------------------------#
	# Test undefined input data
	#------------------------------------------------------------------------------#
	is (MetagDB::Helpers::extractValue(undef, -1), undef, 'Testing undefined input data');
	
	
	#------------------------------------------------------------------------------#
	# Test input data is a literal 0
	#------------------------------------------------------------------------------#
	is (MetagDB::Helpers::extractValue('0', -1), '0', 'Testing input data is a literal zero');
	
	
	#------------------------------------------------------------------------------#
	# Test input data with leading + trailing whitespaces
	#------------------------------------------------------------------------------#
	is (MetagDB::Helpers::extractValue('  foobar  ', -1), '  foobar  ', 'Testing input data with leading + trailing whitespaces');
	
	
	#------------------------------------------------------------------------------#
	# Test empty maxLevel
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::extractValue($zipped, "");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Illegal value for maxLevel/, 'Testing empty maxLevel');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxLevel not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::extractValue($zipped, "a");
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Illegal value for maxLevel/, 'Testing maxLevel not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maxLevel is zero
	#------------------------------------------------------------------------------#
	is (MetagDB::Helpers::extractValue($zipped, 0), $zipped, 'Testing maxLevel is zero');
	
	
	#------------------------------------------------------------------------------#
	# Test to only extract one level of nested archive (at the example of zip.zip)
	#------------------------------------------------------------------------------#
	my $nestedZip = "";
	$algos{'zip'}->($zipped, $nestedZip);
	is(MetagDB::Helpers::extractValue($nestedZip, 1), $zipped, 'Testing to extract only one level of nested archive');
	
		
	#-----------------------------------------------------------------#
	# One FASTA per archive (gzip, zip (also MacOS), bzip2). Extract
	# as many levels as needed.
	#-----------------------------------------------------------------#
	foreach my $algo (keys(%algos)) {
		my $compressed = "";						
		
		if ($algo ne 'zip (MacOS)') {	
			#-----------------------------------------------------------------#
			# Test single file
			#-----------------------------------------------------------------#
			$algos{$algo}->($raw, $compressed);
		}
		else {
			#-----------------------------------------------------------------#
			# Test single file (with MacOS resource forks), only ZIP
			#-----------------------------------------------------------------#
			my $archive = $algos{$algo}->[0]->($compressed, "1.fa");
			$archive->print($raw);
			$archive = $algos{$algo}->[1]->($archive, '__MACOSX/._1.fa');
			$archive->print('foobar');
			$archive->close;
		}
		ok ($raw eq MetagDB::Helpers::extractValue($compressed, -1), 'Testing extraction of ' . $algo . ' archive with one file');
		
		
		#-----------------------------------------------------------------#
		# Test nested archive
		#-----------------------------------------------------------------#
		foreach my $algo2 (keys(%algos)) {
			my $nested = "";
			if ($algo2 ne 'zip (MacOS)') {	
				$algos{$algo2}->($compressed, $nested);
			}
			else {
				my $archive = $algos{$algo2}->[0]->($nested, "1.fa" . $suffixes{$algo});
				$archive->print($compressed);
				$archive = $algos{$algo2}->[1]->($archive, '__MACOSX/._1.fa'  . $suffixes{$algo});
				$archive->print('foobar');
				$archive->close;
			}
			ok ($raw eq MetagDB::Helpers::extractValue($nested, -1), 'Testing extraction of nested archive ' . $algo . '.' . $algo2 . ' archive with one file');
		}
	}
	
	
	#------------------------------------------------------------------------------#
	# Test unsupported (archive) type (HTML as an arbitrary example)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::extractValue('<!DOCTYPE HTML', -1);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Unsupported type/, 'Testing unsupported archive type');
	};
	
		
	#------------------------------------------------------------------------------#
	# Test two FASTAs per archive.
	# Only changes extraction of the inner archive, so no additional tests for
	# nested archives.
	#------------------------------------------------------------------------------#
	foreach my $algo (keys(%algosMult)) {
		my $compressed = "";
		my $archive = $algosMult{$algo}->[0]->($compressed, "raw_file");
		$archive->print($raw);
		$archive = $algosMult{$algo}->[1]->($archive, "rawTwo_file");
		$archive->print($rawTwo);
		$archive->close;
		
		ok ($raw . $rawTwo eq MetagDB::Helpers::extractValue($compressed, -1),
			'Testing extraction of single ' . $algo . ' archive with multiple files');
	}
	
	
	#------------------------------------------------------------------------------#
	# Test two FASTAs per ZIP. Archive created on MacOS (includes resource forks). 
	#------------------------------------------------------------------------------#
	my $compressed = "";
	my $archive = $algosMult{'zip'}->[0]->($compressed, "raw_file");
	$archive->print($raw);
	$archive = $algosMult{'zip'}->[1]->($archive, '__MACOSX/._raw_file');
	$archive->print('foobar');
	$archive = $algosMult{'zip'}->[1]->($archive, "rawTwo_file");
	$archive->print($rawTwo);
	$archive = $algosMult{'zip'}->[1]->($archive, '__MACOSX/._rawTwo_file');
	$archive->print('foobar2');
	$archive->close;
	ok ($raw . $rawTwo eq MetagDB::Helpers::extractValue($compressed, -1),
		'Testing extraction of single MacOS ZIP archive with multiple target files');
		
		
	#------------------------------------------------------------------------------#
	# Test member names not unique (ZIP)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $compressed = "";
		my $archive = $algosMult{'zip'}->[0]->($compressed, "1.fa");
		$archive->print('foobar');
		$archive = $algosMult{'zip'}->[1]->($archive, '1.fa');
		$archive->print('barfoo');
		$archive->close;
		
		MetagDB::Helpers::extractValue($compressed, -1);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*unique member names/, 'Testing member names not unique (ZIP)');
	};
	
	
	#-----------------------------------------------------------------#
	# Test single empty file (only concerns the inner archive
	# --> no tests for nested archives)
	#-----------------------------------------------------------------#
	foreach my $algo (keys(%algos)) {			
		try {
			$err = "";
			
			my $compressed = "";
			if ($algo ne 'zip (MacOS)') {	
				$algos{$algo}->('', $compressed);
			}
			else {
				my $archive = $algos{$algo}->[0]->($compressed, "1.fa");
				$archive->print('');
				$archive = $algos{$algo}->[1]->($archive, '__MACOSX/._1.fa');
				$archive->print('foobar');
				$archive->close;
			}
			
			do {
			    local *STDERR;
			    open STDERR, ">>", "/dev/null";
				my $out = MetagDB::Helpers::extractValue($compressed, -1);
				is ($out, '', 'Testing empty file in ' . $algo . ' archive');
			};
		}
		catch {
			$err = $_;
			
			ok (1==2, 'Testing empty file in ' . $algo . ' archive');
			print "ERROR: $err" . "\n"
		};
	}
	
	
	#-----------------------------------------------------------------#
	# Test single file containing only whitespaces (only concerns the
	# inner archive --> no tests for nested archives)
	#-----------------------------------------------------------------#
	foreach my $algo (keys(%algos)) {			
		try {
			$err = "";
			
			my $compressed = "";
			if ($algo ne 'zip (MacOS)') {	
				$algos{$algo}->('    ', $compressed);
			}
			else {
				my $archive = $algos{$algo}->[0]->($compressed, "1.fa");
				$archive->print('    ');
				$archive = $algos{$algo}->[1]->($archive, '__MACOSX/._1.fa');
				$archive->print('foobar');
				$archive->close;
			}
			
			do {
			    local *STDERR;
			    open STDERR, ">>", "/dev/null";
				my $out = MetagDB::Helpers::extractValue($compressed, -1);
				is ($out, '    ', 'Testing file containing only whitespaces in ' . $algo . ' archive');
			};
		}
		catch {
			$err = $_;
			
			ok (1==2, 'Testing file containing only whitespaces in ' . $algo . ' archive');
			print "ERROR: $err", "\n";
		};
	}
	
	
	#-----------------------------------------------------------------#
	# Test single file containing trailing + leading blanks (only
	# concerns the inner archive --> no tests for nested archives)
	# => should not be altered.
	#-----------------------------------------------------------------#
	foreach my $algo (keys(%algos)) {			
		try {
			$err = "";
			
			my $compressed = "";
			if ($algo ne 'zip (MacOS)') {	
				$algos{$algo}->('  barfoo  ', $compressed);
			}
			else {
				my $archive = $algos{$algo}->[0]->($compressed, "1.fa");
				$archive->print('  barfoo  ');
				$archive = $algos{$algo}->[1]->($archive, '__MACOSX/._1.fa');
				$archive->print('foobar');
				$archive->close;
			}
			my $out = MetagDB::Helpers::extractValue($compressed, -1);
			is ($out, '  barfoo  ', 'Testing file containing trailing + leading whitespaces in  ' . $algo . ' archive');
		}
		catch {
			$err = $_;
			
			ok (1==2, 'Testing file containing trailing + leading whitespaces in  ' . $algo . ' archive');
			print "ERROR: $err", "\n";
		};
	}
	
	
	#-----------------------------------------------------------------#
	# Test single file containing a literal 0 (only concerns the
	# inner archive --> no tests for nested archives)
	#-----------------------------------------------------------------#
	foreach my $algo (keys(%algos)) {			
		try {
			$err = "";
			
			my $compressed = "";
			if ($algo ne 'zip (MacOS)') {	
				$algos{$algo}->('0', $compressed);
			}
			else {
				my $archive = $algos{$algo}->[0]->($compressed, "1.fa");
				$archive->print('0');
				$archive = $algos{$algo}->[1]->($archive, '__MACOSX/._1.fa');
				$archive->print('foobar');
				$archive->close;
			}
			my $out = MetagDB::Helpers::extractValue($compressed, -1);
			is ($out, '0', 'Testing file containing a literal zero in ' . $algo . ' archive');
		}
		catch {
			$err = $_;
			
			ok (1==2, 'Testing file containing a literal zero in ' . $algo . ' archive');
			print "ERROR: $err", "\n";
		};
	}
	

	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Test the readFile function
#--------------------------------------------------------------------------------------------------#
#
sub test_readFile {
	my $rand = "";
	for (my $i = 0; $i <= 30; $i++) {
		my $int = int(rand(25));
		$rand .= getLetter($int);
	}
	
	my $inF = "/tmp/$rand";
	my $maxFileSize = 1;
	my $err = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no file name (+ no maximum file size)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::readFile()
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no file name');
	};
	
		
	#------------------------------------------------------------------------------#
	# Test empty file name
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::readFile("", $maxFileSize)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty file name');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test non-existent file
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::readFile($inF, $maxFileSize)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Input file ->.*<- does not exist/, 'Testing non-existent file');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maximum file size
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::readFile($inF, "")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty maximum file size');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test maximum file size not a number
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::readFile($inF, "abc")
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*not a number/, 'Testing maximum file size not a number');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test file that is too big (includes test to use provided maxFileSize)
	#------------------------------------------------------------------------------#
	my $data = ">abc\nATGATGATG\n";
	
	try {
		$err = "";
		
		open(OUT, ">", $inF) or die "ERROR: Cannot open output file ->$inF<-";
		print OUT $data;
		close (OUT);
		
		MetagDB::Helpers::readFile($inF, $maxFileSize)
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/^ERROR.*Input file is bigger than the file size limit/, 'Testing to read from file that is too big');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty maximum file size
	#------------------------------------------------------------------------------#
	my $fileData = MetagDB::Helpers::readFile($inF,);
	ok ($data eq $fileData, 'Testing empty maximum file size');
	
	
	#------------------------------------------------------------------------------#
	# Test reading contents from binary file (zip as example)
	#------------------------------------------------------------------------------#
	my $compressed = "";
	zip \$data => \$compressed, Name => $rand;
	
	$inF .= ".zip";
	open(OUT, ">", $inF) or die "ERROR: Cannot open output file ->$inF<-";
	print OUT $compressed;
	close (OUT);
	
	$fileData = MetagDB::Helpers::readFile($inF);
	ok ($compressed eq $fileData, 'Testing to read from binary file');
	
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Test find file function
#--------------------------------------------------------------------------------------------------#
#
sub test_findFile {
	# Random string
	my $rand = "";
	for (my $i = 0; $i <= 30; $i++) {
		my $int = int(rand(25));
		$rand .= getLetter($int);
	}
	
	my $basePath = "/dev/null";
	my $dirPattern = $rand . "_dir";
	my $filePattern = $rand . "_file";	
	
	my $err = "";
		
		
	#------------------------------------------------------------------------------#
	# Test no base path (+ no directory pattern + no file pattern)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::findFile();
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no base path');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no directory pattern (+ no file pattern)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::findFile($basePath);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no directory pattern');
	};
		
	
	#------------------------------------------------------------------------------#
	# Test no file pattern
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::findFile($basePath, $dirPattern);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/^Too few arguments/, 'Testing no file pattern');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty base path
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::findFile("", $dirPattern, $filePattern);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/^ERROR.*Not enough arguments/, 'Testing empty base path');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test empty directory pattern
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::findFile($basePath, "", $filePattern);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty directory pattern');
	};
		
	
	#------------------------------------------------------------------------------#
	# Test empty file pattern
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::findFile($basePath, $dirPattern, "");
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Not enough arguments/, 'Testing empty file pattern');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no results for directory pattern (and file pattern)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*No results for/, 'Testing no results for directory pattern');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test no results for file pattern
	#------------------------------------------------------------------------------#
	my $randDirOne = "/tmp/t_$rand/tt1_$rand/$dirPattern";
	try {
		$err = "";
		
		system("mkdir -p $randDirOne") and die "ERROR: Cannot create directory in /tmp";
		MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*No results for/, 'Testing no results for file pattern');
	};

	
	#------------------------------------------------------------------------------#
	# Test more than one directory matches
	#------------------------------------------------------------------------------#
	$basePath = "/tmp/t_$rand";
	try {
		$err = "";
		
		system("touch $randDirOne/$filePattern") and die "ERROR: Cannot create file in /tmp";
		system("mkdir -p /tmp/t_$rand/tt2_$rand/$dirPattern") and die "ERROR: Cannot create directory in /tmp";
		system("touch /tmp/t_$rand/tt2_$rand/$dirPattern/$filePattern") and die "ERROR: Cannot create file in /tmp";
		MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern)
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/ERROR.*Directory pattern.*too unspecific/, 'Testing abiguous directory pattern');
	};
		
	
	#------------------------------------------------------------------------------#
	# Test valid directory and file patterns with multiple files
	#------------------------------------------------------------------------------#
	$basePath = "/tmp/t_$rand/tt1_$rand";
	system("touch $randDirOne/abcd_$filePattern") and die "ERROR: Cannot create file in /tmp";
	my $filesR = MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern);
	my $expecsR = [sort(("$randDirOne/$filePattern", "$randDirOne/abcd_$filePattern"))];
	is ($filesR, $expecsR, "Testing matching files");
	
	
	#------------------------------------------------------------------------------#
	# Test regex support in dir name
	#------------------------------------------------------------------------------#
	$dirPattern = '.*_dir';
	$filesR = MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern);
	is ($filesR, $expecsR, "Testing regex support in dir name");
	
	
	#------------------------------------------------------------------------------#
	# Test regex support in file name
	#------------------------------------------------------------------------------#
	$expecsR = ["$randDirOne/abcd_$filePattern"];
	$filePattern = 'abcd_.*_file$';
	$filesR = MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern);
	is ($filesR, $expecsR, "Testing regex support in file name");
	
	
	#------------------------------------------------------------------------------#
	# Test file duplicate detection: file and .file are not the same
	#------------------------------------------------------------------------------#
	# abcd_$filePattern and .abcd_$filePattern are not duplicates
	$filePattern = 'abcd_.*_file[^/]*$';
	system("touch $randDirOne/.abcd_" . $rand . "_file") and die "ERROR: Cannot create file in /tmp";
	$filesR = MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern);
	my @expecs = sort(("$randDirOne/abcd_" . $rand . "_file", "$randDirOne/.abcd_" . $rand . "_file"));
	is ($filesR, \@expecs, "Testing duplicate detection with hidden files");
	
	
	#------------------------------------------------------------------------------#
	# Test ignore MacOS resource forks (defined as starting with '._')
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		# Even if the file pattern is that of a MacOS resource fork, it cannot be found
		$filePattern = '\._abcd_.*_file[^/]*$';
		system("touch $randDirOne/._abcd_" . $rand . "_file");
		$filesR = MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern);
	}
	catch {
		$err = $_;
	}
	finally {
		ok ($err =~ m/No results for directory pattern/, 'Testing that MacOS resource files are ignored');
	};
	
	
	#------------------------------------------------------------------------------#
	# Test file duplicate detection with complex file extention and duplicate
	# hidden file
	#------------------------------------------------------------------------------#
	# .$filePattern.gz.zip and .$filePattern appear to be duplicates
	$filePattern = '.*file[^/]*$';
	try {
		$err = "";
		
		system("touch $randDirOne/." . $rand  . "file.gz.zip") and die "ERROR: Cannot create file in /tmp";
		system("touch $randDirOne/." . $rand  . "file") and die "ERROR: Cannot create file in /tmp";
		MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Found possible duplicate with different extension.*file/, "Testing duplicate files with complex extension and hidden files");
	};
	
	
	#------------------------------------------------------------------------------#
	# Test file duplicate detection with complex file extention and duplicate file
	#------------------------------------------------------------------------------#
	# $filePattern.gz.zip and $filePattern appear to be duplicates
	try {
		$err = "";
		
		system("mv $randDirOne/." . $rand  . "file.gz.zip" . " $randDirOne/" . $rand  . "file.gz.zip") and die "ERROR: Cannot move file in /tmp";
		system("mv $randDirOne/." . $rand  . "file" . " $randDirOne/" . $rand  . "file") and die "ERROR: Cannot move file in /tmp";
		MetagDB::Helpers::findFile($basePath, $dirPattern, $filePattern);
	}
	catch {
		$err = $_
	}
	finally {
		ok ($err =~ m/ERROR.*Found possible duplicate with different extension.*file/, "Testing duplicate files with complex extension");
	};
		
	
	return;
}


#
#--------------------------------------------------------------------------------------------------#
# Test splitStr function
#--------------------------------------------------------------------------------------------------#
#
sub test_splitStr {
	my $err = "";
	
	
	#------------------------------------------------------------------------------#
	# Test no string
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		MetagDB::Helpers::splitStr();
	}
	catch {
		$err = $_;
	}
	finally {
		ok($err =~ m/Too few arguments/, 'Testing no string');
	};
		
		
	#------------------------------------------------------------------------------#
	# Test empty string
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $linesR = MetagDB::Helpers::splitStr("");
		is($linesR, [], 'Testing empty string')
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing empty string');
		print "ERROR: $err" . "\n"
	};
	
	
	#------------------------------------------------------------------------------#
	# Test string containing only whitespaces
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $linesR = MetagDB::Helpers::splitStr("    ");
		is($linesR, [], 'Testing string containing only whitespaces')
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing string containing only whitespaces');
		print "ERROR: $err" . "\n"
	};
	
	
	#------------------------------------------------------------------------------#
	# Test string containing only newlines
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $linesR = MetagDB::Helpers::splitStr("\n\n");
		is($linesR, [], 'Testing string containing only newlines')
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing string containing only newlines');
		print "ERROR: $err" . "\n"
	};
	
	
	#------------------------------------------------------------------------------#
	# Test string containing only newlines (CRLF)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $linesR = MetagDB::Helpers::splitStr("\r\n\r\n");
		is($linesR, [], 'Testing string containing only newlines (CRLF)')
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing string containing only newlines (CRLF)');
		print "ERROR: $err" . "\n"
	};
	
	
	#------------------------------------------------------------------------------#
	# Test removing empty lines
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $linesR = MetagDB::Helpers::splitStr("A\n    \n\nB\n");
		is($linesR, ["A", "B"], 'Testing removal of empty lines')
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing removal of empty lines');
		print "ERROR: $err" . "\n"
	};
	
	
	#------------------------------------------------------------------------------#
	# Test removing empty lines (CRLF)
	#------------------------------------------------------------------------------#
	try {
		$err = "";
		
		my $linesR = MetagDB::Helpers::splitStr("A\r\n    \r\n\r\nB\r\n");
		is($linesR, ["A", "B"], 'Testing removal of empty lines (CRLF)')
	}
	catch {
		$err = $_;
		
		ok(1==2, 'Testing removal of empty lines (CRLF)');
		print "ERROR: $err" . "\n"
	};
}


#
#--------------------------------------------------------------------------------------------------#
# Main
#--------------------------------------------------------------------------------------------------#
#
# Read from file
print "INFO: Testing read from file\n";
test_readFile;

# Extract archives
print "INFO: Testing extraction of archives\n";
test_extractValue;

# Find files
print "INFO: Testing finding of files\n";
test_findFile;

# Split lines
print "INFO: Testing splitting of string\n";
test_splitStr;

done_testing();
