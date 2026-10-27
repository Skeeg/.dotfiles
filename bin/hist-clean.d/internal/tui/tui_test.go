package tui

import (
	"fmt"
	"reflect"
	"regexp"
	"strings"
	"testing"
	"unicode/utf8"

	tea "github.com/charmbracelet/bubbletea"

	"hist-clean/internal/audit"
	"hist-clean/internal/histfile"
)

const backup = "/home/u/.zsh_history.bak.20261026_143502"

// vbox-start has entries 0, 2, 3; gti has entry 1.
func model() tea.Model {
	cmds := []string{"vbox-start --headless", "gti status", "vbox-start", "FOO=1 vbox-start win11"}
	entries := make([]histfile.Entry, len(cmds))
	for i, c := range cmds {
		entries[i] = histfile.Entry{Raw: []byte(c + "\n"), Command: c}
	}
	groups := []audit.Group{
		{Name: "vbox-start", Entries: []int{0, 2, 3}},
		{Name: "gti", Entries: []int{1}},
	}
	return New("~/.zsh_history", entries, groups, backup)
}

func keyMsg(k string) tea.KeyMsg {
	switch k {
	case " ":
		return tea.KeyMsg{Type: tea.KeySpace, Runes: []rune{' '}}
	case "enter":
		return tea.KeyMsg{Type: tea.KeyEnter}
	case "esc":
		return tea.KeyMsg{Type: tea.KeyEsc}
	case "up":
		return tea.KeyMsg{Type: tea.KeyUp}
	case "down":
		return tea.KeyMsg{Type: tea.KeyDown}
	case "left":
		return tea.KeyMsg{Type: tea.KeyLeft}
	case "right":
		return tea.KeyMsg{Type: tea.KeyRight}
	case "ctrl+c":
		return tea.KeyMsg{Type: tea.KeyCtrlC}
	}
	return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(k)}
}

// press sends keys in order and returns the model and the last command.
func press(m tea.Model, keys ...string) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	for _, k := range keys {
		m, cmd = m.Update(keyMsg(k))
	}
	return m, cmd
}

func quits(cmd tea.Cmd) bool {
	if cmd == nil {
		return false
	}
	_, ok := cmd().(tea.QuitMsg)
	return ok
}

var markRe = regexp.MustCompile(`\[[x\- ]\]`)

// markOf returns the checkbox on the first view line containing text.
func markOf(t *testing.T, m tea.Model, text string) string {
	t.Helper()
	for _, line := range strings.Split(m.View(), "\n") {
		if strings.Contains(line, text) {
			if mk := markRe.FindString(line); mk != "" {
				return mk
			}
		}
	}
	t.Fatalf("no row with a checkbox contains %q in view:\n%s", text, m.View())
	return ""
}

func assertMark(t *testing.T, m tea.Model, text, want string) {
	t.Helper()
	if got := markOf(t, m, text); got != want {
		t.Errorf("row %q: mark %s, want %s", text, got, want)
	}
}

func asModel(t *testing.T, m tea.Model) Model {
	t.Helper()
	mm, ok := m.(Model)
	if !ok {
		t.Fatalf("Update returned %T, want tui.Model", m)
	}
	return mm
}

func TestListShowsNamesByCount(t *testing.T) {
	view := model().View()
	vbox := strings.Index(view, "vbox-start")
	gti := strings.Index(view, "gti")
	if vbox < 0 || gti < 0 || vbox > gti {
		t.Fatalf("want vbox-start listed before gti:\n%s", view)
	}
	if !regexp.MustCompile(`vbox-start\s+3\b`).MatchString(view) {
		t.Errorf("vbox-start row lacks count 3:\n%s", view)
	}
	if !regexp.MustCompile(`gti\s+1\b`).MatchString(view) {
		t.Errorf("gti row lacks count 1:\n%s", view)
	}
	assertMark(t, model(), "gti", "[ ]")
}

func TestSpaceTogglesNameUnderCursor(t *testing.T) {
	m, _ := press(model(), " ")
	assertMark(t, m, "vbox-start", "[x]")
	assertMark(t, m, "gti", "[ ]")
	m, _ = press(m, " ")
	assertMark(t, m, "vbox-start", "[ ]")
}

func TestDownMovesCursor(t *testing.T) {
	m, _ := press(model(), "down", " ")
	assertMark(t, m, "vbox-start", "[ ]")
	assertMark(t, m, "gti", "[x]")
}

