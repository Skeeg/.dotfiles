#!/bin/bash
# Create/setup command log file if it doesn't exist
if [ ! -f ~/.bash_cmdlog ]; then
  touch ~/.bash_cmdlog
  chmod 600 ~/.bash_cmdlog
fi

# Variables to track last logged command
_LAST_HISTCMD=""

# Function to log commands before execution
function _cmd_log_callback() {
  # Get current history command
  local current_cmd="$(fc -ln -1)"
  # Extract just the command text (remove history number)
  current_cmd="${current_cmd#*  }"

  # Only log if this is a new command (avoid duplicates)
  if [ "$current_cmd" != "$_LAST_HISTCMD" ] && [ -n "$current_cmd" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S %Z') $USER: $current_cmd" >> ~/.bash_cmdlog
    _LAST_HISTCMD="$current_cmd"
  fi
}

# Setup trap to capture commands before execution
trap '_cmd_log_callback' DEBUG

# Function to display command history
function cmdhistory() {
  cat ~/.bash_cmdlog
}
