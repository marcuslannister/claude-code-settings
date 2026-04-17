# claude-code-settings

A distribution of Claude Code configuration — skills, subagents, hooks, rules, and alternate-provider settings — intended to be installed into `~/.claude/`.

## Layout

| Path | Purpose | Maps to |
|------|---------|---------|
| `settings.json` | Shared defaults: model, env, permissions, statusLine | `~/.claude/settings.json` |
| `.claude/settings.local.json` | Per-clone local overrides (gitignored) | `~/.claude/settings.local.json` |
| `.mcp.json` | MCP servers shipped with the plugin | `~/.claude/.mcp.json` |
| `skills/` | Skill bundles (each has `SKILL.md` + assets) | `~/.claude/skills/` |
| `agents/` | Subagent definitions | `~/.claude/agents/` |
| `hooks/hooks.json` | Plugin-level hook registrations | loaded via plugin root |
| `rules/` | Coaching or behavior rules included via global CLAUDE.md | referenced by user's global CLAUDE.md |
| `settings/` | Alternate-provider settings (Azure, OpenRouter, Qwen, etc.) | copied manually when switching providers |
| `.claude-plugin/` | Plugin manifest | registers this as a Claude Code plugin |

## Conventions

- **Skills**: keep `SKILL.md` body under ~500 words; move reference material to sibling files (`references/*.md`, `scripts/`). The frontmatter `description` should include concrete triggers so the dispatcher picks the skill up.
- **Permissions**: `settings.json` is the shared policy. Do not add broad allow-rules like `Bash(bash:*)` that bypass the deny list. Local-only exceptions go in `.claude/settings.local.json` (gitignored).
- **Rules**: `rules/*.md` files are loaded by the user's global CLAUDE.md via explicit include. Adding a new rule requires both the file here and an include line in the consumer's global CLAUDE.md.
- **Hooks**: register only through `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}` paths so the plugin stays portable.

## Working in this repo

- Commits: follow the existing short `chore:` / `feat:` / `fix:` style (see `git log`).
- Never commit `.claude/settings.local.json` or anything under `sessions/`, `projects/`, `shell-snapshots/`, `file-history/` — all gitignored.
- When modifying a skill, re-run `/health` afterwards to catch oversized SKILL.md, missing frontmatter, or description drift.
