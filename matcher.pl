#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use Path::Tiny;
use Getopt::Long;
use Time::HiRes;
use Cwd;

# Variables
my $start_time = Time::HiRes::time(); 

my $logFile = '';

my @re = ();
my $regexFile = '';
my %matcher = ();
my @unmatch = ();

my $help = 0;
my $test = 0;
my $arcsight = 0;
my $detailed = 0;
my %detailedOutput = ();
my $output = 0;

# Global variables
our $unmatchSize = 0;

# Custom variables
my $customLogPath = '';
my $customRegexPath = '';

sub help {
	print "Usage: matcher.pl (-l LOGPATH) (-re REGEXPATH) [-htAdO]\n\n";
	print "-h, --help      Displays help message and exit\n";
	print "-l, --log       Set log file to be checked against regexs\n";
	print "-re             Set regex file where are stored all regex to test\n\n";
	print "-t              Test regex syntax. If anyone is incorrect, the script dies\n";
	print "-A              Print all regex in Arcsight format";
	print "-d, --detailed  Print a matched line with all regex groups for all regex\n";
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
=cut

sub readRegexFile {
	open (my $file, '<:encoding(UTF-8)', $regexFile) or die "Could not open file '$regexFile'";
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

sub results{
	# Get window size
	my ($width, $height) = 0;
	if ( $^O eq "MSWin32"){ # Windows
		use Win32::Console;
		my $CONSOLE = Win32::Console->new();
		($width, $height) = $CONSOLE->Size();
	} else { $width = `tput cols`; } # Linux / MacOS

	$unmatchSize = (@unmatch);

	print "\n===== Results =============================\n";
	results_stats($width, $height);

	results_unmatches($unmatchSize) if ( $unmatchSize > 0 );
	results_detailed() if ( $detailed );
	results_arcsight() if ( $arcsight );

	print "\n===== End =================================\n";
}

sub results_stats{
	# Numeric values
	my ($hits, $maxValue) = 0;
	my ($w, $h) = @_;

	foreach my $value (values %matcher) {
		$hits = $hits + $value;
		$maxValue = $value if ($value > $maxValue);
	}

	my $spaceLength = length($maxValue);

	# Stats for all regex
	print "\n";
	foreach my $key (sort {$matcher{$b} <=> $matcher{$a}} keys %matcher){
		# Setting spaces before numbers
		my $regexHits = $matcher{$key};
		my $spaces = $spaceLength - length($regexHits);
		# Checking length of every line
		my $spaceLeft = $w - ($spaceLength + 8 + 1);# 8 - " hits | " ; 1 blank space at the end
		my $regex = $key;
		if ( length($key) > $spaceLeft ){
			$regex = substr $key, 0, ($spaceLeft - 5);
			$regex = $regex . "[...]";
		}
		for my $i (1 .. $spaces){ print " "; }
		print "$regexHits hits | $regex\n";
	}
	# Time used
	my $end_time = Time::HiRes::time();
	my $run_time = sprintf("%0.3f",($end_time - $start_time));
	my $timeUsed = "\nTime used: $run_time seconds\n";
	print "$timeUsed";

	# Resumee
	my $total = $hits + $unmatchSize;
	my $percentage = ($hits / $total) * 100;
	$percentage = sprintf("%0.2f", $percentage);
	print "\nMatched log lines: $hits/$total ($percentage%)\n";
	print "Unmatched lines: $unmatchSize\n" if ($unmatchSize > 0);
}

sub results_unmatches{
	# Note: This sub will change when unmatch option will be developed
	my $unm = @_; 
	print "\n===== Unmatched lines =====================\n";
	if ( $unm < 6 ){
		foreach my $unm (@unmatch){ print "$unm\n"; }
	} else {
		for my $firsts (1 .. 5) { print "$unmatch[$firsts]\n"; }
	}
}

sub results_detailed{
	print "\n===== Detailed matches ====================\n";
	my $firstTheoricalPrint = 0; 
	my $firstPrint = 0;
	foreach my $key (sort {$matcher{$b} <=> $matcher{$a}} keys %matcher){
		if ($matcher{$key} > 0) {
			print "-------------------------------------------\n" if ( $firstPrint != 0 ); 
			my $regex = $key;
			my $example = $detailedOutput{$regex};
			$firstTheoricalPrint++;
			my @groups = $example =~ m/$regex/;
			my $totalGroups = $#+;
			if ( $totalGroups > 0 ){
				print "Regex => $regex\nExample => $example\n\n";
				foreach my $pos ( 0 .. $totalGroups-1 ){ #$#+-1 ){
					print "Group " . ($pos+1) . " => " . $groups[$pos] . "\n";
				}
				$firstPrint++;
			}
		}
	}
	if ( $firstPrint == 0 ){
		if ( $firstTheoricalPrint > 0 ) { print "Your regexs don't have any capture group!\n"; }
		else { print "There is no matches with your regex!\n";}
	}
}

sub results_arcsight{
	print "\n===== Arcsight Regex Format ===============\n";
	foreach my $key (sort {$matcher{$b} <=> $matcher{$a}} keys %matcher){
		my $regex = $key;
		$regex =~ s/\\/\\\\/g;
		print "$regex\n";
	}
}

# Parsing params
GetOptions (
	'help|h|?' => \$help,
	'l|log=s' => \$logFile,
	're|rs=s' => \$regexFile,
	't' => \$test,
	'A' => \$arcsight,
	'details|d' => \$detailed,
	'output|o' => \$output
	) or help();
help() if $help; 

my $currentPath = cwd();
# Build regex hash 
# Test custom regex file
if ( $regexFile ){
	die "Regex file doesn't exist"  if ! ( -e $regexFile );
	die "Regex file cannot be read" if ! ( -r $regexFile );
} else {
	# Testing custom regex file path
	# If doesn't exist, it will try to use default file or the script will die
	if ( -e $customRegexPath ){
		die "Custom regex file cannot be read" if ! ( -r $customRegexPath );
		$regexFile = $customRegexPath;
	} else {
		# Use default regex file. If doesn't exists, the program dies
		print "[WARN] Custom regex file $customRegexPath doesn't exist. Trying to use default regex file...\n";
		my $defaultRegexFile = path($currentPath . "/regex.txt");
		die "Default regex file doesn't exist" if ! ( -e $defaultRegexFile );
		die "Default regex file cannot be read" if ! ( -r $defaultRegexFile );
		$regexFile = $defaultRegexFile;
	}
}
readRegexFile();
testRegex() if $test;

# Check log path and open it
if ( $logFile ){
	die "Log file doesn't exist."  if ! ( -e $logFile );
	die "Log file cannot be read." if ! ( -r $logFile );
} else {
	# Testing custom log file path
	# If doesn't exist, it will try to use default file or the script will die
	if ( -e $customLogPath ){
		die "Custom log file cannot be read" if ! ( -r $customLogPath );
		$logFile = $customLogPath;
	} else {
		# Use default regex file. If doesn't exists, the program dies
		print "[WARN] Custom log file $customLogPath doesn't exist. Trying to use default log file...\n";
		my $defaultLogFile = path($currentPath . "/log.txt");
		die "Default log file doesn't exist" if ! ( -e $defaultLogFile );
		die "Default log file cannot be read" if ! ( -r $defaultLogFile );
		$logFile = $defaultLogFile;
	}
}


open (my $log, '<:encoding(UTF-8)', $logFile) or die "Could not open log file '$logFile'";

# Test all log against regex(s)
my $elems = (@re);
my $checking = "";
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
			if ( $detailed and ! (exists $detailedOutput{$checking}) ){ $detailedOutput{$checking} = $line; }
		} else {
			$elem++;
		}
	}
	if ( $elem == $elems ){ push @unmatch, $line; }
}

# Show results
results()