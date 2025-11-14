# Custom plugin for zsh
#
# Common aliases
#
# Author: Thomas Bendler <code@thbe.org>
# Date:   Wed Jan  1 23:54:03 CET 2020
#

### Command enhancements aliases ###
alias l.='ls -d .*'                                # Preferred 'l.'    implementation
alias cp='cp -v'                                   # Preferred 'cp'    implementation
alias mv='mv -v'                                   # Preferred 'mv'    implementation
alias rm='rm -v'                                   # Preferred 'rm'    implementation
alias mkdir='mkdir -pv'                            # Preferred 'mkdir' implementation
alias less='less -FSRXc'                           # Preferred 'less'  implementation
alias ssh='ssh -A'                                 # Preferred 'ssh'   implementation
alias ping='ping -c 5'                             # Preferred 'ping'  implementation
alias wget='wget -c'                               # Preferred 'wget'  implementation
alias edit='atom'                                  # Preferred 'edit'  implementation
alias lc='colorls'
alias lca='colorls -al'

### Ryan Peay additions.
if [ ${SHELL##*/} = "bash" ]; then
  alias ls='ls -Fh'                                # Preferred 'ls'    implementation
fi

if [ ${SHELL##*/} = "zsh" ]; then
  alias ls='ls -GFh'                               # Preferred 'ls'    implementation
fi

alias ll='ls -lha'
alias sshk='ssh -o "StrictHostKeyChecking no" -o UserKnownHostsFile=/dev/null'
