#!/bin/bash
# Self-check: feeds each hook a command and asserts the outcome.
# Every hook answers with a permissionDecision on stdout. Silence is a failure,
# not an allow: index.ts blocks when a guard produces no decision, so a hook
# that crashes must not read as "safe" here either.
cd "$(dirname "$0")" || exit 1
MODERN=./enforce-modern-cli.sh
fail=0 checks=0

payload() { printf '%s' "$1" | jq -Rsc '{tool_name:"Bash",tool_input:{command:.}}'; } # stdin, not --arg: MSYS rewrites a /usr/bin/... argument for a native jq.exe

# Prints the hook's decision, or `none` when it stayed silent or emitted junk.
verdict() { jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null <<<"$1" || echo none; }

check() { # check <script> <expected: allow|deny> <command>
  checks=$((checks + 1))
  actual=$(verdict "$(payload "$3" | "./$1" 2>/dev/null)")
  if [ "$actual" != "$2" ]; then
    echo "FAIL $1: expected $2, got $actual for: $3"
    fail=$((fail + 1))
  fi
}

decision() { # decision <expected: allow|deny> <command>
  checks=$((checks + 1))
  actual=$(verdict "$(payload "$2" | PATH="$tools:$PATH" "$MODERN" 2>/dev/null)")
  if [ "$actual" != "$1" ]; then
    echo "FAIL enforce-modern-cli.sh: expected $1, got $actual for: $2"
    fail=$((fail + 1))
  fi
}

rewrite() { # rewrite <expected-command> <command>
  checks=$((checks + 1))
  out=$(payload "$2" | PATH="$tools:$PATH" "$MODERN" 2>/dev/null)
  actual=$(jq -r '.hookSpecificOutput.updatedInput.command // empty' <<<"$out")
  if [ "$actual" != "$1" ]; then
    echo "FAIL enforce-modern-cli.sh: expected rewrite $1, got $actual for: $2"
    fail=$((fail + 1))
  fi
}

# enforce-modern-cli.sh rewrites or denies toward a modern tool only when
# `command -v` finds it. $tools holds empty stand-ins for rg, fd, eza, and sd, so
# decision and rewrite do not depend on the machine. $bare holds only what the
# hook runs (jq, dirname, cat) and no modern tool, so classic can test their absence.
fixtures=$(mktemp -d "${TMPDIR:-/tmp}/hooks-fixtures.XXXXXX") || { echo "FAIL: cannot create the fixture folder"; exit 1; }
trap 'rm -rf "$fixtures"' EXIT # later traps repeat this; an empty path above would write to /
tools=$fixtures/tools bare=$fixtures/bare fj=$fixtures/fj
mkdir "$tools" "$bare" "$fj" || { echo "FAIL: cannot create the fixture folders"; exit 1; }
for t in rg fd eza sd; do printf '#!/bin/sh\n' > "$tools/$t"; chmod +x "$tools/$t"; done
for t in jq dirname cat; do printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v "$t")" > "$bare/$t"; chmod +x "$bare/$t"; done

classic() { # classic <command>: without the modern tools the hook allows it unchanged
  checks=$((checks + 1))
  out=$(payload "$1" | PATH=$bare "$BASH" "$MODERN" 2>/dev/null)
  actual=$(jq -r '.hookSpecificOutput | .permissionDecision + (if .updatedInput then " rewritten" else "" end)' <<<"${out:-null}" 2>/dev/null)
  if [ "$actual" != allow ]; then
    echo "FAIL enforce-modern-cli.sh: expected allow unchanged without modern tools, got '$actual' for: $1"
    fail=$((fail + 1))
  fi
}

