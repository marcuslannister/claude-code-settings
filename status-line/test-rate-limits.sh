#!/bin/bash
# Self-check for the rate-limits writer in context-bar.sh: only newer figures replace the file.
# Runs the real script with a temp HOME and TMPDIR, so the real ~/.cache and markers stay untouched.
# Not wired into hooks/test-hooks.sh or CI. Usage: bash status-line/test-rate-limits.sh
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/rl-test.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home" "$tmp/tmp" || exit 1
file=$tmp/home/.cache/claude-code/rate-limits.json
pass=0 fail=0

check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: expected [$2], got [$3]"; fi
}
rl() { # rl <5h percent> <5h resets_at> <7d percent> <7d resets_at>: the rate_limits object
  printf '{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":%s,"resets_at":%s}}' "$@"
}
render() { # render <session> [<rate_limits object>]: one status-line render, prints its stdout
  local extra=""
  [ -n "$2" ] && extra=",\"rate_limits\":$2"
  printf '{"cwd":"/tmp","session_id":"%s","model":{"display_name":"X"}%s}' "$1" "$extra" |
    HOME="$tmp/home" TMPDIR="$tmp/tmp" "$BASH" "$here/context-bar.sh"
}
get() { jq -c "$1" "$file"; }
age() { jq -c '.updated_at = 1' "$file" > "$file.t" && command mv -f "$file.t" "$file"; } # an old updated_at shows a rewrite

# 1. The first session publishes when the file is missing
render S "$(rl 50 1000 20 2000)" > /dev/null
check "1 figures" '{"five_hour":{"used_percentage":50,"resets_at":1000},"seven_day":{"used_percentage":20,"resets_at":2000}}' "$(get 'del(.updated_at)')"
check "1 updated_at" '[["five_hour","seven_day","updated_at"],"number"]' "$(get '[keys, (.updated_at | type)]')"
age

# 2. The gap: session B has no marker and older figures, so the file stays and B gets a marker
render B "$(rl 40 1000 20 2000)" > /dev/null
check "2 file unchanged" '[1,50]' "$(get '[.updated_at, .five_hour.used_percentage]')"
check "2 marker" "$(rl 40 1000 20 2000)" "$(cat "$tmp/tmp/claude-ctx/B.rl" 2> /dev/null)"

# 3. Higher figures in the same window rewrite the file
render B "$(rl 60 1000 20 2000)" > /dev/null
check "3 rewritten" '[60,true]' "$(get '[.five_hour.used_percentage, .updated_at > 1]')"
age

# 4. The same session with unchanged figures does not rewrite; equal figures from a new session are not newer
render B "$(rl 60 1000 20 2000)" > /dev/null
check "4 same session" '[60,1]' "$(get '[.five_hour.used_percentage, .updated_at]')"
render C "$(rl 60 1000 20 2000)" > /dev/null
check "4 equal figures" '[60,1]' "$(get '[.five_hour.used_percentage, .updated_at]')"

# 5. A later resets_at wins even with a lower percentage
render B "$(rl 10 5000 20 2000)" > /dev/null
check "5 later window" '[5000,10,true]' "$(get '[.five_hour.resets_at, .five_hour.used_percentage, .updated_at > 1]')"
age

# 6. An earlier resets_at loses even with a higher percentage
render B "$(rl 90 3000 20 2000)" > /dev/null
check "6 earlier window" '[5000,10,1]' "$(get '[.five_hour.resets_at, .five_hour.used_percentage, .updated_at]')"

# 7. A valid value followed by junk counts as no old figures, though its first value is higher
printf '%s\n' '{"five_hour":{"used_percentage":99,"resets_at":9000},"seven_day":{"used_percentage":99,"resets_at":9000},"updated_at":1}}' > "$file"
render E "$(rl 5 100 5 100)" > /dev/null
check "7 junk file replaced" '[100,true]' "$(get '[.five_hour.resets_at, .updated_at > 1]')"

# 8. No rate_limits in the input writes nothing
rm -f "$file"
render F > /dev/null
check "8 no file" "missing" "$([ -e "$file" ] && echo present || echo missing)"
check "8 no marker" "missing" "$([ -e "$tmp/tmp/claude-ctx/F.rl" ] && echo present || echo missing)"

# 9. The status line output does not depend on rate_limits
check "9 stdout" "$(render G)" "$(render H "$(rl 50 1000 20 2000)")"

echo "$pass passed, $fail failed"
exit $((fail > 0))
