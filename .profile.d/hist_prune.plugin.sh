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
