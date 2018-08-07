# Matcher

matcher is a script written in Perl to test one or more regular expressions against log files and get a little report with total hits per regex, % of log matched and unmatched lines.

TL;DR instant usage: `perl matcher.pl -l <log-file-path> -r <regex-file-path>`

## Usage

This list includes all available parameters which can be used with the script. If any of then uses spaces, they must be written with brackets: `"`.

```
Classical:
-h, --help      Displays help message and exit
-v              Verbose output

Mandatory:
-l, --log       Set log file to be checked against regexs
-r              Set regex file where are stored all regex to test

Optional:
-d, detailed    Print one example of every regex with a match
-i              Set regex file where matched lines from log will be ignored
-t              Test regex syntax. If anyone is incorrect, the script dies
-F              Test log against all regex, even if a match is found
-u [number]     Print first N unmatched lines. If no number is specified, it will print all
-D              Print all regex with double slash
-s              Sort all regex by number of hits. All comments and empty lines will be removed
-o <filename>   Get output redirected to a file instead of screen
-j              Get all hits on JSON format
                If this option is combined with -o, it will create a separate .json file
```

If the script is used without log or regex file, it will try to use the custom option. If any custom option also doesn't exist, the script will finish.

Log lines are checked against regex in the order in which they appear in the regex file until a match is found (or every regex is tested without success). To force a check against all regex, use `-F` (WIP). Empty lines on log file will be ignored.

Optional param `-i` can be used to use a second regex file. Every log line matched by one of those regex will be ignored.

After the script execution finish, maybe the suer will need to run it again (i.e. to get a 100% match of all the log). To improve execution time, is recommended to add `-s` to sort RE of regex file from most matched to less one, improving the execution time.

Regular expressions stored on regex files must be declared one per line (multiline is not supported yet). Comments are available using `#`. Empty lines are ignored.

## Dependencies

`cpan install Path::Tiny JSON`

## Work In Progress
- [ ] Change JSON matches doc to 'group-by' option
- [ ] Check against multiple log files (via wildcar?) (1)

## Priority
- [ ] Interactive mode
- [ ] Test files

## Other ideas
- [ ] (1) Classify output by source log file
- [ ] Option `-C` to get only group matches. Formats: differents files/specific delimiter (using secondary option) e.g. -C -delimiter ':' -> dave:login
- [ ] Custom names for capture groups
- [ ] Test against multiple file logs
- [ ] Improve performance (remove duplicated code)
- [ ] "Intelligent" print mode of regex results
