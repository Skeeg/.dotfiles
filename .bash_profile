#!/bin/bash
GPG_TTY=$(tty)
export GPG_TTY

for item in $(ls -1 ${HOME}/.profile.d/*.plugin.zsh); do
  [ -e "${item}" ] && source "${item}"
done
