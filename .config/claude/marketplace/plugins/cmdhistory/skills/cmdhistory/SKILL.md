---
name: cmdhistory
description: "Use when the user asks which session, directory or agent ran a past command or task, wants to resume the session where they did something, or wants to audit what Bash commands Claude Code has run across projects"
---

# cmdhistory

The cmdhistory hooks in this plugin append one JSON object per Bash command to two local files. Use them to answer "where and when did I do X" across every project and session on this machine.

| File | Written | Extra fields |
|---|---|---|
| `~/.claude_cmdhistory` | Before the command runs (PreToolUse) | none |
| `~/.claude_cmdhistory_done` | After it finishes (PostToolUse) | `duration_ms`, `interrupted` (only when true) |

Every line has `command`, `ts` (UTC, ISO 8601), `session_id`, `cwd` and `agent` (`main`, or the subagent type such as `Explore`). Subagent lines also carry `agent_id`. Lines carry `tool_use_id` when Claude Code includes it in the hook payload, and it pairs a pre-log line with its done-log line exactly.

The difference between the files is the audit signal:

| Pre-log | Done-log | Meaning |
|---|---|---|
| yes | yes | The command ran |
| yes | no | It never ran: a PreToolUse guard or the user denied it, or it is still running |

If a command with a secret on argv is in the pre-log only, a guard caught it before it ran. If it is in the done-log, it ran, and the secret reached the shell.

## Handle the log as sensitive

The log holds full command arguments, so it can contain tokens and passwords that were passed on argv. Anything you print enters this conversation.

- Filter with `grep` before decoding. Never `cat` or `jq` the whole file into the transcript.
- Print `ts`, `cwd`, `session_id` and `agent` first. Print `command` only for the few lines that answer the question.
- If a matched command contains what looks like a secret, say so and do not reproduce the value.

## Find where a task ran

Search the raw JSONL with `grep`, then pretty-print the matches. For example, to find work on LTI:

```bash
cat ~/.claude_cmdhistory | grep lti | jq .
```

Show only where and when, one line per match, newest last:

```bash
grep -i 'lti' ~/.claude_cmdhistory | jq -r '[.ts, .session_id, .agent, .cwd] | @tsv'
```

Collapse to one row per session, with first and last time seen and the match count:

```bash
grep -i 'lti' ~/.claude_cmdhistory \
  | jq -s -r 'group_by(.session_id)[] | [.[0].session_id, .[0].cwd, .[0].ts, .[-1].ts, length] | @tsv'
```

Grep matches the raw JSON text, so a pattern with `"` or `\` needs JSON escaping. To match on one field only, use `jq` instead:

```bash
jq -c 'select(.command | test("helm upgrade"; "i"))' ~/.claude_cmdhistory
```

## Resume the session

`claude --resume` looks up sessions under the current directory's project, so change into the logged `cwd` first:

```bash
cd '<cwd from the log>' && claude --resume '<session_id from the log>'
```

You cannot resume a session from inside this one. Give the user the command to run.

## Audit what was stopped before it ran

List commands in the pre-log with no done-log match: newest time, session, directory, and how many times that command was stopped. Lines match on `tool_use_id` when both have it, otherwise on session plus command text.

```bash
jq -n -r --slurpfile pre ~/.claude_cmdhistory --slurpfile done ~/.claude_cmdhistory_done '
  def key: .tool_use_id // "\(.session_id) \(.command)";
  ($done | map(key) | group_by(.) | map({key: .[0], value: length}) | from_entries) as $ran
  | $pre | group_by(key)[]
  | (length - ($ran[.[0] | key] // 0)) as $missing
  | select($missing > 0)
  | [.[-1].ts, .[0].session_id, .[0].cwd, $missing] | @tsv' | sort
```

The newest row is usually this query itself, still running when it read the files. Ignore it.

To check whether a guard caught a specific leak, search both files for the same pattern. A hit in the pre-log only means it was stopped. A hit in the done-log means it ran.

```bash
for f in ~/.claude_cmdhistory ~/.claude_cmdhistory_done; do
  printf '%s\t%s\n' "$(grep -c 'op item get' "$f")" "$f"
done
```

## Other queries

Everything one session ran, with a header per entry so multi-line commands stay readable:

```bash
grep '"session_id":"<id>"' ~/.claude_cmdhistory | jq -r '"# \(.ts)  \(.cwd)  [\(.agent)]\n\(.command)\n"'
```

Everything run in one directory:

```bash
grep '"cwd":"/path/to/repo"' ~/.claude_cmdhistory | jq -r '.command'
```

Slowest commands, from the done-log:

```bash
jq -s -r 'map(select(.duration_ms)) | sort_by(-.duration_ms)[:10][] | [.duration_ms, .ts, .cwd] | @tsv' ~/.claude_cmdhistory_done
```

Commands that were interrupted:

```bash
jq -c 'select(.interrupted) | {ts, session_id, cwd}' ~/.claude_cmdhistory_done
```

## When the log is missing or empty

The hooks load at session start. A session that was already running when the plugin was installed logs nothing until it restarts. The hooks also need `jq` on `PATH`; without it they exit silently and write nothing.
