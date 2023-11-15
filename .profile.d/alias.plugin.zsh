# Custom plugin for zsh
#
# Common aliases
#
# Author: Thomas Bendler <code@thbe.org>
# Date:   Wed Jan  1 23:54:03 CET 2020
#

### Command enhancements aliases ###
alias ls='ls -GFh'                                 # Preferred 'ls'    implementation
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
alias ll='ls -lha'

### Additions courtesy of Kristy Stallings aka kstallings 
alias create='!git pull && git checkout -b'
alias save='!git add -A && git commit -S -m'
alias oops='!git reset HEAD~'
alias refresh="!sh -c '_CURRENT_BRANCH=$(git symbolic-ref --short HEAD) && git checkout $1 && git pull && git checkout $_CURRENT_BRANCH && git rebase $1' -"
alias br="branch --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative)) [%(authorname)]' --sort=-committerdate"
alias br-all="branch -r --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative)) [%(authorname)]' --sort=-committerdate"
alias br-clean='!git remote prune origin'
alias lg='!git log --pretty=format:\"%C(magenta)%h%Creset -%C(red)%d%Creset %s %C(dim green)(%cr) [%an]\" --abbrev-commit -30'
