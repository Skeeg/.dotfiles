
# GPG agent TTY — required for passphrase prompts and commit signing
# Bash gets this from .bash_profile; zsh gets it here.
[[ -t 0 ]] && { GPG_TTY=$(tty); export GPG_TTY; }

# PATH — available to all ZSH invocations (interactive and non-interactive)
export PATH="$HOME/.local/bin:$PATH"

export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
export AWS_PAGER="";

alias assume="source assume"
fpath=(~/.granted/zsh_autocomplete/assume/ $fpath)
fpath=(~/.granted/zsh_autocomplete/granted/ $fpath)
