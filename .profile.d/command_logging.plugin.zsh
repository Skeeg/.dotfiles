if [ ${SHELL##*/} = "zsh" ]; 
then
  if (( ! $+_cmd_log_fd )); then
    zmodload zsh/system
    typeset -gi _cmd_log_fd
    sysopen -a -m 600 -o cloexec,creat -u _cmd_log_fd ~/.zsh_cmdlog 2>/dev/null
    (( $? )) && _cmd_log_fd=-1
  fi

  if (( _cmd_log_fd >= 0 )); then
    function _cmd_log_preexec() {
      emulate -L zsh
      print -r -- "${(%):-%D{%Y-%m-%d %H:%M:%S %Z\}} $LOGNAME: $3" >&$_cmd_log_fd
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook preexec _cmd_log_preexec
  fi

  function cmdhistory() { cat ~/.zsh_cmdlog }
fi
