# claude-code-settings

A distribution of Claude Code configuration — skills, subagents, hooks, rules, and alternate-provider settings — intended to be installed into `~/.claude/`.

## Layout

| Path | Purpose | Maps to |
|------|---------|---------|
| `settings.json` | Shared defaults: model, env, permissions, statusLine | `~/.claude/settings.json` |
| `.claude/settings.local.json` | Per-clone local overrides (gitignored) | `~/.claude/settings.local.json` |
| `skills/` | Skill bundles (each has `SKILL.md` + assets) | `~/.claude/skills/` |
| `agents/` | Subagent definitions | `~/.claude/agents/` |
| `rules/` | Coaching or behavior rules included via global CLAUDE.md | referenced by user's global CLAUDE.md |
| `settings/` | Alternate-provider settings (Azure, OpenRouter, Qwen, etc.) | copied manually when switching providers |
| `.claude-plugin/` | Plugin manifest | registers this as a Claude Code plugin |

## Conventions

- **Skills**: keep `SKILL.md` body under ~500 words; move reference material to sibling files (`references/*.md`, `scripts/`). The frontmatter `description` should include concrete triggers so the dispatcher picks the skill up.
- **Permissions**: `settings.json` is the shared policy. Do not add broad allow-rules like `Bash(bash:*)` that bypass the deny list. Local-only exceptions go in `.claude/settings.local.json` (gitignored).
- **Rules**: `rules/*.md` files are loaded by the user's global CLAUDE.md via explicit include. Adding a new rule requires both the file here and an include line in the consumer's global CLAUDE.md.

## Working in this repo

- Commits: follow the existing short `chore:` / `feat:` / `fix:` style (see `git log`).
- Never commit `.claude/settings.local.json` or anything under `sessions/`, `projects/`, `shell-snapshots/`, `file-history/` — all gitignored.
- When modifying a skill, re-run `/health` afterwards to catch oversized SKILL.md, missing frontmatter, or description drift.

## Prefer modern CLI tools:

- Use `rg` instead of `grep`.
- Use `fd` instead of `find` for simple file discovery.
- Use `sd` instead of `sed` for find-and-replace.
- Use `eza` instead of `ls`.

Only use the classic tools when the modern tool cannot express the task safely or exactly.

## Never

- Modify `.env`, lockfiles, or CI secrets without explicit approval
- Remove a referenced symbol without searching call sites first
- Commit without running tests when the project has a fast test suite

## Always

- Show diff before committing
- Update CHANGELOG for user-facing changes if the project keeps one

## Verification

- Run the project's test and lint commands before declaring a change complete
- API changes: update or add contract tests if the project has them
- UI changes: capture before/after screenshots

## Compact Instructions

Preserve:

1. Architecture decisions (NEVER summarize)
2. Modified files and key changes
3. Current verification status (pass/fail commands)
4. Open risks, TODOs, rollback notes

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