func TestVimKeysMoveCursor(t *testing.T) {
	m, _ := press(model(), "j", " ", "k", " ")
	assertMark(t, m, "vbox-start", "[x]")
	assertMark(t, m, "gti", "[x]")
}

func TestCursorStopsAtEnds(t *testing.T) {
	m, _ := press(model(), "up", " ")
	assertMark(t, m, "vbox-start", "[x]")
	m, _ = press(model(), "down", "down", "down", " ")
	assertMark(t, m, "gti", "[x]")
}

func TestEnterOpensLinesAllTicked(t *testing.T) {
	m, _ := press(model(), "enter")
	assertMark(t, m, "vbox-start --headless", "[x]")
	assertMark(t, m, "FOO=1 vbox-start win11", "[x]")
	if strings.Contains(m.View(), "gti status") {
		t.Errorf("line view shows another name's entries:\n%s", m.View())
	}
}

func TestUntickedLineMakesNamePartial(t *testing.T) {
	m, _ := press(model(), "enter", "down", " ")
	assertMark(t, m, "FOO=1 vbox-start win11", "[x]")
	m, _ = press(m, "esc")
	assertMark(t, m, "vbox-start", "[-]")
	if got := asModel(t, m).Deleted(); !reflect.DeepEqual(got, []int{0, 3}) {
		t.Errorf("Deleted() = %v, want [0 3]", got)
	}
}

func TestDeleteKeyShowsSummary(t *testing.T) {
	m, _ := press(model(), " ", "d")
	view := m.View()
	for _, want := range []string{"3 entries", "1 name", backup} {
		if !strings.Contains(view, want) {
			t.Errorf("summary lacks %q:\n%s", want, view)
		}
	}
}

func TestConfirmYesQuitsConfirmed(t *testing.T) {
	m, cmd := press(model(), " ", "d", "y")
	if !quits(cmd) {
		t.Error("y did not quit")
	}
	mm := asModel(t, m)
	if !mm.Confirmed() {
		t.Error("not confirmed")
	}
	if got := mm.Deleted(); !reflect.DeepEqual(got, []int{0, 2, 3}) {
		t.Errorf("Deleted() = %v, want [0 2 3]", got)
	}
}

func TestConfirmAnyOtherKeyCancels(t *testing.T) {
	for _, k := range []string{"n", "enter", "esc", "x"} {
		t.Run(k, func(t *testing.T) {
			m, cmd := press(model(), " ", "d", k)
			if quits(cmd) {
				t.Error("quit after cancel")
			}
			if asModel(t, m).Confirmed() {
				t.Error("confirmed")
			}
			assertMark(t, m, "vbox-start", "[x]")
		})
	}
}

func TestDeleteWithNothingSelectedStaysInList(t *testing.T) {
	m, _ := press(model(), "d")
	if strings.Contains(m.View(), backup) {
		t.Errorf("summary shown with nothing selected:\n%s", m.View())
	}
	assertMark(t, m, "vbox-start", "[ ]")
}

// tall builds n names (name-00, name-01, ...) with one entry each, and a
// last name, many, with n entries (cmd-00, cmd-01, ...).
func tall(n int) tea.Model {
	var entries []histfile.Entry
	var groups []audit.Group
	for i := 0; i < n; i++ {
		c := fmt.Sprintf("cmd-%02d", i)
		entries = append(entries, histfile.Entry{Raw: []byte(c + "\n"), Command: c})
	}
	many := audit.Group{Name: "many"}
	for i := 0; i < n; i++ {
		many.Entries = append(many.Entries, i)
	}
	groups = append(groups, many)
	for i := 0; i < n; i++ {
		c := fmt.Sprintf("name-%02d x", i)
		entries = append(entries, histfile.Entry{Raw: []byte(c + "\n"), Command: c})
		groups = append(groups, audit.Group{Name: fmt.Sprintf("name-%02d", i), Entries: []int{n + i}})
	}
	return New("h", entries, groups, backup)
}

func resize(m tea.Model, height int) tea.Model {
	m, _ = m.Update(tea.WindowSizeMsg{Width: 100, Height: height})
	return m
}

func assertFits(t *testing.T, m tea.Model, height int) {
	t.Helper()
	view := strings.TrimSuffix(m.View(), "\n")
	if n := strings.Count(view, "\n") + 1; n > height {
		t.Errorf("view is %d lines, terminal is %d:\n%s", n, height, view)
	}
	if !strings.HasPrefix(view, "hist-clean") && !strings.HasPrefix(view, "many") {
		t.Errorf("header scrolled away:\n%s", view)
	}
	if !strings.Contains(view, "space toggle") {
		t.Errorf("footer scrolled away:\n%s", view)
	}
}

