package audit

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"hist-clean/internal/histfile"
)

// pathDir makes a directory holding an executable file for each name, for
// use as $PATH.
func pathDir(t *testing.T, names ...string) string {
	t.Helper()
	dir := t.TempDir()
	for _, n := range names {
		if err := os.WriteFile(filepath.Join(dir, n), []byte("#!/bin/sh\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

func entries(commands ...string) []histfile.Entry {
	out := make([]histfile.Entry, len(commands))
	for i, c := range commands {
		out[i] = histfile.Entry{Raw: []byte(c + "\n"), Command: c}
	}
	return out
}

func set(names ...string) map[string]bool {
	m := map[string]bool{}
	for _, n := range names {
		m[n] = true
	}
	return m
}

func assertGroups(t *testing.T, got, want []Group) {
	t.Helper()
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got  %+v\nwant %+v", got, want)
	}
}

func TestFindFlagsNameMissingFromPathAndKnown(t *testing.T) {
	got := Find(entries("vbox-start"), set(), pathDir(t))
	assertGroups(t, got, []Group{{Name: "vbox-start", Entries: []int{0}}})
}

func TestFindAcceptsExecutableOnPath(t *testing.T) {
	got := Find(entries("start-vbox --headless"), set(), pathDir(t, "start-vbox"))
	assertGroups(t, got, nil)
}

func TestFindSearchesEveryPathDir(t *testing.T) {
	path := pathDir(t) + string(os.PathListSeparator) + pathDir(t, "start-vbox")
	got := Find(entries("start-vbox"), set(), path)
	assertGroups(t, got, nil)
}

func TestFindRejectsNonExecutableOnPath(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "notes"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	got := Find(entries("notes"), set(), dir)
	assertGroups(t, got, []Group{{Name: "notes", Entries: []int{0}}})
}

func TestFindRejectsDirectoryOnPath(t *testing.T) {
	dir := t.TempDir()
	if err := os.Mkdir(filepath.Join(dir, "sub"), 0o755); err != nil {
		t.Fatal(err)
	}
	got := Find(entries("sub"), set(), dir)
	assertGroups(t, got, []Group{{Name: "sub", Entries: []int{0}}})
}

// A shell reads an empty PATH entry as the current directory. hist-clean
// runs from anywhere, so an executable that happens to sit in its working
// directory must not make a history name look valid.
func TestFindIgnoresEmptyPathEntry(t *testing.T) {
	t.Chdir(pathDir(t, "here"))
	path := string(os.PathListSeparator) + pathDir(t)
	got := Find(entries("here"), set(), path)
	assertGroups(t, got, []Group{{Name: "here", Entries: []int{0}}})
}

// Aliases, functions, builtins and keywords from the calling shell.
func TestFindAcceptsKnownNames(t *testing.T) {
	got := Find(entries("gs", "for x in a; do echo $x; done"), set("gs", "for"), pathDir(t))
	assertGroups(t, got, nil)
}

func TestFindSkipsEntriesValidByRule(t *testing.T) {
	got := Find(entries("./run.sh", "/usr/bin/nope", "$EDITOR x", ""), set(), pathDir(t))
	assertGroups(t, got, nil)
}

func TestFindLooksPastAssignmentsAndWrappers(t *testing.T) {
	got := Find(entries("FOO=1 sudo -u root gti status"), set(), pathDir(t, "sudo"))
	assertGroups(t, got, []Group{{Name: "gti", Entries: []int{0}}})
}

func TestFindSortsByCountThenName(t *testing.T) {
	got := Find(entries("b", "a", "c", "c", "b", "c"), set(), pathDir(t))
	assertGroups(t, got, []Group{
		{Name: "c", Entries: []int{2, 3, 5}},
		{Name: "b", Entries: []int{0, 4}},
		{Name: "a", Entries: []int{1}},
	})
}

func TestFindZshFixture(t *testing.T) {
	data, err := os.ReadFile("../../testdata/zsh_history")
	if err != nil {
		t.Fatal(err)
	}
	_, es := histfile.Parse(data)
	got := Find(es, set("for", "echo"), pathDir(t, "ls", "start-vbox"))
	assertGroups(t, got, []Group{
		{Name: "vbox-start", Entries: []int{1, 2, 10}},
		{Name: "gti", Entries: []int{9}},
		{Name: "kubctl", Entries: []int{8}},
	})
}
