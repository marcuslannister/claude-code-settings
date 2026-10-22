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
  *) guard_allow ;;
esac

command="$(jq -r '.tool_input.command // empty' <<<"$input")"

[ -z "$command" ] && guard_allow
read_command "$input"

rewrite_known_command() {
  local find_re='^find[[:space:]]+([^[:space:];|&]+)[[:space:]]+-name[[:space:]]+([^[:space:];|&]+)$'
  local sed_re="^sed[[:space:]]+-i[[:space:]]+'?s/([^/[:space:]]+)/([^/[:space:]]+)/'?[[:space:]]+([^[:space:];|&]+)$"

  if [[ "$command" =~ $find_re ]]; then
    guard_rewrite "fd --glob ${BASH_REMATCH[2]} ${BASH_REMATCH[1]}"
  fi
  if [[ "$command" =~ $sed_re ]]; then
    guard_rewrite "sd '${BASH_REMATCH[1]}' '${BASH_REMATCH[2]}' ${BASH_REMATCH[3]}"
  fi
}

rewrite_known_command

# True when a command whose first word is sd has a newline inside quotes.
# read_command strips quoted spans, so this walks the raw command instead.
# A multi-line sd pattern can replace nothing and still exit 0.
has_multiline_sd() {
  local raw=$1 ch q="" word="" first="" i
  for ((i = 0; i < ${#raw}; i++)); do
    ch=${raw:i:1}
    if [[ -n $q ]]; then
      if [[ $ch == "$q" ]]; then q=""
      elif [[ $ch == $'\n' && $first == sd ]]; then return 0
      fi
      continue
    fi
    case $ch in
      "'"|'"') q=$ch ;;
      ';'|'&'|'|'|'('|')'|$'\n') first="" word="" ;;
      [[:space:]]) [[ -z $first && -n $word ]] && first=$word; word="" ;;
      *) word+=$ch ;;
    esac
  done
  return 1
}

if has_multiline_sd "$command"; then
  guard_deny "Multi-line sd can replace nothing and still exit 0. Use Edit or mcp__anvil-emacs-eval__file-replace-string for multi-line text."
fi

for i in "${!SEGMENTS[@]}"; do
  # A downstream pipeline command can use grep for filtering. Commands after
  # `||` are separate decisions and remain guarded.
  [[ ${SEGMENT_SEPARATORS[$i]} == '|' || ${SEGMENT_SEPARATORS[$i]} == '|&' ]] && continue
  first=${SEGMENTS[$i]%%[[:space:]]*}
  case "$first" in
    grep)
      guard_deny "Use rg instead of grep. Example: rg -n \"pattern\" path"
      ;;
    ls)
      guard_deny "Use eza instead of ls. Example: eza -la --git"
      ;;
  esac
done

guard_allow
