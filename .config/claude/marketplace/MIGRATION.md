# Moving cmdhistory from settings.json hooks to the plugin

This moves the cmdhistory hooks from the current model, where `claude.plugin.sh` merges them into `~/.claude/settings.json` at every shell start, to the `cmdhistory` plugin in this marketplace. The log files, their paths and their line format stay the same, so your existing history stays searchable and nothing needs converting.

## What changes

| | Current model | Plugin model |
|---|---|---|
| Hook scripts | `.config/claude/hooks/cmdhistory-{pre,post}.sh` | `.config/claude/marketplace/plugins/cmdhistory/scripts/` |
| Registration | `_claude_bootstrap_cmdhistory_hooks` in `.profile.d/claude.plugin.sh` writes absolute paths into `~/.claude/settings.json` | `hooks/hooks.json` in the plugin, using `${CLAUDE_PLUGIN_ROOT}` |
| Turning it off | Edit `claude.plugin.sh` and `settings.json` | `claude plugin disable cmdhistory@dotfiles` |
| Querying | `cldhistory`, or `jq` by hand | Ask Claude, and the `cmdhistory` skill runs the queries. `cldhistory` and `jq` still work. |
| New log files | Created with your umask, `0644` | Created `0600` |
| Extra field | none | `tool_use_id`, when Claude Code sends it |
| Sharing | Copy two scripts and a bootstrap function | Copy the `plugins/cmdhistory/` folder into any marketplace |

## Before you start

- Hooks load when a session starts. Every Claude Code session that is open now keeps running the old hooks from `settings.json` until it exits.
- The order of the steps matters. If you remove the `settings.json` entries before stopping the bootstrap, the next shell you open puts them back.
- Between step 2 and step 4, new sessions log nothing. Do steps 2 to 4 in one sitting.

## Steps

### 1. Stop the bootstrap from re-adding the hooks

In `.profile.d/claude.plugin.sh`, delete the line `_claude_bootstrap_cmdhistory_hooks` near the bottom. Also delete the `_claude_bootstrap_cmdhistory_hooks` function, and remove its name from the `unset -f` line.

Keep `_claude_merge_bash_hook` for now. Nothing else calls it today, but it is generic, so delete it only if you are sure you won't want it back.

Check that no other caller is left:

```bash
grep -n cmdhistory ~/repo/.dotfiles/.profile.d/claude.plugin.sh
```

The only remaining lines should be the header comment, and you can update that too.

### 2. Remove the two hook entries from settings.json

This deletes only the entries that point at the two cmdhistory scripts. Your iTerm2 `cc-status` hooks under `PreToolUse` and `PostToolUse` are kept, and so is every other key. The command writes to a temp file and only replaces `settings.json` if `jq` succeeds.

```bash
s=~/.claude/settings.json
cp "$s" "$s.pre-cmdhistory-plugin"
jq --arg pre "$HOME/.config/claude/hooks/cmdhistory-pre.sh" \
   --arg post "$HOME/.config/claude/hooks/cmdhistory-post.sh" '
  .hooks |= (
    with_entries(.value |= (map(.hooks |= map(select(.command != $pre and .command != $post))) | map(select(.hooks | length > 0))))
    | with_entries(select(.value | length > 0))
  )' "$s" > "$s.tmp" && mv "$s.tmp" "$s"
grep -c cmdhistory "$s"
```

The last line should print `0`. A dry run of this command against a copy of `settings.json` on 2026-11-11 removed 2 cmdhistory entries, kept all 10 `cc-status` entries, and left every non-hook key identical.

### 3. Add the marketplace and install the plugin

```bash
claude plugin marketplace add ~/.config/claude/marketplace
claude plugin install cmdhistory@dotfiles
```

`~/.config` is the dotfiles symlink, so this reads straight from the repo.

### 4. Restart Claude Code and check it

Start a new session and have it run any Bash command, such as `pwd`. Then, from a normal terminal:

```bash
tail -n 1 ~/.claude_cmdhistory | jq .
tail -n 1 ~/.claude_cmdhistory_done | jq .
```

What to look for:

| Check | Expected | If not |
|---|---|---|
| The `pwd` command is the last line of each file | Yes, once in each | Missing: the plugin is not enabled (`claude plugin list`). Twice: an old hook entry is still in `settings.json`, so rerun step 2. |
| `tool_use_id` is present | Probably | Absent means this Claude Code version does not send it. Logging still works, and the audit query falls back to matching on session plus command text. |
| `stat -f %Sp ~/.claude_cmdhistory` | `-rw-------` | The plugin does not change an existing file's mode. Run `chmod 600 ~/.claude_cmdhistory*`. |

Then ask Claude "which session did I last run pwd in?" to check that the skill triggers.

### 5. Clean up once no old sessions are left

Only after every session that started before step 4 has exited, because those sessions still call the old scripts:

1. Delete `.config/claude/hooks/cmdhistory-pre.sh` and `cmdhistory-post.sh`.
2. Remove their two `!hooks/...` lines from `.config/claude/.gitignore`.
3. Move whatever is still useful from `.config/claude/hooks/README.md` into the plugin's README, then delete it. The empirical note about `tool_response` having no exit code is already in the post-hook script.
4. Delete `~/.claude/settings.json.pre-cmdhistory-plugin`.
5. Keep `bin/cldhistory` or drop it. It reads the same files, so it works with either model.
6. Update the `claude.plugin.sh` bullet in the dotfiles `CLAUDE.md`, which still says the bootstrap merges the cmdhistory hooks.

## Changing the plugin later

Claude Code installs a copy of the plugin under `~/.claude/plugins/cache/`, so editing the files in this repo does not change the running hooks. After an edit:

1. Raise `version` in `plugins/cmdhistory/.claude-plugin/plugin.json`.
2. Run `claude plugin marketplace update dotfiles`, then `claude plugin update cmdhistory@dotfiles`.
3. Restart Claude Code.

I have not tested whether a local-directory marketplace skips the update when `version` is unchanged. Bump it every time anyway.

Check your work with `claude plugin validate ~/.config/claude/marketplace --strict`, and run it on `plugins/cmdhistory` too.

## Rolling back

```bash
claude plugin uninstall cmdhistory@dotfiles
cp ~/.claude/settings.json.pre-cmdhistory-plugin ~/.claude/settings.json
```

Then put the `_claude_bootstrap_cmdhistory_hooks` call back in `claude.plugin.sh`, or restore the file with `git checkout`. Restart Claude Code. The `settings.json` backup only exists until step 5. After that, the bootstrap re-adds the entries at the next shell start anyway.

## Pairing with a guard

The point of keeping two files is the gap between them. A command in `~/.claude_cmdhistory` with no line in `~/.claude_cmdhistory_done` never ran. A PreToolUse guard stopped it, you denied it, or it is still running.

If you run a secret-leak guard, such as the secrets-guard plugin that `ps-claude-marketplace` has since removed, you can see what it caught. A caught command shows up in the pre-log only. A secret-shaped command in the done-log ran and reached a shell, and that is the one to rotate. The skill has the query that lists everything stopped before it ran.

Your cached secrets-guard 0.1.1 is uninstalled the next time you update `ps-claude-marketplace`, because that marketplace sets `forceRemoveDeletedPlugins: true`. To keep it, copy it into `plugins/` here before then.
