#!/usr/bin/env bash
# claude.plugin.sh — Claude Code configuration bootstrap
#
# Ensures ~/.claude/settings.json contains:
# - the statusLine block pointing at ~/.config/claude/statusline-command.sh
# - the cmdhistory PreToolUse/PostToolUse Bash hooks pointing at the tracked
#   scripts in ~/.config/claude/hooks/ (see that directory's README.md for
#   what they do and why)
# - attribution disabled (enforced) and outputStyle defaulted to Unslop (only
#   if unset, so a /config choice sticks)
# - baseline permission allow/deny rules (union only, never removes)
#
# Also symlinks the tracked global CLAUDE.md, output styles, and skills from
# ~/.config/claude/ into ~/.claude/ (file/leaf level only).
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

# Attribution off is a rule (Ryan owns the work), so it is re-enforced every
# shell start; outputStyle is only a default.
_claude_bootstrap_preferences() {
  local settings="$HOME/.claude/settings.json" tmp

  [[ -f "$settings" ]]      || return 0
  command -v jq &>/dev/null || return 0

  # Already in the desired state — nothing to do
  if jq -e '.attribution == {"commit": "", "pr": "", "sessionUrl": false} and has("outputStyle")' \
      "$settings" &>/dev/null; then
    return 0
  fi

  tmp=$(mktemp "${settings}.XXXXXX") || return 0
  if jq '.attribution = {"commit": "", "pr": "", "sessionUrl": false} | .outputStyle //= "Unslop"' \
      "$settings" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$settings"
  else
    rm -f "$tmp"
  fi
}

# Baseline permission rules, adapted from Dane's allow list (2026-09-27). Union
# only: entries are added if missing, never removed, so hand-added or /permissions
# rules survive. docker:* is paired with denies for the stacks that anchor the
# macvlan network (sysadmin CLAUDE.md rule 2). Deliberately NOT included: curl,
# mv, source, pkill, python (system interpreter), poetry (uv owns Python),
# Write(*)/Update(*).
_claude_bootstrap_permissions() {
  local settings="$HOME/.claude/settings.json" tmp
  local allow='["Bash(head:*)","Bash(tail:*)","Bash(rg:*)","Bash(lsof:*)","Bash(echo:*)",
    "Bash(go:*)","Bash(npm:*)","Bash(npx:*)","Bash(pnpm:*)","Bash(uv:*)","Bash(make:*)",
    "Bash(deadcode:*)","Bash(touch:*)","Bash(mkdir:*)","Bash(docker:*)","Bash(sed:*)","Bash(chmod:*)"]'
  local deny='["Bash(docker compose down:*)","Bash(docker system prune:*)"]'

  [[ -f "$settings" ]]      || return 0
  command -v jq &>/dev/null || return 0

  # Already in the desired state — nothing to do
  if jq -e --argjson a "$allow" --argjson d "$deny" \
      '(($a - (.permissions.allow // [])) | length) == 0 and (($d - (.permissions.deny // [])) | length) == 0' \
      "$settings" &>/dev/null; then
    return 0
  fi

  tmp=$(mktemp "${settings}.XXXXXX") || return 0
  if jq --argjson a "$allow" --argjson d "$deny" '
      .permissions //= {}
      | .permissions.allow = ((.permissions.allow // []) + ($a - (.permissions.allow // [])))
      | .permissions.deny  = ((.permissions.deny  // []) + ($d - (.permissions.deny  // [])))
    ' "$settings" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$settings"
  else
    rm -f "$tmp"
  fi
}

# Symlink one tracked path into ~/.claude. File- or leaf-level only — never
# ~/.claude itself (see CLAUDE.md § Directory Clobbering Risk). An existing
# non-symlink target is moved to ~/.claude/backups/ once, then replaced.
_claude_link() {
  local src="$1" dest="$2"

  [[ -e "$src" ]] || return 0
  [[ "$(readlink "$dest" 2>/dev/null)" == "$src" ]] && return 0

  if [[ -e "$dest" && ! -L "$dest" ]]; then
    mkdir -p "$HOME/.claude/backups" || return 0
    mv "$dest" "$HOME/.claude/backups/$(basename "$dest").$(date +%Y%m%d%H%M%S)" || return 0
  fi
  ln -sfn "$src" "$dest"
}

_claude_bootstrap_links() {
  local src="$HOME/.config/claude" skill

  [[ -d "$HOME/.claude" ]] || return 0

  _claude_link "$src/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  _claude_link "$src/output-styles" "$HOME/.claude/output-styles"

  mkdir -p "$HOME/.claude/skills"
  for skill in "$src"/skills/*/; do
    [[ -d "$skill" ]] || continue
    skill="${skill%/}"
    _claude_link "$skill" "$HOME/.claude/skills/$(basename "$skill")"
  done

  # Tool-managed skills in the .agents convention (e.g. `gcx agent skills
  # install`, which writes ~/.agents/skills/<name>/). Skip names already taken
  # by a tracked skill or a real directory.
  for skill in "$HOME"/.agents/skills/*/; do
    [[ -d "$skill" ]] || continue
    skill="${skill%/}"
    [[ -e "$HOME/.claude/skills/$(basename "$skill")" && ! -L "$HOME/.claude/skills/$(basename "$skill")" ]] && continue
    _claude_link "$skill" "$HOME/.claude/skills/$(basename "$skill")"
  done
}

_claude_bootstrap_statusline
_claude_bootstrap_cmdhistory_hooks
_claude_bootstrap_preferences
_claude_bootstrap_permissions
_claude_bootstrap_links
unset -f _claude_bootstrap_statusline _claude_bootstrap_cmdhistory_hooks _claude_merge_bash_hook \
  _claude_bootstrap_preferences _claude_bootstrap_permissions _claude_link _claude_bootstrap_links
