package histfile

import (
	"os"
	"path/filepath"
	"sort"
	"testing"
	"time"
)

var at = time.Date(2026, 10, 26, 14, 35, 2, 0, time.Local)

const backupSuffix = ".bak.20261026_143502"

const zshSample = ": 1:0;ls\n" +
	": 2:0;vbox-start\n" +
	": 3:0;for f in a; do\\\n  vbox-start\\\ndone\n" +
	": 4:0;gti status\n"

func writeHist(t *testing.T, content string, mode os.FileMode) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), ".zsh_history")
	if err := os.WriteFile(path, []byte(content), mode); err != nil {
		t.Fatal(err)
	}
	// WriteFile's mode is filtered by umask; set it exactly.
	if err := os.Chmod(path, mode); err != nil {
		t.Fatal(err)
	}
	return path
}

func load(t *testing.T, path string) *File {
	t.Helper()
	f, err := Load(path)
	if err != nil {
		t.Fatal(err)
	}
	return f
}

func readString(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func dirNames(t *testing.T, dir string) []string {
	t.Helper()
	des, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	var names []string
	for _, de := range des {
		names = append(names, de.Name())
	}
	sort.Strings(names)
	return names
}

func TestLoadParsesEntries(t *testing.T) {
	f := load(t, writeHist(t, zshSample, 0o600))
	if f.Format != FormatZsh {
		t.Errorf("format %v, want zsh", f.Format)
	}
	if len(f.Entries) != 4 {
		t.Errorf("got %d entries, want 4", len(f.Entries))
	}
}

func TestLoadMissingFile(t *testing.T) {
	if _, err := Load(filepath.Join(t.TempDir(), "nope")); err == nil {
		t.Error("expected an error for a missing file")
	}
}

func TestRewriteRemovesSelectedEntries(t *testing.T) {
	path := writeHist(t, zshSample, 0o600)
	f := load(t, path)
	if _, err := f.Rewrite([]int{1, 2}, at); err != nil {
		t.Fatal(err)
	}
	want := ": 1:0;ls\n: 4:0;gti status\n"
	if got := readString(t, path); got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestRewriteBacksUpOriginal(t *testing.T) {
	path := writeHist(t, zshSample, 0o600)
	backup, err := load(t, path).Rewrite([]int{3}, at)
	if err != nil {
		t.Fatal(err)
	}
	if backup != path+backupSuffix {
		t.Errorf("backup path %q, want %q", backup, path+backupSuffix)
	}
	if got := readString(t, backup); got != zshSample {
		t.Errorf("backup content %q, want the original", got)
	}
	info, err := os.Stat(backup)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Errorf("backup mode %v, want 0600", info.Mode().Perm())
	}
}

func TestRewriteNothingSelectedTouchesNothing(t *testing.T) {
	path := writeHist(t, zshSample, 0o600)
	backup, err := load(t, path).Rewrite(nil, at)
	if err != nil {
		t.Fatal(err)
	}
	if backup != "" {
		t.Errorf("backup %q, want none", backup)
	}
	if got := dirNames(t, filepath.Dir(path)); len(got) != 1 {
		t.Errorf("dir holds %v, want only the history file", got)
	}
	if got := readString(t, path); got != zshSample {
		t.Errorf("file changed: %q", got)
	}
}

// No backup, no write: an existing backup name stops the rewrite before
// the original is touched.
func TestRewriteRefusesWhenBackupExists(t *testing.T) {
	path := writeHist(t, zshSample, 0o600)
	if err := os.WriteFile(path+backupSuffix, []byte("older backup"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := load(t, path).Rewrite([]int{1}, at); err == nil {
		t.Fatal("expected an error")
	}
	if got := readString(t, path); got != zshSample {
		t.Errorf("original changed: %q", got)
	}
	if got := readString(t, path+backupSuffix); got != "older backup" {
		t.Errorf("existing backup overwritten: %q", got)
	}
}

// A shell appending between Load and Rewrite must not lose its entry.
func TestRewriteRefusesWhenFileChangedSinceLoad(t *testing.T) {
	path := writeHist(t, zshSample, 0o600)
	f := load(t, path)
	appended := zshSample + ": 5:0;echo new\n"
	if err := os.WriteFile(path, []byte(appended), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := f.Rewrite([]int{1}, at); err == nil {
		t.Fatal("expected an error")
	}
	if got := readString(t, path); got != appended {
		t.Errorf("concurrent write lost: %q", got)
	}
}

func TestRewriteKeepsFileMode(t *testing.T) {
	path := writeHist(t, zshSample, 0o640)
	if _, err := load(t, path).Rewrite([]int{1}, at); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o640 {
		t.Errorf("mode %v, want 0640", info.Mode().Perm())
	}
}

func TestRewriteLeavesNoTempFiles(t *testing.T) {
	path := writeHist(t, zshSample, 0o600)
	if _, err := load(t, path).Rewrite([]int{1}, at); err != nil {
		t.Fatal(err)
	}
	want := []string{".zsh_history", ".zsh_history" + backupSuffix}
	got := dirNames(t, filepath.Dir(path))
	if len(got) != len(want) || got[0] != want[0] || got[1] != want[1] {
		t.Errorf("dir holds %v, want %v", got, want)
	}
}

// Dotfile setups often symlink history. The link must survive and the
// target must get the change.
func TestRewriteWritesThroughSymlink(t *testing.T) {
	target := writeHist(t, zshSample, 0o600)
	link := filepath.Join(t.TempDir(), ".zsh_history")
	if err := os.Symlink(target, link); err != nil {
		t.Fatal(err)
	}
	if _, err := load(t, link).Rewrite([]int{1}, at); err != nil {
		t.Fatal(err)
	}
	info, err := os.Lstat(link)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode()&os.ModeSymlink == 0 {
		t.Error("symlink replaced by a regular file")
	}
	want := ": 1:0;ls\n: 3:0;for f in a; do\\\n  vbox-start\\\ndone\n: 4:0;gti status\n"
	if got := readString(t, target); got != want {
		t.Errorf("target got %q, want %q", got, want)
	}
}
