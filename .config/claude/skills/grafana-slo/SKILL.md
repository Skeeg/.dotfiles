---
name: grafana-slo
description: "Grafana SLOs via gcx: SLO health, error budget and burn rate; why an SLO is breaching; create, update, pull or push SLO definitions; objective and alerting tuning advice."
---

# grafana-slo (router)

Routes to the 4 gcx `slo-*` skills.

This is a thin index. It keeps the family's long upstream descriptions out of every session's context. The real skills are installed by `gcx agent skills install` in `~/.agents/skills/` and are deliberately **not** linked into `~/.claude/skills` (see `claude.plugin.sh`).

## How to use

1. Pick the row below that matches the request.
2. Read that skill's `SKILL.md` in full with the Read tool, and follow it as if it had been invoked directly.
3. Relative paths inside it (e.g. `references/…`) resolve against that skill's directory.
4. `gcx` runs the containerized CLI via the `grun` shim. If a skill says `gcx login` or `gcx config set`, skip that step: credentials come from the grun hook (`source /tmp/.op-auth` first).
5. Terraform-managed resources change via `trun`, not a direct gcx push. Ask Ryan before pushing anything that has no Terraform definition. (Sysadmin memory: `feedback_gcx_skills_terraform_boundary`.)

| Skill | Use when | File |
|---|---|---|
| `slo-check-status` | overview or status of SLOs, error budget, burn rate | `~/.agents/skills/slo-check-status/SKILL.md` |
| `slo-investigate` | a specific SLO is breaching or alerting: root cause, dimensional breakdown | `~/.agents/skills/slo-investigate/SKILL.md` |
| `slo-manage` | create, update, delete, pull or push SLO definitions (GitOps) | `~/.agents/skills/slo-manage/SKILL.md` |
| `slo-optimize` | trend analysis and tuning recommendations: objective, alert sensitivity, windows | `~/.agents/skills/slo-optimize/SKILL.md` |
