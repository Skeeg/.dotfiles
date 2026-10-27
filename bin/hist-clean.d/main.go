// hist-clean finds shell history entries whose command does not exist and
// deletes the ones picked in an interactive list.
package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"

	"hist-clean/internal/audit"
	"hist-clean/internal/histfile"
	"hist-clean/internal/tui"
)

const usage = "usage: hist-clean [-known FILE] HISTFILE\n"

type config struct {
	args []string
	path string // $PATH
	now  time.Time
	// commonLimit hides names with this many entries or more. Zero shows all.
	commonLimit int
	// selfDefined counts functions defined in the history file as valid.
	selfDefined    bool
	stdout, stderr io.Writer
	// pick runs the pick list and returns the final model.
	pick func(tea.Model) (tea.Model, error)
}

var reloadHint = map[histfile.Format]string{
	histfile.FormatZsh:             "fc -R",
	histfile.FormatBashTimestamped: "history -c; history -r",
	histfile.FormatBashPlain:       "history -c; history -r",
}

func run(c config) int {
	fs := flag.NewFlagSet("hist-clean", flag.ContinueOnError)
	fs.SetOutput(c.stderr)
	fs.Usage = func() { fmt.Fprint(c.stderr, usage) }
	knownFile := fs.String("known", "", "file of names the shell knows (aliases, functions, builtins, keywords), one per line")
	if err := fs.Parse(c.args); err != nil {
		return 2
	}
	if fs.NArg() != 1 {
		fmt.Fprint(c.stderr, usage)
		return 2
	}
	hist := fs.Arg(0)

	// cmdlog files are an append-only audit trail, never history to clean.
	if strings.Contains(hist, "cmdlog") {
		fmt.Fprintf(c.stderr, "hist-clean: refusing %s: cmdlog files are left alone\n", hist)
		return 1
	}

	known := map[string]bool{}
	if *knownFile != "" {
		names, err := readNames(*knownFile)
		if err != nil {
			fmt.Fprintf(c.stderr, "hist-clean: %v\n", err)
			return 1
		}
		known = names
	}

	f, err := histfile.Load(hist)
	if err != nil {
		fmt.Fprintf(c.stderr, "hist-clean: %v\n", err)
		return 1
	}
	found := audit.Find(f.Entries, known, c.path)
	if c.selfDefined {
		for name := range audit.DefinedNames(f.Entries) {
			known[name] = true
		}
		withDefined := audit.Find(f.Entries, known, c.path)
		if cleared := len(found) - len(withDefined); cleared > 0 {
			noun, pronoun := "names", "them"
			if cleared == 1 {
				noun, pronoun = "name", "it"
			}
			fmt.Fprintf(c.stdout, "%d %s defined in the history file counted as valid. Set HIST_CLEAN_SELF_DEFINED=0 to list %s.\n", cleared, noun, pronoun)
		}
		found = withDefined
	}
	groups := audit.DropCommon(found, c.commonLimit)
	if hidden := len(found) - len(groups); hidden > 0 {
		noun := "names"
		if hidden == 1 {
			noun = "name"
		}
		fmt.Fprintf(c.stdout, "%d %s hidden with %d or more entries each. Set HIST_CLEAN_COMMON=0 to show them.\n", hidden, noun, c.commonLimit)
	}
	if len(groups) == 0 {
		fmt.Fprintf(c.stdout, "No invalid commands in %s.\n", hist)
		return 0
	}

	final, err := c.pick(tui.New(hist, f.Entries, groups, histfile.BackupPath(hist, c.now)))
	if err != nil {
		fmt.Fprintf(c.stderr, "hist-clean: %v\n", err)
		return 1
	}
	m, ok := final.(tui.Model)
	if !ok || !m.Confirmed() {
		fmt.Fprintln(c.stdout, "No changes.")
		return 0
	}

	deleted := m.Deleted()
	backup, err := f.Rewrite(deleted, c.now)
	if err != nil {
		fmt.Fprintf(c.stderr, "hist-clean: %v\n", err)
		if backup != "" {
			fmt.Fprintf(c.stderr, "Backup: %s\n", backup)
		}
		return 1
	}
	fmt.Fprintf(c.stdout, "Removed %d entries from %s.\nBackup: %s\nReload open shells: %s\n",
		len(deleted), hist, backup, reloadHint[f.Format])
	return 0
}

// defaultCommonLimit is how many entries a name needs to count as a real
// tool rather than a typo.
const defaultCommonLimit = 10

// selfDefined parses HIST_CLEAN_SELF_DEFINED. It is on unless set to 0,
// false, no or off.
func selfDefined(env string) bool {
	switch strings.ToLower(strings.TrimSpace(env)) {
	case "0", "false", "no", "off":
		return false
	}
	return true
}

// commonLimit parses HIST_CLEAN_COMMON. Unset or invalid gives the default,
// and 0 turns the hiding off.
func commonLimit(env string) int {
	n, err := strconv.Atoi(env)
	if err != nil || n < 0 {
		return defaultCommonLimit
	}
	return n
}

func readNames(path string) (map[string]bool, error) {
	fh, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer fh.Close()
	names := map[string]bool{}
	sc := bufio.NewScanner(fh)
	for sc.Scan() {
		if n := strings.TrimSpace(sc.Text()); n != "" {
			names[n] = true
		}
	}
	return names, sc.Err()
}

func main() {
	os.Exit(run(config{
		args:        os.Args[1:],
		path:        os.Getenv("PATH"),
		now:         time.Now(),
		commonLimit: commonLimit(os.Getenv("HIST_CLEAN_COMMON")),
		selfDefined: selfDefined(os.Getenv("HIST_CLEAN_SELF_DEFINED")),
		stdout:      os.Stdout,
		stderr:      os.Stderr,
		pick: func(m tea.Model) (tea.Model, error) {
			return tea.NewProgram(m, tea.WithAltScreen()).Run()
		},
	}))
}
