export DOTFILES=$HOME/.dotfiles
alias dotfiles='cd $DOTFILES'
alias dotfiles-install='. $DOTFILES/install.sh'
alias dotfiles-config='. $DOTFILES/config.sh'
alias dev='cd ~/Code'

# Extend path with Homebrew and user binary paths
export PATH=/usr/local/sbin:$PATH
export PATH=/usr/bin:$PATH
export PATH=/usr/sbin:$PATH
export PATH=/sbin:$PATH
export PATH=/bin:$PATH
export PATH=/private/tmp:$PATH
export PATH=/usr/local/bin:$PATH
export PATH=$HOME/bin:$PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=/opt/homebrew/bin:$PATH
export PATH=/opt/homebrew/sbin:$PATH
export MANPATH=/usr/local/man:$MANPATH

# Source secrets lib first
if [ -e "$DOTFILES/environment/secret.sh" ]; then
  source "$DOTFILES/environment/secret.sh"
  secret export NPM_TOKEN --silent
  secret export ARTIFACTORY_NPM_TOKEN --silent
  secret export HOME_TOWN --silent
  secret export GIT_NAME --silent
  secret export GIT_EMAIL --silent
  secret export GIT_USERNAME --silent
  secret export ARTIFACTORY_GLOBAL_PULL_USER --silent
  secret export ARTIFACTORY_GLOBAL_PULL_TOKEN --silent
fi

# Source environment extensions
[ -e "$DOTFILES/environment/npm.sh" ] && source "$DOTFILES/environment/npm.sh"
[ -e "$DOTFILES/environment/asdf.sh" ] && source "$DOTFILES/environment/asdf.sh"
[ -e "$DOTFILES/environment/awssdk.sh" ] && source $DOTFILES/environment/awssdk.sh
[ -e "$DOTFILES/environment/certs.sh" ] && source $DOTFILES/environment/certs.sh
[ -e "$DOTFILES/environment/git.sh" ] && source $DOTFILES/environment/git.sh
[ -e "$DOTFILES/environment/granted.sh" ] && source $DOTFILES/environment/granted.sh
[ -e "$DOTFILES/environment/killport.sh" ] && source $DOTFILES/environment/killport.sh
[ -e "$DOTFILES/environment/pnpm.sh" ] && source $DOTFILES/environment/pnpm.sh
[ -e "$DOTFILES/environment/search.sh" ] && source $DOTFILES/environment/search.sh
[ -e "$DOTFILES/environment/starship.sh" ] && source $DOTFILES/environment/starship.sh
[ -e "$DOTFILES/environment/upbrew.sh" ] && source $DOTFILES/environment/upbrew.sh
[ -e "$DOTFILES/environment/utils.sh" ] && source $DOTFILES/environment/utils.sh
[ -e "$DOTFILES/environment/weather.sh" ] && source $DOTFILES/environment/weather.sh
[ -e "$DOTFILES/environment/yarn.sh" ] && source $DOTFILES/environment/yarn.sh
[ -e "$DOTFILES/environment/zim.sh" ] && source $DOTFILES/environment/zim.sh
[ -e "$DOTFILES/environment/zsh.sh" ] && source $DOTFILES/environment/zsh.sh

[ -e "$HOME/.zshrc.local" ] && source $HOME/.zshrc.local
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
[ -e "$HOME/.docker/completions" ] && fpath=(~/.docker/completions $fpath)
autoload -Uz compinit
# compinit
# End of Docker CLI completions
