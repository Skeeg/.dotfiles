#!/usr/bin/env bash
# ~/.claude/statusline-command.sh
# Claude Code status line, two lines.
#
# Line 1 mirrors the Starship prompt color philosophy:
#   bold green  → user, host
#   bold blue   → directory
#   green       → git branch
#   yellow      → git status
#
# Line 2 is a segmented usage bar separated by ›:
#   model › effort › ctx N% › cache N% Nm left › read Nk write Nk › $cost
#   ctx and cache go green, yellow, red as they cross thresholds

input=$(cat)

# --- Extract fields from JSON ---
cwd=$(echo "$input"        | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input"      | jq -r '.model.display_name // empty')
effort=$(echo "$input"     | jq -r '.effort.level // .effort // empty' 2>/dev/null)
used_pct=$(echo "$input"   | jq -r '.context_window.used_percentage // empty')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // empty')
cache_write=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // empty')
hit_ratio=$(echo "$input"  | jq -r '.prompt_cache.hit_ratio // empty')
cache_expires=$(echo "$input" | jq -r '.prompt_cache.expires_at // empty')
cost=$(echo "$input"       | jq -r '.cost.total_cost_usd // empty')
five_hr=$(echo "$input"    | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day=$(echo "$input"  | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_hr_reset=$(echo "$input"   | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
session=$(echo "$input"    | jq -r '.session_name // empty')

# --- Colors ---
bold_green='\033[1;32m'
bold_blue='\033[1;34m'
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
dim='\033[2m'
reset='\033[0m'

# Print a token count as 27k, 1.2M, or the raw number under 1000.
fmt_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000)      printf "%.1fM", n / 1000000
    else if (n >= 1000)    printf "%.0fk", n / 1000
    else                   printf "%d", n
  }'
}

# Print 3d4h, 1h12m or 20m until a Unix timestamp.
# Prints nothing if the timestamp is empty or already past.
fmt_reset() {
  [[ -z "$1" ]] && return
  local remain=$(( $1 - $(date +%s) ))
  [[ "$remain" -le 0 ]] && return
  local mins=$(( (remain + 59) / 60 ))
  local d=$(( mins / 1440 )) h=$(( mins % 1440 / 60 )) m=$(( mins % 60 ))
  if   [[ "$d" -gt 0 ]]; then printf '%dd%dh' "$d" "$h"
  elif [[ "$h" -gt 0 ]]; then printf '%dh%dm' "$h" "$m"
  else                        printf '%dm' "$m"
  fi
}

# Pick a color for a percentage where higher is worse.
pct_color_high_bad() {
  if   [[ "$1" -ge 70 ]]; then printf '%s' "$red"
  elif [[ "$1" -ge 50 ]]; then printf '%s' "$yellow"
  else                         printf '%s' "$green"
  fi
}

sep="${dim} › ${reset}"

# ---------------------------------------------------------------- line 1
user=$(whoami)
host=$(hostname -s)
printf "${bold_green}%s@%s${reset} " "$user" "$host"

if [[ -n "$cwd" ]]; then
  display_dir="${cwd/#$HOME/\~}"
  truncated=$(echo "$display_dir" | awk -F/ '{
    n=NF; start=n-3; if(start<1) start=1;
    result=""; sep="";
    for(i=start;i<=n;i++){result=result sep $i; sep="/"}
    if(start>1) result=".../" result
    print result
  }')
  printf "${bold_blue}%s${reset} " "$truncated"
fi

if git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  printf "${green}git:%s${reset} " "$git_branch"
  git_flags=""
  git_staged=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  git_modified=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
  git_untracked=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  [[ "$git_staged"    -gt 0 ]] && git_flags="${git_flags}${green}+${git_staged}${reset} "
  [[ "$git_modified"  -gt 0 ]] && git_flags="${git_flags}${yellow}~${git_modified}${reset} "
  [[ "$git_untracked" -gt 0 ]] && git_flags="${git_flags}?${git_untracked} "
  [[ -n "$git_flags" ]] && printf "%b" "$git_flags"
fi

[[ -n "$session" ]] && printf "[%s]" "$session"
printf '\n'

# ---------------------------------------------------------------- line 2
segments=()

[[ -n "$model" ]]  && segments+=("$model")
[[ -n "$effort" ]] && segments+=("${dim}${effort}${reset}")

# --- context window (percent used) ---
if [[ -n "$used_pct" ]]; then
  used_int=${used_pct%.*}
  used_int=${used_int:-0}
  c=$(pct_color_high_bad "$used_int")
  segments+=("${c}ctx ${used_int}%${reset}")
fi

# --- prompt cache: hit rate and time left (needs Claude Code 2.1.251+) ---
if [[ -n "$hit_ratio" ]]; then
  hit=$(awk -v r="$hit_ratio" 'BEGIN { printf "%.0f", r * 100 }')
  # Higher hit rate is better, so invert the threshold colors.
  if   [[ "$hit" -ge 40 ]]; then cc=$green
  elif [[ "$hit" -ge 15 ]]; then cc=$yellow
  else                           cc=$red
  fi
  # Renders as: Cache Hit/Expires: 96%/60m
  left=""
  if [[ -n "$cache_expires" ]]; then
    left=$(fmt_reset "$cache_expires")
    left=${left:-expired}
  fi
  segments+=("Cache Hit/Expires: ${cc}${hit}%${left:+/$left}${reset}")
fi

# --- cache read / write tokens ---
if [[ -n "$cache_read" || -n "$cache_write" ]]; then
  segments+=("${dim}read $(fmt_tokens "${cache_read:-0}") write $(fmt_tokens "${cache_write:-0}")${reset}")
fi

# --- session cost ---
if [[ -n "$cost" ]]; then
  segments+=("${yellow}$(printf '$%.2f' "$cost")${reset}")
fi

# --- subscription rate limits (Pro/Max only, absent on enterprise or API key) ---
# Renders as: 5h|7d RateLimits Consumed/Reset: 2%/4h35m|15%/3d18h
rl_labels=""
rl_values=""
if [[ -n "$five_hr" ]]; then
  p=$(printf '%.0f' "$five_hr")
  r=$(fmt_reset "$five_hr_reset")
  rl_labels="5h"
  rl_values="$(pct_color_high_bad "$p")${p}%${r:+/$r}${reset}"
fi
if [[ -n "$seven_day" ]]; then
  p=$(printf '%.0f' "$seven_day")
  r=$(fmt_reset "$seven_day_reset")
  rl_labels="${rl_labels:+$rl_labels|}7d"
  rl_values="${rl_values:+$rl_values|}$(pct_color_high_bad "$p")${p}%${r:+/$r}${reset}"
fi
[[ -n "$rl_labels" ]] && segments+=("${rl_labels} RateLimits Consumed/Reset: ${rl_values}")

# Join with the separator.
out=""
for s in "${segments[@]}"; do
  [[ -n "$out" ]] && out="${out}${sep}"
  out="${out}${s}"
done
[[ -n "$out" ]] && printf '%b\n' "$out"
