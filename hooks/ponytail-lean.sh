#!/usr/bin/env bash
# SessionStart: make the ponytail helper skills manual-only, so their
# descriptions do not load in every session. /ponytail-help and the others
# still work. skillOverrides in settings.json does not apply to plugin
# skills, and plugin updates replace the files, so this runs every session
# and reapplies the frontmatter line.
# shortcut: matches the `name: <skill>` frontmatter line; if upstream changes
# the layout, the script exits 1 so updaters warn.
set -euo pipefail

installed="$HOME/.claude/plugins/installed_plugins.json"
[ -f "$installed" ] || exit 0
root="$(jq -r '.plugins["ponytail@ponytail"][0].installPath // empty' "$installed" 2>/dev/null || true)"
[ -n "$root" ] && [ -d "$root/skills" ] || exit 0

missed=0
for skill in ponytail-gain ponytail-help ponytail-debt ponytail-audit; do
  file="$root/skills/$skill/SKILL.md"
  [ -f "$file" ] || continue
  rg -q '^disable-model-invocation: true$' "$file" && continue
  if ! rg -q "^name: $skill\$" "$file"; then
    printf 'ponytail-lean: no name line in %s; patch skipped\n' "$file" >&2
    missed=1
    continue
  fi
  tmp="$file.lean-tmp"
  awk -v n="name: $skill" '{ print } $0 == n { print "disable-model-invocation: true" }' "$file" > "$tmp"
  mv -f "$tmp" "$file"
done
exit "$missed"
