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
  # tmux passes this through via `extended-keys on` in .tmux.conf.
  # Claude Code intercepts it directly via ~/.claude/keybindings.json.
  _zle_shift_enter() { LBUFFER+=$'\n' }
  zle -N _zle_shift_enter
  bindkey '\e[13;2u' _zle_shift_enter

  # Alt+Enter: same behavior. iTerm2 sends \033\r when Option is set to Esc+.
  _zle_alt_enter() { LBUFFER+=$'\n' }
  zle -N _zle_alt_enter
  bindkey '\033\r' _zle_alt_enter
fi
