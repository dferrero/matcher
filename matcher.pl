#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use Path::Tiny;
use Getopt::Long qw(:config no_ignore_case);
use Time::HiRes;
use Cwd;
use JSON;

# Customizable variables
my $customLogPath = 'C:\Users\David\Documents\Github\matcher\test\ssh-examples.log'; 
my $customRegexPath = 'C:\Users\David\Documents\Github\matcher\test\ssh.re';
my $customIgnoringPath = 'C:\Users\David\Documents\Github\matcher\test\ignoring.re';

# === Variables ===
my $time_initialize = Time::HiRes::time();
my ($regexPath, $logPath, $ignoringPath, $output, $json) = ('') x4;
my ($help, $verbose, $test, $arcsight, $detailed, $sort, $forceAll) = (0) x7;
my $u = -1;

my (@re, @unmatch, @ignoring) = () x3;
my (%matcher, %detailedOutput, %regexFiles) = () x3;

my $currentIndex = 0;
my %indexMatchRegister =  ();
my @allMatchRegister = (); 		# $allMatchRegister[x][0] is always the matcher regex

# Global variables
our ($unmatchSize, $globalHits, $total) = (0) x3;
our $outputHandler;

my $banner="   _____          __         .__                  
  /     \\ _____ _/  |_  ____ |  |__   ___________ 
 /  \\ /  \\\\__  \\\\   __\\/ ___\\|  |  \\_/ __ \\_  __ \\
