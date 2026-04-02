# Starship — cross-platform, cross-shell prompt
# Replaces oh-my-zsh + Powerlevel10k with a single binary and one config file.
# Config: ~/.config/starship.toml (tracked in dotfiles)
#
# Install:
#   macOS:  brew install starship
#   Linux:  curl -sS https://starship.rs/install.sh | sh -s -- --yes
#           (not in standard apt repos; bootstrap.sh handles this)

# In SSH sessions without tmux, set the iTerm2 tab title to the hostname.
# When inside tmux (local or remote), tmux set-titles owns the tab title instead.
# Uses add-zsh-hook so this coexists with Starship's own precmd hooks.
if [[ -n "$SSH_CONNECTION" ]]; then
  if [[ -n "$ZSH_VERSION" ]]; then
    autoload -Uz add-zsh-hook
    _ssh_tab_title() { [[ -z "$TMUX" ]] && print -Pn "\e]1;%m\a" }
    add-zsh-hook precmd _ssh_tab_title
  elif [[ -n "$BASH_VERSION" ]]; then
    PROMPT_COMMAND='[[ -z "$TMUX" ]] && printf "\e]1;%s\a" "${HOSTNAME%%.*}";'"${PROMPT_COMMAND:-}"
  fi
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
