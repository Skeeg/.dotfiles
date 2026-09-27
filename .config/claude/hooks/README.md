# Claude Code command-history hooks

## Purpose

Claude Code session transcripts (`~/.claude/projects/<project>/<session-id>.jsonl`)
technically contain every Bash command an agent ran, but that format is
internal, undocumented, and can change between Claude Code versions —
grepping it directly is fragile and not something the docs recommend.

These two hooks give a stable, purpose-built alternative: a flat, global,
append-only JSONL log of every Bash command any Claude Code agent (main
session or subagent) runs on this machine, independent of which project or
session it ran in. That log exists to:

- **Audit secrets usage** — confirm what actually got sent to a shell across
  every session, not just the one you're currently in.
- **Learn from agent command patterns** — see what commands/flags/idioms
  agents reach for, without depending on re-reading transcripts.

## Design

Two hooks, registered in `~/.claude/settings.json` under a `Bash` matcher:

| Hook | Event | Writes to | Adds over the pre-hook |
|---|---|---|---|
| `cmdhistory-pre.sh` | `PreToolUse` | `~/.claude_cmdhistory` | — |
| `cmdhistory-post.sh` | `PostToolUse` | `~/.claude_cmdhistory_done` | `interrupted`, `duration_ms` |

Both write one JSON object per line, `command` always first for easy
`head`/`grep` skimming of raw file content:

```json
{"command": "...", "ts": "2026-09-14T18:03:11Z", "session_id": "...", "cwd": "...", "agent": "main"}
```

`agent_id` is added when present (subagent invocations). The post-hook adds
`interrupted` (only when true) and `duration_ms` (when available).

**Design constraints, both deliberate:**

- **Observe-only.** Each script always exits `0` and prints nothing, so a
  hook bug can never block or alter a tool call. A no-op (missing/empty
  `tool_input.command`, malformed JSON) fails silently rather than
  disrupting the session.
- **Never logs output.** Only `tool_input.command` is captured — never
  `tool_response` (stdout/stderr). A command whose *arguments* embed a
  secret still lands here in full (that's the audit point), but a
  command's *output* never does, so grepping this file can't itself leak
  a secret that only appeared in output.

**Known gotcha (verified empirically 2026-09-11):** the post-hook originally
tried to record an exit code from `tool_response.exit_code`. That field does
not exist in this Claude Code version's Bash `tool_response` — only
`stdout`, `stderr`, `interrupted`, `isImage`, `noOutputExpected` do (plus a
sibling `duration_ms`). The script records what's actually there
(`interrupted`, `duration_ms`) instead of a phantom exit code. Re-check this
if a future Claude Code version changes the `tool_response` shape.

## Installation

Tracked here as the source of truth; `.profile.d/claude.plugin.sh` installs
them into `~/.claude/settings.json` automatically at shell startup (see
`_claude_bootstrap_cmdhistory_hooks` — idempotent, matches on the hook
command path so it won't double-register). No manual step needed once the
dotfiles are bootstrapped, beyond having `jq` installed.

## Use

Both log files are raw JSONL — decode `command` back to real, copy/pasteable
text. `cldhistory` (in `bin/`) wraps the common cases:

```bash
cldhistory                 # jq -r '.command' ~/.claude_cmdhistory
cldhistory --full          # jq '.'          ~/.claude_cmdhistory
cldhistory --done          # jq -r '.command' ~/.claude_cmdhistory_done
cldhistory --done --full   # jq '.'          ~/.claude_cmdhistory_done
```

For anything beyond that — filtering, custom formatting — use `jq`/`grep`
directly on the files:

```bash
jq -r '.command' ~/.claude_cmdhistory
jq -r '.command' ~/.claude_cmdhistory_done
```

Add a header per entry when scanning interactively (a decoded multi-line
command otherwise runs together visually with the next entry):

```bash
jq -r '"# \(.ts)  \(.cwd)  [\(.agent)]\n\(.command)\n"' ~/.claude_cmdhistory
```

Filter before decoding by grepping the raw file (fields are still plain
JSON text, so this is fast and version-independent):

```bash
grep '"cwd":"/Users/ryan-peay/repo/helm-charts"' ~/.claude_cmdhistory | jq -r '.command'
```

Because hooks are loaded at session start, a session's own Bash calls before
the hooks are (re-)registered won't be logged — this only affects the very
first session after a fresh install or a settings.json change.
