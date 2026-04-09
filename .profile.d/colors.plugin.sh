# Color and visual enhancements
# Replaces omz plugins: colored-man-pages, colorize
#
# Provides:
#   - Colored man pages (via bat as MANPAGER, or less ANSI env vars as fallback)
#   - ccat / cless — syntax-highlighted cat/less via bat
#   - ls colors (platform-aware: LSCOLORS on macOS, dircolors/LS_COLORS on Linux)
#   - Colored grep, diff output
#   - zsh-autosuggestions + zsh-syntax-highlighting (zsh only)
#
# Install:
#   macOS:  brew install bat zsh-autosuggestions zsh-syntax-highlighting
#   Ubuntu: apt-get install -y bat zsh-autosuggestions zsh-syntax-highlighting

# --- Colored man pages + ccat/cless ---
# bat is preferred; it handles man formatting and syntax highlighting.
# On Ubuntu, bat binary may be named 'batcat' in older releases.
_bat_cmd=""
if command -v bat &>/dev/null; then
  _bat_cmd="bat"
elif command -v batcat &>/dev/null; then
  _bat_cmd="batcat"
fi

if [[ -n "$_bat_cmd" ]]; then
  # Use bat as the man pager: col strips backspace sequences, bat renders with color
  export MANPAGER="sh -c 'col -bx | ${_bat_cmd} -l man -p'"
  export MANROFFOPT="-c"
  alias ccat="${_bat_cmd}"
  alias cless="${_bat_cmd} --paging=always"
else
  # Fallback: ANSI escape sequences via less environment variables
  export LESS_TERMCAP_mb=$'\e[1;32m'   # begin blink
  export LESS_TERMCAP_md=$'\e[1;36m'   # begin bold
  export LESS_TERMCAP_me=$'\e[0m'      # reset bold/blink
  export LESS_TERMCAP_se=$'\e[0m'      # reset standout
  export LESS_TERMCAP_so=$'\e[01;33m'  # standout (search highlights)
  export LESS_TERMCAP_ue=$'\e[0m'      # reset underline
  export LESS_TERMCAP_us=$'\e[1;4;31m' # begin underline
fi
unset _bat_cmd

# --- ls colors ---
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS BSD ls: -G enables color
  export CLICOLOR=1
  export LSCOLORS="ExGxBxDxCxEgEdxbxgxcxd"
  alias ls='ls -GFh'
else
  # GNU ls (Linux): --color=auto
  if command -v dircolors &>/dev/null; then
    eval "$(dircolors -b)"
  fi
  alias ls='ls --color=auto -Fh'
fi

# Rebuild ll to pick up the updated ls
alias ll='ls -lha'

# --- Colored grep / diff ---
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
command -v diff &>/dev/null && alias diff='diff --color=auto'

# --- zsh-autosuggestions + zsh-syntax-highlighting ---
# These are independent of omz; we just need to find and source them.
# zsh-syntax-highlighting MUST be sourced last — it wraps ZLE widgets.
if [[ -n "$ZSH_VERSION" ]]; then
  _zsh_autosuggest=""
  if [[ -f "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    _zsh_autosuggest="/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  elif [[ -f "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    _zsh_autosuggest="/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  elif [[ -f "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    _zsh_autosuggest="$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
  fi
  [[ -n "$_zsh_autosuggest" ]] && source "$_zsh_autosuggest"
  unset _zsh_autosuggest

  _zsh_syntax=""
  if [[ -f "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    _zsh_syntax="/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  elif [[ -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    _zsh_syntax="/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  elif [[ -f "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    _zsh_syntax="$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi
  [[ -n "$_zsh_syntax" ]] && source "$_zsh_syntax"
  unset _zsh_syntax
fi
