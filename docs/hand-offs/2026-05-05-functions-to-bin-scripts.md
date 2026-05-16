# Hand-Off: Convert Shell Functions to Standalone `bin/` Scripts

**Date:** 2026-05-05
**Ticket(s):** N/A (dotfiles personal project)
**Branch:** `feat/functions-to-bin-scripts` (on `~/repo/.dotfiles`)
**Status:** In Progress — ~80% complete, 8 commits landed, 131 scripts created

---

## What Was Being Done

Claude Code's shell snapshot (`~/.claude/shell-snapshots/`) captures aliases via `alias -p` but NOT function definitions. This caused `alias env=_truncated_env_output` to resolve the alias name but fail to find the function body, producing "command not found: _truncated_env_output" in any Claude Code subprocess.

The fix: convert all user-callable shell functions from `.profile.d/` plugins into standalone executable scripts in a new `bin/` directory. Bootstrap symlinks `bin/` → `~/bin` (already in PATH via `.zshrc`). Scripts are found by name via PATH in any subprocess — solving the snapshot gap permanently.

All scripts use kebab-case naming. Already-hyphenated functions kept as-is; camelCase and snake_case converted. Functions that MUST stay as shell functions (mutate current shell via `cd`, `export`, or `source`) were identified and left in place.

---

## Current State

- **131 scripts** created in `~/repo/.dotfiles/bin/`, all `chmod +x`, all `#!/usr/bin/env bash`
- **8 commits** on `feat/functions-to-bin-scripts` (all clean, no staged/unstaged changes)
- **Key fix already committed:** `alias env=peek-env` and `alias printenv=peek-env` in `skeegfunctions.plugin.sh`; `bin/peek-env` exists and contains the `_truncated_env_output` body

### Functions still remaining as bodies in plugin files (not yet converted to scripts)

| Plugin | Function | Script name needed | Notes |
|---|---|---|---|
| `skeegfunctions.plugin.sh` | `gittyup` | `gittyup` | Needs `$REPOPATH` + `$SCRIPTS` guard |
| `skeegfunctions.plugin.sh` | `gittyupsalt` | `gittyupsalt` | Same guards |
| `skeegfunctions.plugin.sh` | `init-sessions` | `init-sessions` | Needs `$SCRIPTS` guard |
| `skeegfunctions.plugin.sh` | `get-tfc-variable-id` | `get-tfc-variable-id` | — |
| `skeegfunctions.plugin.sh` | `get-tfc-variable-data` | `get-tfc-variable-data` | — |
| `skeegfunctions.plugin.sh` | `patch-tfc-vault-token` | `patch-tfc-vault-token` | Needs `$TFC_API_TOKEN`, `$TFC_ORGANIZATION`, `$VAULT_TOKEN` guards |
| `skeegfunctions.plugin.sh` | `patch-tfc-cli-args` | `patch-tfc-cli-args` | Same guards |
| `skeegfunctions.plugin.sh` | `clear-tfc-cli-args` | `clear-tfc-cli-args` | — |
| `skeegfunctions.plugin.sh` | `msi` | `msi` | — |
| `skeegfunctions.plugin.sh` | `hash_api_key` | `hash-api-key` | — |
| `skeegfunctions.plugin.sh` | `get_1password_field` | — | `bin/get-1password-field` already EXISTS — just remove from plugin |
| `skeegfunctions.plugin.sh` | `create_1password_entry` | — | `bin/create-1password-entry` already EXISTS — just remove from plugin |
| `skeegfunctions.plugin.sh` | `secret` | — | `bin/secret` already EXISTS — just remove from plugin |
| `git.plugin.sh` | `git-default-branch` | `git-default-branch` | — |
| `git.plugin.sh` | `git-switch-default` | `git-switch-default` | — |
| `git.plugin.sh` | `git-clean-merged` | `git-clean-merged` | — |
| `tmux.plugin.sh` | `start-claude` | `start-claude` | — |
| `pluralsight_custom.plugin.sh` | `identity-up` | `identity-up` | Check if body still present |
| `pluralsight_custom.plugin.sh` | `identity-down` | `identity-down` | Check if body still present |
| `pluralsight_custom.plugin.sh` | `artifactory-download` | `artifactory-download` | Check if body still present |

### Functions intentionally left as shell functions (NEVER convert these)

| Function | Location | Reason |
|---|---|---|
| `ae`, `ae-nonprod`, `ae-prod` | `aws.plugin.sh` | Call `assume --export` to set AWS creds in current shell |
| `setenv` | `skeegfunctions.plugin.sh` | Does `export $(...)` — must mutate current shell |
| `lcd` | `skeegfunctions.plugin.sh` | Does `cd "$1"` — must run in current shell |
| `.1` through `.6` | `macos/functions.plugin.sh` | All do `cd` |
| `mcd` | `macos/functions.plugin.sh` | Does `mkdir && cd` |
| `_claude_bootstrap_statusline` | `claude.plugin.sh` | One-time init, immediately `unset -f`'d |
| `_dotfiles_sync` | `dotfiles-sync.plugin.sh` | One-time init, immediately `unset -f`'d |
| `_zle_shift_enter`, `_zle_alt_enter`, `_rl_insert_newline` | `keybindings.plugin.sh` | ZLE widgets — zsh requires shell functions |
| `_set_tab_title` | `prompt.plugin.sh` | `precmd` hook |
| `_cmd_log_callback`, `_cmd_log_preexec` | `history.plugin.sh` | `preexec` hooks |

