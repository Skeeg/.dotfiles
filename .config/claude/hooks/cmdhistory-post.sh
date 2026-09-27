#!/usr/bin/env bash
# PostToolUse hook (Bash matcher) — appends every completed Bash command as
# one JSON object per line (JSONL), same as cmdhistory-pre.sh but recorded
# after the tool finishes so completion-only fields can be included. Verified
# empirically (2026-09-11) that this Claude Code version's Bash tool_response
# carries no exit-code field at all (only stdout/stderr/interrupted/isImage/
# noOutputExpected) — so this records what actually exists: whether the
# command was interrupted, and how long it took. `command` is always the
# first key. Decode a command back to raw, copy/paste-able text with:
#   jq -r '.command' ~/.claude_cmdhistory_done
# Observe-only: always exits 0 with no output, never blocks a tool call.
set -uo pipefail

LOG_FILE="$HOME/.claude_cmdhistory_done"

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"

if [ -z "$CMD" ]; then
  exit 0
fi

TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

printf '%s' "$INPUT" | jq -c --arg ts "$TS" '
  {command: .tool_input.command, ts: $ts, session_id: (.session_id // "unknown"), cwd: (.cwd // ""), agent: (.agent_type // "main")}
  + (if .agent_id then {agent_id: .agent_id} else {} end)
  + (if .tool_response.interrupted then {interrupted: .tool_response.interrupted} else {} end)
  + (if .duration_ms then {duration_ms: .duration_ms} else {} end)
' >> "$LOG_FILE"

exit 0
