# Matcher

matcher is a script written in Perl to test one or more regular expressions against log files and get a little report with total hits per regex, % of log matched and unmatched lines.

TL;DR instant usage: `perl matcher.pl -l <log-file-path> -re <regex-file-path>`

## Usage

This list includes all available parameters which can be used with the script. If any of then uses spaces they must be written with brackets: `"`.

```
-h, --help      Displays help message and exit
-l, --log       Set log file to be checked against regexs
-re             Set regex file where are stored all regex to test
-r              Set an unique regex to test against the file instead of use a regex file
                Cannot be set at same time -r and -re
-t              Test regex syntax. If anyone is incorrect, the script dies
-d, detailed    Print one example of every regex with a match in JSON
-o, --output    *NOT IMPLEMENTED* Classify all matched lines in files
```

Regular expressions stored on regex file must be declared one per line. Comments are supported using `#` and empty lines are ignored.

## Dependencies

* Path::Tiny

## Work in progress

- [x] ~~Help message~~
- [x] ~~Check if all regex are correct syntactically~~
- [x] ~~Better print for regex hits (using one line only)~~
- [ ] Test against multiple file logs
- [ ] Improve performance
- [ ] Get output on files option
- [x] ~~Print few unmatched lines (if they are too many)~~
- [x] ~~Print group matches (one per regex)~~
- [ ] Default regex and log files
- [x] ~~Stats with % after execution~~
- [ ] Output regex in Arcsight format using param `-A`
