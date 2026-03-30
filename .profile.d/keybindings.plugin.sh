# Keybinding and word-boundary preferences
#
# Author: Ryan Peay

# ZSH word boundary behavior for opt+backspace:
# Exclude - _ = . from WORDCHARS so hyphens/underscores/equals/dots act as
# delimiters. For example, opt+backspace on `--key-setting=attrs-defined-here`
# deletes `here`, then `defined`, etc. rather than the entire token at once.
# Bash readline already treats these as boundaries by default; no change needed.
if [ -n "$ZSH_VERSION" ]; then
  WORDCHARS='*?[]~&;!#$%^(){}<>'

  # Shift+Enter: insert a literal newline into the ZLE buffer (multi-line editing).
  # iTerm2 must be configured to send \e[13;2u for Shift+Enter.
  # tmux passes this through via `extended-keys always` in .tmux.conf.
  # Claude Code intercepts it directly via ~/.claude/keybindings.json.
  _zle_shift_enter() { LBUFFER+=$'\n'; }
  zle -N _zle_shift_enter
  bindkey '\e[13;2u' _zle_shift_enter

  # Alt+Enter: same behavior. iTerm2 sends \033\r when Option is set to Esc+.
  _zle_alt_enter() { LBUFFER+=$'\n'; }
  zle -N _zle_alt_enter
  bindkey '\033\r' _zle_alt_enter

elif [ -n "$BASH_VERSION" ]; then
  # Bash readline equivalents using bind -x (requires bash 4+).
  # READLINE_LINE/READLINE_POINT are the bash analogues of zsh's LBUFFER.
  _rl_insert_newline() {
    READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}"$'\n'"${READLINE_LINE:$READLINE_POINT}"
    READLINE_POINT=$(( READLINE_POINT + 1 ))
  }
  # Shift+Enter (CSI u: \e[13;2u)
  bind -x '"\e[13;2u": _rl_insert_newline'
  # Alt+Enter (\e\r — sent when Option/Meta is configured as Esc+)
  bind -x '"\e\r": _rl_insert_newline'
fi