func repeat(k string, n int) []string {
	out := make([]string, n)
	for i := range out {
		out[i] = k
	}
	return out
}

func TestListScrollsToCursor(t *testing.T) {
	m := resize(tall(30), 12)
	assertFits(t, m, 12)
	m, _ = press(m, repeat("down", 20)...)
	m, _ = press(m, " ")
	assertFits(t, m, 12)
	assertMark(t, m, "name-19", "[x]")
	if strings.Contains(m.View(), "name-00") {
		t.Errorf("top row still shown after scrolling down:\n%s", m.View())
	}
}

func TestListScrollsBackUp(t *testing.T) {
	m := resize(tall(30), 12)
	m, _ = press(m, repeat("down", 25)...)
	m, _ = press(m, repeat("up", 25)...)
	m, _ = press(m, " ")
	assertMark(t, m, "many", "[x]")
	assertFits(t, m, 12)
}

func TestLineViewScrollsToCursor(t *testing.T) {
	m := resize(tall(30), 12)
	m, _ = press(m, "enter")
	assertFits(t, m, 12)
	m, _ = press(m, repeat("down", 20)...)
	m, _ = press(m, " ")
	assertFits(t, m, 12)
	assertMark(t, m, "cmd-20", "[ ]")
	if strings.Contains(m.View(), "cmd-00") {
		t.Errorf("top line still shown after scrolling down:\n%s", m.View())
	}
}

// History can hold escape sequences and stray bytes. Printed raw, they
// would drive the terminal instead of showing as text.
func TestViewNeutralizesControlBytes(t *testing.T) {
	cmds := []string{"vbox-start \x1b[2J\x07 \x7f", "vbox-start \xff"}
	entries := make([]histfile.Entry, len(cmds))
	for i, c := range cmds {
		entries[i] = histfile.Entry{Raw: []byte(c + "\n"), Command: c}
	}
	m := tea.Model(New("h", entries, []audit.Group{{Name: "vbox-start", Entries: []int{0, 1}}}, backup))
	lines, _ := press(m, "enter")
	for name, view := range map[string]string{"list": m.View(), "lines": lines.View()} {
		for _, r := range strings.ReplaceAll(view, "\n", "") {
			if r < 0x20 || r == 0x7f || (r >= 0x80 && r < 0xa0) {
				t.Errorf("%s view holds control rune %U", name, r)
			}
		}
		if !utf8.ValidString(view) {
			t.Errorf("%s view is not valid UTF-8: %q", name, view)
		}
	}
	if !strings.Contains(lines.View(), `vbox-start ^[[2J^G ^?`) {
		t.Errorf("control bytes not shown in caret notation:\n%q", lines.View())
	}
	if !strings.Contains(lines.View(), "vbox-start �") {
		t.Errorf("invalid byte not shown as U+FFFD:\n%q", lines.View())
	}
}

// wide builds one name whose two entries run past a 40-column terminal,
// ending in TAIL-A and TAIL-B.
func wide() tea.Model {
	cmds := []string{
		"vbox-start " + strings.Repeat("a", 60) + " TAIL-A",
		"vbox-start " + strings.Repeat("b", 30) + " TAIL-B",
	}
	entries := make([]histfile.Entry, len(cmds))
	for i, c := range cmds {
		entries[i] = histfile.Entry{Raw: []byte(c + "\n"), Command: c}
	}
	m := tea.Model(New("h", entries, []audit.Group{{Name: "vbox-start", Entries: []int{0, 1}}}, backup))
	m, _ = m.Update(tea.WindowSizeMsg{Width: 40, Height: 20})
	return m
}

func assertFitsWidth(t *testing.T, m tea.Model, width int) {
	t.Helper()
	for _, line := range strings.Split(m.View(), "\n") {
		if n := utf8.RuneCountInString(line); n > width {
			t.Errorf("line is %d columns, terminal is %d: %q", n, width, line)
		}
	}
}

func TestRowsClipToWidth(t *testing.T) {
	m := wide()
	assertFitsWidth(t, m, 40)
	if strings.Contains(m.View(), "TAIL-A") {
		t.Errorf("long line not clipped:\n%s", m.View())
	}
	lines, _ := press(m, "enter")
	assertFitsWidth(t, lines, 40)
}

