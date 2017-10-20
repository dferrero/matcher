#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use Path::Tiny;
use Getopt::Long;
use Time::HiRes;
use Cwd;

# Custom variables
my $customLogPath = '';
my $customRegexPath = '';

# === Variables ===
my $start_time = Time::HiRes::time(); 
my $regexFile = '';
my $logFile = '';
my $u = -1;
my ($help, $test, $arcsight, $detailed, $output) = 0;


my @re = ();
my @unmatch = ();

my %matcher = ();
my %detailedOutput = ();

# Global variables
our $unmatchSize = 0;

# === Subs ===
# Help message
sub help {
	print "Usage: matcher.pl (-l LOGPATH) (-r REGEXPATH) [-hdtuAo]\n\n";
	print "-h, --help        Displays help message and exit\n";
	print "-l, --log <file>  Set log file to be checked against regexs\n";
	print "-r <file>         Set regex file where are stored all regex to test\n\n";
	print "-d, --detailed    Print a matched line with all regex groups for all regex\n";
	print "-t                Test regex syntax. If anyone is incorrect, the script dies\n";
	print "-u [number]       Print first N unmatched lines. If no number is specified, it will print all\n";
	print "-A                Print all regex in Arcsight format";
	print "-o, --output      *NOT IMPLEMENTED* Classify all matched lines in files\n";
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
	# Get window size
	my ($width, $height) = 0;
	if ( $^O eq "MSWin32"){ # Windows
		use Win32::Console;
		my $CONSOLE = Win32::Console->new();
		($width, $height) = $CONSOLE->Size();
	} else { $width = `tput cols`; } # Linux / MacOS

	$unmatchSize = (@unmatch);
	print "\n===== Results =============================\n";
	report_stats($width, $height);

#	report_unmatches($unmatchSize) if ( $unmatchSize > 0 );
	report_unmatches() if ( $u > -1 );
	report_detailed()  if ( $detailed );
	report_arcsight()  if ( $arcsight );

	print "\n===== End =================================\n";
}

sub report_stats{
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
		my $spaceLeft = $w - ($spaceLength + 8 + 1); # 8 - " hits | " ; 1 blank space at the end
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
	print "\nTime used: $run_time seconds\n";

	# Resumee
	my $total = $hits + $unmatchSize;
	my $percentage = ($hits / $total) * 100;
	$percentage = sprintf("%0.2f", $percentage);
	print "\nMatched log lines: $hits/$total ($percentage%)\n";
	print "Unmatched lines: $unmatchSize\n" if ($unmatchSize > 0);
}

sub report_unmatches{
	if ( $u == 0 || $u > $unmatchSize ){
		print "\n===== Unmatched lines (all) ===================\n";
		foreach my $unm (@unmatch){ print "$unm\n"; }
	} else {
		print "\n===== Unmatched lines (" . $u . ") =================\n";
		for my $firsts (0 .. $u-1) { print "$unmatch[$firsts]\n"; }
	}
}

sub report_detailed{
	print "\n===== Detailed matches ====================\n";
	my ($firstTheoricalPrint, $firstPrint) = 0; 
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
				foreach my $pos ( 0 .. $totalGroups-1 ){ 
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

sub report_arcsight{
	print "\n===== Arcsight Regex Format ===============\n";
	foreach my $key (sort {$matcher{$b} <=> $matcher{$a}} keys %matcher){
		my $regex = $key;
		$regex =~ s/\\/\\\\/g;
		print "$regex\n";
	}
}

# === Main program ===
# Parsing params
GetOptions (
	'help|h|?' => \$help,
	'l|log=s' => \$logFile,
	'r=s' => \$regexFile,
	'details|d' => \$detailed,
	't' => \$test,
	'A' => \$arcsight,
	'u:i' => \$u,
	'output|o' => \$output
	) or help();
help() if $help; 

die "Number of unmatched lines must be a non negative number" if ( ! ($u == -1) && ($u < -1) );

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
		} else { $elem++; }
	}
	if ( $elem == $elems ){ push @unmatch, $line; }
}

# Show report
report()