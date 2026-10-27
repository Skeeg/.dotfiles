// Package histfile splits zsh and bash history files into entries without
// re-encoding them, so kept entries can be written back byte for byte.
package histfile

import (
	"bytes"
	"regexp"
	"strings"
)

type Format int

const (
	FormatBashPlain Format = iota
	FormatBashTimestamped
	FormatZsh
)

// Entry is one history entry. Raw holds its exact bytes in the file,
// including the zsh prefix or bash timestamp line and the trailing newline.
// Command is the command text with that prefix removed.
type Entry struct {
	Raw     []byte
	Command string
}

var (
	zshPrefix     = regexp.MustCompile(`^: [0-9]+:[0-9]+;`)
	bashTimestamp = regexp.MustCompile(`^#[0-9]+$`)
)

func Parse(data []byte) (Format, []Entry) {
	lines := splitLines(data)
	format := detect(lines)
	switch format {
	case FormatZsh:
		return format, parseZsh(lines)
	case FormatBashTimestamped:
		return format, parseBashTimestamped(lines)
	}
	return format, parsePlain(lines)
}

// splitLines splits after each newline, keeping it. A final line without a
// newline is kept as is.
func splitLines(data []byte) [][]byte {
	var lines [][]byte
	for len(data) > 0 {
		i := bytes.IndexByte(data, '\n')
		if i < 0 {
			lines = append(lines, data)
			break
		}
		lines = append(lines, data[:i+1])
		data = data[i+1:]
	}
	return lines
}

func trimNewline(b []byte) []byte {
	return bytes.TrimSuffix(b, []byte("\n"))
}

// detect reads zsh from the first non-blank line. Bash is timestamped when
// any line is a timestamp, since a history kept from before HISTTIMEFORMAT
// was set starts with plain lines.
func detect(lines [][]byte) Format {
	for _, l := range lines {
		l = trimNewline(l)
		if len(bytes.TrimSpace(l)) == 0 {
			continue
		}
		if zshPrefix.Match(l) {
			return FormatZsh
		}
		break
	}
	for _, l := range lines {
		if bashTimestamp.Match(trimNewline(l)) {
			return FormatBashTimestamped
		}
	}
	return FormatBashPlain
}

// entryFrom joins lines into one entry whose Command is the joined text
// minus skip leading bytes and the final newline.
func entryFrom(lines [][]byte, skip int) Entry {
	raw := bytes.Join(lines, nil)
	return Entry{Raw: raw, Command: string(trimNewline(raw[skip:]))}
}

// parseZsh starts an entry at each ": <epoch>:<duration>;" line. A line
// ending in a backslash continues the entry onto the next line.
func parseZsh(lines [][]byte) []Entry {
	var entries []Entry
	for i := 0; i < len(lines); {
		start := i
		for i < len(lines) && bytes.HasSuffix(trimNewline(lines[i]), []byte(`\`)) {
			i++
		}
		if i < len(lines) {
			i++
		}
		skip := len(zshPrefix.Find(lines[start]))
		e := entryFrom(lines[start:i], skip)
		e.Command = unmetafy(e.Command)
		entries = append(entries, e)
	}
	return entries
}

// zshMeta marks a metafied byte in a zsh history file: the next byte is
// the real one XOR 0x20.
const zshMeta = 0x83

func unmetafy(s string) string {
	if strings.IndexByte(s, zshMeta) < 0 {
		return s
	}
	b := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		if s[i] == zshMeta && i+1 < len(s) {
			i++
			b = append(b, s[i]^0x20)
			continue
		}
		b = append(b, s[i])
	}
	return string(b)
}

// parseBashTimestamped starts an entry at each "#<epoch>" line and runs
// until the next one. Lines before the first timestamp are entries of
// their own.
func parseBashTimestamped(lines [][]byte) []Entry {
	var entries []Entry
	for i := 0; i < len(lines); {
		start := i
		if !bashTimestamp.Match(trimNewline(lines[i])) {
			entries = append(entries, entryFrom(lines[i:i+1], 0))
			i++
			continue
		}
		i++
		for i < len(lines) && !bashTimestamp.Match(trimNewline(lines[i])) {
			i++
		}
		entries = append(entries, entryFrom(lines[start:i], len(lines[start])))
	}
	return entries
}

func parsePlain(lines [][]byte) []Entry {
	entries := make([]Entry, 0, len(lines))
	for _, l := range lines {
		entries = append(entries, entryFrom([][]byte{l}, 0))
	}
	return entries
}
