---
name: grafana-agento11y
description: "Grafana Agent Observability (AI agent o11y) via gcx: agent conversations, generations, evaluators, eval rules, scores and guards; instrumenting an LLM app or agent with the SDKs; offline agent test suites."
---

# grafana-agento11y (router)

Routes to the 4 gcx `agento11y*` skills for Grafana Cloud's Agent Observability product.

This is a thin index. It keeps the family's long upstream descriptions out of every session's context. The real skills are installed by `gcx agent skills install` in `~/.agents/skills/` and are deliberately **not** linked into `~/.claude/skills` (see `claude.plugin.sh`).

## How to use

1. Pick the row below that matches the request.
2. Read that skill's `SKILL.md` in full with the Read tool, and follow it as if it had been invoked directly.
3. Relative paths inside it (e.g. `references/…`) resolve against that skill's directory.
4. `gcx` runs the containerized CLI via the `grun` shim. If a skill says `gcx login` or `gcx config set`, skip that step: credentials come from the grun hook (`source /tmp/.op-auth` first).
5. Terraform-managed resources change via `trun`, not a direct gcx push. Ask Ryan before pushing anything that has no Terraform definition. (Sysadmin memory: `feedback_gcx_skills_terraform_boundary`.)

| Skill | Use when | File |
|---|---|---|
| `agento11y` | list or search conversations or generations, export experiment data, manage evaluators, eval rules, scores, templates | `~/.agents/skills/agento11y/SKILL.md` |
| `agento11y-instrument` | instrument, or fix instrumentation of, an LLM app or agent so generations reach Agent Observability | `~/.agents/skills/agento11y-instrument/SKILL.md` |
| `agento11y-test-starter` | pre-ship, no traffic yet: write and run an offline starter test suite for an agent | `~/.agents/skills/agento11y-test-starter/SKILL.md` |
| `agento11y-prod-setup` | deployed agent with real traffic: online eval rules and guardrails (redact, tool-filter) | `~/.agents/skills/agento11y-prod-setup/SKILL.md` |
