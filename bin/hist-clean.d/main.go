// hist-clean finds shell history entries whose command does not exist and
// deletes the ones picked in an interactive list.
package main

import (
	"io"
	"os"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

type config struct {
	args           []string
	path           string // $PATH
	now            time.Time
	stdout, stderr io.Writer
	// pick runs the pick list and returns the final model.
	pick func(tea.Model) (tea.Model, error)
}

func run(c config) int {
	return 1
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
