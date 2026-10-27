package tui

import (
	"reflect"
	"regexp"
	"strings"
	"testing"

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
