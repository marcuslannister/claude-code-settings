#!/bin/bash
# PreToolUse hook for the read-only subagents (Explore, reviewer), set in their
# frontmatter: allow one rg, fd, or eza command and nothing else.
# Allowlist, not blocklist: plain words and 'single-quoted' strings only, so
# pipes, redirects, substitution, double quotes, and zsh glob qualifiers cannot pass.
source "$(dirname "$0")/lib.sh"

cmd=$(jq -r '.tool_input.command // empty')
block() { guard_deny "Blocked: $1. Run one rg, fd, or eza command. Use plain words and single quotes only."; }
[ -z "$cmd" ] && block 'empty command'

re="^(rg|fd|eza)( +([][A-Za-z0-9_./:,=@+%^*?~{}-]+|'[^']*'))* *$"
[[ $cmd =~ $re ]] || block 'command shape not allowed'

read -ra words <<<"$cmd"
for w in "${words[@]}"; do
  w=${w//\'/}
  case ${words[0]}:$w in
    rg:--pre|rg:--pre=*) block 'rg --pre runs a program' ;;
    fd:--exec|fd:--exec=*|fd:--exec-batch|fd:--exec-batch=*|fd:-[xX]*|fd:-[!-]*[xX]*) block 'fd --exec runs a program' ;;
  esac
done
guard_allow
