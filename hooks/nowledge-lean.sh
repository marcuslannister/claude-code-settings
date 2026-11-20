#!/usr/bin/env bash
# SessionStart: patch the installed nowledge-mem plugin so it injects a short
# routing note instead of the full Context Bundle, and nothing per prompt.
# The plugin has no switch for this. Plugin updates replace the file, so this
# runs every session and reapplies the patch. NMEM_FULL_CONTEXT=1 restores the
# plugin's own output without unpatching.
# shortcut: string match on upstream code; if upstream changes main(), the
# patch is skipped and the script exits 1, so updaters warn. Then update the anchor.
set -euo pipefail

installed="$HOME/.claude/plugins/installed_plugins.json"
[ -f "$installed" ] || exit 0
root="$(jq -r '.plugins["nowledge-mem@nowledge-community"][0].installPath // empty' "$installed" 2>/dev/null || true)"
script="$root/scripts/nmem-hook-context.py"
[ -n "$root" ] && [ -f "$script" ] || exit 0

python3 - "$script" <<'PY'
import sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
marker = "# local patch: nowledge-lean"
if marker in src:
    sys.exit(0)
anchor = """    if is_grok_runtime():
        return 0
    if event == "UserPromptSubmit":"""
if src.count(anchor) != 1:
    print(f"nowledge-lean: anchor not found in {path}; patch skipped", file=sys.stderr)
    sys.exit(1)
patch = """    if is_grok_runtime():
        return 0
    %s
    if os.environ.get("NMEM_FULL_CONTEXT") != "1":
        if event == "SessionStart":
            note = ("[Nowledge Mem] Memory is available. For prior decisions, history, or "
                    "continuation work, search first: nmem --json m search \\"query\\" -n 5, or "
                    "nmem --json t search \\"query\\" --limit 5. If retrieval fails, say so. "
                    "Save durable decisions with nmem m add \\"content\\" -t \\"Title\\" -i 0.8.")
            write_response(event, note + ("\\n\\n" + COMPACT_GUIDANCE if compact else ""))
        return 0
    if event == "UserPromptSubmit":""" % marker
tmp = path + ".lean-tmp"
with open(tmp, "w", encoding="utf-8") as f:
    f.write(src.replace(anchor, patch))
import os
os.replace(tmp, path)
PY
