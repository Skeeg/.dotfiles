#!/usr/bin/env bash
# mise.plugin.sh — interpreter management (Node, Go, Python) via mise
#
# Division of labor:
#   mise -> interpreters (~/.config/mise/config.toml; honors .nvmrc / .python-version)
#   uv   -> Python project venvs (.venv, auto-sourced via mise's uv_venv_auto)
#
# Replaces nvm, pyenv, and asdf. Skips silently if mise isn't installed.

command -v mise &>/dev/null || return 0

if [[ -n "${ZSH_VERSION:-}" ]]; then
  eval "$(mise activate zsh)"
elif [[ -n "${BASH_VERSION:-}" ]]; then
  eval "$(mise activate bash)"
fi
