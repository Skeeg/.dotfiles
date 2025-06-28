if [ ${SHELL##*/} = "bash" ]; then
  . ~/.profile.d/bash_cmdlog.sh
fi

if [ ${SHELL##*/} = "zsh" ]; then
  . ~/.profile.d/zsh_cmdlog.sh
fi