# Only removing a harness worktree under .claude/worktrees/ without --force is exempt.
check block-git-destructive.sh allow 'git worktree remove .claude/worktrees/agent-ab12'
check block-git-destructive.sh allow 'git -C /tmp/repo worktree remove /tmp/repo/.claude/worktrees/agent-ab12/'
check block-git-destructive.sh allow 'git worktree remove .claude/worktrees/a && git worktree remove .claude/worktrees/b && git branch -d impl/x'
check block-git-destructive.sh deny 'git worktree remove --force .claude/worktrees/agent-ab12'
check block-git-destructive.sh deny 'git worktree remove -f .claude/worktrees/agent-ab12'
check block-git-destructive.sh deny 'git worktree remove ../sibling-checkout'
check block-git-destructive.sh deny 'git worktree remove .claude/worktrees/..'
check block-git-destructive.sh deny 'git worktree remove .claude/worktrees/../../repo'
check block-git-destructive.sh deny 'git worktree add .claude/worktrees/new'
check block-git-destructive.sh deny 'git worktree prune'
check block-git-destructive.sh deny 'git worktree remove .claude/worktrees/a && git reset --hard'
# A plain `git push` is intentionally allowed: a hook cannot tell an
# authorised ship from an unprompted one. CLAUDE.md governs plain pushes.
# `--force` rewrites published history regardless, so it stays blocked.
check block-git-destructive.sh allow 'git push origin main'
check block-git-destructive.sh deny 'git -C ./repo push --force'
check block-git-destructive.sh deny 'git push -f origin main'
check block-git-destructive.sh deny 'git push --force-with-lease origin main'
# Bundled short flags and forced refspecs also force.
check block-git-destructive.sh deny 'git push -fu origin main'
check block-git-destructive.sh deny 'git push -uf origin main'
check block-git-destructive.sh deny 'git push origin +main'
# A branch/refspec that merely ends in `-f`, or a lease-adjacent option that
# does not by itself force, must not false-positive.
check block-git-destructive.sh allow 'git push origin feature-f'
check block-git-destructive.sh allow 'git push --force-if-includes origin main'
check block-git-destructive.sh deny 'git reset --hard HEAD~1'
check block-git-destructive.sh deny 'git commit -m x --amend'
check block-git-destructive.sh deny 'git rebase main'
check block-git-destructive.sh deny 'git clean -fd'
check block-git-destructive.sh allow 'git status -sb'
check block-git-destructive.sh allow 'git commit -m "fix: no push here"'
# Privacy guard bypasses (agent-scripts ADR-0011).
check block-git-destructive.sh deny 'git commit --no-verify -m x'
check block-git-destructive.sh deny 'git commit -m x -n'
check block-git-destructive.sh deny 'git commit -anm x'
check block-git-destructive.sh deny 'git -c core.hooksPath=/dev/null commit -m x'
check block-git-destructive.sh deny 'git -c core.hookspath= status'
check block-git-destructive.sh deny 'git config core.hooksPath /dev/null'
check block-git-destructive.sh deny 'git config --unset core.hooksPath'
check block-git-destructive.sh allow 'git config --get core.hooksPath'
# Reading the key with no value is allowed; any value, unset, add, or set is not.
check block-git-destructive.sh allow 'git config core.hooksPath'
check block-git-destructive.sh allow 'git config --global core.hooksPath'
check block-git-destructive.sh allow 'git config --show-origin core.hooksPath'
check block-git-destructive.sh deny 'git config --global core.hooksPath /dev/null'
check block-git-destructive.sh deny 'git config --unset-all core.hooksPath'
check block-git-destructive.sh deny 'git config unset core.hooksPath'
check block-git-destructive.sh deny 'git config --add core.hooksPath x'
check block-git-destructive.sh deny 'git config --replace-all core.hooksPath x'
check block-git-destructive.sh deny 'git config set core.hooksPath x'
# Git config keys are case-insensitive, so the key's case must not matter.
check block-git-destructive.sh deny 'git config core.HOOKSPATH /dev/null'
check block-git-destructive.sh deny 'git config --global Core.HooksPath x'
check block-git-destructive.sh allow 'git config core.HOOKSPATH'
# Quote removal erases an empty or spaced value, so a quote keeps the deny.
check block-git-destructive.sh deny 'git config core.hooksPath ""'
check block-git-destructive.sh deny "git config core.hooksPath '/tmp/my hooks'"
check block-git-destructive.sh deny 'git config --global core.hooksPath "$(echo /dev/null)"'
check block-git-destructive.sh allow 'git commit -m -n'
check block-git-destructive.sh allow 'git commit -am x'
check block-git-destructive.sh allow 'git push --no-verify origin main'
# Finishing an authorised rebase, and previewing a clean, are not destructive.
check block-git-destructive.sh allow 'git rebase --continue'
check block-git-destructive.sh allow 'git clean -n'
# `git checkout -- <path>` discards working-tree changes; a branch checkout does not.
check block-git-destructive.sh deny 'git checkout -- .'
check block-git-destructive.sh deny 'git checkout -f main'
check block-git-destructive.sh allow 'git checkout -b feature/x'
check block-git-destructive.sh allow 'git checkout main'
# Prefixes that used to hide the command word.
check block-git-destructive.sh deny '/usr/bin/git clean -fd'
check block-git-destructive.sh deny 'FOO=1 git clean -fd'
check block-git-destructive.sh deny 'if git clean -fd; then echo x; fi'

