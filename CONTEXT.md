# Status Line

The vocabulary of `status-line.sh` — the single line Claude Code renders in the
prompt footer each turn. This glossary exists because the script conflated two
different token aggregations under one name; the terms below keep them apart.

## Language

**Session**:
One Claude Code transcript, bounded by its transcript file. All per-session
figures are derived by reading that file.

**Context fill**:
How full the model's context window is *right now*, derived from the most recent
message's input and cache token counts. A point-in-time reading.
_Avoid_: usage, context cost, tokens used

**Cost**:
Cumulative dollar spend for the current session, summed across every message in
the transcript and priced with Anthropic's per-model, cache-aware rates. A
running total, not a per-turn figure — distinct from Context fill.
_Avoid_: price, spend rate, last-turn cost

**Proxy mode**:
The session is routed through a non-Anthropic endpoint (`ANTHROPIC_BASE_URL`
points off `api.anthropic.com`). First-party Cost and Utilization figures do not
apply and are suppressed.
_Avoid_: gateway mode, non-native

**Utilization**:
Anthropic account-level rate-window usage (the 5-hour bar and its reset clock),
read from the first-party OAuth usage endpoint. Meaningful only on first-party
Anthropic auth, never in Proxy mode.
_Avoid_: quota, rate limit, usage bar