func TestRightScrollsCommandText(t *testing.T) {
	for _, keys := range [][]string{{"right"}, {"l"}} {
		t.Run(keys[0], func(t *testing.T) {
			m, _ := press(wide(), repeat(keys[0], 10)...)
			assertFitsWidth(t, m, 40)
			if !strings.Contains(m.View(), "TAIL-A") {
				t.Errorf("tail not shown after scrolling right:\n%s", m.View())
			}
			assertMark(t, m, "vbox-start", "[ ]")
		})
	}
}

func TestScrollStopsAtEnds(t *testing.T) {
	m, _ := press(wide(), repeat("right", 50)...)
	if !strings.Contains(m.View(), "TAIL-A") {
		t.Errorf("scrolled past the longest line:\n%s", m.View())
	}
	m, _ = press(m, repeat("left", 60)...)
	if !strings.Contains(m.View(), "vbox-start aa") {
		t.Errorf("left did not return to the start:\n%s", m.View())
	}
}

func TestLineViewScrolls(t *testing.T) {
	m, _ := press(wide(), "enter")
	m, _ = press(m, repeat("right", 10)...)
	assertFitsWidth(t, m, 40)
	if !strings.Contains(m.View(), "TAIL-A") {
		t.Errorf("tail not shown after scrolling right:\n%s", m.View())
	}
	for _, k := range []string{"left", "h"} {
		if m, _ = press(m, k); !strings.Contains(m.View(), "esc back") {
			t.Errorf("%s left the line view:\n%s", k, m.View())
		}
	}
	m, _ = press(m, "esc")
	if strings.Contains(m.View(), "esc back") {
		t.Errorf("esc did not return to the list:\n%s", m.View())
	}
}

func TestQuitKeysQuitUnconfirmed(t *testing.T) {
	for _, k := range []string{"q", "ctrl+c"} {
		t.Run(k, func(t *testing.T) {
			m, cmd := press(model(), " ", k)
			if !quits(cmd) {
				t.Error("did not quit")
			}
			if asModel(t, m).Confirmed() {
				t.Error("confirmed")
			}
		})
	}
}

// multi has a group of three entries, the first with four lines.
func multi(cmds ...string) tea.Model {
	if len(cmds) == 0 {
		cmds = []string{"f() {\n  echo one\n  echo two\n}", "g() {\n  echo three\n}", "third-cmd"}
	}
	entries := make([]histfile.Entry, len(cmds))
	idx := make([]int, len(cmds))
	for i, c := range cmds {
		entries[i] = histfile.Entry{Raw: []byte(c + "\n"), Command: c}
		idx[i] = i
	}
	return New("~/.zsh_history", entries, []audit.Group{{Name: "many", Entries: idx}}, backup)
}

func TestLinesOpenFullyExpanded(t *testing.T) {
	m, _ := press(multi(), "enter")
	view := m.View()
	for _, want := range []string{"echo one", "echo two", "echo three", "third-cmd"} {
		if !strings.Contains(view, want) {
			t.Errorf("line view lacks %q:\n%s", want, view)
		}
	}
	if strings.Contains(view, "(+") {
		t.Errorf("expanded rows should not show a line count:\n%s", view)
	}
}

func TestXCollapsesAndExpandsRowUnderCursor(t *testing.T) {
	m, _ := press(multi(), "enter", "x")
	view := m.View()
	if !strings.Contains(view, "(+3 lines)") || strings.Contains(view, "echo one") {
		t.Errorf("first row not collapsed:\n%s", view)
	}
	if !strings.Contains(view, "echo three") {
		t.Errorf("other rows should stay expanded:\n%s", view)
	}
	m, _ = press(m, "x")
	if !strings.Contains(m.View(), "echo one") || strings.Contains(m.View(), "(+3 lines)") {
		t.Errorf("second x did not expand the row:\n%s", m.View())
	}
}

func TestXAppliesToTheRowUnderTheCursor(t *testing.T) {
	m, _ := press(multi(), "enter", "down", "x")
	view := m.View()
	if strings.Contains(view, "echo three") || !strings.Contains(view, "(+2 lines)") {
		t.Errorf("second row not collapsed:\n%s", view)
	}
	if !strings.Contains(view, "echo one") {
		t.Errorf("first row should stay expanded:\n%s", view)
	}
}