# A nested shell payload is inspected, not discarded as a string.
check block-git-destructive.sh deny "bash -lc 'git restore .'"
check block-git-destructive.sh deny 'bash -c "git clean -fd"'
check block-git-destructive.sh deny "/bin/sh -c 'git reset --hard'"
check block-git-destructive.sh allow "bash -lc 'git status -sb'"
# An exempt command beside a destructive one does not excuse it.
check block-git-destructive.sh deny 'git clean -fd; git clean -n'
check block-git-destructive.sh deny 'git rebase main; git rebase --continue'
check block-git-destructive.sh deny 'git status && git clean -fd'
check block-git-destructive.sh allow 'git clean -n; git rebase --continue'

# A quoted token still runs: `git 'clean'` is a clean.
check block-git-destructive.sh deny "git 'clean' -fd"
check block-git-destructive.sh deny 'git "reset" --hard'
# Transparent prefixes run the next word as the command.
check block-git-destructive.sh deny 'command git clean -fd'
check block-git-destructive.sh deny 'exec git clean -fd'
check block-git-destructive.sh deny 'env -u GIT_DIR git clean -fd'
check block-git-destructive.sh allow 'env -u GIT_DIR git status'

check block-env-dump.sh deny 'env'
check block-env-dump.sh deny 'env | rg TOKEN'
check block-env-dump.sh deny 'export -p'
check block-env-dump.sh deny 'printenv'
check block-env-dump.sh allow 'printenv GITHUB_TOKEN'
check block-env-dump.sh allow 'env -u GITHUB_TOKEN gh pr create --body-file ./b'
check block-env-dump.sh allow 'set -euo pipefail'
check block-env-dump.sh allow 'git reset --soft HEAD~1'

check block-secret-file-read.sh deny 'cat docker-compose.yml'
check block-secret-file-read.sh deny "ssh vm16 'cd /srv/app && cat docker-compose.yml && du -sh data'"
check block-secret-file-read.sh deny 'tail -n 5 .env'
check block-secret-file-read.sh deny 'cat ~/Projects/proxy-config/mihomo/home-secret.local'
check block-secret-file-read.sh deny 'docker compose config'
check block-secret-file-read.sh allow "rg -v 'SECRET|TOKEN|KEY|PASSWORD' docker-compose.yml"
check block-secret-file-read.sh allow 'cat docker-compose.yml | rg -v SECRET'
check block-secret-file-read.sh allow 'cat README.md'
check block-secret-file-read.sh allow 'docker compose up -d'
# A heredoc written to a file prints nothing, whatever words it holds.
check block-secret-file-read.sh allow $'cat > /tmp/x.md <<\'EOF\'\nuse your Windows password\nEOF\ngh pr create --body-file /tmp/x.md'
check block-secret-file-read.sh allow $'cat >> /tmp/x.ps1 <<EOF\n(git config --get-all credential.helper)\nEOF'
check block-secret-file-read.sh allow $'cat > /tmp/p.ps1 <<"END"\nschtasks /rp not-the-password\nEND'
check block-secret-file-read.sh allow $'cat > /tmp/i.sh <<-EOF\n\tsecret prose\n\tEOF'
# With no end word, bash takes the rest as heredoc text: nothing in it runs.
check block-secret-file-read.sh allow $'cat > /tmp/a <<EOF\nnever closed\ncat .env'
check block-secret-file-read.sh deny $'cat > /tmp/a <<EOF\nharmless\nEOF\ncat secrets.txt'
check block-secret-file-read.sh deny $'ssh host sh -s <<\'EOF\'\ncat .env\nEOF'
check block-secret-file-read.sh deny 'cat ~/.git-credentials'
# mihomo provider caches: quoted JSON passwords slip past -v filters and text masks.
check block-secret-file-read.sh deny "rg -o '\"name\":\"HK[^}]*' ~/applications/mihomo/proxy_provider/local.yaml"
check block-secret-file-read.sh deny 'rg -v password proxy_provider/local.yaml'
check block-secret-file-read.sh deny 'cd ~/applications/mihomo && jq . proxy_provider/local.yaml'
check block-secret-file-read.sh allow 'fd . ~/applications/mihomo/proxy_provider'
check block-secret-file-read.sh allow 'ctl.sh home proxy HY2'
# A quoted alternation is text, not a command word.
check block-env-dump.sh allow 'rg -i "cli|env|gh" hooks/'
check block-env-dump.sh deny 'declare -x'
check block-env-dump.sh deny 'typeset -p'
check block-env-dump.sh deny '/usr/bin/env'
# A printed secret value, quoted or not.
check block-env-dump.sh deny 'echo $GITHUB_TOKEN'
check block-env-dump.sh deny 'echo "$ANTHROPIC_API_KEY"'
check block-env-dump.sh deny 'printf "%s" "${MY_SECRET}"'
check block-env-dump.sh allow 'echo $HOME'
check block-env-dump.sh allow 'gh auth status'
check block-env-dump.sh deny "sh -c 'env'"
check block-env-dump.sh deny 'printenv; echo done'
check block-env-dump.sh deny "'env'"
# An option is not a target, so these still dump.
check block-env-dump.sh deny 'env -0'
check block-env-dump.sh deny 'printenv -0'
check block-env-dump.sh deny 'export'
check block-env-dump.sh deny 'declare'
# A named target is a lookup, not a dump.
check block-env-dump.sh allow 'declare -p FOO'
check block-env-dump.sh allow 'export FOO=1'
check block-env-dump.sh allow 'set -x'
# A secret print inside shell control flow.
check block-env-dump.sh deny 'if echo $GITHUB_TOKEN; then :; fi'
check block-env-dump.sh deny 'echo "${GH_TOKEN}"'

