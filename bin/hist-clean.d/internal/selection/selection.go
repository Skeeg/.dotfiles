// Package selection holds the pick list's state: which lines of which
// invalid names are ticked for deletion.
package selection

import (
	"sort"

	"hist-clean/internal/audit"
)

type Mark int

const (
	Unchecked Mark = iota
	Partial
	Full
)

// Selection keeps one tick per line of each group. Name marks are derived
// from the ticks, so they can never disagree with them.
type Selection struct {
	groups []audit.Group
	ticked [][]bool
}

func New(groups []audit.Group) *Selection {
	s := &Selection{groups: groups, ticked: make([][]bool, len(groups))}
	for g := range groups {
		s.ticked[g] = make([]bool, len(groups[g].Entries))
	}
	return s
}

// Mark is the name row's state, derived from its lines.
func (s *Selection) Mark(g int) Mark {
	n := 0
	for _, t := range s.ticked[g] {
		if t {
			n++
		}
	}
	switch n {
	case 0:
		return Unchecked
	case len(s.ticked[g]):
		return Full
	}
	return Partial
}

// Toggle flips a name row: unchecked or partial goes full, full goes
// unchecked.
func (s *Selection) Toggle(g int) {
	s.setAll(g, s.Mark(g) != Full)
}

// Open prepares the line view. An unchecked name starts with every line
// ticked; otherwise the current ticks stand.
func (s *Selection) Open(g int) {
	if s.Mark(g) == Unchecked {
		s.setAll(g, true)
	}
}

func (s *Selection) setAll(g int, v bool) {
	for l := range s.ticked[g] {
		s.ticked[g][l] = v
	}
}

func (s *Selection) Line(g, l int) bool { return s.ticked[g][l] }

func (s *Selection) ToggleLine(g, l int) { s.ticked[g][l] = !s.ticked[g][l] }

// Deleted returns the entry indices of every ticked line, ascending.
func (s *Selection) Deleted() []int {
	var out []int
	for g, ticks := range s.ticked {
		for l, t := range ticks {
			if t {
				out = append(out, s.groups[g].Entries[l])
			}
		}
	}
	sort.Ints(out)
	return out
}

// Counts returns how many entries are ticked and across how many names.
func (s *Selection) Counts() (entries, names int) {
	for g := range s.ticked {
		if s.Mark(g) == Unchecked {
			continue
		}
		names++
		for _, t := range s.ticked[g] {
			if t {
				entries++
			}
		}
	}
	return entries, names
}
