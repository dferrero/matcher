#!/usr/bin/perl
use strict;
use warnings;
use autodie; # die if problem reading or writing a file

use Path::Tiny;
use Getopt::Long;
use Pod::Usage;
use Time::HiRes;

my $start_time = Time::HiRes::time(); #Time::HiRes::Value->now();

my $logfile = '';

my @re = ();
my $regexfile = '';
my %matcher = ();
my @unmatch = ();

# Checks for ARGV
my $check_r = 0;
my $check_rs = 0;

my $output = 0;
my $help = 0;

sub help {
	print "Show help";
}

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

# Mandatory arg checks
foreach my $arg ( @ARGV ){
	if ($arg =~ m/-{1,2}(r)$/){
		$check_r = $check_r + 1;
	} elsif ($arg =~ m/-{1,2}(re|rs)$/){
		$check_rs = $check_rs + 1;
	}
}

# Parsing params
GetOptions (
	'help|h|?' => \$help,
	'l|log=s' => \$logfile,
	'output|o' => \$output,
	"r=s" => \@re,
	're|rs=s' => \$regexfile
	) or pod2usage(2);
help() if $help; # http://perldoc.perl.org/Pod/Usage.html

die "Cannot be set re and regex file at same time." if ( $check_r and $check_rs);
die "At least one regex or a regex file must be declared." if (! $check_r and ! $check_rs);
die "Only one regex can be set with -r. If you need more than one regex, please use -re <regex file>." if ( $check_r > 1 );

# Build regex hash
if ( $check_r == 1 ){
	print "Usando una regex\n";
	print "\t@re\n";
	#TODO
} 
if ( $check_rs == 1 ){
	die "Regex file doesn't exist."  if ! ( -e $regexfile );
	die "Regex file cannot be read." if ! ( -r $regexfile );
	readRegexFile();
}
# Check log path and open it
die "Log file doesn't exist."  if ! ( -e $logfile );
die "Log file cannot be read." if ! ( -r $logfile );

open (my $log, '<:encoding(UTF-8)', $logfile) or die "Could not open log file '$logfile'";

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
			#print "MATCH\t\t$line\n";
			$matcher{$checking}++;
			$match++;
		} else {
			#print "NO MATCH\t$line\n";
			$elem++;
		}
	}
	if ( $elem == $elems ){
		push @unmatch, $line;
	}
}

# Show stats
foreach my $key (sort {$matcher{$a} <=> $matcher{$b}} keys %matcher) {
    print "$matcher{$key} hits\t\t$key\n";
}
my $unmatchsize = (@unmatch);
print "\nUnmatched lines: $unmatchsize\n";
#foreach my $unm (@unmatch){
#	print "\t$unm\n";
#}

my $end_time = Time::HiRes::time(); #Time::HiRes::Value->now();
my $run_time = $end_time - $start_time;
print "Time used: $run_time";