# Isolate the Anvil probe cache from the real one (/tmp/.anvil-probe-$UID) so
# these checks never race a live Claude Code session's redirect decisions,
# and clean up via trap so an interrupted run can't leave stale state behind.
export ANVIL_PROBE_CACHE
ANVIL_PROBE_CACHE=$(mktemp "${TMPDIR:-/tmp}/anvil-probe-test.XXXXXX")
trap 'rm -f "$ANVIL_PROBE_CACHE"; rm -rf "$fixtures"' EXIT

# The modern-CLI hook now owns exact `find` and `sed -i` rewrites.
echo no > "$ANVIL_PROBE_CACHE"

decision deny  'grep -r foo .'
# A plain ls maps to eza; -h is dropped and -A becomes -a. Any other ls runs as typed.
rewrite 'eza' 'ls'
rewrite 'eza -la' 'ls -la'
rewrite 'eza -la src' 'ls -lah src'
rewrite 'eza -a ~/Projects' 'ls -A ~/Projects'
decision allow 'ls -t'
decision allow 'ls a b'
decision allow 'ls -la | head'
decision allow 'ls $(pwd)'
rewrite 'fd --glob x .' 'find . -name x'
rewrite "fd --glob '*.ts' src" "find src -name '*.ts'"
decision allow 'find . -maxdepth 3'
decision allow 'find . -inum 42'
decision allow 'find . -exec rm {} ;'
rewrite "sd 'a' 'b' f" 'sed -i s/a/b/ f'
rewrite "sd 'a' 'b' f" "sed -i 's/a/b/' f"
decision allow 'sed -i s/a/b/g f'
decision allow 'git grep foo'
decision allow 'rg foo'
# Downstream pipeline use stays allowed, including the stderr-carrying pipe.
decision allow 'ps aux | grep claude'
decision allow 'cat f | sed s/a/b/'
decision allow 'cat f |& grep x'
# Grouping punctuation must not swallow the pipe that precedes it, and must
# not manufacture an exemption where the preceding operator was not a pipe.
decision allow 'ps aux | (grep x)'
decision deny  'true; (grep foo f)'
decision deny  '(grep foo f)'
decision deny  'ps aux | (true; grep x)'
# `||` and `&&` start a fresh command, so they are not a pipeline exemption.
decision deny  'true || grep foo f'
decision deny  'true && grep foo f'
# Sharing lib.sh closed what the old inline splitter missed: a nested shell
# payload and the transparent `command`/`env` prefixes.
decision deny  "bash -c 'grep foo f'"
decision deny  'command grep foo f'
decision deny  'env grep foo f'
# The old script also strips env assignments and leading paths.
decision deny  'FOO=1 grep foo f'
decision deny  '/usr/bin/grep foo f'
# A leading shell keyword must not hide the command word.
decision deny  'if grep foo f; then echo x; fi'
decision deny  'while grep foo f; do :; done'
decision deny  '! grep foo f'
decision deny  'if FOO=1 /usr/bin/grep foo f; then :; fi'
decision allow 'if rg foo; then echo x; fi'
# A multi-line sd pattern can match nothing and still exit 0.
decision deny  $'sd -F \'a\nb\' \'c\' f'
decision deny  $'true && sd \'x\' \'y\nz\' f'
decision allow "sd -F 'a' 'b' f"
decision allow $'sd \'a\' \'b\' f\nrg b f'

