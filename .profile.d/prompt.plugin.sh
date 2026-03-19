# Starship — cross-platform, cross-shell prompt
# Replaces oh-my-zsh + Powerlevel10k with a single binary and one config file.
# Config: ~/.config/starship.toml (tracked in dotfiles)
#
# Install:
#   macOS:  brew install starship
#   Linux:  curl -sS https://starship.rs/install.sh | sh -s -- --yes
#           (not in standard apt repos; bootstrap.sh handles this)

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
