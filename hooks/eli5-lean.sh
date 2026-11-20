#!/usr/bin/env bash
# SessionStart: make the eli5 plugin skill manual-only, so its description does
# not load in every session. /eli5 still works. skillOverrides in settings.json
# does not apply to plugin skills, and plugin updates replace the file, so this
# runs every session and reapplies the frontmatter line.
# shortcut: matches the `name: eli5` frontmatter line; if upstream changes the
# layout, the script exits 1 so updaters warn.
set -euo pipefail

installed="$HOME/.claude/plugins/installed_plugins.json"
[ -f "$installed" ] || exit 0
root="$(jq -r '.plugins["eli5@claude-community"][0].installPath // empty' "$installed" 2>/dev/null || true)"
file="$root/skills/eli5/SKILL.md"
[ -n "$root" ] && [ -f "$file" ] || exit 0

rg -q '^disable-model-invocation: true$' "$file" && exit 0
if ! rg -q '^name: eli5$' "$file"; then
  printf 'eli5-lean: no name line in %s; patch skipped\n' "$file" >&2
  exit 1
fi
tmp="$file.lean-tmp"
awk '{ print } $0 == "name: eli5" { print "disable-model-invocation: true" }' "$file" > "$tmp"
mv -f "$tmp" "$file"
