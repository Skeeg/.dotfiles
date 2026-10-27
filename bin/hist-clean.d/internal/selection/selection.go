// Package selection holds the pick list's state: which lines of which
// invalid names are ticked for deletion.
package selection

import "hist-clean/internal/audit"

type Mark int

const (
	Unchecked Mark = iota
	Partial
	Full
)

type Selection struct{}

func New(groups []audit.Group) *Selection { return &Selection{} }

// Mark is the name row's state, derived from its lines.
func (s *Selection) Mark(g int) Mark { return Unchecked }

// Toggle flips a name row: unchecked or partial goes full, full goes
// unchecked.
func (s *Selection) Toggle(g int) {}

// Open prepares the line view. An unchecked name starts with every line
// ticked; otherwise the current ticks stand.
func (s *Selection) Open(g int) {}

func (s *Selection) Line(g, l int) bool { return false }

func (s *Selection) ToggleLine(g, l int) {}

// Deleted returns the entry indices of every ticked line, ascending.
func (s *Selection) Deleted() []int { return nil }

// Counts returns how many entries are ticked and across how many names.
func (s *Selection) Counts() (entries, names int) { return 0, 0 }
