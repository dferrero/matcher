# Matcher

matcher is a script written in Perl to test one or more regular expressions against log files and get a little report with total hits per regex, % of log matched and unmatched lines.

TL;DR instant usage: `perl matcher.pl -l <log-file-path> -r <regex-file-path>`

## Usage

This list includes all available parameters which can be used with the script. If any of then uses spaces they must be written with brackets: `"`.

```
-h, --help      Displays help message and exit
-l, --log       Set log file to be checked against regexs
-r              Set regex file where are stored all regex to test

-d, detailed    Print one example of every regex with a match in JSON
-t              Test regex syntax. If anyone is incorrect, the script dies
-u [number]     Print first N unmatched lines. If no number is specified, it will print all
-A              Print all regex in Arcsight format
-o, --output    *NOT IMPLEMENTED* Classify all matched lines in files
```

If the script is used without log or regex file, it will try to use the custom option. If no custom file has been set, it will try to use the default ones `log.txt` and `regex.txt`. If no one exist, the script will finish.

Regular expressions stored on regex file must be declared one per line. Comments are supported using `#` and empty lines are ignored.

## Work in progress

- [ ] Option (to be defined) to update regex file and rearrange regex order for better performance
- [ ] Get output on files option
- [ ] Test against multiple file logs
- [ ] Improve performance
- [x] ~~Option `-u [number]` to choose if unmatched lines are printed and how many ones~~
- [x] ~~Default regex and log files~~
- [x] ~~Rearrange output info~~
- [x] ~~Print group matches (one per regex)~~
- [x] ~~Stats with % after execution~~
- [x] ~~Help message~~
- [x] ~~Check if all regex are correct syntactically~~
- [x] ~~Better print for regex hits (using one line only)~~
- [x] ~~Output regex in Arcsight format using param `-A`~~
