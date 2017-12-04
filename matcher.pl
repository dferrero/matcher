#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use Path::Tiny;
use Getopt::Long;
use Time::HiRes;
use Cwd;

# Custom variables
my ($customLogPath, $customRegexPath) = ('') x2;

# === Variables ===
my $time_init = Time::HiRes::time(); 
my ($regexFile, $logFile, $output) = ('') x3;
my ($help, $verbose, $test, $arcsight, $detailed, $outputmatches) = (0) x6;
my $u = -1;

my (@re, @unmatch) = () x2;
my (%matcher, %detailedOutput, %regexFiles) = () x3;

# Global variables
our $unmatchSize = 0;
our $outputHandler;

# === Subs ===
# Help message
sub help {
	print "Usage: matcher.pl (-l LOGPATH) (-r REGEXPATH) [-hdtuAo]\n\n";
	print "-h, --help        Displays help message and exit\n";
	print "-v                Verbose output [WIP]\n";
	print "-l, --log <file>  Set log file to be checked against regexs\n";
	print "-r <file>         Set regex file where are stored all regex to test\n\n";
	print "-d, --detailed    Print a matched line with all regex groups for all regex\n";
	print "-t                Test regex syntax. If anyone is incorrect, the script dies\n";
	print "-u [number]       Print first N unmatched lines. If no number is specified, it will print all\n";
	print "-A                Print all regex in Arcsight format";
	print "-o <filename>     Print results on a file instead of screen\n";
	print "-om               Classify all matched lines in files\n";
	exit;
}

# Interaction with files
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

sub createNewFile {
	# Dinamic file handlers:
	# http://www.perlmonks.org/?node_id=464068
}

sub closeAllFiles{
	# WIP
}

# Tests
sub testRegex{
	foreach my $testing (@re){
		my $res = eval { qr/$testing/ };
		die "Invalid regex syntax on $@" if $@;
	}
	print "All regex have been checked. Syntax is correct.\n";
}

# Report subs
sub report{
	open ($outputHandler, '>', $output) or die "Could not open file '$outputHandler'" if (!$output eq '');
	# Get window size
	my ($width, $height) = (0) x2;
	if ($^O eq "MSWin32"){ # Windows
		use Win32::Console;
		my $CONSOLE = Win32::Console->new();
		($width, $height) = $CONSOLE->Size();
	} else { $width = `tput cols`; } # Linux / MacOS

	$unmatchSize = (@unmatch);
	$output eq '' ? print "\n===== Results =============================\n" : print $outputHandler "===== Results =============================\n";
	report_stats($width, $height);

	report_unmatches() if ($u > -1);
	report_detailed()  if ($detailed);
	report_arcsight()  if ($arcsight);

	close ($outputHandler) if (!$output eq '');
}

sub report_stats{
	# Numeric values
	my ($hits, $maxValue) = (0) x2;
	my ($w, $h) = @_;

	foreach my $value (values %matcher) {
		$hits = $hits + $value;
		$maxValue = $value if ($value > $maxValue);
	}
	my $spaceLength = length($maxValue);

	# Stats for all regex
	foreach my $key (sort {$matcher{$b} <=> $matcher{$a}} keys %matcher){
		# Setting spaces before numbers
		my $regexHits = $matcher{$key};
		my $spaces = $spaceLength - length($regexHits);
		# Checking length of every line
		my $spaceLeft = $w - ($spaceLength + 8 + 1); # 8 - " hits | " ; 1 blank space at the end
		my $regex = $key;
		if (length($key) > $spaceLeft){
			$regex = substr $key, 0, ($spaceLeft - 5);
			$regex = $regex . "[...]";
		}
		for my $i (1 .. $spaces){ print " "; }
		$output eq '' ? print "$regexHits hits | $regex\n" : print $outputHandler "$regexHits hits | $regex\n";
	}
	# Time used
	my $time_finish = Time::HiRes::time();
	my $time_execution = sprintf("%0.3f",($time_finish - $time_init));
	$output eq '' ? print "\nTime used: $time_execution seconds\n" : print $outputHandler "\nTime used: $time_execution seconds\n";

	# Resumee
	my $total = $hits + $unmatchSize;
	my $percentage = ($hits / $total) * 100;
	$percentage = sprintf("%0.2f", $percentage);
	$output eq '' ? print "\nMatched log lines: $hits/$total ($percentage%)\n" : print $outputHandler "\nMatched log lines: $hits/$total ($percentage%)\n";
	if ($unmatchSize > 0){
		$output eq '' ? print "Unmatched lines: $unmatchSize\n" : print $outputHandler "Unmatched lines: $unmatchSize\n";
	}
}

sub report_unmatches{
	if ($u == 0 || $u > $unmatchSize){
		$output eq '' ? print "\n===== Unmatched lines (all) ===================\n" : print $outputHandler "\n===== Unmatched lines (all) ===================\n";
		foreach my $unm (@unmatch){ $output eq '' ? print "$unm\n" : print $outputHandler "$unm\n"; }
	} else {
		$output eq '' ? print "\n===== Unmatched lines (" . $u . ") =================\n" : print $outputHandler "\n===== Unmatched lines (" . $u . ") =================\n";
		for my $firsts (0 .. $u-1) { $output eq '' ? print "$unmatch[$firsts]\n" : print $outputHandler "$unmatch[$firsts]\n"; }
	}
}

