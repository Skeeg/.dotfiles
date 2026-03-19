#!/bin/bash
# ~/.bash_profile — Login shell entry point (SSH, console login)
# Sets login-specific environment, then delegates to .bashrc for
# interactive configuration so login and non-login shells are consistent.

GPG_TTY=$(tty)
export GPG_TTY

# Source .bashrc so login shells get the same plugins/aliases as
# interactive non-login shells (e.g. tmux new windows, subshells).
[[ -f "$HOME/.bashrc" ]] && source "$HOME/.bashrc"