---

## Key Decisions Made

- **kebab-case** for all script names (not snake_case) — one fewer keyshift per separator, more standard for CLI tools
- **`#!/usr/bin/env bash` default** — only use zsh shebang if body uses zsh-exclusive builtins (`setopt`, `zstyle`, etc.); in practice all converted functions are bash-compatible
- **Env var guards use portable syntax** — `[ -n "${VAR+x}" ]` not `[[ -v VAR ]]`, because macOS ships bash 3.2 which lacks `[[ -v ]]`
- **`dvs-bootstrap-staging/production` print exports** rather than execute them — so callers use `eval "$(dvs-bootstrap-staging)"` to populate their environment; other dvs-* scripts already use this pattern
- **`update-1password-item` uses 5-arg signature** (from skeegfunctions) not 3-arg (from 1password.plugin.sh) — the 5-arg version is what `generate-api-keys-1password` calls
- **`mount` renamed `list-mounts`** — original function does `sudo mount | column -t` (lists, not mounts); keeping name `mount` would shadow system binary via PATH precedence
- **`flushDNS` from macos/functions.plugin.sh was dropped** — duplicate of `flush-dns` (from skeegfunctions `flushdns`), which is more complete (kills mDNSResponder too)

---

## Next Steps (in order)

1. **Convert remaining skeeg functions** — read `skeegfunctions.plugin.sh` from line 12 onwards, create scripts for `gittyup`,`init-sessions`, `get-tfc-variable-id`, `get-tfc-variable-data`, `patch-tfc-vault-token`, `patch-tfc-cli-args`, `clear-tfc-cli-args`, `msi`, `hash_api_key`; add env var guards per the table above; remove their bodies from the plugin

2. **Remove already-converted duplicates from skeegfunctions.plugin.sh** — `get_1password_field` (line 252), `create_1password_entry` (line 267), `secret` (line 22) still exist as function bodies but bin/ scripts already exist; just delete those bodies from the plugin

3. **Convert git.plugin.sh** — create `bin/git-default-branch`, `bin/git-switch-default`, `bin/git-clean-merged`; remove bodies from plugin

4. **Convert tmux.plugin.sh** — create `bin/start-claude`; remove body from plugin; check if this function modifies shell state (if it does `tmux new-session` it's fine as a script; if it does `source` anything it must stay)

5. **Check pluralsight_custom.plugin.sh** — verify if `identity-up`, `identity-down`, `artifactory-download` bodies are still present; if so create scripts and remove bodies

6. **Run `bootstrap.sh`** in `~/repo/.dotfiles` to create the `~/bin → ~/repo/.dotfiles/bin` symlink

7. **Verify**: `ls -la ~/bin`, `which peek-env`, `peek-env`, `env | head` (should show truncated values), `flush-dns` (macOS only)

8. **Test env var guard**: `(unset REPOPATH && compose-up)` should print error and exit 1

9. **Commit and create MR/PR** for the branch

---

## Gotchas

- **The root cause of this whole effort**: Claude Code shell snapshots at `~/.claude/shell-snapshots/snapshot-zsh-*.sh` — run `grep env= ~/.claude/shell-snapshots/snapshot-*.sh | head` to see aliases captured without their function bodies. After bootstrap + new Claude session, `alias env` will still show `env=peek-env`, and now `peek-env` will be found via `~/bin` in PATH.

- **`skeegfunctions.plugin.sh` still has many function bodies** — it was the source of ~17 functions in Task 1 but several weren't listed and slipped through. Read from line 1 before touching anything.

- **`get_1password_field` and `create_1password_entry` appear BOTH in skeegfunctions.plugin.sh AND as existing bin/ scripts** — the bin/ scripts are the correct versions (written from the skeegfunctions bodies during Task 4 fix). Just delete the redundant function bodies from skeegfunctions.

- **`dush` and `ttop`** exist in both `macos/functions.plugin.sh` (removed) and were created as `bin/dush`, `bin/ttop` — they're fine.

- **`hist_prune.plugin.sh`** was previously an untracked file; it's now committed. The function bodies are replaced with `# Moved to bin/...` comments — leave those.

- **bootstrap.sh symlinks entire directories** as single symlinks. If `~/bin` already exists as a real directory (not a symlink), bootstrap will back it up to `~/.dotfiles_backups/` before symlinking.

- **`~/bin` path** is already in `.zshrc` PATH (second entry after `~/.local/bin`). No PATH changes needed — just run bootstrap.

---

## Context Files to Read First

1. `~/repo/.dotfiles/.profile.d/skeegfunctions.plugin.sh` — still has the most remaining function bodies; read in full before Task 6
2. `~/repo/.dotfiles/bin/` — scan `ls` output to know what already exists before creating new scripts
3. `~/repo/.dotfiles/bootstrap.sh` — understand what it excludes and what it symlinks before running it
4. `~/.claude/shell-snapshots/snapshot-zsh-*.sh` — the root cause artifact; verify `alias env` is in there but `peek-env` function is not
