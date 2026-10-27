// Package cmdname finds the command a history entry runs.
package cmdname

// Name returns the command name of a history entry and whether it needs
// checking against PATH and the shell's known names. check is false when
// the entry is valid by rule: a path, a word that can't be judged, or no
// command at all.
func Name(command string) (name string, check bool) {
	return "", false
}
