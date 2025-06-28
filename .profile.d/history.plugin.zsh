HISTSIZE=100000
SAVEHIST=$HISTSIZE #zsh
HISTFILESIZE=$HISTSIZE #bash
HISTFILE="$HOME/.zsh_history"

# Configure history stamp format
HIST_STAMPS="yyyy-mm-dd"
HISTTIMEFORMAT="%Y/%m/%d %T "

export HISTSIZE SAVEHIST HISTFILESIZE HISTFILE HIST_STAMPS HISTTIMEFORMAT
if [ $(echo $SHELL | rev | cut -d"/" -f1 | rev) = "zsh" ];
then
  setopt extendedhistory
  setopt histexpiredupsfirst
  setopt histignoredups
  setopt histignorespace
  setopt histverify
  setopt sharehistory
  unsetopt noappendhistory
  unsetopt nobanghist
  unsetopt cshjunkiehistory
  unsetopt histallowclobber
  unsetopt nohistbeep
  unsetopt histfcntllock
  unsetopt histfindnodups
  unsetopt histignorealldups
  unsetopt histlexwords
  unsetopt histnofunctions
  unsetopt histnostore
  unsetopt histreduceblanks
  unsetopt nohistsavebycopy
  unsetopt histsavenodups
  unsetopt histsubstpattern
  unsetopt incappendhistory
  unsetopt incappendhistorytime
fi
