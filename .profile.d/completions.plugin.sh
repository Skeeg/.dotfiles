# Shell completion system
# Replaces oh-my-zsh's compinit setup for zsh; loads bash-completion for bash.
#
# Install:
#   macOS:  brew install bash-completion@2
#   Ubuntu: apt-get install -y bash-completion

if [[ -n "$ZSH_VERSION" ]]; then
  # Only initialize compinit if not already done (e.g., by Zim's completion module).
  # $_comps is set by compinit; its presence means the system is already up.
  if ! (( ${+_comps} )); then
    # Add Homebrew's zsh completions to fpath before compinit (macOS only)
    if [[ "$(uname)" == "Darwin" ]] && command -v brew &>/dev/null; then
      FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
    fi

    autoload -Uz compinit

    # Regenerate .zcompdump at most once per day — avoids ~200ms hit on every
    # shell open while still picking up new completions after installs.
    local _zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
    # Regenerate at most once per day. Portable find-based check replaces the
    # zsh glob qualifier (N.mh+24) which bash cannot parse even inside a
    # [[ -n "$ZSH_VERSION" ]] guard — bash parses the whole file before branching.
    if [[ ! -f "${_zcompdump}" ]] || [[ -n "$(find "${_zcompdump}" -mmin +1440 2>/dev/null)" ]]; then
      compinit
    else
      compinit -C
    fi
    unset _zcompdump
  fi

  # Completion styling
  zstyle ':completion:*' menu select                          # arrow-key menu
  zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'        # case-insensitive
  zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"    # color file completions
  zstyle ':completion:*:descriptions' format '%B%d%b'
  zstyle ':completion:*:warnings' format 'No matches for: %d'
  zstyle ':completion:*' group-name ''                       # group by category

elif [[ -n "$BASH_VERSION" ]]; then
  # Homebrew bash-completion@2 (macOS)
  if [[ -f "/opt/homebrew/etc/profile.d/bash_completion.sh" ]]; then
    source "/opt/homebrew/etc/profile.d/bash_completion.sh"
  elif [[ -f "/usr/local/etc/profile.d/bash_completion.sh" ]]; then
    source "/usr/local/etc/profile.d/bash_completion.sh"
  # System bash-completion (Ubuntu/Debian)
  elif [[ -f "/usr/share/bash-completion/bash_completion" ]]; then
    source "/usr/share/bash-completion/bash_completion"
  elif [[ -f "/etc/bash_completion" ]]; then
    source "/etc/bash_completion"
  fi
fi