/    Y    \\/ __ \\|  | \\  \\___|   Y  \\  ___/|  | \\/
\\____|__  (____  /__|  \\___  >___|  /\\___  >__|   
        \\/     \\/          \\/     \\/     \\/       
   Author: \@dferrero	Version: 0.1\n\n";

# === Subs ===
# Help message
sub help {
	print "Usage: matcher.pl (-l LOGPATH) (-r REGEXPATH) [-hvdtFuAso]
	-h, --help      Displays help message and exit
	-v              Verbose output
	-l <file>       Set log file to be checked against regexs
	-r <file>       Set regex file where are stored all regex to test

	-d, --detailed  Print a matched line with all regex groups for all regex
	-i              Set regex file where matched lines from log will be ignored
	-t              Test regex syntax. If anyone is incorrect, the script dies
	-F              Test log against all regex, even if a match is found
	-u [number]     Print first N unmatched lines. If no number is specified, it will print all
	-A              Print all regex in Arcsight format
	-s              Sort all regex. All comments and empty will be removed
	-o <filename>   Get output redirected to a file instead of screen
	-j              Get all hits on JSON format
	";
	exit;
}

# Interaction with files
sub storeRegexFile {
	# TODO: Modify to be more generic. Input: filename, array to store info <- could it be done?
	print "Reading regex file\t" if $verbose;
	open (my $file, '<:encoding(UTF-8)', $regexPath) or die "Could not open file '$regexPath'";
	my $firstChar = '';
	my ($total_re, $duplicates) = (0) x2;
	while (my $regex = <$file>) {
		chomp $regex;
		$firstChar = substr($regex, 0, 1);
		if ($firstChar ne "#" and $firstChar ne "") {
			if (exists $matcher{$regex}) {
				print "[WARN] Duplicate found!\n" if (($duplicates eq 0) and $verbose);
				print "Ignoring regex $regex\n" if $verbose;
				$duplicates++;
			} else {
				push @re, $regex;
				$total_re++;
				$matcher{$regex} .= 0;
			}

		}
	}
	if ($verbose) { $duplicates eq 0 ? print "Done\n" : print "Total duplicates: $duplicates\n\n"; }
	die "Regex file is empty" if ($total_re eq 0);
	close($file);
}

sub storeIgnoringFile {
	my ($args) = @_;

	my $ignoringFile = $args->{file};	# Name (path) of the ignoring regex file
	my ($stored) = $args->{ignoring};	# Array where ignoring regex will be stored

	#if (ref $var eq ref {}) {
	#	print "$var is a hash\n";
	#}

	print "Reading ignoring file\t" if $verbose;
	open (my $file, '<:encoding(UTF-8)', $ignoringFile) or die "Could not open file '$ignoringFile'";
	my $firstChar = '';
	my ($total_re, $duplicates) = (0) x2;
	while (my $regex = <$file>) {
		chomp $regex;
		$firstChar = substr($regex, 0, 1);
		if ($firstChar ne "#" and $firstChar ne "") {
			if (grep(/$regex/, @{$stored})) {
				print "[WARN] Duplicate found!\n" if (($duplicates eq 0) and $verbose);
				print "Ignoring regex $regex\n" if $verbose;
				$duplicates++;
				print "Duplicada: $regex\n";
			} else { 
				push @{$stored}, $regex;
				$total_re++;
			}
		}
	}
	if ($verbose) { $duplicates eq 0 ? print "Done\n" : print "Total duplicates: $duplicates\n\n"; }
	print "Ignoring file is empty!\n" if ($detailed and ($total_re eq 0));
	close($file);
}

# Tests
sub checkRegex{
	print "Checking regex syntax\n" if $verbose;
	foreach my $testing (@re) {
		my $res = eval { qr/$testing/ };
		die "Invalid regex syntax on $@" if $@;
	}
	print "All regex have been checked. Syntax is correct.\n" if $verbose;
}

# TODO: rename this sub
sub writeJson{
	my %currentRow = ();
	my $currentRegex = '';
	my @currentHits = ();
	my @allJSON = ();
	for my $row ( 0 .. $#allMatchRegister ) {
		$currentRegex = $allMatchRegister[$row][0];
		@currentHits = ();
		for my $column ( 1 .. $#{$allMatchRegister[$row]} ) {
			push @currentHits, $allMatchRegister[$row][$column];
		}
		my %currentRow = ('regex'=>$currentRegex, 'hits'=>($#currentHits + 1),'matches'=>[@currentHits]);
		my $pretty = JSON->new->pretty->canonical->encode(\%currentRow);
		push @allJSON, from_json($pretty);
	}
	print JSON->new->pretty->canonical->encode(\@allJSON);
}

# Report subs
sub report{
	if (!$output eq '') {
		open ($outputHandler, '>:encoding(UTF-8)', $output) or die "Could not open file '$outputHandler'";
		print $outputHandler $banner;
	}
	# Get window size
	my ($width, $height) = (0) x2;
	if ($^O eq "MSWin32") { # Windows
		use Win32::Console;
		my $CONSOLE = Win32::Console->new();
		($width, $height) = $CONSOLE->Size();
	} else { $width = `tput cols`; } # Linux / MacOS


	$unmatchSize = (@unmatch);
	if ($output eq '') {
		print "\n===== Results =============================\n";
	} else {
		print $outputHandler "===== Results =============================\n";
	}
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
	foreach my $key (sort {$matcher{$b} <=> $matcher{$a}} keys %matcher) {
		# Setting spaces before numbers
		my $regexHits = $matcher{$key};
		my $spaces = $spaceLength - length($regexHits);
		# Checking length of every line
		my $spaceLeft = $w - ($spaceLength + 8 + 1); # 8 - " hits | " ; 1 blank space at the end
		my $regex = $key;
		if (length($key) > $spaceLeft) {
			$regex = substr $key, 0, ($spaceLeft - 5);
			$regex = $regex . "[...]";
		}
		for my $i (1 .. $spaces) { print " "; }
		$output eq '' ? print "$regexHits hits | $regex\n" : print $outputHandler "$regexHits hits | $regex\n";
	}
	# Time used
	if ($verbose) {
		my $time_terminate = Time::HiRes::time();
		my $time_used =  sprintf("%0.3f",($time_terminate - $time_initialize));
		if ($output eq '') {
			print "\nTime used on execution:\t$time_used seconds\n";
		} else {
			print $outputHandler "\nTime used on execution:\t$time_used seconds\n";
		}
	}

	# Resumee
	my $total = $globalHits + $unmatchSize;
	my $percentage = ($total eq 0 ? 0 : ($globalHits / $total) * 100);
	$percentage = sprintf("%0.2f", $percentage);
	if ($output eq '') {
		if ($total eq 0) {
			print "\nMatched log lines:\t0 ($percentage%)\n";
		} else {
			print "\nMatched log lines:\t$globalHits/$total ($percentage%)\n";
		}
	} else { 
		if ($total eq 0) {
			print $outputHandler "\nMatched log lines:\t0 ($percentage%)\n";
		} else {
			print $outputHandler "\nMatched log lines:\t$globalHits/$total ($percentage%)\n"; 
		}
	}
	if ($unmatchSize > 0) { 
		if ($output eq '') {
			print "Unmatched lines:\t$unmatchSize\n";
		} else {
			print $outputHandler "Unmatched lines:\t$unmatchSize\n"; 
		}
	}
}

sub report_unmatches{
	if ($u == 0 || $u > $unmatchSize) {
		if ($output eq '') {
			print "\n===== Unmatched lines (all) ===================\n";
		} else {
			print $outputHandler "\n===== Unmatched lines (all) ===================\n";
		}
		foreach my $unm (@unmatch) { $output eq '' ? print "$unm\n" : print $outputHandler "$unm\n"; }
	} else {
		if ($output eq '') {
			print "\n===== Unmatched lines (" . $u . ") =================\n";
		} else {
			print $outputHandler "\n===== Unmatched lines (" . $u . ") =================\n";
		}
		for my $firsts (0 .. $u-1) { 
			$output eq '' ? print "$unmatch[$firsts]\n" : print $outputHandler "$unmatch[$firsts]\n"; 
		}
	}
}

sub report_detailed{
	if ($output eq '') {
		print "\n===== Detailed matches ====================\n";
	} else {
		print $outputHandler "\n===== Detailed matches ====================\n";
	}
	my ($firstTheoricalPrint, $firstPrint) = (0) x2; 
	foreach my $key (sort {$matcher{$b} <=> $matcher{$a}} keys %matcher) {
		if ($matcher{$key} > 0) {
			if ($output eq '') { 
				print "-------------------------------------------\n" if ($firstPrint != 0); 
			} else { 
				if ($firstPrint != 0) {
					print $outputHandler "-------------------------------------------\n"; 
				}
			}			
			my $regex = $key;
			my $example = $detailedOutput{$regex};
			$firstTheoricalPrint++;
			my @groups = $example =~ m/$regex/;
			my $totalGroups = $#+;
			if ($totalGroups > 0) {
				if ($output eq '') {
					print "Regex => $regex\nExample => $example\n\n";
				} else {
					print $outputHandler "Regex => $regex\nExample => $example\n\n";
				}
				foreach my $pos (0 .. $totalGroups-1) { 
					if ($output eq '') {
						print "Group ".($pos+1)." => ".$groups[$pos]."\n";
					} else {
						print $outputHandler "Group ".($pos+1)." => ".$groups[$pos]."\n";
					}
				}
				$firstPrint++;
			}
		}
	}
	if ($firstPrint == 0) {
		if ($firstTheoricalPrint > 0) { 
			if ($output eq '') {
				print "Your regexs don't have any capture group!\n";
			} else {
				print $outputHandler "Your regexs don't have any capture group!\n";
			}
		} else { 
			if ($output eq '') {
				print "There is no matches with your regex!\n";
			} else {
				print $outputHandler "There is no matches with your regex!\n";
			}
		}
	}
}

sub report_arcsight{
	if ($output eq '') {
		print "\n===== Arcsight Regex Format ===============\n";
	} else {
		print $outputHandler "\n===== Arcsight Regex Format ===============\n";
	}
	my $arcsightCounter = 1;
	foreach my $key (sort {$matcher{$b} <=> $matcher{$a}} keys %matcher) {
		if ($matcher{$key} > 0) {
			my $regex = $key;
			$regex =~ s/\\/\\\\/g;
			if ($output eq '') {
				print "Regex #" . $arcsightCounter . ":\n$regex\n";
			} else {
				print $outputHandler "Regex #" . $arcsightCounter . ":\n";
				print $outputHandler "$regex\n";
			}
			$arcsightCounter++;
		}
	}
}

sub sortRegexOnFile{
	# Do we want to save comments and empty lines?
	print "\nSorting regex...\t" if $verbose;
	open (my $reFile, '>:encoding(UTF-8)', $regexPath) or die "Could not open file '$regexPath'";
	foreach my $key (sort {$matcher{$b} <=> $matcher{$a}} keys %matcher) {
		print $reFile "$key\n";
	}
	print "Done\n" if $verbose;
	close($reFile);
}

sub checkFilePath{
	my ($args) = @_;

	my $checkingPath = $args->{path};		# 
	my ($checkingCustomPath) = $args->{customPath};	# 
	
	my $canBeRead = 1;
	if ($checkingPath) {
		if (!(-e "$checkingPath")) {
			print "[WARN] File $checkingPath doesn't exist. Switching to $checkingCustomPath\n";
			$canBeRead = 0;
		} elsif (!(-f "$checkingPath")) {
			print "[WARN] $checkingPath is not a file. Switching to $checkingCustomPath\n";
			$canBeRead = 0;
		} elsif (!(-r "$checkingPath")) {
		 	print "[WARN] File $checkingPath can't be read. Switching to $checkingCustomPath\n";
		 	$canBeRead = 0;
		}
	} 
	if (!($canBeRead)) {
		# Testing custom regex file path
		# If doesn't exist, it will try to use custom file or the script will die
		die "[ERR] Custom file $checkingCustomPath doesn't exist\n"  if (!(-e $checkingCustomPath));
		die "[ERR] Custom file $checkingCustomPath is not a file\n"  if (!(-f $checkingCustomPath));
		die "[ERR] Custom file $checkingCustomPath cannot be read\n" if (!(-r $checkingCustomPath));
		return $checkingCustomPath;
	}
	return $checkingPath;
}

# === Main program ===
# Parsing params
GetOptions (
	'help|h|?' => \$help,
	'v+' => \$verbose,
	'l=s' => \$logPath,
	'r=s' => \$regexPath,
	'details|d' => \$detailed,
	'i=s' => \$ignoringPath,
	't' => \$test,
	'F' => \$forceAll,
	'u:i' => \$u,
	'A' => \$arcsight,
	's' => \$sort,
	'o=s' => \$output,
	'j' => \$json
	) or help();
help() if $help; 
print $banner if (!$output);
die "Number of unmatched lines must be a non negative number" if (!($u == -1) && ($u < -1)); 
$logPath = checkFilePath({
	path => $logPath,
	customPath => $customLogPath
	});
$regexPath = checkFilePath({
	path => $regexPath,
	customPath => $customRegexPath
	});
$ignoringPath = checkFilePath({
	path => $ignoringPath,
	customPath => $customIgnoringPath
	});

# TODO: one storeFile() sub
storeRegexFile();
storeIgnoringFile({
	file => $ignoringPath,
	ignoring => \@ignoring
	}) if ($ignoringPath);
checkRegex() if $test;

print "Reading log file\t" if $verbose;
open (my $log, '<:encoding(UTF-8)', $logPath) or die "Could not open log file '$logPath'";
print "Done\n" if $verbose;
# Test all log against regex(s)
my $elems = (@re);
my ($size, $ignorePos, $ignoreHit) = (0) x3;
my ($checking, $ignoreLine) = ("") x2;
while (my $line = <$log>) {			# TIME TO RESTRUCTURE THIS GIANT LOOP INTO SUBS
	my ($match, $elem) = (0) x 2;
	chomp $line;
	# Check if line must be ignored
	$ignoreLine = "";
	if ($ignoringPath) {
		($ignorePos, $ignoreHit) = (0) x2;
		$size = @ignoring;
		while ($ignorePos < $size and !($ignoreHit)) {
			$ignoreHit++ if ($line =~ m/$ignoring[$ignorePos]/);
			$ignorePos++;
		}
	}
	if (!(length($line) eq 0) and !($ignoreHit)) {
		#print "Ignore: $ignoreHit for line $line\n";
		if ($forceAll) { # Check against all regex
			while ($elem < $elems) {
				$checking = $re[$elem];
				chomp $checking;
				if ($line =~ m/$checking/) {
					$matcher{$checking}++;
					$globalHits++ if ($match eq 0);
					$match++;
					if (!(exists $indexMatchRegister{$checking})) { # Doesn't exist yet @ index
						 $indexMatchRegister{$checking} = $currentIndex;
						 $allMatchRegister[$currentIndex][0] = $checking;
						 $allMatchRegister[$currentIndex][1] = $line;
						 $currentIndex++;
					} else {
						push @{ $allMatchRegister[$indexMatchRegister{$checking}] }, $line;
					}
					# Temporary; will be removed when all matches array is finished
					if ($detailed and ! (exists $detailedOutput{$checking})) {
						$detailedOutput{$checking} = $line; 
					}
				} 
				$elem++;
			}
		} else { # Check until a match is found
			while (! $match and ($elem < $elems)) {
				$checking = $re[$elem];
				chomp $checking;
				if ($line =~ m/$checking/) {
					$matcher{$checking}++;
					$match++;
					$globalHits++;
					if (!(exists $indexMatchRegister{$checking})) { # Doesn't exist yet @ index
						 $indexMatchRegister{$checking} = $currentIndex;
						 $allMatchRegister[$currentIndex][0] = $checking;
						 $allMatchRegister[$currentIndex][1] = $line;
						 $currentIndex++;
					} else {
						my $index = $indexMatchRegister{$checking};
						push @{ $allMatchRegister[$index] }, $line;
					}
					# Temporary; will be removed when all matches array is finished
					if ($detailed and ! (exists $detailedOutput{$checking})) {
						$detailedOutput{$checking} = $line; 
					}
				} else { $elem++; }
			}
		}
		if ($elem == $elems and $match eq 0) { push @unmatch, $line; }
	}
}
# Close log file
close($log);

# Show report
report();
sortRegexOnFile() if $sort;
writeJson() if ($json); 