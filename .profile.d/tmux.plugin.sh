# tmux.plugin.sh — tmux session helpers

# start-claude <path>
#   Creates (or attaches to) a tmux session named after the last path component,
#   cds into that path, and launches claude.
#
#   Usage:
#     start-claude ~/repo/sysadmin   # session: sysadmin
#     start-claude .                 # session: current dir name
# Moved to bin/start-claude
