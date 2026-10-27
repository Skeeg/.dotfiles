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

		// a backslash before a newline continues the line
		{"AWS_PROFILE=staging \\\naws sts get-caller-identity", "aws", true},
		{"FOO=1 \\\n  BAR=2 \\\n  gti status", "gti", true},
		{"sudo \\\n  gti", "gti", true},
		{"\\\ngti status", "gti", true},
		{"FOO=1 \\\n", "", false},
		{"\\", "", false},
		{"FOO=1 \\", "", false},

		// zsh stores a typed backslash-newline as two backslashes and a newline
		{"PINGFED_BASEURL=x \\\\\nPINGFED_USERNAME=$(op item get a \"b\" --fields label=\"Username\") \\\\\nPINGFED_PASSWORD=$(op item get a) \\\\\n  python run.py \\\\\n    --input in.json", "python", true},
		{"AWS_PROFILE=staging \\\\\naws sts get-caller-identity", "aws", true},
		{"sudo \\\\\n  gti", "gti", true},
		{"FOO=1 \\\\\n", "", false},

		// a leading backslash skips aliases and is not part of the name
		{"\\ls -la", "ls", true},
		{"sudo \\ls", "ls", true},

		// a bare bash timestamp is a stray, grouped under its own name
		{"#1716322788", StrayTimestamp, true},
		{"  #1716322788", StrayTimestamp, true},
		{"#12345", "", false},
		{"#1716322788 note", "", false},

		// comments are not commands
		{"# Function: install-teleport", "", false},
		{"#", "", false},
		{"FOO=1 # note", "", false},

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
