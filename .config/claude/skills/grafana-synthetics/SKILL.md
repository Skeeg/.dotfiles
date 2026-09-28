---
name: grafana-synthetics
description: "Grafana Synthetic Monitoring via gcx: check and probe health, why a synthetic check is failing, create, update or delete checks for a URL or host."
---

# grafana-synthetics (router)

Routes to the 3 gcx `synth-*` skills.

This is a thin index. It keeps the family's long upstream descriptions out of every session's context. The real skills are installed by `gcx agent skills install` in `~/.agents/skills/` and are deliberately **not** linked into `~/.claude/skills` (see `claude.plugin.sh`).

## How to use

1. Pick the row below that matches the request.
2. Read that skill's `SKILL.md` in full with the Read tool, and follow it as if it had been invoked directly.
3. Relative paths inside it (e.g. `references/…`) resolve against that skill's directory.
4. `gcx` runs the containerized CLI via the `grun` shim. If a skill says `gcx login` or `gcx config set`, skip that step: credentials come from the grun hook (`source /tmp/.op-auth` first).
5. Terraform-managed resources change via `trun`, not a direct gcx push. Ask Ryan before pushing anything that has no Terraform definition. (Sysadmin memory: `feedback_gcx_skills_terraform_boundary`.)

| Skill | Use when | File |
|---|---|---|
| `synth-check-status` | inventory, pass/fail and success-rate trends of checks | `~/.agents/skills/synth-check-status/SKILL.md` |
| `synth-investigate-check` | a check or probe is failing: triage and root cause | `~/.agents/skills/synth-investigate-check/SKILL.md` |
| `synth-manage-checks` | create, update, export or delete checks from YAML, or monitor a new URL or host | `~/.agents/skills/synth-manage-checks/SKILL.md` |
