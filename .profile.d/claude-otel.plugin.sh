#!/usr/bin/env bash
# claude-otel.plugin.sh — Claude Code telemetry → Alloy OTLP on ubuntuserver (ADR-025)
#
# Opt-in per machine: put the collector endpoint in ~/.config/claude/otel.local
# (untracked; .config/claude/.gitignore's `*` ignores it). Machines without the
# file (the work laptop) export nothing.
#   ubuntuserver:            echo 'http://127.0.0.1:4317' > ~/.config/claude/otel.local
#   other personal devices:  echo 'http://10.2.2.2:4317'  > ~/.config/claude/otel.local
#
# Only reaches `claude` processes launched from a shell that sourced this
# plugin; running sessions keep their old environment.

_claude_otel_file="$HOME/.config/claude/otel.local"
if [[ -r "$_claude_otel_file" ]]; then
  export CLAUDE_CODE_ENABLE_TELEMETRY=1
  export CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1          # required for traces
  export OTEL_METRICS_EXPORTER=otlp OTEL_LOGS_EXPORTER=otlp OTEL_TRACES_EXPORTER=otlp
  export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
  OTEL_EXPORTER_OTLP_ENDPOINT="$(head -n1 "$_claude_otel_file")"
  export OTEL_EXPORTER_OTLP_ENDPOINT
  export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative
  # OTEL_METRICS_INCLUDE_SESSION_ID stays at its default (true). Setting it false
  # also strips session.id from log events, and concurrent sessions on one host
  # then emit identical series whose cumulative counters corrupt each other.
  export OTEL_METRICS_INCLUDE_ACCOUNT_UUID=false
  export OTEL_LOG_USER_PROMPTS=1                         # filtered by loki.secretfilter
  export OTEL_LOG_TOOL_DETAILS=1
  # OTEL_LOG_TOOL_CONTENT stays unset: span events bypass secretfilter (ADR-025)
  OTEL_RESOURCE_ATTRIBUTES="host.name=$(hostname -s),deployment.environment=personal"
  export OTEL_RESOURCE_ATTRIBUTES
fi
unset _claude_otel_file
