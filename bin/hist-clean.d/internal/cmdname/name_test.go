package cmdname

import "testing"

func TestName(t *testing.T) {
	tests := []struct {
		command   string
		wantName  string
		wantCheck bool
	}{
		// plain commands
		{"ls -la", "ls", true},
		{"vbox-start", "vbox-start", true},
		{"  \tvbox-start --headless", "vbox-start", true},

		// leading assignments are skipped
		{"FOO=1 vbox-start", "vbox-start", true},
		{"FOO=1 BAR=two vbox-start win11", "vbox-start", true},
		{"FOO= vbox-start", "vbox-start", true},
		{"FOO=1", "", false},

		// an assignment value is one word, quotes and substitutions included
		{`FOO="a b" gti`, "gti", true},
		{`FOO='a b' gti`, "gti", true},
		{`TOKEN=$(op item get x --fields y) gti status`, "gti", true},
		{`TOKEN=$(op item get "a b" --fields $(echo y)) gti`, "gti", true},
		{"TOKEN=`op item get x` gti", "gti", true},
		{`TOKEN=$(op item get x`, "", false},

		// wrappers are looked through, with their flags
		{"sudo gti status", "gti", true},
		{"sudo -E kubctl get pods", "kubctl", true},
		{"sudo -u root gti status", "gti", true},
		{"sudo -uroot gti", "gti", true},
		{"sudo -- gti", "gti", true},
		{"env -i FOO=1 gti", "gti", true},
		{"env -u HOME gti", "gti", true},
		{"time gti", "gti", true},
		{"nohup gti &", "gti", true},
		{"nice -n 10 gti", "gti", true},
		{"command gti", "gti", true},
		{"exec gti", "gti", true},
		{"builtin gti", "gti", true},
		{"FOO=1 sudo -u root env BAR=2 time gti", "gti", true},
		{"sudo", "sudo", true},
		{"sudo -u root", "sudo", true},

		// a word containing / is a path and is valid
		{"./run.sh --flag", "", false},
		{"../run.sh", "", false},
		{"/usr/bin/env true", "", false},
		{"~/bin/foo", "", false},
		{"bin/foo", "", false},
		{"sudo ./run.sh", "", false},
		{"FOO=1 /opt/x/bin/y", "", false},

		// words that can't be judged are valid
		{"$EDITOR notes.txt", "", false},
		{"${EDITOR} notes.txt", "", false},
		{"`which vim` notes.txt", "", false},
		{"", "", false},
		{"   ", "", false},

		// operators end the command word
		{"gti;ls", "gti", true},
		{"gti|less", "gti", true},
		{"gti&&ls", "gti", true},
		{"gti>out.txt", "gti", true},
		{"(cd /tmp && make)", "cd", true},

		// only the first line of a multi-line entry counts
		{"for f in a b; do\\\n  echo $f\\\ndone", "for", true},
		{"vbox-start\nls", "vbox-start", true},
	}
	for _, tt := range tests {
		t.Run(tt.command, func(t *testing.T) {
			name, check := Name(tt.command)
			if name != tt.wantName || check != tt.wantCheck {
				t.Errorf("Name(%q) = (%q, %v), want (%q, %v)", tt.command, name, check, tt.wantName, tt.wantCheck)
			}
		})
	}
}
