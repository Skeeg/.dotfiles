# Custom plugin for zsh
#
# Various Functions
#
# Author: Ryan Peay
# Date:   Mon Aug 8 21:28:29 MST 2022
#




# Moved to bin/gittyup

# Moved to bin/secret


# Moved to bin/get-tfc-variable-id

# Moved to bin/get-tfc-variable-data

# Moved to bin/patch-tfc-vault-token

# Moved to bin/patch-tfc-cli-args

# Moved to bin/clear-tfc-cli-args

# Moved to bin/msi

# Method to set environment variables from a file, excluding commented out files
setenv() {
  # shellcheck disable=SC2046
  export $(grep -v '^#' "$1" | xargs)
}


alias env=peek-env
alias printenv=peek-env
alias status-vbox="sudo systemctl status vbox-dmz"
alias restart-vbox="sudo systemctl restart vbox-dmz"
alias start-vbox="sudo systemctl start vbox-dmz"
alias stop-vbox="sudo systemctl stop vbox-dmz"

lcd() {
  if [ $# -le 0 ]
  then
    echo "launch vs code and change to that directory: lcd ~/repo/directory"
    return 0
  fi
  if ! command -v code &>/dev/null; then echo "lcd: 'code' CLI not found — install VS Code and enable shell command."; return 1; fi
  code "$1"
  cd "$1"
}


# Moved to bin/hash-api-key



# Moved to bin/get-1password-field

# Moved to bin/create-1password-entry

