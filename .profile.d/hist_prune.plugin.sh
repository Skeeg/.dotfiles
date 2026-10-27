# hist_prune — shell history cleanup utilities (bash + zsh compatible)
#
# Workflow A — typo/invalid first-word pruning:
#   hist_audit      <histfile> [review_file]
#   hist_prune      <histfile> [review_file]
#
# Workflow B — non-existent path pruning:
#   hist_audit_paths <histfile> [review_file]
#   hist_prune_paths <histfile> [review_file]
#
# Interactive — pick invalid commands to delete (Go, bin/hist-clean.d/):
#   hist-clean <histfile>
#
# Bonus — extract shell function definitions from history:
#   hist_extract_functions <histfile> [outfile]
#   outfile defaults to ~/repo/claude-scratch/command-scratch.reference
#
# histfile is required and explicit — no defaulting to prevent accidents.
# review_file defaults to ~/.cache/hist_{cmd,path}_review.txt
# After pruning: fc -R (zsh) or history -r (bash) to reload in open terminals.

_hist_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"

# ── Workflow A ────────────────────────────────────────────────────────────────

# Phase 1: scan history for unrecognized first-words (typos, deleted binaries).
# Writes candidates to review_file — edit out any you want to keep, then run hist-prune.
# Moved to bin/hist-audit

# Phase 2: remove all entries whose first word appears in review_file.
# Creates a timestamped backup before touching histfile.
# Moved to bin/hist-prune

# ── Workflow B ────────────────────────────────────────────────────────────────

# Phase 1: scan history for entries containing paths that don't exist on disk.
# Writes flagged raw history lines to review_file — edit out keepers, then hist-prune-paths.
# Moved to bin/hist-audit-paths

# Phase 2: remove exact history lines listed in review_file.
# Creates a timestamped backup before touching histfile.
# Moved to bin/hist-prune-paths

# ── Function extractor ────────────────────────────────────────────────────────

# Scan history for shell function definitions and append them to a reference file.
# Reconstructs multi-line bodies from zsh's backslash-continuation format.
# Definitions are appended (never overwritten) so the file accumulates over time.
#
# Detects both forms:
#   name()        { ... }   — compact or multi-line
#   function name { ... }   — alternate keyword form
# Moved to bin/hist-extract-functions

# ── hist-clean ────────────────────────────────────────────────────────────────

# The Go binary can't see this shell's aliases, functions, builtins or
# keywords, so the function lists them to a temp file and passes it in.
# The binary is built on first use, and again whenever the source is newer.
hist-clean() {
  local known bin rc
  bin=$(_hist_clean_bin) || return 1
  known=$(mktemp) || return 1
  if [ -n "$ZSH_VERSION" ]; then
    # eval keeps zsh-only expansion syntax away from bash's parser
    eval 'print -rl -- ${(k)functions} ${(k)aliases} ${(k)builtins} ${(k)reswords}' > "$known"
  else
    compgen -A function -a -b -k > "$known"
  fi
  "$bin" -known "$known" "$@"
  rc=$?
  rm -f "$known"
  return $rc
}

# Prints the path to an up-to-date hist-clean binary, building it with the
# host's go if there is one, otherwise through go-docker.
_hist_clean_bin() {
  local src="$HOME/bin/hist-clean.d"
  local out="${XDG_CACHE_HOME:-$HOME/.cache}/hist-clean-go/bin/hist-clean"
  if [ -x "$out" ] && [ -z "$(find "$src" -newer "$out" \( -name '*.go' -o -name 'go.mod' -o -name 'go.sum' \) ! -name '*_test.go' -print 2>/dev/null | head -1)" ]; then
    printf '%s\n' "$out"
    return 0
  fi
  printf 'hist-clean: building %s\n' "$out" >&2
  local goos goarch
  goos=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$(uname -m)" in
    x86_64) goarch=amd64 ;;
    aarch64|arm64) goarch=arm64 ;;
    *) printf 'hist-clean: unsupported arch %s\n' "$(uname -m)" >&2; return 1 ;;
  esac
  if command -v go >/dev/null 2>&1; then
    (cd "$src" && CGO_ENABLED=0 go build -o "$out" .) >&2 || return 1
  else
    # go-docker mounts the same cache dir at /go-cache
    GOOS=$goos GOARCH=$goarch CGO_ENABLED=0 "$src/go-docker" build -o /go-cache/bin/hist-clean . >&2 || return 1
  fi
  printf '%s\n' "$out"
}
