#!/usr/bin/env bash
# SessionStart: make the ponytail helper skills manual-only, so their
# descriptions do not load in every session. /ponytail-help and the others
# still work. skillOverrides in settings.json does not apply to plugin
# skills, and plugin updates replace the files, so this runs every session
# and reapplies the frontmatter line.
# shortcut: matches the exact `name: <skill>` line inside the opening
# frontmatter; if upstream changes the layout, the script exits 1 so updaters warn.
set -euo pipefail

installed="$HOME/.claude/plugins/installed_plugins.json"
[ -f "$installed" ] || exit 0
root="$(jq -r '.plugins["ponytail@ponytail"][0].installPath // empty' "$installed" 2>/dev/null || true)"
[ -n "$root" ] && [ -d "$root/skills" ] || exit 0

tmp=""
trap 'rm -f "$tmp"' EXIT
missed=0
for skill in ponytail-gain ponytail-help ponytail-debt ponytail-audit; do
  file="$root/skills/$skill/SKILL.md"
  [ -f "$file" ] || continue
  # One awk pass over the opening frontmatter only (line 1 `---` to the next
  # `---`), so a body example cannot match. Exit 2: no anchor. Exit 3: flag is
  # already there. Exit 0: patched copy written to $tmp.
  tmp="$(mktemp "$file.XXXXXX")"
  cp -p "$file" "$tmp"
  rc=0
  awk -v n="name: $skill" '
    { l[NR] = $0 }
    NR == 1 && $0 != "---" { bad = 1 }
    NR > 1 && !end && $0 == "---" { end = NR }
    !end && $0 == n { name = NR }
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
    2) printf 'ponytail-lean: no name line in the frontmatter of %s; patch skipped\n' "$file" >&2; missed=1 ;;
    *) exit "$rc" ;;
  esac
  rm -f "$tmp"
done
exit "$missed"
