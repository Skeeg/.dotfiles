# dotfiles-sync.plugin.sh — auto-pull dotfiles on session start (at most once/hour)
# Warns if uncommitted changes or unpushed commits are present.
#
# Resolves the dotfiles repo root by following the ~/.profile.d symlink so this
# works regardless of where the repo is cloned.

_dotfiles_sync() {
  local profile_link="$HOME/.profile.d"
  local dir

  # Resolve repo root via the .profile.d symlink
  if [[ -L "$profile_link" ]]; then
    local link_target
    link_target="$(readlink "$profile_link")"
    if [[ "$link_target" = /* ]]; then
      # Absolute symlink — go up one level from .profile.d to repo root
      dir="$(dirname "$link_target")"
    else
      # Relative symlink — resolve relative to the symlink's parent directory
      dir="$(dirname "$(dirname "$profile_link")/$link_target")"
    fi
  else
    # Fallback: .profile.d is not a symlink; use $DOTFILES or the default path
    dir="${DOTFILES:-$HOME/.dotfiles}"
  fi

  # Skip if the resolved directory is not a git repo
  [[ -d "$dir/.git" ]] || return 0

  local ts_file="$dir/.dotfiles_pull_ts"

  # --- Warn about local state (fast local-only checks) ---
  local unpushed dirty

  # Commits ahead of upstream — silently skipped if no upstream is configured
  unpushed="$(git -C "$dir" log "@{u}..HEAD" --oneline 2>/dev/null)"

  # Uncommitted or untracked changes
  dirty="$(git -C "$dir" status --porcelain 2>/dev/null)"

  if [[ -n "$unpushed" ]]; then
    local count
    count="$(echo "$unpushed" | wc -l | tr -d ' ')"
    echo "[dotfiles] $count unpushed commit(s) — consider: git -C $dir push" >&2
  fi

  if [[ -n "$dirty" ]]; then
    echo "[dotfiles] uncommitted changes present — consider committing and pushing" >&2
  fi

  # --- Throttled git pull (at most once per hour) ---
  # If the timestamp file was touched within the last 60 minutes, skip the pull
  if [[ -f "$ts_file" ]] && [[ -n "$(find "$ts_file" -mmin -60 2>/dev/null)" ]]; then
    return 0
  fi

  # Touch timestamp before launching the pull so concurrent shells don't pile up
  touch "$ts_file"

  # Pull in the background — ff-only avoids auto-merges, output suppressed.
  # Run inside a subshell () so the backgrounded job is owned by the subshell,
  # not the interactive parent shell.  This prevents zsh from printing
  # "[N] PID" on start and "done" on completion.
  (git -C "$dir" pull --quiet --ff-only >/dev/null 2>&1 </dev/null &)
}

_dotfiles_sync
unset -f _dotfiles_sync
