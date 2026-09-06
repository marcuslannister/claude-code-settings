# Changelog

## Unreleased

- Allow `eza`, `fd`, `rg`, and `echo` in the Bash allowlist, since `enforce-modern-cli.sh` already steers commands toward them.
- Standardise the guard hooks on JSON `permissionDecision` output and fail closed: every hook now answers with a decision on stdout instead of mixing exit-2-plus-stderr with JSON, and a hook that crashes or cannot run blocks the command rather than silently reading as an allow. `enforce-modern-cli.sh` drops its own segment splitter in favour of `lib.sh`'s shared parser, which closes three bypasses that the weaker splitter let through (`bash -c 'ls -la'`, `command ls`, `env ls`). `lib.sh` now records the operator before each segment, so the downstream-pipeline exemption (`ps aux | rg foo` allowed, `ls; rg foo` not) is expressed through the shared parser instead of a second one, and `(`/`)` group commands rather than separate them so `producer | (rg x)` keeps its pipe.
- Add `hooks/test-hooks.sh`, a 100-check self-check for the guard hooks. Silence counts as a failure, so a hook that crashes fails the suite instead of passing as an allow.
- Remove `redirect-to-anvil.sh`'s `sed -i` deny: `enforce-modern-cli.sh` now rewrites `sed -i` straight to `sd` instead of asking the user to switch to `file-replace-string`/`file-replace-regexp` by hand.
- Fix `enforce-modern-cli.sh`'s `find`/`sed` rewrites: `find ... -name '*.ts'` now rewrites to `fd --glob '*.ts' ...` (bare `fd` treats the pattern as a regex and fails on globs like `*.ts`), and `sed -i 's/pat/rep/'` now rewrites to `sd 'pat' 'rep' file` with the pattern and replacement quoted, so a literal `$HOME` in the original `sed` expression isn't shell-expanded before `sd` sees it.
- Fix `enforce-modern-cli.sh`'s `find`/`sed` flag scan to stop only at an unquoted pipe: a downstream pipeline command's own flags (e.g. `find ... | head -5`) were being misread as the command's unsupported flags and triggering a needless approval ask, while a literal `|` inside quotes (`-name '*|*'`, `sed 's|old|new|'`) now still gets scanned so real flags like `-exec` or `-i` after it are caught.
- Extend `redirect-to-anvil.sh` to nudge plain `curl` GET/HEAD calls toward `http-fetch`/`http-head` and `sed -i` toward `file-replace-string`/`file-replace-regexp`, alongside its existing `git`/`.org` redirects; register the hook in `settings.json`, where it had never been wired in. Move the cached Emacs-daemon probe into `hooks/lib.sh` so it's shared, bound it with `emacsclient --timeout`, and route Bash commands through `lib.sh`'s segment parser so wrapped forms (`FOO=1 sed -i`, `/usr/bin/sed -i`, `echo ok; sed -i`) aren't judged differently from the bare form.
- Fix `enforce-modern-cli.sh` to stop suggesting `sd` for `sed -i` when Anvil is reachable, since `redirect-to-anvil.sh` already denies that case in favor of `file-replace-string`; the two hooks were giving contradictory advice for the same command.
- Fix `enforce-modern-cli.sh` to stop asking for approval on plain `find` calls that use only flags `fd` directly replaces (`-maxdepth`, `-mindepth`, `-type`, `-name`, `-iname`, `-path`, `-ipath`); any other flag (`-exec`, `-inum`, `-mtime`, ...) still asks, since `fd` can't express every `find` predicate and unsupported operations must stay approvable rather than denied outright.
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
