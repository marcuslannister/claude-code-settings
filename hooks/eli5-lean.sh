#!/usr/bin/env bash
# SessionStart: make the eli5 plugin skill manual-only, so its description does
# not load in every session. /eli5 still works. skillOverrides in settings.json
# does not apply to plugin skills, and plugin updates replace the file, so this
# runs every session and reapplies the frontmatter line.
# shortcut: matches the exact `name: eli5` line inside the opening frontmatter;
# if upstream changes the layout, the script exits 1 so updaters warn.
set -euo pipefail

installed="$HOME/.claude/plugins/installed_plugins.json"
[ -f "$installed" ] || exit 0
root="$(jq -r '.plugins["eli5@claude-community"][0].installPath // empty' "$installed" 2>/dev/null || true)"
file="$root/skills/eli5/SKILL.md"
[ -n "$root" ] && [ -f "$file" ] || exit 0

# One awk pass over the opening frontmatter only (line 1 `---` to the next
# `---`), so a body example cannot match. Exit 2: no anchor. Exit 3: flag is
# already there. Exit 0: patched copy written to $tmp.
tmp="$(mktemp "$file.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
cp -p "$file" "$tmp"
rc=0
awk '
  { l[NR] = $0 }
  NR == 1 && $0 != "---" { bad = 1 }
  NR > 1 && !end && $0 == "---" { end = NR }
  !end && $0 == "name: eli5" { name = NR }
  !end && $0 == "disable-model-invocation: true" { flag = 1 }
  END {
    if (bad || !end || !name) exit 2
    if (flag) exit 3
    for (i = 1; i <= NR; i++) { print l[i]; if (i == name) print "disable-model-invocation: true" }
  }
' "$file" > "$tmp" || rc=$?
case "$rc" in
  0) mv -f "$tmp" "$file" ;;
  3) ;;
  2) printf 'eli5-lean: no name line in the frontmatter of %s; patch skipped\n' "$file" >&2; exit 1 ;;
  *) exit "$rc" ;;
esac
