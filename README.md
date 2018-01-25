# Matcher

matcher is a script written in Perl to test one or more regular expressions against log files and get a little report with total hits per regex, % of log matched and unmatched lines.

TL;DR instant usage: `perl matcher.pl -l <log-file-path> -r <regex-file-path>`

## Usage

This list includes all available parameters which can be used with the script. If any of then uses spaces they must be written with brackets: `"`.

```
-h, --help      Displays help message and exit
-v              Verbose output
-l, --log       Set log file to be checked against regexs
-r              Set regex file where are stored all regex to test

-d, detailed    Print one example of every regex with a match
-t              Test regex syntax. If anyone is incorrect, the script dies
-F              Test log against all regex, even if a match is found
-u [number]     Print first N unmatched lines. If no number is specified, it will print all
-A              Print all regex in Arcsight format
-s              Sort all regex. All comments and empty lines will be removed
-o <filename>   Get output redirected to a file instead of screen
-j              Get all hits on JSON format
```

If the script is used without log or regex file, it will try to use the custom option. If no custom file has been set, it will try to use the default ones `log.txt` and `regex.txt`. If no one exist, the script will finish.

Log lines are checked against regex in the order in which they appear in the regex file until a match is found (or every regex is tested without success). To force a check with all regex, use `-F` (WIP). Empty lines on log file will be ignored.

After the script finish, new executions may be needed (i.e. to get a 100% match of all the log). To improve execution time, is recommended to add `-s` to rearrange RE of regex file from most matched to less one.

Regular expressions stored on regex file must be declared one per line. Comments are supported using `#`. Empty lines are ignored.

## Dependencies

`cpan install Path::Tiny JSON` (add `Win32::Console` for Windows)

## Work In Progress
- [x] ~~Option `-s` to update regex file and rearrange regex order for better performance~~
- [x] ~~Option `-F` to force to test all log lines against all regex~~
- [ ] Secondary regex file to ignore (`-i`) lines who matches
- [ ] Check against multiple log files (via wildcar?) (1)

## Ideas
- [ ] (1) Classify output by source log file
- [ ] Get output redirected to a file instead of screen
- [ ] Option `-C` to get only group matches. Formats: differents files/specific delimiter (using secondary option)
- [ ] Test against multiple file logs
- [ ] Daemon mode (monitoring one or more files to get unmatches and/or reports)
- [ ] Improve performance
- [ ] "Intelligent" print mode of regex results
- [ ] Get output of all matches to JSON and CSV. Groups # should be changed to custom names for both formats.