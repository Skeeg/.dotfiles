# fzf — fuzzy finder
# Provides:
#   Ctrl+R  — fuzzy history search (replaces zsh-navigation-tools from omz)
#   Ctrl+T  — fuzzy file search, inserts path at cursor
#   Alt+C   — fuzzy cd into subdirectory
#
# Install:
#   macOS:  brew install fzf
#   Ubuntu: apt-get install -y fzf
#
# Shell integration files vary by install method and platform. This plugin
# probes known locations in priority order: Homebrew (Apple Silicon, Intel),
# then system apt paths.

if ! command -v fzf &>/dev/null; then
  return 0
fi

# Default options: compact height, reverse layout, border, preview toggle
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --inline-info --bind "ctrl-/:toggle-preview"'

# Prefer fd for file search if available — respects .gitignore, faster
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

# Locate shell integration files
_fzf_shell_dir=""
if [[ -d "/opt/homebrew/opt/fzf/shell" ]]; then
  # Homebrew (Apple Silicon)
  _fzf_shell_dir="/opt/homebrew/opt/fzf/shell"
elif [[ -d "/usr/local/opt/fzf/shell" ]]; then
  # Homebrew (Intel)
  _fzf_shell_dir="/usr/local/opt/fzf/shell"
elif [[ -d "/usr/share/doc/fzf/examples" ]]; then
  # apt-installed (Ubuntu/Debian)
  _fzf_shell_dir="/usr/share/doc/fzf/examples"
fi

if [[ -n "$_fzf_shell_dir" ]]; then
  if [[ -n "$BASH_VERSION" ]]; then
    [[ -f "${_fzf_shell_dir}/key-bindings.bash" ]] && source "${_fzf_shell_dir}/key-bindings.bash"
    [[ -f "${_fzf_shell_dir}/completion.bash" ]]   && source "${_fzf_shell_dir}/completion.bash"
  elif [[ -n "$ZSH_VERSION" ]]; then
    [[ -f "${_fzf_shell_dir}/key-bindings.zsh" ]]  && source "${_fzf_shell_dir}/key-bindings.zsh"
    [[ -f "${_fzf_shell_dir}/completion.zsh" ]]    && source "${_fzf_shell_dir}/completion.zsh"
  fi
fi

unset _fzf_shell_dir
