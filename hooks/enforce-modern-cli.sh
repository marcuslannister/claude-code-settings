#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
tool_name="$(jq -r '.tool_name // empty' <<<"$input")"

# Gate: only act on shell-running tools. Catches future tool names
# (Shell, Exec, mcp__*-shell-*, mcp__*-exec-*) without needing matcher updates.
case "$tool_name" in
  Bash|Shell|Exec) ;;
  *[Ss]hell*|*[Ee]xec*) ;;
  *) exit 0 ;;
esac

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
  # Split on ; and & only — not on |, so downstream pipeline use of
  # grep/sed/etc. (e.g. `ps aux | grep foo`) is allowed.
  printf '%s\n' "$command" |
    tr ';' '\n' |
    tr '&' '\n'
)

exit 0
