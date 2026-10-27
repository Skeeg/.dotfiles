// Package tui is the interactive pick list for hist-clean.
package tui

import (
	tea "github.com/charmbracelet/bubbletea"

	"hist-clean/internal/audit"
	"hist-clean/internal/histfile"
)

type Model struct{}

// New builds the pick list for the invalid groups found in entries.
// backup is the path the backup will be written to, shown on the
// confirmation screen.
func New(title string, entries []histfile.Entry, groups []audit.Group, backup string) Model {
	return Model{}
}

func (m Model) Init() tea.Cmd { return nil }

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) { return m, nil }

func (m Model) View() string { return "" }

// Confirmed reports whether the user confirmed deletion with y.
func (m Model) Confirmed() bool { return false }

// Deleted returns the entry indices ticked for deletion, ascending.
func (m Model) Deleted() []int { return nil }
