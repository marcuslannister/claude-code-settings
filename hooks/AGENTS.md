# Hook portability
- Hooks run on macOS (BSD tools, bash 3.2), Linux (GNU tools), and Windows Git Bash. Run `bash hooks/test-hooks.sh` before you commit; CI runs it on all three. Reason: a hook that passes on one system can fail open on another.
- Check a tool with `command -v` before you use it, for example `sd`, `eza`, `fd`, `rg`, and `trash`. Reason: some machines lack them, and the agent then gets `command not found`.
- Call GNU first, then BSD: `stat -c %Y`, then `stat -f %m`. Reason: GNU `stat -f` prints file system data and exits 1.
- Source `lib.sh` in every hook that calls `jq`, and send test input on stdin, not as a `jq --arg` argument. Reason: a native `jq.exe` writes CRLF (`lib.sh` adds `-b`), and MSYS rewrites an argument such as `/usr/bin/git`.
- Read a command through `read_command`, or call `strip_heredocs` before you read the raw command. Test a new rule with a heredoc body that starts with the word. Reason: a body is data, and a line that starts with `set` or `env` denied a harmless `cat >> f <<'EOF'`. A body stays checked when a shell reads it, and an unquoted body keeps its `$` and backtick lines.
