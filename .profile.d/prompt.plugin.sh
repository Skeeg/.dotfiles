# Starship — cross-platform, cross-shell prompt
# Replaces oh-my-zsh + Powerlevel10k with a single binary and one config file.
# Config: ~/.config/starship.toml (tracked in dotfiles)
#
# Install:
#   macOS:  brew install starship
#   Linux:  curl -sS https://starship.rs/install.sh | sh -s -- --yes
#           (not in standard apt repos; bootstrap.sh handles this)

# Set the iTerm2 tab title on every prompt.
# Inside tmux (local or remote), tmux set-titles owns the title — skip.
# Outside tmux, always set to the short hostname so the title self-heals
# after ssh, tmux, or any other context change.
# Applies the same *-MAC normalization used in .tmux.conf set-titles-string.
_set_tab_title() {
  [[ -n "$TMUX" ]] && return
  local host dir
  if [[ -n "$ZSH_VERSION" ]]; then
    host=${(%):-%m}
    dir=${PWD:t}
  else
    host=${HOSTNAME%%.*}
    dir=${PWD##*/}
  fi
  host=${host/*-MAC/MAC}
  printf "\e]1;%s: %s\a" "$host" "$dir"
}

if [[ -n "$ZSH_VERSION" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _set_tab_title
elif [[ -n "$BASH_VERSION" ]]; then
  PROMPT_COMMAND="_set_tab_title;${PROMPT_COMMAND:-}"
fi

if command -v starship &>/dev/null; then
  if [[ -n "$ZSH_VERSION" ]]; then
    eval "$(starship init zsh)"
  elif [[ -n "$BASH_VERSION" ]]; then
    # Note: starship init bash prepends to PROMPT_COMMAND safely —
    # it uses the same ${PROMPT_COMMAND:+; $PROMPT_COMMAND} pattern
    # so the history -a entry set in history.plugin.zsh is preserved.
    eval "$(starship init bash)"
  fi
fi
