#!/usr/bin/env bash
# PreToolUse hook for Bash: redirect standalone grep/find to rg/fd.
# Matches only when grep/find is the FIRST token of the command. This avoids
# false positives on `ps | grep foo` and on commands that mention these names
# inside quoted strings.
set -euo pipefail

cmd=$(jq -r '.tool_input.command // ""')
first=$(printf '%s' "$cmd" | awk '{print $1}')

case "$first" in
  grep|egrep|fgrep)
    cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Use `rg` instead of `grep` (per CLAUDE.md). rg is faster and respects .gitignore."}}
JSON
    exit 0 ;;
  find)
    cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Use `fd` instead of `find` (per CLAUDE.md). fd is faster and has saner defaults."}}
JSON
    exit 0 ;;
esac
