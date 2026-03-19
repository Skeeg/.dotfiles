# Python and pylint convenience aliases
# Replaces omz python + pylint plugins.

# Core interpreter aliases
alias py='python3'
alias py3='python3'
command -v python2 &>/dev/null && alias py2='python2'

# Search helpers
alias pyfind='find . -name "*.py"'
alias pygrep='grep --include="*.py" -rn .'

# Virtual environment management
alias mkenv='python3 -m venv .venv'
alias startenv='source ./.venv/bin/activate'
alias stopenv='deactivate'

# pylint
if command -v pylint &>/dev/null; then
  alias pylint-quiet='pylint --disable=C0111'
  alias pylint-errors='pylint -E'
fi
