#!/usr/bin/env bash
# PostToolUse: in a herdr pane, tell the agent once per session when context
# fill reaches HANDOFF_PCT, so it hands off to a new tab before auto compact
# (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE in settings.json) fires.
# The fill comes from status-line/context-bar.sh, which knows the window size;
# hook input does not.
set -euo pipefail

HANDOFF_PCT="${HANDOFF_PCT:-36}"
[ "${HERDR_ENV:-}" = "1" ] || exit 0

session=$(jq -r '.session_id // empty')
[ -n "$session" ] || exit 0
dir="${TMPDIR:-/tmp}/claude-ctx"
fill_file="$dir/$session"
[ -f "$fill_file" ] && [ ! -e "$fill_file.warned" ] || exit 0

pct=$(cat "$fill_file")
[[ "$pct" =~ ^[0-9]+$ ]] && [ "$pct" -ge "$HANDOFF_PCT" ] || exit 0
touch "$fill_file.warned"

jq -n --arg msg "Context fill is ${pct}% (handoff threshold ${HANDOFF_PCT}%). Read $HOME/.claude/agent-rules/handoff.md and hand off now." \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'
