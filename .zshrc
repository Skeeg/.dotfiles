# Homebrew
# https://brew.sh/
# Alias command to update all installed Homebrew modules
alias upbrew="brew update && brew upgrade && brew cleanup && brew doctor && say 'brews done'"

# Antibody
# https://getantibody.github.io/
# Run static antibody bundle to load ZSH and plugins
source $HOME/.antibody-bundle.sh
alias antibundle='antibody bundle < $HOME/.antibody-plugins > $HOME/.antibody-bundle.sh'

# Dotfiles
# https://www.atlassian.com/git/tutorials/dotfiles
# Alias using git commands with local user config repo
# e.g. config add ~/.zshrc to commit this file.
alias config='git --git-dir=$HOME/.cfg --work-tree=$HOME'

# ASDF
# http://asdf-vm.com/
# Add ASDF environment setup.
source $(brew --prefix asdf)/libexec/asdf.sh

# Granted
# https://granted.dev/
# Alias to switch profile and populate temporary credentials
alias awssso='source assume $1 --export'

# Function to assume and open AWS Profile in the console
aws-console() {
	assume -c $1 -s $2;
}
# Ensure AWS SDK uses config for profile region etc
export AWS_SDK_LOAD_CONFIG=1

# Secrets
# Internal tool at ~/bin/secret
# Export secrets from Keychain into shell
source $HOME/lib/secret.sh
secret export NPM_TOKEN
secret export BUILDKITE_TOKEN

# Spaceship
# https://spaceship-prompt.sh/
# Fix unsightly colours in prompt ;)
LSCOLORS=ExFxBxDxCxegedabagacad
SPACESHIP_DIR_COLOR=blue
SPACESHIP_PACKAGE_SHOW=false
SPACESHIP_GIT_STATUS_COLOR=magenta

# ZSH local
# Add personal configs here
if [ -f "$HOME/.zshrc.local" ]; then
  source $HOME/.zshrc.local
fi

# Path
# Extend defaults with Homebrew and user binary paths
export PATH=/usr/local/sbin:$PATH
export PATH=/usr/bin:$PATH
export PATH=/usr/sbin:$PATH
export PATH=/sbin:$PATH
export PATH=/bin:$PATH
export PATH=/private/tmp:$PATH
export PATH=/usr/local/bin:$PATH
export PATH=$HOME/bin:$PATH
export PATH=/opt/homebrew/bin:$PATH
export MANPATH=/usr/local/man:$MANPATH

# Use hyphen-insensitive completion
HYPHEN_INSENSITIVE="true"

# Change how often to auto-update (in days).
export UPDATE_ZSH_DAYS=30

# Enable command auto-correction.
ENABLE_CORRECTION="true"

# Display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Disable marking untracked files under VCS as dirty
DISABLE_UNTRACKED_FILES_DIRTY="true"
