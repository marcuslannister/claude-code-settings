# CLAUDE.md

These rules apply to every task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

## Rule 1 — Think Before Coding
State assumptions explicitly. If uncertain, ask rather than guess.
Present multiple interpretations when ambiguity exists.
Push back when a simpler approach exists.
Stop when confused. Name what's unclear.

## Rule 2 — Simplicity First
Minimum code that solves the problem. Nothing speculative.
No features beyond what was asked. No abstractions for single-use code.
Test: would a senior engineer say this is overcomplicated? If yes, simplify.

## Rule 3 — Surgical Changes
Touch only what you must. Clean up only your own mess.
Don't "improve" adjacent code, comments, or formatting.
Don't refactor what isn't broken. Match existing style.

## Rule 4 — Goal-Driven Execution
Define success criteria. Loop until verified.
Don't follow steps. Define success and iterate.
Strong success criteria let you loop independently.

## Rule 5 — Use the model only for judgment calls
Use me for: classification, drafting, summarization, extraction.
Do NOT use me for: routing, retries, deterministic transforms.
If code can answer, code answers.

## Rule 6 — Token budgets are not advisory
Per-task: 4,000 tokens. Per-session: 30,000 tokens.
If approaching budget, summarize and start fresh.
Surface the breach. Do not silently overrun.

## Rule 7 — Surface conflicts, don't average them
If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup.
Don't blend conflicting patterns.

## Rule 8 — Read before you write
Before adding code, read exports, immediate callers, shared utilities.
"Looks orthogonal" is dangerous. If unsure why code is structured a way, ask.

## Rule 9 — Tests verify intent, not just behavior
Tests must encode WHY behavior matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

## Rule 10 — Checkpoint after every significant step
Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back.
If you lose track, stop and restate.

## Rule 11 — Match the codebase's conventions, even if you disagree
Conformance > taste inside the codebase.
If you genuinely think a convention is harmful, surface it. Don't fork silently.

## Rule 12 — Fail loud
"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

## Prefer modern CLI tools:

- Use `rg` instead of `grep`.
- Use `fd` instead of `find` for simple file discovery.
- Use `sd` instead of `sed` for find-and-replace.
- Use `eza` instead of `ls`.

Only use the classic tools when the modern tool cannot express the task safely or exactly.

## File editing

Prefer Anvil MCP tools over the built-in Read/Edit/Write
whenever they apply. They ship only the delta, batch multiple
edits in one round trip, and avoid full-file reads.

- `anvil-file-batch` — 3+ edits to the same file (collapse into one call)
- `anvil-file-replace-string` / `anvil-file-replace-regexp` —
  pinpoint replacement; no need to read the whole file first
- `anvil-file-insert-at-line` / `anvil-file-delete-lines` /
  `anvil-file-append` — localized line-level operations

Use the built-in `Edit` only for small one-off changes. For 3 or
more edits to the same file, always use `anvil-file-batch`.

## org-mode

For section moves, refile, splits, or reading a single heading
from a large org file, use `anvil-org-*` tools instead of
Read+Write. They are 10–20× cheaper in tokens.

- `anvil-org-read-headline` — read a single subtree
- `anvil-org-read-outline` — outline view without bodies
- `anvil-org-edit-body` / `anvil-org-rename-headline` /
  `anvil-org-update-todo-state` — targeted org edits

## Heavy operations — worker dispatch

Long-running Emacs ops (large tangles, byte-compile, multi-MB
org scans, full-tree searches) must not run on the main daemon —
they block every other tool call. Dispatch them through the
worker pool instead.

- Elisp called from inside Anvil: prefer `anvil-worker-call` over
  raw `eval` for anything that may exceed ~1s.
- If the worker is registered as its own MCP server (see README
  "Optional: register the worker pool too"), heavy `eval` calls
  should target `mcp__anvil-worker__eval` directly so the main
  session stays responsive.

Symptom that you should have used the worker: the main MCP
session stops accepting tool calls for several seconds.

## Scheduled tasks (cron)

If `anvil-cron` tasks are configured (lint, health checks, batch
indexers, etc.), do not re-implement their work ad hoc. Inspect
and trigger them through the cron MCP tools:

- `anvil-cron-list` — what tasks exist and their schedules
- `anvil-cron-status` — last run time, status, recent failures
- `anvil-cron-run` — fire a registered task on demand

Before writing a new ad-hoc script, check `anvil-cron-list` —
the job may already be defined.

## MCP tool self-reinforcement

If during a task you notice any of the following, switch to
the appropriate Anvil tool before continuing:

- The same elisp pattern is being written twice in one session
- Three or more `anvil-eval` calls were issued for one logical edit
  (a single `anvil-file-batch` would have sufficed)
- Repeated full-file Reads of the same large file
- A heavy elisp op blocked the main session — should have been
  routed via `anvil-worker-call` / `mcp__anvil-worker__eval`

Course-correct mid-task — do not wait until the end.
