// Package audit finds history entries whose command does not resolve.
package audit

import (
	"os"
	"path/filepath"
	"sort"

	"hist-clean/internal/cmdname"
	"hist-clean/internal/histfile"
)

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
	dirs := filepath.SplitList(path)
	valid := map[string]bool{}
	byName := map[string]*Group{}
	var groups []*Group

	for i, e := range entries {
		name, check := cmdname.Name(e.Command)
		if !check {
			continue
		}
		ok, seen := valid[name]
		if !seen {
			ok = known[name] || onPath(name, dirs)
			valid[name] = ok
		}
		if ok {
			continue
		}
		g := byName[name]
		if g == nil {
			g = &Group{Name: name}
			byName[name] = g
			groups = append(groups, g)
		}
		g.Entries = append(g.Entries, i)
	}

	sort.Slice(groups, func(a, b int) bool {
		if len(groups[a].Entries) != len(groups[b].Entries) {
			return len(groups[a].Entries) > len(groups[b].Entries)
		}
		return groups[a].Name < groups[b].Name
	})
	var out []Group
	for _, g := range groups {
		out = append(out, *g)
	}
	return out
}

// onPath reports whether name is an executable regular file in one of
// dirs. Empty entries, which a shell reads as the current directory, are
// skipped: the history may have been typed anywhere.
func onPath(name string, dirs []string) bool {
	for _, d := range dirs {
		if d == "" {
			continue
		}
		info, err := os.Stat(filepath.Join(d, name))
		if err == nil && info.Mode().IsRegular() && info.Mode().Perm()&0o111 != 0 {
			return true
		}
	}
	return false
}
