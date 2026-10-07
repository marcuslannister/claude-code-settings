#!/usr/bin/env bash
# PreToolUse hook: redirect built-in calls to Anvil MCP equivalents
# when the Emacs daemon is reachable. No-op when Anvil is unavailable.
#
# - Bash git (read-only)     → mcp__anvil__git-*
# - Bash curl (plain GET)    → mcp__anvil__http-fetch / http-head
# Org files are not redirected: Anvil's org module is disabled (rules/tooling.md).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input=$(cat)
tool=$(jq -r '.tool_name // ""' <<<"$input")

case "$tool" in
  Bash)
    # read_command (lib.sh) normalizes each segment before Git and curl checks.
    read_command "$input"
    for seg in "${SEGMENTS[@]}"; do
      first=${seg%%[[:space:]]*}
      case "$first" in
        git)
          anvil_available || guard_allow
          # Skip global options (git -C dir, --no-pager, -c k=v) so they
          # cannot hide the subcommand.
          read -ra words <<<"$seg"
          i=1
          while (( i < ${#words[@]} )); do
            case "${words[i]}" in
              -C|-c|--git-dir|--work-tree|--namespace|--config-env) i=$((i + 2)) ;;
              -*) i=$((i + 1)) ;;
              *) break ;;
            esac
          done
          sub=${words[i]:-}
          args=("${words[@]:i+1}")
          case "$sub" in
            status)
              guard_deny "Use \`mcp__anvil__git-status\` — structured plist with ahead/behind counts and bucketed paths."
              ;;
            log)
              guard_deny "Use \`mcp__anvil__git-log\` — returns hash/date/author/subject plists."
              ;;
            diff)
              # --check is a whitespace gate, not a read; no Anvil tool does it.
              [[ " $seg " == *" --check "* ]] && continue
              # An explicit pathspec reads named files' content, which no Anvil tool shows.
              [[ " $seg " == *" -- "* ]] && continue
              guard_deny "Use \`mcp__anvil__git-diff-names\` (paths) or \`git-diff-stats\` (file/insert/delete counts)."
              ;;
            rev-parse)
              guard_deny "Use \`mcp__anvil__git-head-sha\` or \`git-repo-root\`."
              ;;
            branch)
              # Only redirect bare 'git branch' (read-only). Allow -d/-D/-m/-c/--set-upstream etc.
              if (( ${#args[@]} == 0 )); then
                guard_deny "Use \`mcp__anvil__git-branch-current\` — returns the current branch name."
              fi
              ;;
            worktree)
              if [[ ${args[0]:-} == list ]]; then
                guard_deny "Use \`mcp__anvil__git-worktree-list\` — structured plists."
              fi
              ;;
          esac
          ;;
        curl)
          anvil_available || guard_allow
          # Only a plain GET/HEAD (a URL and nothing http-fetch/http-head
          # can't express) gets redirected; anything else is left unguarded.
          has_url=0 is_head=0 unsupported=0
          for tok in ${seg#curl}; do
            case "$tok" in
              http://*|https://*) has_url=1 ;;
              -I|--head) is_head=1 ;;
              -X|--request|-d|--data*|-F|--form|-T|--upload-file|-o|--output|-O|--remote-name|-H|--header|-u|--user)
                unsupported=1 ;;
            esac
          done
          if [[ $unsupported -eq 0 && $has_url -eq 1 ]]; then
            if [[ $is_head -eq 1 ]]; then
              guard_deny "Use \`mcp__anvil__http-head\` for a HEAD request."
            else
              guard_deny "Use \`mcp__anvil__http-fetch\`."
            fi
          fi
          ;;
      esac
    done
    ;;
esac

guard_allow
