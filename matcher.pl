#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use Path::Tiny;
use Getopt::Long;
use Time::HiRes;

my $start_time = Time::HiRes::time(); 

my $logfile = '';

my @re = ();
my $regexfile = '';
my %matcher = ();
my @unmatch = ();

# Checks for ARGV
my $check_r = 0;
my $check_rs = 0;

my $test = 0;
my $output = 0;
my $help = 0;

# Global variables
our $unmatchsize = 0;

sub help {
	print "Usage: matcher.pl -l LOGPATH (-re REGEXPATH | -r REGEX) [-O]\n\n";
	print "-l, --log       Set log file to be checked against regexs\n";
	print "-re             Set regex file where are stored all regex to test\n\n";
	print "-h, --help      Displays help message and exit\n";
	print "-r              Set an unique regex to test against the file instead of use a regex file.\n";
	print "                Cannot be set at same time -r and -re\n";
	print "-t              Test regex syntax. If anyone is incorrect, the script dies.\n";
	print "-o, --output    *NOT IMPLEMENTED* Classify all matched lines in files\n";
	exit;
}

=begin File operations aux subroutines
sub writeToFile {
	my $dir = path("/tmp"); # /tmp

	my $file = $dir->child("file.txt"); # /tmp/file.txt

	# Get a file_handle (IO::File object) you can write to
	# with a UTF-8 encoding layer
	my $file_handle = $file->openw_utf8();

	my @list = ('a', 'list', 'of', 'lines');

	foreach my $line ( @list ) {
	    # Add the line to the file
	    $file_handle->print($line . "\n");
	}
}

sub appendToFile {
	my $dir = path("/tmp"); # /tmp

	my $file = $dir->child("file.txt"); # /tmp/file.txt

	# Get a file_handle (IO::File object) you can write to
	# with a UTF-8 encoding layer
	my $file_handle = $file->opena_utf8();

	my @list = ('a', 'list', 'of', 'lines');

	foreach my $line ( @list ) {
	    # Add the line to the file
	    $file_handle->print($line . "\n");
	}
}


sub readFromFile {
	my $dir = path("/tmp"); # /tmp

	my $file = $dir->child("file.txt");

	# Read in the entire contents of a file
	my $content = $file->slurp_utf8();

	# openr_utf8() returns an IO::File object to read from
	# with a UTF-8 decoding layer
	my $file_handle = $file->openr_utf8();

	# Read in line at a time
	while( my $line = $file_handle->getline() ) {
	        print $line;
	}

}
=cut

sub readRegexFile {
	open (my $file, '<:encoding(UTF-8)', $regexfile) or die "Could not open file '$regexfile'";
	my $letter = '';
	my $total_re = 0;
	while (my $regex = <$file>){
		chomp $regex;
		$letter = substr($regex, 0, 1);
		if ($letter ne "#" and $letter ne ""){
			$total_re++;
			push @re, $regex;
			$matcher{$regex} .= 0;
		}
	}
	die "Regex file is empty or has all regex commented" if ($total_re eq 0);
}

sub testRegex{
	foreach my $testing (@re){
		my $res = eval { qr/$testing/ };
		die "Invalid regex syntax on $@" if $@;
	}
	print "All regex have been checked. Syntax is correct.\n";
}

sub finalReport{
	# Get window size
	my ($width, $height) = 0;
	if ( $^O eq "MSWin32"){ # Windows
		use Win32::Console;
		my $CONSOLE = Win32::Console->new();
		($width, $height) = $CONSOLE->Size();
	} else { # Linux / MacOS
		$width = `tput cols`;
	}

	# Numeric values
	my $hits = 0;
	my $maxValue = 0;

	foreach my $value (values %matcher) {
		$hits = $hits + $value;
		$maxValue = $value if ($value > $maxValue);
	}

	my $spaceLength = length($maxValue);
	$unmatchsize = (@unmatch);

	my $total = $hits + $unmatchsize;
	my $percentage = ($hits / $total) * 100;
	$percentage = sprintf("%0.2f", $percentage);
	print "Matched log lines: $hits/$total ($percentage%)\n";
	print "Unmatched lines: $unmatchsize\n" if ($unmatchsize > 0);

	# Stats for all regex
	print "\n";
	foreach my $key (sort {$matcher{$a} <=> $matcher{$b}} keys %matcher) {
		# Setting spaces before numbers
		my $regexHits = $matcher{$key};
		my $spaces = $spaceLength - length($regexHits);
		# Checking length of every line
		my $spaceLeft = $width - ($spaceLength + 8 + 1);# 8 - " hits | " ; 1 blank space at the end
		my $regex = $key;
		if ( length($key) > $spaceLeft ){
			$regex = substr $key, 0, ($spaceLeft - 5);
			$regex = $regex . "[...]";
		}
		# Print information
		for my $i (1 .. $spaces){ print " "; }
		print "$regexHits hits | $regex\n";
	}

	# Print unmatched lines
	if ( $unmatchsize > 0 ){
		print "\n======== Unmatched lines (max 5 displayed) ========\n";
		if ( $unmatchsize < 6 ){
			foreach my $unm (@unmatch){ print "$unm\n"; }
		} else {
			for my $firsts (1 .. 5) { print "$unmatch[$firsts]\n"; }
		}
		print "===================================================\n";		
	} else { print "\n"; }

	# Time used
	my $end_time = Time::HiRes::time();
	my $run_time = sprintf("%0.3f",($end_time - $start_time));
	my $timeUsed = "Time used: $run_time seconds\n";
	$timeUsed = "\n" . $timeUsed if ( $unmatchsize > 0 );
	print "$timeUsed";
}

# Mandatory arg checks
foreach my $arg ( @ARGV ){
	if ($arg =~ m/-{1,2}(r)$/){ $check_r = $check_r + 1; } 
	elsif ($arg =~ m/-{1,2}(re|rs)$/){ $check_rs = $check_rs + 1; }
}

# Parsing params
GetOptions (
	'help|h|?' => \$help,
	'l|log=s' => \$logfile,
	'output|o' => \$output,
	't' => \$test,
	"r=s" => \@re,
	're|rs=s' => \$regexfile
	) or help();
help() if $help; 

# Checking mandatory params
die "Cannot be set re and regex file at same time." if ( $check_r and $check_rs);
die "At least one regex or a regex file must be declared." if (! $check_r and ! $check_rs);
die "Only one regex can be set with -r. If you need more than one regex, please use -re <regex file>." if ( $check_r > 1 );

# Build regex hash 
# a) One regex option
if ( $check_r == 1 ){
	print "\t@re\n";
	#TODO
} 
# b) File regex option
if ( $check_rs == 1 ){
	die "Regex file doesn't exist."  if ! ( -e $regexfile );
	die "Regex file cannot be read." if ! ( -r $regexfile );
	readRegexFile();
	testRegex() if $test;
}

# Check log path and open it
die "Log file doesn't exist."  if ! ( -e $logfile );
die "Log file cannot be read." if ! ( -r $logfile );

open (my $log, '<:encoding(UTF-8)', $logfile) or die "Could not open log file '$logfile'";

# Test all log against regex(s)
my $elems = (@re);
my $checking = "";
#prepareFiles();
while (my $line = <$log>){
	my $match = 0;
	my $elem = 0;
	chomp $line;
	while ( ! $match and ( $elem < $elems )){
		$checking = $re[$elem];
		chomp $checking;
		if ( $line =~ m/$checking/ ){
			$matcher{$checking}++;
			$match++;
		} else {
			$elem++;
		}
	}
	if ( $elem == $elems ){
		push @unmatch, $line;
	}
}

# Show results
finalReport()