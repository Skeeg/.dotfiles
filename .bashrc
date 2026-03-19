#!/bin/bash
# ~/.bashrc — Interactive bash configuration
# Sourced by .bash_profile (login shells) and directly by interactive non-login shells.
# Guard ensures this is a no-op for non-interactive sessions (rsync, scp, scripts, etc.).

if [[ $- == *i* ]] && [[ -z "$RSYNC_PROTECT_ARGS" ]]; then

  if [[ -d "${HOME}/.profile.d" ]]; then
    # Load cross-platform plugins (root level only)
    # -L required: .profile.d is a symlink; find won't descend without it
    for item in $(find -L "${HOME}/.profile.d" -maxdepth 1 -name "*.plugin.sh" 2>/dev/null | sort); do
      [[ -e "${item}" ]] && source "${item}"
    done

    # Load macOS-exclusive plugins (active failures on other systems)
    if [[ "$(uname)" == "Darwin" ]] && [[ -d "${HOME}/.profile.d/macos" ]]; then
      for item in $(find -L "${HOME}/.profile.d/macos" -name "*.plugin.sh" 2>/dev/null | sort); do
        [[ -e "${item}" ]] && source "${item}"
      done
    fi
  fi

  # Machine-local overrides (not tracked in git).
  # Shared with .zshrc — any zsh-specific content must be guarded with
  # [[ -n "$ZSH_VERSION" ]] to avoid bash parse errors.
  [[ -f "${HOME}/.zshrc.local" ]] && source "${HOME}/.zshrc.local"

fi
