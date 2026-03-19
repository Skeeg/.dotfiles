
# GPG agent TTY — required for passphrase prompts and commit signing
# Bash gets this from .bash_profile; zsh gets it here.
[[ -t 0 ]] && { GPG_TTY=$(tty); export GPG_TTY; }

alias assume="source assume"
fpath=(~/.granted/zsh_autocomplete/assume/ $fpath)
fpath=(~/.granted/zsh_autocomplete/granted/ $fpath)
