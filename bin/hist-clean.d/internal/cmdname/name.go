// Package cmdname finds the command a history entry runs.
package cmdname

import (
	"regexp"
	"strings"
)

// wrappers run another command. Each maps to its flags that take a
// separate argument, so "sudo -u root gti" looks past "root" to "gti".
var wrappers = map[string]map[string]bool{
	"sudo":    {"-u": true, "-g": true, "-h": true, "-p": true, "-C": true, "-D": true, "-r": true, "-t": true, "-U": true, "-T": true},
	"env":     {"-u": true, "-C": true, "-S": true},
	"nice":    {"-n": true},
	"time":    {"-f": true, "-o": true},
	"exec":    {"-a": true},
	"nohup":   {},
	"command": {},
	"builtin": {},
}

var assignment = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*=`)

// Name returns the command name of a history entry and whether it needs
// checking against PATH and the shell's known names. check is false when
// the entry is valid by rule: a path, a word that can't be judged, or no
// command at all.
func Name(command string) (name string, check bool) {
	line, _, _ := strings.Cut(command, "\n")
	words := split(strings.TrimLeft(line, " \t("))

	i := 0
	skipAssignments := func() {
		for i < len(words) && assignment.MatchString(words[i]) {
			i++
		}
	}
	skipAssignments()

	wrapper := ""
	for i < len(words) {
		argFlags, ok := wrappers[words[i]]
		if !ok {
			break
		}
		wrapper = words[i]
		i++
		for i < len(words) && strings.HasPrefix(words[i], "-") {
			flag := words[i]
			i++
			if flag == "--" {
				break
			}
			if argFlags[flag] {
				i++
			}
		}
		skipAssignments()
	}

	if i >= len(words) {
		// A bare wrapper ("sudo", "sudo -u root") still names a command.
		return wrapper, wrapper != ""
	}

	word := words[i]
	if cut := strings.IndexAny(word, ";|&<>)"); cut >= 0 {
		word = word[:cut]
	}
	switch {
	case word == "":
		return "", false
	case strings.Contains(word, "/"):
		return "", false
	case strings.HasPrefix(word, "$"), strings.HasPrefix(word, "`"):
		return "", false
	}
	return word, true
}

// split breaks a line into shell words. Whitespace inside quotes,
// backticks or $( ) does not split, so FOO="a b" and TOKEN=$(op item get x)
// stay one word each. An unclosed quote or substitution runs to the end of
// the line.
func split(line string) []string {
	var words []string
	var word strings.Builder
	single, double, backtick := false, false, false
	depth := 0 // open $( ) levels
	for i := 0; i < len(line); i++ {
		c := line[i]
		switch {
		case single:
			single = c != '\''
		case c == '\\' && i+1 < len(line):
			word.WriteByte(c)
			i++
			c = line[i]
		case c == '\'' && !double:
			single = true
		case c == '"':
			double = !double
		case c == '`':
			backtick = !backtick
		case c == '$' && i+1 < len(line) && line[i+1] == '(':
			word.WriteByte(c)
			i++
			c = line[i]
			depth++
		case c == '(' && depth > 0:
			depth++
		case c == ')' && depth > 0:
			depth--
		case (c == ' ' || c == '\t') && !double && !backtick && depth == 0:
			if word.Len() > 0 {
				words = append(words, word.String())
				word.Reset()
			}
			continue
		}
		word.WriteByte(c)
	}
	if word.Len() > 0 {
		words = append(words, word.String())
	}
	return words
}
