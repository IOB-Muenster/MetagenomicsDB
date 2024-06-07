package MetagDB::Fastq;


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
# Extract the important information from FASTQ variable
#--------------------------------------------------------------------------------------------------#
#
sub process($fastq, $targetFieldsR = {}) {
	foreach my $param ($fastq, $targetFieldsR) {
		die "ERROR: Not enough arguments." if (not $param or not defined $param);
	}
	# No ref
	if (not ref($targetFieldsR)) {
			die "ERROR: Fields not a reference";
	}	

	my %targetFields = %{$targetFieldsR};
	my %reads = ();
	my @lines = @{MetagDB::Helpers::splitStr($fastq)};

	my $lineC = scalar(@lines);
	die "ERROR: Invalid FASTQ; ->" . $lineC . "<-lines" if ($lineC % 4 != 0 or $lineC == 0);
	
	while (@lines) {		
		my @headerConts = split(" ", $lines[0]);
		
		my $readID = $headerConts[0];
		die "ERROR: Invalid FASTQ header" if ($readID !~ /^@/);
		$readID =~ s/^@//;
		
		# Deep copy of targetFields hash -> not just a pointer to original hash
		$reads{$readID} = dclone(\%targetFields);
		
		foreach my $entry (@headerConts[1..$#headerConts]) {
			my ($key, $value) = split("=", $entry, -1);
			
			# Only extract the requested metadata
			if (exists $reads{$readID}->{$key}) {
				$reads{$readID}->{$key} = $value;
			}
		}
		
		my $seq = $lines[1];
		my $spacer = $lines[2];
		my $qual = $lines[3];
		
		die "ERROR: Invalid FASTQ format" if ($spacer !~ m/^\+/);
		# This is only a problem, if the user requests to extract this data via %targetFields
		die "ERROR: Header metadata cannot contain special keys ->_seq_<- or ->_qual_<-" if (exists $reads{$readID}->{'_seq_'} or exists $reads{$readID}->{'_qual_'});
		
		$reads{$readID}->{'_seq_'} = $seq;
		$reads{$readID}->{'_qual_'} = $qual;
		
		splice(@lines,0,4);
	}
	return \%reads;
}


1;