check gh-json.sh deny 'gh pr view 12'
check gh-json.sh deny 'gh -R o/r issue list'
check gh-json.sh deny 'gh api --paginate repos/o/r/issues'
check gh-json.sh allow 'gh pr view 12 --json title,state'
check gh-json.sh allow 'gh pr diff 12'
check gh-json.sh allow 'rg "gh pr view" docs/'
check gh-json.sh deny 'gh release list'
check gh-json.sh deny 'gh search prs --state open'
check gh-json.sh allow 'gh search prs --state open --json number,title'
# A run log has no JSON form, like `gh pr diff`.
check gh-json.sh allow 'gh run view 123 --log'
check gh-json.sh allow 'gh run view 123 --log-failed'
check gh-json.sh allow 'gh pr create --body-file ./b'
# Each gh read is judged on its own.
check gh-json.sh deny 'gh pr view 1; gh pr view 2 --json title'
check gh-json.sh deny 'gh run view 1 --log; gh pr view 2'
check gh-json.sh allow 'gh pr view 1 --json title; gh run view 2 --log'
check gh-json.sh deny "gh pr 'view' 1"
check gh-json.sh deny 'env gh pr view 1'
# Other JSON-capable read families.
check gh-json.sh deny 'gh label list'
check gh-json.sh deny 'gh variable list'
check gh-json.sh deny 'gh secret list'
check gh-json.sh allow 'gh label list --json name'

# Without the modern tools on PATH, the classic commands run as typed.
classic 'grep -r foo .'
classic 'ls -la'
classic 'find . -name x'
classic 'sed -i s/a/b/ f'

# Flip the isolated probe cache to 'ok' for the Anvil checks.
REDIRECT=./redirect-to-anvil.sh
echo ok > "$ANVIL_PROBE_CACHE"

redirect_decision() { # redirect_decision <expected: allow|deny> <tool_name> <tool_input-json>
  checks=$((checks + 1))
  actual=$(verdict "$(printf '{"tool_name":"%s","tool_input":%s}' "$2" "$3" | "$REDIRECT" 2>/dev/null)")
  if [ "$actual" != "$1" ]; then
    echo "FAIL redirect-to-anvil.sh: expected $1, got $actual for: $2 $3"
    fail=$((fail + 1))
  fi
}

redirect_decision deny  Bash '{"command":"git status"}'
redirect_decision allow Bash '{"command":"git push origin main"}'
redirect_decision deny  Bash '{"command":"git diff --stat"}'
redirect_decision allow Bash '{"command":"git diff --cached --check"}'
# A command of only Git reads (plus cd and pipeline consumers) goes to Anvil.
redirect_decision deny  Bash '{"command":"cd /tmp/repo && git status && git log -3"}'
redirect_decision deny  Bash '{"command":"git log -1 --format=%s | head -1"}'
redirect_decision deny  Bash '{"command":"git rev-parse HEAD || git status"}'
# Other work in the chain means no Anvil call can replace it, so the read runs.
redirect_decision allow Bash '{"command":"git diff --check; git status"}'
redirect_decision allow Bash '{"command":"git add f && git commit -m x && git push && git status --porcelain"}'
redirect_decision allow Bash '{"command":"cd /tmp/repo && git rev-parse --show-toplevel; rg -n foo f.md"}'
redirect_decision allow Bash '{"command":"git fetch -q origin && git log -1 HEAD..origin/main"}'
redirect_decision allow Bash '{"command":"git status || echo failed"}'
# A pipe stage or redirect with its own effect is other work too.
redirect_decision allow Bash '{"command":"git status | tee /tmp/status"}'
redirect_decision allow Bash '{"command":"git log -3 > /tmp/log.txt"}'
redirect_decision allow Bash '{"command":"git log -3 | head -1 >> /tmp/log.txt"}'
redirect_decision deny  Bash '{"command":"git status --porcelain 2>/dev/null | wc -l"}'
# Global options must not hide the subcommand.
redirect_decision deny  Bash '{"command":"git --no-pager diff"}'
redirect_decision deny  Bash '{"command":"git -C /tmp/repo status --porcelain"}'
redirect_decision deny  Bash '{"command":"git -c color.ui=never log -3"}'
redirect_decision deny  Bash '{"command":"git -C /tmp/repo branch"}'
redirect_decision allow Bash '{"command":"git -C /tmp/repo branch -d old"}'
redirect_decision deny  Bash '{"command":"git -C /tmp/repo worktree list"}'
redirect_decision allow Bash '{"command":"git -C /tmp/repo push"}'
redirect_decision allow Bash '{"command":"git --no-pager diff -- hooks/lib.sh"}'
redirect_decision allow Bash '{"command":"git"}'
redirect_decision deny  Bash '{"command":"curl https://example.com"}'
redirect_decision deny  Bash '{"command":"curl -I https://example.com"}'
redirect_decision allow Bash '{"command":"curl -X POST https://example.com -d foo"}'
# Flags placed after the URL must still be scanned, not just token 2.
redirect_decision allow Bash '{"command":"curl https://example.com --head -o out.html"}'
redirect_decision allow Bash '{"command":"curl https://example.com -X POST -d foo"}'
redirect_decision deny  Bash '{"command":"curl -fsSL https://example.com"}'
redirect_decision deny  Bash '{"command":"curl --silent --location https://example.com"}'
redirect_decision allow Bash '{"command":"curl -6 -s https://example.com"}'
redirect_decision allow Bash '{"command":"curl -s -m 5 https://example.com/"}'
redirect_decision allow Bash '{"command":"curl --resolve a.example.com:443:192.0.2.10 https://a.example.com/"}'
redirect_decision allow Bash '{"command":"curl -sk -w %{http_code} https://example.com"}'
redirect_decision deny  Bash '{"command":"curl -s https://example.com >/dev/null"}'
redirect_decision deny  Bash '{"command":"curl -s https://example.com 2>/dev/null"}'
redirect_decision allow Bash '{"command":"curl -s -m 5 https://example.com >/dev/null"}'
redirect_decision allow Bash '{"command":"sed -i s/a/b/ f.txt"}'
redirect_decision allow Bash '{"command":"sed -n 1,5p f.txt"}'
redirect_decision allow Read '{"file_path":"./x.org"}'
redirect_decision allow Read '{"file_path":"./x.md"}'
redirect_decision allow Bash '{"command":"echo ok; sed -i s/a/b/ f.txt"}'
redirect_decision allow Bash '{"command":"FOO=1 sed -i s/a/b/ f.txt"}'
redirect_decision allow Bash '{"command":"/usr/bin/sed -i s/a/b/ f.txt"}'