func TestFoldingKeepsTicksUntouched(t *testing.T) {
	m, _ := press(multi(), "enter", "x")
	assertMark(t, m, "f() {", "[x]")
	m, _ = press(m, " ")
	assertMark(t, m, "f() {", "[ ]")
	m, _ = press(m, "X")
	assertMark(t, m, "f() {", "[ ]")
	assertMark(t, m, "g() {", "[x]")
}

func TestCapitalXCollapsesAllWhenAllExpanded(t *testing.T) {
	m, _ := press(multi(), "enter", "X")
	view := m.View()
	for _, gone := range []string{"echo one", "echo three"} {
		if strings.Contains(view, gone) {
			t.Errorf("%q still shown after collapsing all:\n%s", gone, view)
		}
	}
	if !strings.Contains(view, "(+3 lines)") || !strings.Contains(view, "(+2 lines)") {
		t.Errorf("collapsed rows lack their line counts:\n%s", view)
	}
	m, _ = press(m, "X")
	if !strings.Contains(m.View(), "echo one") || !strings.Contains(m.View(), "echo three") {
		t.Errorf("second X did not expand all:\n%s", m.View())
	}
}

func TestCapitalXExpandsAllWhenSomeAreCollapsed(t *testing.T) {
	m, _ := press(multi(), "enter", "x", "X")
	if !strings.Contains(m.View(), "echo one") || !strings.Contains(m.View(), "echo three") {
		t.Errorf("X did not expand every row:\n%s", m.View())
	}
}

func TestCollapsedStateResetsOnLeavingLines(t *testing.T) {
	m, _ := press(multi(), "enter", "X", "esc", "enter")
	if !strings.Contains(m.View(), "echo one") {
		t.Errorf("rows should open expanded again:\n%s", m.View())
	}
}

func TestFoldKeysDoNothingInList(t *testing.T) {
	before := multi().View()
	for _, k := range []string{"x", "X"} {
		if m, _ := press(multi(), k); m.View() != before {
			t.Errorf("%s changed the list view:\n%s", k, m.View())
		}
	}
}

func TestExpandedLinesNeutralizeControlBytes(t *testing.T) {
	m, _ := press(multi("f() {\n  \x1b[2J\x07\n  \xff\n}"), "enter")
	if strings.ContainsAny(m.View(), "\x1b\x07") || strings.Contains(m.View(), "\xff") {
		t.Errorf("raw control bytes in view: %q", m.View())
	}
	if !strings.Contains(m.View(), "^[[2J") {
		t.Errorf("escape not shown in caret notation:\n%s", m.View())
	}
}

func TestExpandedLinesClipToWidthAndScroll(t *testing.T) {
	long := "f() {\n  " + strings.Repeat("a", 60) + "TAIL-X\n}"
	m, _ := multi(long).Update(tea.WindowSizeMsg{Width: 30, Height: 20})
	m, _ = press(m, "enter")
	assertFitsWidth(t, m, 30)
	if strings.Contains(m.View(), "TAIL-X") {
		t.Errorf("long line not clipped:\n%s", m.View())
	}
	m, _ = press(m, repeat("right", 10)...)
	assertFitsWidth(t, m, 30)
	if !strings.Contains(m.View(), "TAIL-X") {
		t.Errorf("tail of an expanded line unreachable by scrolling right:\n%s", m.View())
	}
}

func TestExpandedEntryScrollsWithCursor(t *testing.T) {
	m := resize(multi(), 9)
	m, _ = press(m, "enter")
	assertFits(t, m, 9)
	m, _ = press(m, "down", "down")
	assertFits(t, m, 9)
	if !strings.Contains(m.View(), "third-cmd") {
		t.Errorf("cursor row not visible after scrolling:\n%s", m.View())
	}
	m, _ = press(m, "up", "up", "up")
	assertFits(t, m, 9)
	if !strings.Contains(m.View(), "f() {") {
		t.Errorf("first row not visible after scrolling back up:\n%s", m.View())
	}
}

func TestExpandedEntryTallerThanScreenIsCut(t *testing.T) {
	m := resize(multi("f() {\n  a\n  b\n  c\n  d\n  e\n  f\n  g\n}"), 8)
	m, _ = press(m, "enter")
	assertFits(t, m, 8)
}

func TestLineFooterMentionsFoldKeys(t *testing.T) {
	m, _ := press(multi(), "enter")
	for _, want := range []string{"x expand/collapse", "X all"} {
		if !strings.Contains(m.View(), want) {
			t.Errorf("footer lacks %q:\n%s", want, m.View())
		}
	}
}
