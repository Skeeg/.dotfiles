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

    local session_name
    session_name="$(basename "$resolved_path")"

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
        tmux send-keys -t "$session_name" "claude" Enter
        if [[ -n "$TMUX" ]]; then
            tmux switch-client -t "$session_name"
        else
            tmux attach-session -t "$session_name"
        fi
    fi
}