# A distributed skill copy carries a marker naming its source; edits go there.
copy_root=$(mktemp -d "${TMPDIR:-/tmp}/skill-copy-test.XXXXXX")
trap 'rm -f "$ANVIL_PROBE_CACHE"; rm -rf "$copy_root" "$fixtures"' EXIT
mkdir -p "$copy_root/copy/refs" "$copy_root/plain"
printf '%s\nskill-matrix\n' "$copy_root/source" > "$copy_root/copy/.agent-scripts-copy"

copy_decision() { # copy_decision <expected: allow|deny> <tool_name> <tool_input-json>
  checks=$((checks + 1))
  actual=$(verdict "$(printf '{"tool_name":"%s","tool_input":%s}' "$2" "$3" | ./block-skill-copy-edit.sh 2>/dev/null)")
  if [ "$actual" != "$1" ]; then
    echo "FAIL block-skill-copy-edit.sh: expected $1, got $actual for: $2 $3"
    fail=$((fail + 1))
  fi
}

copy_decision deny  Edit  "{\"file_path\":\"$copy_root/copy/SKILL.md\"}"
copy_decision deny  Write "{\"file_path\":\"$copy_root/copy/refs/notes.md\"}"
copy_decision deny  mcp__anvil-emacs-eval__file-replace-string "{\"path\":\"$copy_root/copy/SKILL.md\"}"
# data-set-path: `file` is the file, `path` is a JSON key path.
copy_decision deny  mcp__anvil-emacs-eval__data-set-path "{\"file\":\"$copy_root/copy/x.json\",\"path\":\"a.b\"}"
copy_decision deny  mcp__anvil-emacs-eval__file-batch-across "{\"file-ops-json\":\"[{\\\"path\\\":\\\"$copy_root/plain/a.md\\\"},{\\\"path\\\":\\\"$copy_root/copy/SKILL.md\\\"}]\"}"
# sexp rename/replace-call: `scope` is a file, a comma list, or a directory.
copy_decision deny  mcp__anvil-emacs-eval__sexp-rename-symbol "{\"scope\":\"$copy_root/plain/a.el, $copy_root/copy/b.el\"}"
copy_decision deny  mcp__anvil-emacs-eval__sexp-replace-call "{\"scope\":\"$copy_root/copy/refs\"}"
copy_decision deny  mcp__anvil-emacs-eval__sexp-rename-symbol "{\"scope\":\"$copy_root\"}"
copy_decision allow mcp__anvil-emacs-eval__sexp-rename-symbol "{\"scope\":\"$copy_root/plain\"}"
copy_decision allow mcp__anvil-emacs-eval__sexp-rename-symbol "{\"scope\":\"project\"}"
# A copy under a gitignored directory is still found.
git -C "$copy_root" init -q && echo '/copy/' > "$copy_root/.gitignore"
copy_decision deny  mcp__anvil-emacs-eval__sexp-rename-symbol "{\"scope\":\"$copy_root\"}"
copy_decision allow Edit  "{\"file_path\":\"$copy_root/plain/SKILL.md\"}"
copy_decision allow mcp__anvil-emacs-eval__data-set-path "{\"file\":\"$copy_root/plain/x.json\",\"path\":\"a.b\"}"
reason=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$copy_root/copy/refs/notes.md" | ./block-skill-copy-edit.sh | jq -r '.hookSpecificOutput.permissionDecisionReason')
checks=$((checks + 1)); [[ $reason == *"$copy_root/source/refs/notes.md"* ]] || { echo "FAIL block-skill-copy-edit.sh: reason does not name the source file: $reason"; fail=$((fail + 1)); }

