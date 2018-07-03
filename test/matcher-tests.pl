use strict;
use warnings;
use IPC::System::Simple qw(system capture);

# Run a command, wait until it finishes, and make sure it works.
# Output from this program goes directly to STDOUT, and it can take input
# from your STDIN if required.
system($^X, "yourscript.pl", @ARGS);

# Run a command, wait until it finishes, and make sure it works.
# The output of this command is captured into $results.
my $results = capture($^X, "yourscript.pl", @ARGS);

#https://stackoverflow.com/questions/364842/how-do-i-run-a-perl-script-from-within-a-perl-script