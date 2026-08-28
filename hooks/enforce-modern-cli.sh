#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

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

ask() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Truncate a string at the first pipe that is not inside single or double
# quotes, so `-name '*|*'` or sed's `s|old|new|` don't get mistaken for a
# pipeline separator.
truncate_at_unquoted_pipe() {
  local str="$1" i=0 c in_s=0 in_d=0 out=""
  local len=${#str}
  while (( i < len )); do
    c="${str:i:1}"
    if [[ $in_s -eq 0 && $in_d -eq 0 && "$c" == "|" ]]; then
      break
    fi
    if [[ $in_d -eq 0 && "$c" == "'" ]]; then
      (( in_s ^= 1 ))
    elif [[ $in_s -eq 0 && "$c" == '"' ]]; then
      (( in_d ^= 1 ))
    fi
    out+="$c"
    (( i++ ))
  done
  printf '%s' "$out"
}

check_segment() {
  local segment="$1"

  # Trim leading whitespace without using sed.
  segment="${segment#"${segment%%[!$' \t\r\n']*}"}"

  # Drop a leading shell keyword, so `if ls; then ...` still reads as `ls`.
  while [[ "$segment" =~ ^(if|then|elif|else|do|while|until|!)[[:space:]]+(.*)$ ]]; do
    segment="${BASH_REMATCH[2]}"
  done

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
      # fd can't cover every find predicate, so unrecognized flags must stay
      # approvable (ask), never a hard deny. Only skip the ask when every
      # flag used is one fd directly replaces.
      local rest="${segment#*find}" simple=1 tok
      # Stop at the first unquoted pipe: downstream commands' flags (e.g.
      # `| head -5`) aren't find's own arguments and must not count against it.
      rest="$(truncate_at_unquoted_pipe "$rest")"
      for tok in $rest; do
        case "$tok" in
          -maxdepth|-mindepth|-type|-name|-iname|-path|-ipath) ;;
          -*) simple=0 ;;
        esac
      done
      if [[ $simple -eq 0 ]]; then
        ask "Prefer fd for simple file search (e.g. fd -t f \"name\" path). Approve if you need a find predicate fd can't express (-exec, -print0, -newer, -mtime, -inum, ...)."
      fi
      ;;
    sed)
      # sd only does find-and-replace and always edits in place; a sed call
      # with no -i (including bundled short opts like -ni) can't modify
      # files, so sd can't replace it either (e.g. `sed -n '10,20p' file`
      # to print a line range) — allow silently.
      local rest="${segment#*sed}" has_i=0 tok
      rest="$(truncate_at_unquoted_pipe "$rest")"
      for tok in $rest; do
        [[ "$tok" =~ ^-[^-]*i || "$tok" == --in-place* ]] && has_i=1
      done
      # redirect-to-anvil.sh already denies sed -i in favor of Anvil's
      # file-replace-string/-regexp when the Emacs daemon is reachable;
      # only fall back to the sd suggestion when Anvil isn't available.
      if [[ $has_i -eq 1 ]] && ! anvil_available; then
        ask "Prefer sd for find-and-replace (e.g. sd 'old' 'new' file). Approve if you need sed's -i, -n, address ranges, or multi-line scripts."
      fi
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
