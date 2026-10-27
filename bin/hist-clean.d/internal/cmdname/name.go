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
	words := strings.Fields(strings.TrimLeft(line, " \t("))

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
