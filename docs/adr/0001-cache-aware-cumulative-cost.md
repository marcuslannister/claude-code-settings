# Cache-aware cumulative session cost in the status line

Status: accepted

The status line's `Cost` is computed as **cumulative session spend** — summed
across the transcript's distinct messages (deduped by `.message.id`, since a
single response spans several JSONL rows that repeat the same usage object) —
pricing token streams separately against current Anthropic rates: base input
×1, cache read ×0.1, 5-minute cache write ×1.25, 1-hour cache write ×2, output
×1. We chose this over the previous flat model (last-message input
+ cumulative output at a single per-model rate) because that model was wrong in
three compounding directions: it undercounted input by only counting the final
turn, it used stale per-model prices (Opus $15/$75 vs the current $5/$25 for
4.5+; Haiku $0.25/$1.25 vs $1/$5), and it charged cache reads — which dominate
Claude Code's token mix — at 10× their real 0.1× rate.

## Consequences

- **Prices rot.** The per-model rates are hardcoded and dated in the script;
  this ADR is the pointer explaining why they exist and must be refreshed. Source
  of truth: https://platform.claude.com/docs/en/about-claude/pricing
- **5-minute vs 1-hour cache writes are priced separately** from the transcript's
  nested `.message.usage.cache_creation` counters (`ephemeral_5m_input_tokens` /
  `ephemeral_1h_input_tokens`), at ×1.25 and ×2 respectively. Older transcripts
  that expose only the flat `cache_creation_input_tokens` fall back to the
  5-minute rate.
- **Usage is deduped by `.message.id`.** Claude transcripts emit one row per
  content block (thinking, text, tool_use), each repeating the identical usage
  object; summing rows would multiply cost by the per-response row count
  (observed ~3.3× on a real session). One usage record is counted per message.
- **Cost is suppressed in Proxy mode** (see [[CONTEXT.md]] → Proxy mode), since
  first-party list prices do not reflect what a proxied user actually pays.
