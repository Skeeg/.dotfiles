// Package tui is the interactive pick list for hist-clean.
package tui

import (
	"fmt"
	"strings"
	"unicode/utf8"

	tea "github.com/charmbracelet/bubbletea"

	"hist-clean/internal/audit"
	"hist-clean/internal/histfile"
	"hist-clean/internal/selection"
)

type screen int

const (
	listScreen screen = iota
	linesScreen
	confirmScreen
)

type Model struct {
	title   string
	entries []histfile.Entry
	groups  []audit.Group
	backup  string
	sel     *selection.Selection

	screen     screen
	cursor     int // name row in the list
	lineCursor int // line row in the line view of group cursor
	confirmed  bool

	height     int // terminal rows; 0 until Bubble Tea reports it
	width      int // terminal columns; 0 until Bubble Tea reports it
	offset     int // first name row shown
	lineOffset int // first line row shown
	shift      int // first column of command text shown, shared by all rows
}

// step is how many columns one left or right press scrolls.
const step = 8

// chrome is the header and footer lines around the rows of a view.
const chrome = 4

// rows is how many of n rows fit on screen.
func (m Model) rows(n int) int {
	if m.height <= 0 {
		return n
	}
	return max(1, m.height-chrome)
}

// follow moves offset just enough to keep cursor inside a window of size
// rows.
func follow(cursor, offset, rows int) int {
	switch {
	case cursor < offset:
		return cursor
	case cursor >= offset+rows:
		return cursor - rows + 1
	}
	return offset
}

func (m Model) scrolled() Model {
	m.offset = follow(m.cursor, m.offset, m.rows(len(m.groups)))
	if m.screen == linesScreen {
		n := len(m.groups[m.cursor].Entries)
		m.lineOffset = follow(m.lineCursor, m.lineOffset, m.rows(n))
	}
	return m
}

// New builds the pick list for the invalid groups found in entries.
// backup is the path the backup will be written to, shown on the
// confirmation screen.
func New(title string, entries []histfile.Entry, groups []audit.Group, backup string) Model {
	return Model{
		title:   title,
		entries: entries,
		groups:  groups,
		backup:  backup,
		sel:     selection.New(groups),
	}
}

func (m Model) Init() tea.Cmd { return nil }

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.height, m.width = msg.Height, msg.Width
		m.shift = min(m.shift, m.maxShift())
		return m.scrolled(), nil
	case tea.KeyMsg:
		k := msg.String()
		if k == "ctrl+c" {
			return m, tea.Quit
		}
		var cmd tea.Cmd
		switch {
		case m.screen == confirmScreen:
		case k == "left" || k == "h":
			m.shift = max(m.shift-step, 0)
			return m, nil
		case k == "right" || k == "l":
			m.shift = min(m.shift+step, m.maxShift())
			return m, nil
		}
		switch m.screen {
		case listScreen:
			m, cmd = m.updateList(k)
		case linesScreen:
			m, cmd = m.updateLines(k)
		default:
			m, cmd = m.updateConfirm(k)
		}
		return m.scrolled(), cmd
	}
	return m, nil
}

func (m Model) updateList(k string) (Model, tea.Cmd) {
	switch k {
	case "up", "k":
		m.cursor = max(m.cursor-1, 0)
	case "down", "j":
		m.cursor = min(m.cursor+1, len(m.groups)-1)
	case " ":
		m.sel.Toggle(m.cursor)
	case "enter":
		m.sel.Open(m.cursor)
		m.lineCursor, m.lineOffset, m.shift = 0, 0, 0
		m.screen = linesScreen
	case "d":
		if n, _ := m.sel.Counts(); n > 0 {
			m.screen = confirmScreen
		}
	case "q":
		return m, tea.Quit
	}
	return m, nil
}

func (m Model) updateLines(k string) (Model, tea.Cmd) {
	switch k {
	case "up", "k":
		m.lineCursor = max(m.lineCursor-1, 0)
	case "down", "j":
		m.lineCursor = min(m.lineCursor+1, len(m.groups[m.cursor].Entries)-1)
	case " ":
		m.sel.ToggleLine(m.cursor, m.lineCursor)
	case "esc":
		m.screen, m.shift = listScreen, 0
	case "q":
		return m, tea.Quit
	}
	return m, nil
}

func (m Model) updateConfirm(k string) (Model, tea.Cmd) {
	if k == "y" {
		m.confirmed = true
		return m, tea.Quit
	}
	m.screen = listScreen
	return m, nil
}

var marks = map[selection.Mark]string{
	selection.Unchecked: "[ ]",
	selection.Partial:   "[-]",
	selection.Full:      "[x]",
}

func tick(on bool) string {
	if on {
		return marks[selection.Full]
	}
	return marks[selection.Unchecked]
}

func pointer(on bool) string {
	if on {
		return "> "
	}
	return "  "
}

// firstLine is the entry's first command line, marked when more follow.
func firstLine(command string) string {
	line, rest, more := strings.Cut(command, "\n")
	if more {
		return fmt.Sprintf("%s  (+%d lines)", printable(line), strings.Count(rest, "\n")+1)
	}
	return printable(line)
}

