#!/usr/bin/env bash
# PreToolUse hook (Bash matcher) — appends every attempted Bash command as one
# JSON object per line (JSONL) to a global history file, across every project
# and subagent on this machine. `command` is always the first key. Decode a
# command back to raw, copy/paste-able text with:
#   jq -r '.command' ~/.claude_cmdhistory
# Observe-only: always exits 0 with no output, never blocks a tool call.
set -uo pipefail

# The log holds full command arguments, including any secret passed on argv.
# Create it owner-only (0600). umask does not change an existing file's mode.
umask 077

LOG_FILE="$HOME/.claude_cmdhistory"

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"

if [ -z "$CMD" ]; then
  exit 0
fi

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

printf '%s' "$INPUT" | jq -c --arg ts "$TS" '
  {command: .tool_input.command, ts: $ts, session_id: (.session_id // "unknown"), cwd: (.cwd // ""), agent: (.agent_type // "main")}
  + (if .agent_id then {agent_id: .agent_id} else {} end)
  + (if .tool_use_id then {tool_use_id: .tool_use_id} else {} end)
' >> "$LOG_FILE" 2>/dev/null

exit 0
