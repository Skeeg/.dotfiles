#!/bin/bash
# ~/.bashrc — Interactive bash configuration
# Sourced by .bash_profile (login shells) and directly by interactive non-login shells.
# Guard ensures this is a no-op for non-interactive sessions (rsync, scp, scripts, etc.).

# PATH — set before the interactive guard so scripts that source .bashrc also benefit
export PATH="$HOME/.local/bin:$PATH"

# blesh (ble.sh) — bash readline enhancement: inline autosuggestions + syntax highlighting.
# Must be sourced before other readline customizations; --noattach defers activation
# until ble-attach at the end of this file. No-op if blesh is not installed.
[[ $- == *i* ]] && [[ -f "$HOME/.local/share/blesh/ble.sh" ]] \
  && source "$HOME/.local/share/blesh/ble.sh" --noattach

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

fi

# Attach blesh after all other config is loaded (required by blesh; no-op if not installed)
[[ ${BLE_VERSION-} ]] && ble-attach

# Re-apply .inputrc after blesh attach — blesh resets readline meta settings on attach
[[ $- == *i* ]] && [[ ${BLE_VERSION-} ]] && [[ -f ~/.inputrc ]] && bind -f ~/.inputrc
