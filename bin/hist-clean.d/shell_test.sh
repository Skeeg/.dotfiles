#!/usr/bin/env bash
# Tests the hist-clean shell function in bash and zsh: the names the shell
# knows (aliases, functions, builtins) must reach the binary.
#   ./shell_test.sh
set -uo pipefail

plugin=$(dirname "$(readlink -f "$0")")/../../.profile.d/hist_prune.plugin.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# Only names the shell itself defines: a binary not on PATH would be
# flagged.
printf '%s\n' 'zz-alias' 'zz_fn arg' 'cd /tmp' 'ls -la' > "$tmp/known_history"
printf '%s\n' 'zz-typo-nope' > "$tmp/typo_history"

check() {
  local shell=$1 hist=$2 want=$3 out
  out=$("$shell" -c "
    source '$plugin'
    alias zz-alias=true
    zz_fn() { :; }
    hist-clean '$hist'
  " 2>&1 </dev/null)
  case $want in
    clean) [[ $out == *"No invalid commands"* ]] ;;
    flagged) [[ $out != *"No invalid commands"* && $out != *"not found"* ]] ;;
  esac || {
    printf 'FAIL %s %s (want %s):\n%s\n\n' "$shell" "${hist##*/}" "$want" "$out"
    failures=$((failures + 1))
    return
  }
  printf 'ok   %s %s\n' "$shell" "${hist##*/}"
}

for shell in bash zsh; do
  check "$shell" "$tmp/known_history" clean
  check "$shell" "$tmp/typo_history" flagged
done

exit $((failures > 0))
