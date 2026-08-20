# Changelog

## Unreleased

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
