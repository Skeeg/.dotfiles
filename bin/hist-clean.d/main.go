// hist-clean finds shell history entries whose command does not exist and
// deletes the ones picked in an interactive list.
package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"

	"hist-clean/internal/audit"
	"hist-clean/internal/histfile"
	"hist-clean/internal/tui"
)

const usage = "usage: hist-clean [-known FILE] HISTFILE\n"

type config struct {
	args           []string
	path           string // $PATH
	now            time.Time
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
	groups := audit.Find(f.Entries, known, c.path)
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
		args:   os.Args[1:],
		path:   os.Getenv("PATH"),
		now:    time.Now(),
		stdout: os.Stdout,
		stderr: os.Stderr,
		pick: func(m tea.Model) (tea.Model, error) {
			return tea.NewProgram(m, tea.WithAltScreen()).Run()
		},
	}))
}
