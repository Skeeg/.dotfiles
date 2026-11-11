# cmdhistory

Logs every Bash command Claude Code runs on your machine to a local JSONL file, across every project, session and subagent. The bundled `cmdhistory` skill lets Claude search that log, so you can ask "which session was I in when I worked on LTI?" and get back the directory and session ID to resume.

## Read this before installing

The log records **full command arguments**. If an agent ever passes a token, password or key on the command line, that value is written to the log in plain text. That is deliberate: the log exists partly to audit what was sent to a shell. It means:

- The files are created `0600` (owner-only). A file that already exists keeps its mode, so check with `ls -l ~/.claude_cmdhistory*`.
- The files grow forever. Nothing rotates or prunes them. One user's log reached 3.6 MB at about 5,000 commands.
- Command output (stdout and stderr) is never logged.

Install it only if you want that record on your disk.

## Install

```
/plugin install cmdhistory@dotfiles
```

Restart Claude Code afterwards. Hooks load at session start, so the session you installed from logs nothing.

## What it writes

| File | Hook | Fields |
|---|---|---|
| `~/.claude_cmdhistory` | `PreToolUse`, before the command runs | `command`, `ts`, `session_id`, `cwd`, `agent`, `agent_id` (subagents only) |
| `~/.claude_cmdhistory_done` | `PostToolUse`, after it finishes | the same, plus `duration_ms` and `interrupted` (only when true) |

One JSON object per line, `command` first:

```json
{"command":"git status","ts":"2026-09-14T18:03:11Z","session_id":"6f1c…","cwd":"/Users/you/repo/app","agent":"main"}
```

There is no exit code: Claude Code's Bash hook payload does not include one. Lines also carry `tool_use_id` when the payload has it, and that pairs a line in one file with its line in the other.

## Pairing with a PreToolUse guard

Two files, not one, because the gap between them is the audit record. The pre-hook logs every command Claude *tried* to run. The done-hook logs only the ones that *did* run.

| In `~/.claude_cmdhistory` | In `~/.claude_cmdhistory_done` | What happened |
|---|---|---|
| yes | yes | It ran |
| yes | no | It never ran: a guard hook or you denied it, or it is still running |

Pair this with a PreToolUse guard that flags secret-leak patterns, such as `echo $TOKEN`, `curl -v` with an auth header, or `printenv`. Such a guard asks before the command runs. When it catches one and you deny it:

- the command is in the pre-log, so you can see the attempt happened and which session made it;
- it is not in the done-log, so you know the secret never reached a shell.

A secret-shaped command that shows up in the done-log ran. That is the leak to act on, such as rotating the credential.

Hooks for the same event run in parallel, so the pre-hook records the command whether or not the guard then blocks it. Plain permission denials leave the same trace, guard or no guard. The skill has the query that lists every command that was stopped before it ran.

## Design

- **Observe-only.** Both scripts always exit `0` and print nothing, so a hook bug cannot block or change a tool call.
- **No output capture.** Only `tool_input.command` is read, never `tool_response.stdout` or `stderr`.
- **Requires `jq`.** Without it the hooks exit silently and nothing is logged.
- **Claude Code only.** claude.ai chat and Cowork do not run hooks.

## Using it

Ask Claude, and the skill does the querying: "find the session where I ran the helm upgrade for search-api".

Or query the files yourself:

```bash
# Every match, pretty-printed
cat ~/.claude_cmdhistory | grep lti | jq .

# Where and when, one line each
grep -i 'lti' ~/.claude_cmdhistory | jq -r '[.ts, .session_id, .cwd] | @tsv'

# Resume that session
cd '<cwd>' && claude --resume '<session_id>'
```

`skills/cmdhistory/SKILL.md` has more recipes.

## Already running these hooks from your own settings.json?

Remove your copy of the two hook entries from `~/.claude/settings.json` (or whatever script re-adds them at shell startup) before installing this plugin. Otherwise every command is logged twice. The log paths and line format are the same, so existing history stays searchable.

## Changing it

Bump `version` in `.claude-plugin/plugin.json` with every change under this directory. CI fails the merge request otherwise.
