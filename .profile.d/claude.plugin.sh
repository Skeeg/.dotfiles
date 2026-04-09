#!/usr/bin/env bash
# claude.plugin.sh — Claude Code configuration bootstrap
#
# Ensures ~/.claude/settings.json contains the statusLine block pointing at
# ~/.config/claude/statusline-command.sh (tracked in dotfiles).
#
# Runs at shell startup; idempotent and silent on success.
# Skips silently if: Claude Code not installed, jq not available,
# or statusLine already configured.

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

_claude_bootstrap_statusline
unset -f _claude_bootstrap_statusline