// printable makes history text safe to print: control characters show in
// caret notation (ESC is ^[, DEL is ^?) and invalid UTF-8 and C1 controls
// show as U+FFFD, so nothing in history can drive the terminal.
func printable(s string) string {
	var b strings.Builder
	for _, r := range strings.ToValidUTF8(s, "�") {
		switch {
		case r < 0x20:
			b.WriteByte('^')
			b.WriteRune(r + 0x40)
		case r == 0x7f:
			b.WriteString("^?")
		case r >= 0x80 && r < 0xa0:
			b.WriteRune('�')
		default:
			b.WriteRune(r)
		}
	}
	return b.String()
}

func plural(n int, one, many string) string {
	if n == 1 {
		return fmt.Sprintf("%d %s", n, one)
	}
	return fmt.Sprintf("%d %s", n, many)
}

func (m Model) View() string {
	switch m.screen {
	case linesScreen:
		return m.fit(m.viewLines())
	case confirmScreen:
		return m.fit(m.viewConfirm())
	}
	return m.fit(m.viewList())
}

// fit cuts each line of view to the terminal width, so no line wraps.
func (m Model) fit(view string) string {
	if m.width <= 0 {
		return view
	}
	lines := strings.Split(view, "\n")
	for i, l := range lines {
		if r := []rune(l); len(r) > m.width {
			lines[i] = string(r[:m.width])
		}
	}
	return strings.Join(lines, "\n")
}

// shifted drops the first shift columns of text.
func (m Model) shifted(text string) string {
	r := []rune(text)
	return string(r[min(m.shift, len(r)):])
}

// maxShift is the shift that puts the end of the longest command text in
// the current view at the right edge.
func (m Model) maxShift() int {
	if m.width <= 0 || m.screen == confirmScreen {
		return 0
	}
	var prefix string
	var texts []string
	if m.screen == linesScreen {
		g := m.groups[m.cursor]
		prefix = m.linePrefix(0)
		for _, e := range g.Entries {
			texts = append(texts, firstLine(m.entries[e].Command))
		}
	} else {
		prefix = m.listPrefix(0, m.nameWidth())
		for _, g := range m.groups {
			texts = append(texts, firstLine(m.entries[g.Entries[0]].Command))
		}
	}
	longest := 0
	for _, t := range texts {
		longest = max(longest, utf8.RuneCountInString(t))
	}
	return max(0, longest-max(1, m.width-utf8.RuneCountInString(prefix)))
}

func (m Model) nameWidth() int {
	width := 0
	for _, g := range m.groups {
		width = max(width, len(g.Name))
	}
	return width
}

// listPrefix is the fixed part of name row i, before the command text.
func (m Model) listPrefix(i, width int) string {
	g := m.groups[i]
	return fmt.Sprintf("%s%s  %-*s  %5d   ", pointer(i == m.cursor), marks[m.sel.Mark(i)], width, printable(g.Name), len(g.Entries))
}

// linePrefix is the fixed part of line row l, before the command text.
func (m Model) linePrefix(l int) string {
	return fmt.Sprintf("%s%s  ", pointer(l == m.lineCursor), tick(m.sel.Line(m.cursor, l)))
}

func (m Model) viewList() string {
	var b strings.Builder
	total := 0
	for _, g := range m.groups {
		total += len(g.Entries)
	}
	width := m.nameWidth()
	fmt.Fprintf(&b, "hist-clean %s    %s, %s\n\n", m.title, plural(len(m.groups), "invalid name", "invalid names"), plural(total, "entry", "entries"))
	end := min(m.offset+m.rows(len(m.groups)), len(m.groups))
	for i := m.offset; i < end; i++ {
		sample := firstLine(m.entries[m.groups[i].Entries[0]].Command)
		fmt.Fprintf(&b, "%s%s\n", m.listPrefix(i, width), m.shifted(sample))
	}
	b.WriteString("\nspace toggle   enter view lines   ←→ scroll   d delete selected   q quit\n")
	return b.String()
}

func (m Model) viewLines() string {
	var b strings.Builder
	g := m.groups[m.cursor]
	fmt.Fprintf(&b, "%s: %s\n\n", g.Name, plural(len(g.Entries), "entry", "entries"))
	end := min(m.lineOffset+m.rows(len(g.Entries)), len(g.Entries))
	for l := m.lineOffset; l < end; l++ {
		e := g.Entries[l]
		fmt.Fprintf(&b, "%s%s\n", m.linePrefix(l), m.shifted(firstLine(m.entries[e].Command)))
	}
	b.WriteString("\nspace toggle line   esc back   ←→ scroll   q quit\n")
	return b.String()
}

func (m Model) viewConfirm() string {
	entries, names := m.sel.Counts()
	return fmt.Sprintf("Delete %s across %s?\nBackup first: %s\n\ny delete   any other key cancel\n",
		plural(entries, "entry", "entries"), plural(names, "name", "names"), m.backup)
}

// Confirmed reports whether the user confirmed deletion with y.
func (m Model) Confirmed() bool { return m.confirmed }

// Deleted returns the entry indices ticked for deletion, ascending.
func (m Model) Deleted() []int { return m.sel.Deleted() }
