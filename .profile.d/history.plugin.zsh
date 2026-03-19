HISTSIZE=100000
SAVEHIST=$HISTSIZE #zsh
HISTFILESIZE=$HISTSIZE #bash
if [[ -n "$ZSH_VERSION" ]]; then
  HISTFILE="$HOME/.zsh_history"
else
  HISTFILE="$HOME/.bash_history"
fi

# Configure history stamp format
HIST_STAMPS="yyyy-mm-dd"
HISTTIMEFORMAT="%Y/%m/%d %T "

export HISTSIZE SAVEHIST HISTFILESIZE HISTFILE HIST_STAMPS HISTTIMEFORMAT
if [ $(echo $SHELL | rev | cut -d"/" -f1 | rev) = "bash" ]; then
  # Append to HISTFILE on exit rather than overwriting — prevents last-session-wins
  # clobber when multiple terminals are open simultaneously.
  shopt -s histappend
  # Flush each command to HISTFILE immediately after it runs (before next prompt).
  # Combined with histappend this means concurrent sessions share history
  # incrementally rather than colliding at exit.
  # Note: PROMPT_COMMAND does NOT capture abrupt termination (sudo reboot, killed
  # terminal) — cmdhistory's DEBUG trap handles that case separately.
  PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi

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
