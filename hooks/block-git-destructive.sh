#!/bin/bash
# Blocks Git operations that need an explicit user request (AGENTS.MD: push and
# destructive operations). Each command in the string is judged on its own, so
# an exempt command cannot excuse a destructive one beside it.
source "$(dirname "$0")/lib.sh"
read_command "$(cat)"

deny() {
  echo "Blocked: $1" >&2
  echo "This needs an explicit user request in the current task. Leave the work in the tree and report that it is ready." >&2
  exit 2
}

for seg in "${SEGMENTS[@]}"; do
  # `git` plus any global flags, including the ones that take a value token.
  [[ $seg =~ ^git([[:space:]]+(-[cC][[:space:]]+[^[:space:]]+|-[^[:space:]]+))*[[:space:]]+(.*)$ ]] || continue
  args=${BASH_REMATCH[3]}
  arg() { grep -qE -- "$1" <<<"$args"; }

  arg '^push\b'                 && deny "\`git push\`. Never ship automatically."
  arg '^reset\b.*--hard'        && deny "\`git reset --hard\`."
  arg '^restore\b'              && deny "\`git restore\`."
  arg '^filter-(branch|repo)\b' && deny "\`git filter-branch\`/\`filter-repo\` rewrites published history."
  arg '^commit\b.*--amend'      && deny "\`git commit --amend\`. No amend unless asked."
  arg '^worktree\b'             && deny "\`git worktree\`. No CLI worktree unless asked."
  # `git checkout -- <path>` and `git checkout -f` discard working-tree changes,
  # exactly as `git restore` does. A plain branch checkout stays allowed.
  arg '^checkout\b.*( -- |-f\b|--force\b)' \
    && deny "\`git checkout\` with \`--\` or \`--force\` discards working-tree changes."
  # These two exemptions are read inside this segment only. `git rebase
  # --continue` finishes a rebase the user authorised; `git clean -n` previews.
  arg '^rebase\b' && ! arg '^rebase\b.*--(continue|abort|skip|quit|edit-todo)' \
    && deny "\`git rebase\` can rewrite published history."
  arg '^clean\b' && ! arg '^clean\b.*(-n\b|--dry-run)' \
    && deny "\`git clean\`."
done

exit 0
