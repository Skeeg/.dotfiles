// Package audit finds history entries whose command does not resolve.
package audit

import "hist-clean/internal/histfile"

// Group is one invalid command name and the indices of its entries, in
// file order.
type Group struct {
	Name    string
	Entries []int
}

// Find returns the invalid names in entries, most entries first. A name is
// valid when it is in known or is an executable file in a directory of
// path, a $PATH-style list.
func Find(entries []histfile.Entry, known map[string]bool, path string) []Group {
	return nil
}
