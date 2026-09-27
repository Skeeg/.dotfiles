#!/usr/bin/env bash
# claude.plugin.sh — Claude Code configuration bootstrap
#
# Ensures ~/.claude/settings.json contains:
# - the statusLine block pointing at ~/.config/claude/statusline-command.sh
# - the cmdhistory PreToolUse/PostToolUse Bash hooks pointing at the tracked
#   scripts in ~/.config/claude/hooks/ (see that directory's README.md for
#   what they do and why)
#
# Runs at shell startup; idempotent and silent on success.
# Skips silently if: Claude Code not installed, jq not available,
# or the relevant config is already present.

_claude_bootstrap_statusline() {
  local settings="$HOME/.claude/settings.json"
  local script="$HOME/.config/claude/statusline-command.sh"
  local tmp

  # Prerequisites
  [[ -d "$HOME/.claude" ]]         || return 0
  command -v jq &>/dev/null        || return 0
  [[ -f "$script" ]]               || return 0

  # Create settings.json if it doesn't exist yet
  if [[ ! -f "$settings" ]]; then
    printf '{}' > "$settings"
  fi

  # Already configured — nothing to do
  if jq -e '.statusLine' "$settings" &>/dev/null; then
    return 0
  fi

  # Merge in the statusLine block; write atomically via tmp file
  tmp=$(mktemp "${settings}.XXXXXX") || return 0
  if jq --arg cmd "bash $script" \
      '. + {"statusLine": {"type": "command", "command": $cmd}}' \
      "$settings" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$settings"
  else
    rm -f "$tmp"
  fi
}

_claude_merge_bash_hook() {
  local settings="$1" event="$2" script="$3" tmp

  # Already registered — nothing to do
  if jq -e --arg event "$event" --arg cmd "$script" \
      '(.hooks[$event] // [])[] | select(.matcher == "Bash") | .hooks[] | select(.command == $cmd)' \
      "$settings" &>/dev/null; then
    return 0
  fi

  # Merge in the hook, appending to an existing Bash matcher if present;
  # write atomically via tmp file
  tmp=$(mktemp "${settings}.XXXXXX") || return 0
  if jq --arg event "$event" --arg cmd "$script" '
      .hooks //= {}
      | .hooks[$event] //= []
      | (.hooks[$event] | map(.matcher == "Bash") | index(true)) as $i
      | if $i != null then
          .hooks[$event][$i].hooks += [{"type": "command", "command": $cmd, "timeout": 5}]
        else
          .hooks[$event] += [{"matcher": "Bash", "hooks": [{"type": "command", "command": $cmd, "timeout": 5}]}]
        end
    ' "$settings" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$settings"
  else
    rm -f "$tmp"
  fi
}

_claude_bootstrap_cmdhistory_hooks() {
  local settings="$HOME/.claude/settings.json"
  local pre_script="$HOME/.config/claude/hooks/cmdhistory-pre.sh"
  local post_script="$HOME/.config/claude/hooks/cmdhistory-post.sh"

  # Prerequisites
  [[ -d "$HOME/.claude" ]]  || return 0
  command -v jq &>/dev/null || return 0
  [[ -f "$pre_script" ]]    || return 0
  [[ -f "$post_script" ]]   || return 0

  # Create settings.json if it doesn't exist yet
  if [[ ! -f "$settings" ]]; then
    printf '{}' > "$settings"
  fi

  _claude_merge_bash_hook "$settings" "PreToolUse" "$pre_script"
  _claude_merge_bash_hook "$settings" "PostToolUse" "$post_script"
}

_claude_bootstrap_statusline
_claude_bootstrap_cmdhistory_hooks
unset -f _claude_bootstrap_statusline _claude_bootstrap_cmdhistory_hooks _claude_merge_bash_hook
