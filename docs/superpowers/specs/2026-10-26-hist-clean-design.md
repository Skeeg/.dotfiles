# hist-clean design

Date: 2026-10-26
Branch: `hist-clean`

## Intent

Shell history is full of commands that never existed: typos and name guesses like `vbox-start` vs `start-vbox`, where only one is real. When both sit in history, Ctrl+R and up-arrow recall hand back the wrong one. `hist-clean` finds history entries whose command does not resolve, shows them grouped by command name, and deletes exactly what Ryan selects.

It replaces the edit-a-text-file step of `bin/hist-audit` + `bin/hist-prune` with an interactive pick list, and is written in Go with tests.

## Prior art in this repo

| Script | Role | Gap |
|---|---|---|
| `bin/hist-audit` | first word of each entry, `type` check, writes names to `~/.cache/hist_cmd_review.txt` | no counts, no selection UI, skips `VAR=val cmd` entirely, cannot see interactive functions/aliases (needs `-w` whitelist) |
| `bin/hist-prune` | backup, delete every entry whose first word is in the review file | all-or-nothing per name, no per-line choice |
| `bin/hist-audit-paths`, `bin/hist-prune-paths` | entries pointing at missing absolute paths | out of scope, left as is |

## Goals

- Handle both zsh and bash history files.
- The file to clean is an explicit, required argument. No default.
- Find the command name of each entry, skipping leading `VAR=value` assignments and wrapper commands.
- Treat the entry as valid, never offered for deletion, when the command word starts with `./` or is a path.
- Flag a name as invalid when it is not on `$PATH` and not a known shell function, alias, builtin or keyword.
- Show invalid names sorted by number of entries, most first, with tri-state selection and a per-line drill-down.
- Back up the file, dated, before any modification. No backup, no write.
- Go test suite, built test-first, with synthetic zsh and bash fixtures.

## Non-goals

- `~/.bash_cmdlog` and any other cmdlog file. Never read, never written.
- Missing-path pruning (`hist-audit-paths` covers it).
- Editing or rewriting kept entries. Kept bytes are copied through unchanged.
- Retiring the old bash scripts. That is a later decision.

## Anti-goals

- Deleting an entry that was not selected.
- Changing the history file in any way without a backup on disk first.
- Corrupting the file: reordering, re-encoding, dropping timestamps, or splitting a multi-line entry.

## Input formats

The format is detected from file contents.

| Format | Entry shape |
|---|---|
| zsh extended | `: <epoch>:<duration>;<command>`. A command line ending in `\` continues on the next line, and the entry spans all of them. |
| bash with timestamps | `#<epoch>` line, then the command, which may span several lines up to the next `#<epoch>` line. Any `#<epoch>` line in the file selects this format, because a history kept from before `HISTTIMEFORMAT` was set starts with plain lines. Each of those plain lines is an entry of its own. |
| bash plain | one line per entry. |

Bytes are handled raw. zsh "metafies" non-ASCII bytes in its history file, and since kept entries are copied through byte for byte, the tool never needs to decode them.

## Finding the command name

Rules, applied to the entry's first line in order:

1. Trim leading whitespace.
2. Skip leading `NAME=value` words (`FOO=1 BAR=x vbox-start` gives `vbox-start`). Words split on whitespace outside quotes, backticks and `$( )`, so `TOKEN=$(op item get x) gti` gives `gti`. An unclosed quote or substitution runs to the end of the line, and the entry is then valid by rule.
3. Skip wrapper commands and look at what they run: `sudo`, `time`, `env`, `nohup`, `command`, `exec`, `nice`, `builtin`. Flags after a wrapper are skipped too, and `env` may be followed by more `NAME=value` words.
4. The next word is the command name.

Then:

- A command word containing `/` is a path: `./run.sh`, `../x`, `/usr/bin/foo`, `~/bin/foo`. The entry is valid.
- An entry whose command word can't be judged is valid. This covers words starting with `$` or `` ` ``, and empty entries.

## Deciding validity

A name is valid when either:

- `exec.LookPath`-style search of `$PATH` finds an executable, or
- it appears in the known-names list handed in by the shell: functions, aliases, builtins, keywords.

Aliases count as valid. The known-names list comes from the shell `hist-clean` is run in, so an alias defined there makes its name valid even with no binary behind it. The same goes for functions.

The Go binary cannot see the calling shell's functions and aliases. A shell function in `.profile.d/` collects them and passes the list in (bash: `compgen -A function -a -b -k`; zsh: `${(k)functions}`, `${(k)aliases}`, `${(k)builtins}`, `${(k)reswords}`), then calls the binary.