# readonly-search.sh: one rg, fd, or eza command, plain words and single quotes only.
ro=readonly-search.sh
check $ro allow "rg -n 'foo|bar' src"; check $ro allow "fd -e md docs"; check $ro allow "eza -l"
check $ro allow "rg 'a\$' ."; check $ro allow "fd -g '*.md' ."; check $ro allow "rg -x foo"
check $ro allow "rg --pre-glob '*.gz' foo"
check $ro deny "rg foo; rm x"; check $ro deny "rg foo | sh"; check $ro deny "rg foo > out"
check $ro deny 'rg $(rm x)'; check $ro deny 'rg `rm x`'; check $ro deny "rm x"; check $ro deny ""
check $ro deny "rg --pre sh foo"; check $ro deny "rg '--pre' sh foo"; check $ro deny "rg --pre=sh foo"
check $ro deny "fd -x rm"; check $ro deny "fd -Hx rm"; check $ro deny "fd --exec=rm"; check $ro deny "fd -X rm"
check $ro deny "rg foo *(e:'rm x':)"; check $ro deny 'rg "a"'; check $ro deny 'rg \" ; rm x ; \"'
check $ro deny "rg \$'\\'' ; rm x ; ''"; check $ro deny "FOO=1 rg x"; check $ro deny "rg foo =(rm x)"
check $ro deny "rg foo && rm x"; check $ro deny $'rg foo\nrm x'; check $ro deny "rg foo & rm x"; check $ro deny "rgx foo"

# A heredoc body is data: a line that starts with `set`, `env`, `git reset --hard`, or
# `grep` is not a command. This holds for every way to write the opener, in every hook
# that parses with read_command.
hd_body=$'set\nenv\nexport\nprintenv\ndeclare -x\ngit reset --hard\ngit status\ngh pr view 1\ngrep -r x .'
for hd in "<<'EOF'" '<<"EOF"' '<<\EOF' '<<EOF' '<< EOF'; do
  hd_cmd="cat >> /tmp/x.md $hd"$'\n'"$hd_body"$'\nEOF'
  for h in block-env-dump.sh block-git-destructive.sh gh-json.sh block-secret-file-read.sh; do
    check $h allow "$hd_cmd"
  done
  decision allow "$hd_cmd"
  check block-env-dump.sh deny "$hd_cmd"$'\nenv'          # a command after the end word is still read
  check block-git-destructive.sh deny "$hd_cmd"$'\ngit reset --hard'
