package histfile

import (
	"bytes"
	"os"
	"testing"
)

func readFixture(t *testing.T, name string) []byte {
	t.Helper()
	data, err := os.ReadFile("../../testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func commands(entries []Entry) []string {
	out := make([]string, len(entries))
	for i, e := range entries {
		out[i] = e.Command
	}
	return out
}

func assertCommands(t *testing.T, got []Entry, want []string) {
	t.Helper()
	gotCmds := commands(got)
	if len(gotCmds) != len(want) {
		t.Fatalf("got %d entries, want %d\ngot:  %q\nwant: %q", len(gotCmds), len(want), gotCmds, want)
	}
	for i := range want {
		if gotCmds[i] != want[i] {
			t.Errorf("entry %d: got %q, want %q", i, gotCmds[i], want[i])
		}
	}
}

func TestDetectFormat(t *testing.T) {
	tests := []struct {
		fixture string
		want    Format
	}{
		{"zsh_history", FormatZsh},
		{"bash_history_timestamped", FormatBashTimestamped},
		{"bash_history_plain", FormatBashPlain},
		{"bash_history_mixed", FormatBashTimestamped},
	}
	for _, tt := range tests {
		t.Run(tt.fixture, func(t *testing.T) {
			got, _ := Parse(readFixture(t, tt.fixture))
			if got != tt.want {
				t.Errorf("got format %v, want %v", got, tt.want)
			}
		})
	}
}

func TestParseZshEntries(t *testing.T) {
	_, entries := Parse(readFixture(t, "zsh_history"))
	assertCommands(t, entries, []string{
		"ls -la",
		"vbox-start --headless win11",
		"FOO=1 BAR=two vbox-start",
		"start-vbox",
		"for f in a b; do\\\n  echo $f\\\ndone",
		"./run.sh --flag",
		"/usr/bin/env true",
		"echo café",
		"kubctl get pods -A",
		"sudo -u root gti status",
		"vbox-start",
	})
}

func TestParseBashTimestampedEntries(t *testing.T) {
	_, entries := Parse(readFixture(t, "bash_history_timestamped"))
	assertCommands(t, entries, []string{
		"ls -la",
		"vbox-start --headless win11",
		"for f in a b; do\n  echo $f\ndone",
		"FOO=1 vbox-start",
		"./run.sh",
		"kubctl get pods -A",
	})
}

// A bash history kept from before HISTTIMEFORMAT was set starts with plain
// lines. The timestamp lines after them still belong to the next command.
func TestParseBashMixedEntries(t *testing.T) {
	_, entries := Parse(readFixture(t, "bash_history_mixed"))
	assertCommands(t, entries, []string{
		"cat ~/bin/start-claude",
		"gti status",
		"ls -la",
		"for f in a b; do\n  echo $f\ndone",
		"kubctl get pods -A",
	})
}

func TestParseBashPlainEntries(t *testing.T) {
	_, entries := Parse(readFixture(t, "bash_history_plain"))
	assertCommands(t, entries, []string{
		"ls -la",
		"vbox-start",
		"kubctl get pods",
		"./run.sh",
	})
}

// Kept entries are written back from Raw, so the Raw slices must cover the
// file exactly: no byte lost, duplicated or re-encoded.
func TestParseRawRoundTrip(t *testing.T) {
	for _, name := range []string{"zsh_history", "bash_history_timestamped", "bash_history_mixed", "bash_history_plain"} {
		t.Run(name, func(t *testing.T) {
			data := readFixture(t, name)
			_, entries := Parse(data)
			var joined []byte
			for _, e := range entries {
				joined = append(joined, e.Raw...)
			}
			if !bytes.Equal(joined, data) {
				t.Errorf("joined Raw differs from file\ngot:  %q\nwant: %q", joined, data)
			}
		})
	}
}

func TestParseRawIncludesTimestampLine(t *testing.T) {
	_, entries := Parse(readFixture(t, "bash_history_timestamped"))
	if len(entries) < 4 {
		t.Fatalf("got %d entries, want at least 4", len(entries))
	}
	want := "#1729500030\nFOO=1 vbox-start\n"
	if got := string(entries[3].Raw); got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestParseMissingTrailingNewline(t *testing.T) {
	data := []byte(": 1:0;ls\n: 2:0;vbox-start")
	_, entries := Parse(data)
	assertCommands(t, entries, []string{"ls", "vbox-start"})
	if got := string(entries[1].Raw); got != ": 2:0;vbox-start" {
		t.Errorf("last Raw: got %q", got)
	}
}

// zsh writes each byte >= 0x83 as 0x83 then the byte XOR 0x20. A meta byte
// with nothing after it is kept as is.
func TestParseZshUnmetafiesCommand(t *testing.T) {
	_, entries := Parse([]byte(": 1:0;echo caf\x83\xe3\x83\x89\n: 2:0;echo x\x83"))
	assertCommands(t, entries, []string{"echo café", "echo x\x83"})
	if got := string(entries[0].Raw); got != ": 1:0;echo caf\x83\xe3\x83\x89\n" {
		t.Errorf("Raw changed: %q", got)
	}
}

// Metafication is zsh-only; bash files hold bytes as typed.
func TestParseBashKeepsBytes(t *testing.T) {
	_, entries := Parse([]byte("echo caf\x83\xe3\n"))
	assertCommands(t, entries, []string{"echo caf\x83\xe3"})
}

func TestParseEmpty(t *testing.T) {
	_, entries := Parse(nil)
	if len(entries) != 0 {
		t.Errorf("got %d entries from empty input", len(entries))
	}
}