## The pick list

```
hist-clean ~/.zsh_history         23 invalid names, 412 entries

  [x]  vbox-start         181   vbox-start --headless win11
  [-]  kubctl              97   kubctl get pods -A
> [ ]  terrafrom           64   terrafrom plan
  [ ]  gti                 41   gti status
  ...

space toggle   enter view lines   d delete selected   q quit
```

Each name row shows the mark, the name, the entry count and a sample command line.

| Mark | Meaning | Deleted |
|---|---|---|
| `[x]` | full check | every entry for that name |
| `[-]` | partial | only the lines still ticked inside it |
| `[ ]` | unchecked | nothing |

- Space on a name row: `[ ]` or `[-]` goes to `[x]`, and `[x]` goes to `[ ]`.
- Enter on a name row opens the line view: every entry for that name, one per row. When the name is `[ ]`, every line starts ticked. Otherwise the current line ticks are kept.
- In the line view, space toggles one line, and esc returns to the name list.
- In both views, left/right (or `h`/`l`) scroll the command text 8 columns, like `less -S`. The mark, name and count columns stay put, every row shifts together, and the scroll stops once the longest line's end reaches the right edge. Rows are cut at the terminal width. Changing view resets the scroll. Ryan asked for this on 2026-10-26.
- The name mark follows its lines: all ticked is `[x]`, some ticked is `[-]`, none ticked is `[ ]`.
- `d` opens a summary: entries to delete, names involved, backup path. `y` confirms. Any other key, including enter, cancels.
- `q` quits with no changes.

## Writing

1. Nothing selected means no write and no backup.
2. Copy the file to `<file>.bak.YYYYMMDD_HHMMSS`, in the same directory, mode 0600, created exclusively. If that name exists or the copy fails, stop.
3. Write the kept entries to a temp file in the same directory, preserving the original mode.
4. Before the rename, check the original's size and mtime against what was read. If either changed, a shell wrote to it meanwhile, so stop and leave the original alone.
5. Rename the temp file over the original.
6. Print the number of entries removed, the backup path, and the reload hint: `fc -R` (zsh) or `history -c; history -r` (bash).

## Layout

| Path | Contents |
|---|---|
| `bin/hist-clean.d/` | Go module: `go.mod`, packages, `testdata/` fixtures |
| `.profile.d/hist_prune.plugin.sh` | `hist-clean` shell function: collects known names, calls the binary |

TUI: Bubble Tea. The selection state is a plain Go type with no Bubble Tea dependency, so it can be tested directly.

## Testing

- Synthetic fixtures in `testdata/`: one zsh extended file, one bash timestamped file, one bash plain file. No real history.
- Unit tests for parsing (entry boundaries, multi-line entries, raw bytes), command-name extraction, validity, grouping and sort order, the selection state machine, backup and write.
- The write tests check that a round trip with nothing deleted is byte-identical, and that the backup exists before the original changes.
- Go runs in Docker, not a host install (Ryan's call): `bin/hist-clean.d/go-docker test ./...` runs the toolchain from `golang:1.26` as the calling user.
- Every red and green step gets its own commit, so the branch history shows how the code evolved (Ryan's call).

## Calls made by Claude, not by Ryan

- Tool name `hist-clean`, and the module location `bin/hist-clean.d/`, following the `bin/k8s-toolbox.d/` precedent and avoiding a new root dir that bootstrap would symlink into `$HOME`.
- Backup name format, matching `bin/hist-prune`.
- Any command word containing `/` counts as a path, not only `./` and absolute paths.
- Words starting with `$` or a backtick count as valid.
- The wrapper list in step 3 of the command-name rules.
- The size and mtime check before the rename, guarding against zsh `sharehistory` writing mid-edit.
- Bubble Tea for the TUI.

- Any history path containing `cmdlog` is refused outright, as a guard on the cmdlog non-goal.
- In the confirmation screen, only lowercase `y` confirms.
- Control bytes in history show in caret notation (`^[`), and invalid UTF-8 shows as U+FFFD, so history text can't drive the terminal.
- The binary is never on `$PATH`. The `hist-clean` shell function builds it into `~/.cache/hist-clean-go/bin/hist-clean` on first use and whenever a non-test `.go`, `go.mod` or `go.sum` is newer. It uses the host's `go` if present, otherwise `go-docker` cross-building for the host's OS and arch.

## Left to the builder

- Colours in the TUI.

## Open risks, unchecked

- zsh may rewrite the whole history file from memory when it trims to `SAVEHIST`. If so, an open shell could put deleted entries back. The reload hint covers the common case. I have not verified zsh's trimming behaviour.