done
check block-env-dump.sh allow $'cat > /tmp/i.sh <<-EOF\n\tset\n\tenv\n\tEOF'
check block-env-dump.sh deny $'cat > /tmp/i.sh <<-EOF\n\tset\n\tEOF\nenv'
# The multi-line `sd` check reads the raw command, so it skips a body too.
decision allow $'cat > f <<\'EOF\'\nsd \'a\nb\' file\nEOF'
decision deny $'cat > f <<\'EOF\'\nx\nEOF\nsd \'a\nb\' file'
# Windows: a CRLF command ends the heredoc at `EOF\r`.
check block-git-destructive.sh allow $'cat > /tmp/x <<EOF\r\ngit reset --hard\r\nEOF\r\n'
check block-git-destructive.sh deny $'cat > /tmp/x <<EOF\r\nx\r\nEOF\r\ngit reset --hard\r\n'
# Two heredocs on one line: both bodies are data.
check block-env-dump.sh allow $'cat <<\'A\' <<\'B\'\nset\nA\nenv\nB'
check block-env-dump.sh deny $'cat <<\'A\' <<\'B\'\nset\nA\nenv\nB\nenv'
# The command line that opens the heredoc is still checked.
check block-git-destructive.sh deny $'git reset --hard <<\'EOF\'\nx\nEOF'
check block-env-dump.sh deny $'env -0 && cat <<\'EOF\'\nx\nEOF'
check block-env-dump.sh deny $'cat <<EOF $GITHUB_TOKEN\nx\nEOF'
# An unquoted body expands: `$(...)`, a backtick, and `$VAR` still run or print.
check block-git-destructive.sh deny $'cat <<EOF\n$(git reset --hard)\nEOF'
check block-git-destructive.sh deny $'cat <<EOF\n`git reset --hard`\nEOF'
check block-env-dump.sh deny $'cat <<EOF\necho $GITHUB_TOKEN\nEOF'
check block-env-dump.sh allow $'cat <<\'EOF\'\necho $GITHUB_TOKEN\nEOF'
check block-secret-file-read.sh deny $'cat <<EOF\n$(cat .env)\nEOF'
check block-secret-file-read.sh deny $'cat >&2 <<EOF\n$(cat .env)\nEOF'
check block-secret-file-read.sh allow $'cat > /tmp/x.sh <<EOF\nexport TOKEN_FILE=$HOME/.token\nEOF'
check block-secret-file-read.sh allow $'git commit -F - <<\'EOF\'\nnote: cat .env is blocked\nEOF'
# A shell reads the body of its heredoc as commands, so those lines stay checked.
check block-git-destructive.sh deny $'ssh h sh -s <<\'EOF\'\ngit reset --hard\nEOF'
check block-git-destructive.sh deny $'ssh h <<\'EOF\'\ngit reset --hard\nEOF'
check block-git-destructive.sh deny $'cat <<\'EOF\' | bash\ngit reset --hard\nEOF'
check block-env-dump.sh deny $'bash <<EOF\nenv\nEOF'
# `<<` that is not a heredoc opener hides nothing: here-string, quoted text, arithmetic.
check block-env-dump.sh allow 'cat <<< set'
check block-git-destructive.sh deny $'cat <<< x\ngit reset --hard'
check block-git-destructive.sh deny $'git commit -m "mention <<EOF here"\ngit reset --hard'
check block-git-destructive.sh deny $'git commit -m "title\n\nmention <<EOF here"\ngit reset --hard'
check block-git-destructive.sh deny $'echo $((1<<3))\ngit reset --hard'
check block-git-destructive.sh deny $'# use <<EOF here\ngit reset --hard'
check block-git-destructive.sh deny $'echo hi # <<EOF\ngit reset --hard'

# context-handoff.sh: warns once in herdr when the status line fill reaches 36%.
ctx_tmp=$(mktemp -d); mkdir "$ctx_tmp/claude-ctx"
handoff() { # handoff <expected: warn|none> <herdr-env> <fill or empty>
  checks=$((checks + 1))
  [ -n "$3" ] && echo "$3" > "$ctx_tmp/claude-ctx/s1"
  out=$(echo '{"session_id":"s1"}' | TMPDIR="$ctx_tmp" HERDR_ENV="$2" ./context-handoff.sh 2>/dev/null)
  actual=$(jq -r 'if .hookSpecificOutput.additionalContext then "warn" else "none" end' <<<"${out:-null}")
  if [ "$actual" != "$1" ]; then
    echo "FAIL context-handoff.sh: expected $1, got $actual for herdr=$2 fill=$3"
    fail=$((fail + 1))
  fi
}
handoff none 1 35; handoff none 0 50; handoff warn 1 36; handoff none 1 80
rm -rf "$ctx_tmp"

# format-json.sh must write LF. A native jq.exe on Windows writes CRLF unless lib.sh adds -b.
printf '{"a":1,"b":[2,3]}\n' > "$fj/x.json"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$fj/x.json" | ./format-json.sh 2>/dev/null
checks=$((checks + 1))
lines=$(wc -l < "$fj/x.json"); crs=$(tr -cd '\r' < "$fj/x.json" | wc -c)
if [ "$((lines))" -lt 3 ] || [ "$((crs))" -ne 0 ]; then
  echo "FAIL format-json.sh: expected a formatted file with LF only, got $((lines)) lines and $((crs)) CR"
  fail=$((fail + 1))
fi

echo "$((checks - fail)) passed, $fail failed"
exit $((fail > 0))
