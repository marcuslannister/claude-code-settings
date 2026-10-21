#!/usr/bin/env bash
# PreToolUse hook: redirect built-in calls to Anvil MCP equivalents
# when the Emacs daemon is reachable. No-op when Anvil is unavailable.
#
# - Bash git (read-only)     → mcp__anvil-emacs-eval__git-*, only when the whole
#   command is Git reads (plus `cd` and read-only filters such as `| head`). In a chain that also
#   does other work, such as commit-push-verify, no Anvil call can replace it.
# - Bash curl (plain GET)    → mcp__anvil-emacs-eval__http-fetch / http-head
# Org files are not redirected: Anvil's org module is disabled (rules/tooling.md).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input=$(cat)

READ_ONLY_FILTERS="head tail rg grep wc sort uniq cut cat jq tr column less"

# True when the segment redirects output into a file (not /dev/null).
writes_file() {
  local s=${1//[0-9]>/>}
  s=${s//>>/>}
  s=${s//> \/dev\/null/}
  s=${s//>\/dev\/null/}
  [[ $s == *'>'* ]]
}
tool=$(jq -r '.tool_name // ""' <<<"$input")

case "$tool" in
  Bash)
    # read_command (lib.sh) normalizes each segment before Git and curl checks.
    read_command "$input"
    git_reason="" other_work=0
    for idx in "${!SEGMENTS[@]}"; do
      seg=${SEGMENTS[idx]}
      first=${seg%%[[:space:]]*}
      reason=""
      case "$first" in
        git)
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
              reason="Use \`mcp__anvil-emacs-eval__git-status\` — structured plist with ahead/behind counts and bucketed paths."
              ;;
            log)
              reason="Use \`mcp__anvil-emacs-eval__git-log\` — returns hash/date/author/subject plists."
              ;;
            diff)
              # --check is a whitespace gate, not a read; no Anvil tool does it.
              # An explicit pathspec reads named files' content, which no Anvil tool shows.
              [[ " $seg " == *" --check "* || " $seg " == *" -- "* ]] \
                || reason="Use \`mcp__anvil-emacs-eval__git-diff-names\` (paths) or \`git-diff-stats\` (file/insert/delete counts)."
              ;;
            rev-parse)
              reason="Use \`mcp__anvil-emacs-eval__git-head-sha\` or \`git-repo-root\`."
              ;;
            branch)
              # Only redirect bare 'git branch' (read-only). Allow -d/-D/-m/-c/--set-upstream etc.
              if (( ${#args[@]} == 0 )); then
                reason="Use \`mcp__anvil-emacs-eval__git-branch-current\` — returns the current branch name."
              fi
              ;;
            worktree)
              if [[ ${args[0]:-} == list ]]; then
                reason="Use \`mcp__anvil-emacs-eval__git-worktree-list\` — structured plists."
              fi
              ;;
          esac
          if [[ -n $reason ]] && ! writes_file "$seg"; then
            [[ -n $git_reason ]] || git_reason=$reason
          else
            other_work=1
          fi
          ;;
        cd) ;;
        curl)
          anvil_available || guard_allow
          # Only a plain GET/HEAD gets redirected: a URL plus quiet/follow/fail
          # flags. Any other token (-6, -m 5, --noproxy, --resolve, -w, -o ...)
          # is something http-fetch/http-head can't express, so curl stays.
          has_url=0 is_head=0 unsupported=0
          for tok in ${seg#curl}; do
            case "$tok" in
              http://*|https://*) has_url=1 ;;
              -I|--head) is_head=1 ;;
              --silent|--show-error|--location|--fail) ;;
              '>'*|'<'*|[0-9]'>'*|'&>'*) ;;  # shell redirections, not curl options
              -[sSLf]*) [[ $tok =~ ^-[sSLf]+$ ]] || unsupported=1 ;;
              *) unsupported=1 ;;
            esac
          done
          if [[ $unsupported -eq 0 && $has_url -eq 1 ]]; then
            if [[ $is_head -eq 1 ]]; then
              guard_deny "Use \`mcp__anvil-emacs-eval__http-head\` for a HEAD request."
            else
              guard_deny "Use \`mcp__anvil-emacs-eval__http-fetch\`."
            fi
          fi
          other_work=1
          ;;
        *)
          # A read-only filter after a pipe (`git log | head`) only shapes the
          # read's output. Any other stage, such as `tee`, has its own effect.
          if [[ ${SEGMENT_SEPARATORS[idx]} == '|' || ${SEGMENT_SEPARATORS[idx]} == '|&' ]] \
            && [[ " $READ_ONLY_FILTERS " == *" $first "* ]] && ! writes_file "$seg"; then
            :
          else
            other_work=1
          fi
          ;;
      esac
    done
    if [[ -n $git_reason ]] && (( ! other_work )) && anvil_available; then
      guard_deny "$git_reason"
    fi
    ;;
esac

guard_allow
