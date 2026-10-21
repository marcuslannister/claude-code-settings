#!/usr/bin/env bash
# PreToolUse hook: block edits to a distributed skill copy.
#
# agent-scripts' sync-skill-surfaces.sh copies each selected skill into the
# agent surfaces and drops a `.agent-scripts-copy` marker whose first line is
# the source directory. An edit to the copy is lost at the next sync, so send
# the agent to the source instead.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input=$(cat)

deny_copy() { # deny_copy <path> <copy-dir>
  local source_dir
  source_dir=$(head -n 1 "$2/.agent-scripts-copy")
  jq -n --arg reason "$1 is in a distributed skill copy, and the next sync overwrites it. Edit the source in $source_dir${1#"$2"}, then run agent-tooling/sync-skill-surfaces.sh in agent-scripts." '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# data-set-path names its file `file` and its JSON key path `path`, so `path`
# is the file only when no other field is set. file-batch-across lists paths
# inside its JSON string argument. The sexp rename and replace-call tools take
# a `scope`: a file, a directory, or a comma-separated list of files.
paths=$(jq -r '.tool_input
  | (([.file_path, .notebook_path, .file] | map(select(type == "string")) | .[0]) // .path // empty),
    ((.["file-ops-json"] // empty) | fromjson? | .[]?.path // empty),
    ((.scope // empty) | select(. != "project") | split(",")[] | gsub("^\\s+|\\s+$"; ""))' <<<"$input")
# shortcut: scope "project" resolves inside Emacs, so it is not checked here.

while IFS= read -r path; do
  [[ -n $path ]] || continue
  path=${path/#\~/$HOME}
  path=${path%/}
  # A directory scope can hold copies below it as well as sit inside one.
  # -I: the copies' surfaces are often gitignored (claude-code-settings ignores /skills/).
  if [[ -d $path ]]; then
    marker=$(fd -H -I -t f -1 '^\.agent-scripts-copy$' "$path" 2>/dev/null || true)
    [[ -n $marker ]] && deny_copy "$(dirname "$marker")" "$(dirname "$marker")"
    dir=$path
  else
    dir=$(dirname "$path")
  fi
  while [[ $dir != / && $dir != . ]]; do
    [[ -f $dir/.agent-scripts-copy ]] && deny_copy "$path" "$dir"
    dir=$(dirname "$dir")
  done
done <<<"$paths"

guard_allow
