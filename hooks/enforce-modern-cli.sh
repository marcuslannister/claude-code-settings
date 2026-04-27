#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
command="$(jq -r '.tool_input.command // empty' <<<"$input")"

[ -z "$command" ] && exit 0

deny() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

check_segment() {
  local segment="$1"

  # Trim leading whitespace without using sed.
  segment="${segment#"${segment%%[!$' \t\r\n']*}"}"

  # Drop simple env assignments like FOO=bar command.
  while [[ "$segment" =~ ^[A-Za-z_][A-Za-z0-9_]*=([^[:space:]]+)[[:space:]]+(.*)$ ]]; do
    segment="${BASH_REMATCH[2]}"
  done

  local first="${segment%%[[:space:]]*}"
  first="${first##*/}"

  case "$first" in
    grep)
      deny "Use rg instead of grep. Example: rg -n \"pattern\" path"
      ;;
    find)
      deny "Use fd instead of find for simple file search. Example: fd -t f \"name\" path"
      ;;
    sed)
      deny "Use sd instead of sed for find-and-replace. Example: sd 'old' 'new' file.txt"
      ;;
    ls)
      deny "Use eza instead of ls. Example: eza -la --git"
      ;;
  esac
}

while IFS= read -r part; do
  check_segment "$part"
done < <(
  printf '%s\n' "$command" |
    tr '|' '\n' |
    tr ';' '\n' |
    tr '&' '\n'
)

exit 0