sub report_detailed{
	$output eq '' ? print "\n===== Detailed matches ====================\n" : print $outputHandler "\n===== Detailed matches ====================\n";
	my ($firstTheoricalPrint, $firstPrint) = (0) x2; 
	foreach my $key (sort {$matcher{$b} <=> $matcher{$a}} keys %matcher){
		if ($matcher{$key} > 0) {
			if ($output eq ''){ print "-------------------------------------------\n"   if ($firstPrint != 0); } 
			else { print $outputHandler "-------------------------------------------\n" if ($firstPrint != 0); }
			
			my $regex = $key;
			my $example = $detailedOutput{$regex};
			$firstTheoricalPrint++;
			my @groups = $example =~ m/$regex/;
			my $totalGroups = $#+;
			if ($totalGroups > 0){
				$output eq '' ? print "Regex => $regex\nExample => $example\n\n" : print $outputHandler "Regex => $regex\nExample => $example\n\n";
				foreach my $pos (0 .. $totalGroups-1){ 
					$output eq '' ? print "Group " . ($pos+1) . " => " . $groups[$pos] . "\n" : print $outputHandler "Group " . ($pos+1) . " => " . $groups[$pos] . "\n";
				}
				$firstPrint++;
			}
		}
	}
	if ($firstPrint == 0){
		if ($firstTheoricalPrint > 0) { $output eq '' ? print "Your regexs don't have any capture group!\n" : print $outputHandler "Your regexs don't have any capture group!\n"; }
		else { $output eq '' ? print "There is no matches with your regex!\n" : print $outputHandler "There is no matches with your regex!\n"; }
	}
}

sub report_arcsight{
	$output eq '' ? print "\n===== Arcsight Regex Format ===============\n" : print $outputHandler "\n===== Arcsight Regex Format ===============\n";
	my $arcsightCounter = 1;
	foreach my $key (sort {$matcher{$b} <=> $matcher{$a}} keys %matcher){
		if ($matcher{$key} > 0){
			my $regex = $key;
			$regex =~ s/\\/\\\\/g;
			$output eq '' ? print "Regex #" . $arcsightCounter . ":\n" : print $outputHandler "Regex #" . $arcsightCounter . ":\n";
			$output eq '' ? print "$regex\n" : print $outputHandler "$regex\n";
			$arcsightCounter++;
		}
	}
}

# === Main program ===
# Parsing params
GetOptions (
	'help|h|?' => \$help,
	'v+' => \$verbose,
	'l|log=s' => \$logFile,
	'r=s' => \$regexFile,
	'details|d' => \$detailed,
	't' => \$test,
	'A' => \$arcsight,
	'u:i' => \$u,
	'o=s' => \$output,
	'om' => \$outputmatches
	) or help();
help() if $help; 

die "Number of unmatched lines must be a non negative number" if (!($u == -1) && ($u < -1));

my $currentPath = cwd();
# Build regex hash 
# Test custom regex file
if ($regexFile){
	die "$regexFile is not a file"  if ! (-f $regexFile);
	die "Regex file doesn't exist"  if ! (-e $regexFile);
	die "Regex file cannot be read" if ! (-r $regexFile);
} else {
	# Testing custom regex file path
	# If doesn't exist, it will try to use default file or the script will die
	if (-e $customRegexPath){
		die "Custom regex file cannot be read" if ! (-r $customRegexPath);
		$regexFile = $customRegexPath;
	} else {
		# Use default regex file. If doesn't exists, the program dies
		print "[WARN] Custom regex file $customRegexPath doesn't exist. Trying to use default regex file...\n";
		my $defaultRegexFile = path($currentPath . "/regex.txt");
		die "Default regex file doesn't exist"  if ! (-e $defaultRegexFile);
		die "Default regex file cannot be read" if ! (-r $defaultRegexFile);
		$regexFile = $defaultRegexFile;
	}
}
readRegexFile();
testRegex() if $test;

# Check log path and open it
if ($logFile){
	die "$logFile is not a file"  if ! (-f $logFile);
	die "Log file doesn't exist"  if ! (-e $logFile);
	die "Log file cannot be read" if ! (-r $logFile);
} else {
	# Testing custom log file path
	# If doesn't exist, it will try to use default file or the script will die
	if (-e $customLogPath){
		die "Custom log file cannot be read" if ! (-r $customLogPath);
		$logFile = $customLogPath;
	} else {
		# Use default regex file. If doesn't exists, the program dies
		print "[WARN] Custom log file $customLogPath doesn't exist. Trying to use default log file...\n";
		my $defaultLogFile = path($currentPath . "/log.txt");
		die "Default log file doesn't exist"  if ! (-e $defaultLogFile);
		die "Default log file cannot be read" if ! (-r $defaultLogFile);
		$logFile = $defaultLogFile;
	}
}

open (my $log, '<:encoding(UTF-8)', $logFile) or die "Could not open log file '$logFile'";

# Test all log against regex(s)
my $elems = (@re);
my $checking = "";
while (my $line = <$log>){
	my ($match, $elem) = (0) x 2;
	chomp $line;
	while (! $match and ($elem < $elems)){
		$checking = $re[$elem];
		chomp $checking;
		if ($line =~ m/$checking/){
			$matcher{$checking}++;
			$match++;
			if ($detailed and ! (exists $detailedOutput{$checking})){ $detailedOutput{$checking} = $line; }
		} else { $elem++; }
	}
	if ($elem == $elems){ push @unmatch, $line; }
}

# Show report
report()