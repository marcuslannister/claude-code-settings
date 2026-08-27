# Changelog

## Unreleased

- Fix `enforce-modern-cli.sh` to stop asking for approval on read-only `sed` (no `-i`/`--in-place`, e.g. `sed -n '10,20p' file`), since `sd` cannot replace a print/range operation anyway; still asks for any in-place form, including bundled short opts (`-ni`), reordered suffixes (`-in`), and quoted suffixes (`-i''`, `-i".bak"`).
- Fix `block-git-destructive.sh` to block a force push, which rewrites published history same as `rebase` or `filter-branch` and needs an explicit request regardless of ship authorisation. Checked token-by-token: `-f`, `--force`, `--force-with-lease`, a bundled short flag (`-fu`), and a forced refspec (`push origin +main`) all block; a plain `push`, `--force-if-includes` alone, and a branch name that merely ends in `-f` (`push origin feature-f`) stay allowed.
- Add `PreToolUse` Bash guard hooks that enforce the hard rules deterministically: `block-git-destructive.sh` (`reset --hard`, `clean`, `restore`, `checkout --`, `rebase`, `filter-branch`, `commit --amend`, `worktree`; `push` is left to the CLAUDE.md rule, because a hook cannot tell an authorised ship from an unprompted one), `block-env-dump.sh` (environment dumps and printed secret values), and `gh-json.sh` (`gh` reads without `--json`, and `gh api --paginate`).
- Share command parsing across the guard hooks in `hooks/lib.sh`: it unwraps `bash -c '...'` payloads, removes quote syntax without losing the token, splits on the shell operators, and strips keywords, environment assignments, leading paths, and transparent prefixes such as `command` and `env`.
- Wire `hooks/enforce-modern-cli.sh` into `settings.json`, where it had never been registered, and teach it to see past a leading shell keyword (`if ls; then`).
- Cover the guard hooks with `hooks/test-hooks.sh`, a 91-case self-check that runs without Claude Code.
- Symlink `rules/` to `../agent-scripts/rules` so the topic rule files have one editable source.
- Disable `autoDreamEnabled`.
- Disable the `claude-mem` plugin.
- Disable `autoMemoryEnabled`.
- Add the herdr `SessionStart` hook (`hooks/herdr-agent-state.sh`) to report agent session state to the herdr daemon.
- Enable the `ponytail` plugin and its marketplace, and ignore its `.ponytail-active` session marker.
- Redesign `context-bar.sh`: emoji segments, thinking effort, git line changes with an untracked count, and a `modus-operandi-tinted` theme.
- Re-pin `opus[1m]` as the default model after Muxy reset it to `sonnet`.
- Remove Otty hooks, superseded by the Muxy and tty7 hooks.
- Ignore the local `skills/` directory.
- Enable CodeGraph MCP tools and prompt context injection.
- Use Opus by default and remove Orca and Zellij hooks that could block Claude Code tool calls.
- Default model to Sonnet 5.
- Add `context-bar.sh` status line script and switch to it.
- Move status line assets (`context-bar.sh`, `status-line.sh`, `ccstatusline-config.json`) into a `status-line/` folder.
- Trim `README.md` to what the repo actually ships and fix the kiro/spec-kit plugin links.
- Fix the status line command to an absolute path so it renders in every project, not only the `agent-scripts` checkout.
- Run the CodeGraph prompt hook under `$SHELL` (`"shell": "bash"`) instead of `/bin/sh`, which does not read the Zsh configuration that puts the npm global bin directory on `PATH`.
