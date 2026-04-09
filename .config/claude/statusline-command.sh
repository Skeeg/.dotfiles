#!/usr/bin/env bash
# ~/.claude/statusline-command.sh
# Claude Code status line — mirrors the Starship prompt color philosophy:
#   bold green  → user, host
#   bold blue   → directory
#   green       → git branch
#   yellow      → git status / context warning
#   no color    → model name, context %

input=$(cat)

# --- Extract fields from JSON ---
cwd=$(echo "$input"        | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input"      | jq -r '.model.display_name // empty')
used_pct=$(echo "$input"   | jq -r '.context_window.used_percentage // empty')
remaining=$(echo "$input"  | jq -r '.context_window.remaining_percentage // empty')
session=$(echo "$input"    | jq -r '.session_name // empty')

# --- Colors (ANSI, dimmed since Claude Code renders status dim by default) ---
bold_green='\033[1;32m'
bold_blue='\033[1;34m'
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
reset='\033[0m'

# --- user@host ---
user=$(whoami)
host=$(hostname -s)
printf "${bold_green}%s@%s${reset} " "$user" "$host"

# --- directory (truncate to last 4 segments, like Starship) ---
if [[ -n "$cwd" ]]; then
  # Replace $HOME with ~
  display_dir="${cwd/#$HOME/\~}"
  # Keep up to 4 path components from the right
  truncated=$(echo "$display_dir" | awk -F/ '{
    n=NF; start=n-3; if(start<1) start=1;
    result=""; sep="";
    for(i=start;i<=n;i++){result=result sep $i; sep="/"}
    if(start>1) result=".../" result
    print result
  }')
  printf "${bold_blue}%s${reset} " "$truncated"
fi

# --- git branch (skip optional lock) ---
if git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  printf "${green}git:%s${reset} " "$git_branch"
  # git status (short: staged, modified, untracked)
  git_flags=""
  git_staged=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  git_modified=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  git_untracked=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  [[ "$git_staged"    -gt 0 ]] && git_flags="${git_flags}${green}+${git_staged}${reset} "
  [[ "$git_modified"  -gt 0 ]] && git_flags="${git_flags}${yellow}~${git_modified}${reset} "
  [[ "$git_untracked" -gt 0 ]] && git_flags="${git_flags}?${git_untracked} "
  [[ -n "$git_flags" ]] && printf "%b" "$git_flags"
fi

# --- model ---
if [[ -n "$model" ]]; then
  printf "%s " "$model"
fi

# --- context window ---
if [[ -n "$remaining" ]]; then
  used_int=${used_pct%.*}
  used_int=${used_int:-0}
  if [[ "$used_int" -ge 80 ]]; then
    printf "${red}ctx:%.0f%%${reset} " "$remaining"
  elif [[ "$used_int" -ge 60 ]]; then
    printf "${yellow}ctx:%.0f%%${reset} " "$remaining"
  else
    printf "ctx:%.0f%% " "$remaining"
  fi
fi

# --- session name (if set) ---
if [[ -n "$session" ]]; then
  printf "[%s]" "$session"
fi

printf '\n'
