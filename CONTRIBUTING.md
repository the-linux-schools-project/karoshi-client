If you have any questions on how to install or use Karoshi Client, please have
a look at our [forum][forum]. We are also usually available on [IRC][irc] - we
are in #karoshi on freenode.net.

[forum]: http://linuxschools.org.uk/forum
[irc]: http://webchat.freenode.net/?channels=karoshi

## Reporting Bugs

If you have found a bug in the software while running on the latest released
client, please report them here on GitHub. The Linux Schools Project always
appreciates any feedback, as it helps make the software better! Please search
through existing reported issues however, as your problem may have already been
fixed. More information available in the [GitHub documentation][issues-doc].

[issues-doc]: https://help.github.com/articles/searching-issues

## Contributing to the Source Code

Thanks for your interest in the project! Pull requests are always welcome.

As much as possible, try to follow [Google's shell script style guide][google-style],
with one exception: tabs should be used for all indentation purposes. A summary
of the most important points follows:

 * *Be consistent* with the rest of the script
   - Unless refactoring a script, try to keep your new code in line with the
     pre-existing code
 * Use tabs for indentation
 * Keep `if ...; then`, `while ...; do` and `for ...; do` on the same line
 * Avoid the use of `test` and `[` - please use `[[` instead
   - `test` and `[` are programs from the POSIX shell days, and are highly
     vulnerable to variable expansion
 * Always double-quote variables outside of `[[` unless specifically required
   - `[[` doesn't perform variable expansion, so it is optional to double-quote
     within them, but in any other case all variables must be double-quoted
 * When doing arithmetic, use `((` instead of `let`
 * Avoid the use of `eval` at all costs
   - Only use `eval` where absolutely necessary, and when using it put
     safeguards in place
 * Variables in use only in one script should be in lowercase
   - camelCaseNames or underscore_names are accepted
 * Variables for use in multiple scripts (sourced) should be in uppercase
 * Use Bash commands for things instead of external commands where possible
   - Don't use `sed/tr/cut` where [Bash string manipulation][bash-str] will
     suffice
   - Sometimes it is easier to use external commands however
 * When capturing output from external commands, use `$(...)`
   - Backticks (`` `...` ``) cannot be nested, and are often difficult to see

If you do have any questions about contributing, don't hesitate to ask on IRC
or on the forums!

[google-style]: http://google-styleguide.googlecode.com/svn/trunk/shell.xml
[bash-str]: http://tldp.org/LDP/abs/html/string-manipulation.html
