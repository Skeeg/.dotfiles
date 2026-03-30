# tmux.plugin.sh — tmux session helpers

# start-claude <path>
#   Creates (or attaches to) a tmux session named after the last path component,
#   cds into that path, and launches claude.
#
#   Usage:
#     start-claude ~/repo/sysadmin   # session: sysadmin
#     start-claude .                 # session: current dir name
start-claude() {
    local target_path="${1:-.}"
    local resolved_path
    resolved_path="$(realpath "$target_path" 2>/dev/null)" || resolved_path="$target_path"

    # Ensure Claude Code keybindings are in place. The canonical source lives in
    # .config/claude/keybindings.json (symlinked to ~/.config/claude/keybindings.json
    # by bootstrap). Copy it to ~/.claude/keybindings.json if either binding is absent.
    local _kb_src="$HOME/.config/claude/keybindings.json"
    local _kb_dst="$HOME/.claude/keybindings.json"
    if [[ -f "$_kb_src" ]]; then
        if ! grep -q '"shift+enter"' "$_kb_dst" 2>/dev/null || \
           ! grep -q '"alt+enter"'   "$_kb_dst" 2>/dev/null; then
            mkdir -p "$(dirname "$_kb_dst")"
            cp "$_kb_src" "$_kb_dst"
        fi
    fi

    local session_name
    session_name="$(basename "$resolved_path" | tr '.' '_')"

    if tmux has-session -t "$session_name" 2>/dev/null; then
        # Session already exists — just attach/switch
        if [[ -n "$TMUX" ]]; then
            tmux switch-client -t "$session_name"
        else
            tmux attach-session -t "$session_name"
        fi
    else
        # New session: start detached, cd, launch claude, then attach
        tmux new-session -d -s "$session_name" -c "$resolved_path"
        tmux send-keys -t "${session_name}:" "claude" Enter
        if [[ -n "$TMUX" ]]; then
            tmux switch-client -t "$session_name"
        else
            tmux attach-session -t "$session_name"
        fi
    fi
}
