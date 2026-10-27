package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

var at = time.Date(2026, 10, 26, 14, 35, 2, 0, time.Local)

const zshSample = ": 1:0;ls\n" +
	": 2:0;vbox-start\n" +
	": 3:0;gti status\n" +
	": 4:0;FOO=1 vbox-start win11\n"

// keys returns a pick function that feeds key presses to the real model,
// standing in for the terminal.
func keys(ks ...string) func(tea.Model) (tea.Model, error) {
	return func(m tea.Model) (tea.Model, error) {
		for _, k := range ks {
			var msg tea.KeyMsg
			switch k {
			case " ":
				msg = tea.KeyMsg{Type: tea.KeySpace, Runes: []rune{' '}}
			case "down":
				msg = tea.KeyMsg{Type: tea.KeyDown}
			default:
				msg = tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(k)}
			}
			m, _ = m.Update(msg)
		}
		return m, nil
	}
}

func notCalled(t *testing.T) func(tea.Model) (tea.Model, error) {
	return func(m tea.Model) (tea.Model, error) {
		t.Error("pick list shown")
		return m, nil
	}
}

type result struct {
	code           int
	stdout, stderr string
}

func setup(t *testing.T, name, content string) (dir, hist, pathDir string) {
	t.Helper()
	dir = t.TempDir()
	hist = filepath.Join(dir, name)
	if err := os.WriteFile(hist, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	pathDir = filepath.Join(dir, "bin")
	if err := os.Mkdir(pathDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(pathDir, "ls"), nil, 0o755); err != nil {
		t.Fatal(err)
	}
	return dir, hist, pathDir
}

func runWith(args []string, path string, pick func(tea.Model) (tea.Model, error)) result {
	var out, errOut bytes.Buffer
	code := run(config{args: args, path: path, now: at, stdout: &out, stderr: &errOut, pick: pick})
	return result{code, out.String(), errOut.String()}
}

func readString(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func assertNoBackup(t *testing.T, hist string) {
	t.Helper()
	matches, _ := filepath.Glob(hist + ".bak.*")
	if len(matches) != 0 {
		t.Errorf("backup written: %v", matches)
	}
}

func TestRunRequiresHistoryFile(t *testing.T) {
	r := runWith(nil, "", notCalled(t))
	if r.code != 2 {
		t.Errorf("exit %d, want 2", r.code)
	}
	if !strings.Contains(r.stderr, "usage:") {
		t.Errorf("stderr lacks usage: %q", r.stderr)
	}
}

func TestRunRefusesCmdlog(t *testing.T) {
	_, hist, pathDir := setup(t, ".bash_cmdlog", "vbox-start\n")
	r := runWith([]string{hist}, pathDir, notCalled(t))
	if r.code == 0 {
		t.Error("exit 0 on a cmdlog file")
	}
	if !strings.Contains(r.stderr, "cmdlog") {
		t.Errorf("stderr does not say why: %q", r.stderr)
	}
	if got := readString(t, hist); got != "vbox-start\n" {
		t.Errorf("cmdlog changed: %q", got)
	}
	assertNoBackup(t, hist)
}

func TestRunMissingFile(t *testing.T) {
	dir := t.TempDir()
	r := runWith([]string{filepath.Join(dir, "nope")}, dir, notCalled(t))
	if r.code != 1 || r.stderr == "" {
		t.Errorf("exit %d stderr %q, want 1 and an error", r.code, r.stderr)
	}
}

func TestRunNothingInvalid(t *testing.T) {
	_, hist, pathDir := setup(t, ".zsh_history", ": 1:0;ls\n")
	r := runWith([]string{hist}, pathDir, notCalled(t))
	if r.code != 0 {
		t.Errorf("exit %d, want 0", r.code)
	}
	if !strings.Contains(r.stdout, "No invalid commands") {
		t.Errorf("stdout %q", r.stdout)
	}
	assertNoBackup(t, hist)
}

func TestRunKnownNamesAreValid(t *testing.T) {
	dir, hist, pathDir := setup(t, ".zsh_history", zshSample)
	known := filepath.Join(dir, "known")
	if err := os.WriteFile(known, []byte("gti\nvbox-start\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	r := runWith([]string{"-known", known, hist}, pathDir, notCalled(t))
	if r.code != 0 || !strings.Contains(r.stdout, "No invalid commands") {
		t.Errorf("exit %d stdout %q", r.code, r.stdout)
	}
}

func TestRunConfirmedDeleteRewritesFile(t *testing.T) {
	_, hist, pathDir := setup(t, ".zsh_history", zshSample)
	// vbox-start (2 entries) sorts first; tick it and confirm.
	r := runWith([]string{hist}, pathDir, keys(" ", "d", "y"))
	if r.code != 0 {
		t.Fatalf("exit %d, stderr %q", r.code, r.stderr)
	}
	if got, want := readString(t, hist), ": 1:0;ls\n: 3:0;gti status\n"; got != want {
		t.Errorf("history %q, want %q", got, want)
	}
	backup := hist + ".bak.20261026_143502"
	if got := readString(t, backup); got != zshSample {
		t.Errorf("backup %q", got)
	}
	for _, want := range []string{"Removed 2 entries", backup, "fc -R"} {
		if !strings.Contains(r.stdout, want) {
			t.Errorf("stdout lacks %q: %q", want, r.stdout)
		}
	}
}

func TestRunBashReloadHint(t *testing.T) {
	_, hist, pathDir := setup(t, ".bash_history", "ls\nvbox-start\n")
	r := runWith([]string{hist}, pathDir, keys(" ", "d", "y"))
	if !strings.Contains(r.stdout, "history -c; history -r") {
		t.Errorf("stdout lacks bash reload hint: %q", r.stdout)
	}
}

func TestRunQuitWithoutConfirmChangesNothing(t *testing.T) {
	_, hist, pathDir := setup(t, ".zsh_history", zshSample)
	r := runWith([]string{hist}, pathDir, keys(" ", "q"))
	if r.code != 0 {
		t.Errorf("exit %d", r.code)
	}
	if !strings.Contains(r.stdout, "No changes") {
		t.Errorf("stdout %q", r.stdout)
	}
	if got := readString(t, hist); got != zshSample {
		t.Errorf("history changed: %q", got)
	}
	assertNoBackup(t, hist)
}

func TestCommonLimitFromEnv(t *testing.T) {
	tests := []struct {
		env  string
		want int
	}{
		{"", 10},
		{"25", 25},
		{"0", 0},
		{"-3", 10},
		{"many", 10},
	}
	for _, tt := range tests {
		if got := commonLimit(tt.env); got != tt.want {
			t.Errorf("commonLimit(%q) = %d, want %d", tt.env, got, tt.want)
		}
	}
}

func TestCommonNamesAreHiddenAndReported(t *testing.T) {
	_, hist, pathDir := setup(t, "zsh_history", ": 1:0;vbox-start\n: 2:0;vbox-start a\n: 3:0;ls\n")
	var out, errOut bytes.Buffer
	code := run(config{args: []string{hist}, path: pathDir, now: at, commonLimit: 2, stdout: &out, stderr: &errOut, pick: notCalled(t)})
	if code != 0 {
		t.Fatalf("code %d, stderr %q", code, errOut.String())
	}
	if !strings.Contains(out.String(), "1 name hidden") || !strings.Contains(out.String(), "HIST_CLEAN_COMMON") {
		t.Errorf("stdout %q does not report the hidden name and the variable", out.String())
	}
}

func TestSelfDefinedFromEnv(t *testing.T) {
	tests := map[string]bool{"": true, "1": true, "yes": true, "junk": true, "0": false, "false": false, "off": false, "no": false}
	for env, want := range tests {
		if got := selfDefined(env); got != want {
			t.Errorf("selfDefined(%q) = %v, want %v", env, got, want)
		}
	}
}

const selfDefinedSample = ": 1:0;gen_key() { echo k; }\n: 2:0;gen_key\n: 3:0;gen_keys\n"

func TestFunctionsDefinedInHistoryCountAsValid(t *testing.T) {
	_, hist, pathDir := setup(t, "zsh_history", selfDefinedSample)
	var out, errOut bytes.Buffer
	code := run(config{args: []string{hist}, path: pathDir, now: at, selfDefined: true, stdout: &out, stderr: &errOut, pick: keys("q")})
	if code != 0 {
		t.Fatalf("code %d, stderr %q", code, errOut.String())
	}
	if !strings.Contains(out.String(), "1 name defined in the history file") || !strings.Contains(out.String(), "HIST_CLEAN_SELF_DEFINED") {
		t.Errorf("stdout %q does not report the cleared name and the variable", out.String())
	}
}

func TestSelfDefinedOffListsDefinedNames(t *testing.T) {
	_, hist, pathDir := setup(t, "zsh_history", selfDefinedSample)
	var out, errOut bytes.Buffer
	var shown string
	pick := func(m tea.Model) (tea.Model, error) { shown = m.View(); return m, nil }
	code := run(config{args: []string{hist}, path: pathDir, now: at, selfDefined: false, stdout: &out, stderr: &errOut, pick: pick})
	if code != 0 {
		t.Fatalf("code %d, stderr %q", code, errOut.String())
	}
	if !strings.Contains(shown, "gen_key ") || strings.Contains(out.String(), "defined in the history file") {
		t.Errorf("want gen_key listed and no note.\nview:\n%s\nstdout: %q", shown, out.String())
	}
}
