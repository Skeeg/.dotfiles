# override dev alias from .zshrc
alias dev='cd ~/repo'
ENABLE_CORRECTION='false'
export ENABLE_CORRECTION
if [ $(echo $SHELL | rev | cut -d"/" -f1 | rev) = "zsh" ];
then
  unsetopt correct
fi
