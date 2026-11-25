#!/bin/bash
# Shared command parsing for the PreToolUse Bash hooks.
#
# read_command sets SEGMENTS and SEGMENT_SEPARATORS. Each normalised segment
# starts at its command word. Its matching separator is the operator before it.
#
# The pipeline is: drop heredoc bodies -> unwrap nested shells -> remove remaining
# quoted spans -> split on the shell operators -> normalise each segment.

# Windows: a native jq.exe writes CRLF for every newline, which breaks line
# parsing (a heredoc end marker becomes `EOF\r`). -b keeps LF.
case $OSTYPE in msys* | cygwin*) jq() { command jq -b "$@"; } ;; esac

# Constant payload, so the common case (every guard allowing) spawns no jq.
guard_allow() {
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
}

guard_deny() {
  jq -n --arg reason "$1 Nothing in this command ran; re-run any other parts." '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

guard_rewrite() {
  jq -n --arg command "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      updatedInput: {command: $command}
    }
  }'
  exit 0
}

# Replaces the quoted payload of `bash -c '...'` with a separate segment, so the
# payload is inspected as commands instead of being discarded as a string.
# Handles a leading path (/bin/sh) and any flag cluster (-lc, -e -u -c).
# Each pass removes one quote pair, so the loop always ends.
unwrap_shell() {
  local c=$1 sq="'" quoted payload
  local re='(^|[[:space:]])([^[:space:]]*/)?((ba|z|k|da)?sh)(([[:space:]]+-[A-Za-z]+)*)[[:space:]]+("[^"]*"|'"$sq"'[^'"$sq"']*'"$sq"')'
  while [[ $c =~ $re ]]; do
    quoted=${BASH_REMATCH[7]}
    payload=${quoted:1:${#quoted}-2}
    c=${c/"$quoted"/"; $payload ;"}
  done
  printf '%s' "$c"
}

# Removes quote syntax. A span holding one plain token keeps its text, because
# `git 'push'` still runs push. A span holding a space or a shell metacharacter
# is data and goes away, so rg -i "cli|env|gh" cannot read as a bare `env`.
# Runs after unwrap_shell, so a real nested command has already been taken out.
strip_quotes() {
  local c=$1 sq="'" span body
  while [[ $c =~ (\"[^\"]*\"|$sq[^$sq]*$sq) ]]; do
    span=${BASH_REMATCH[1]}
    body=${span:1:${#span}-2}
    [[ $body =~ ^[A-Za-z0-9_.:/=@$%{}+-]+$ ]] || body=" "
    c=${c/"$span"/"$body"}
  done
  printf '%s' "$c"
}

# Strips what hides a command word: a shell keyword (`if ls`), an environment
# assignment (`FOO=1 git`), and a leading path (`/usr/bin/git`).
normalize_segment() {
  local s=$1 first rest
  while [[ $s =~ ^[[:space:]]*(if|then|elif|else|do|while|until|!)[[:space:]]+(.*)$ ]]; do
    s=${BASH_REMATCH[2]}
  done
  while [[ $s =~ ^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+(.*)$ ]]; do
    s=${BASH_REMATCH[1]}
  done
  # These run the next word as the command, so they must not hide it.
  while [[ $s =~ ^[[:space:]]*(command|builtin|exec|nohup|time|stdbuf|nice)([[:space:]]+-[^[:space:]]+)*[[:space:]]+(.*)$ ]]; do
    s=${BASH_REMATCH[3]}
  done
  # `env` is transparent only when a command follows its options. `env -0` and
  # bare `env` keep their name, so block-env-dump still sees the dump.
  if [[ $s =~ ^[[:space:]]*env[[:space:]]+(.*)$ ]]; then
    local t=${BASH_REMATCH[1]}
    while [[ $t =~ ^(-[iu][[:space:]]+[^[:space:]]+|--unset=[^[:space:]]+|-[a-zA-Z]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*)[[:space:]]+(.*)$ ]]; do
      t=${BASH_REMATCH[2]}
    done
    [[ -n $t && $t != -* ]] && s=$t
  fi
  # `read` trims both ends and splits off the first word.
  read -r first rest <<<"$s"
  printf '%s' "${first##*/}${rest:+ $rest}"
}

# Cached Anvil probe (60s TTL) — avoids spawning emacsclient on every hook fire.
# Returns 0 if the Emacs daemon answers, 1 otherwise. Shared by any hook that
# needs to know whether an Anvil MCP redirect is available before it fires.
# ANVIL_PROBE_CACHE overrides the cache path (tests use an isolated file so
# they never race the real probe a concurrent Claude Code session relies on).
anvil_available() {
  local cache="${ANVIL_PROBE_CACHE:-/tmp/.anvil-probe-${UID:-$(id -u)}}"
  if [[ -f $cache ]]; then
    local mtime now
    # GNU first: GNU `stat -f` prints file system data and exits 1, not an mtime.
    mtime=$(/usr/bin/stat -c %Y "$cache" 2>/dev/null || /usr/bin/stat -f %m "$cache" 2>/dev/null || echo 0)
    [[ $mtime =~ ^[0-9]+$ ]] || mtime=0
    now=$(date +%s)
    if (( now - mtime < 60 )); then
      [[ $(cat "$cache") == ok ]]
      return
    fi
  fi
  # --timeout bounds a stuck-but-listening daemon; without it a blocked
  # socket hangs the probe (and every hook waiting on it) indefinitely.
  if command -v emacsclient >/dev/null 2>&1 && emacsclient --timeout=2 -e t >/dev/null 2>&1; then
    echo ok > "$cache"; return 0
  fi
  echo no > "$cache"; return 1
}

# True when the command runs a shell or a script, so a heredoc body may run as commands: a shell
# word (`sh`, `bash`, `ssh`, `su`, `source`, `eval`), `sudo -i` or `sudo -s`, a `.` command word, or
# `./file` and `/path/file.sh` in command position. Any letter case. The text is the command without
# its heredoc bodies, so a word inside a body does not count. A false yes only keeps a body checked.
runs_script() {
  local t=$1 ncm rc=1 cmd=$'(^|[;&|(`]|\n)[[:space:]]*'
  local shell='(^|[^[:alnum:]_.-])(ssh|(ba|z|k|da|c|tc)?sh|fish|su|source|eval)([^[:alnum:]_-]|$)'
  local sudo='(^|[^[:alnum:]_.-])sudo[[:space:]]([^;&|]*[[:space:]])?-[A-Za-z]*[is]([[:space:]]|$)'
  local dot=$cmd'\.[[:space:]]'
  local script=$cmd'(\./[^[:space:];&|()<>]+|[~/][^[:space:];&|()<>]*\.sh)([[:space:]]|[;&|()]|$)'
  shopt -q nocasematch && ncm=-s || ncm=-u
  shopt -s nocasematch
  if [[ $t =~ $shell || $t =~ $sudo || $t =~ $dot || $t =~ $script ]]; then rc=0; fi
  shopt $ncm nocasematch
  return $rc
}

# Removes the body and end word of each heredoc: its lines are data, not commands. The
# line that opens it stays. A body stays when its lines can still run or print:
#   - the command runs a shell or a script anywhere (see runs_script): then every body stays;
#   - it is unquoted (`<<EOF`) and expands, so a line with `$` or a backtick stays.
# QUIET is an optional ERE. An opening line that matches it writes to a file, so its body is
# dropped whatever runs later (block-secret-file-read: a body that is written prints nothing).
# A `\` that ends a line joins the next line first, as bash does, so the opening line is whole.
# The end word is the word without its quotes (`E"O"F` ends at `EOF`). The scan skips quoted text,
# comments, and `<<<`. Like bash, it treats a heredoc with no end word as running to the end.
# shortcut: a heredoc inside `bash -c '...'` keeps its body (it may still block), and
# `$((a<<b))` with a letter operand reads as a heredoc; upgrade by calling this again
# after unwrap_shell, and by tracking `$((`.
strip_heredocs() {
  local c=$1 quiet=${2:-} keepall=0 sq="'" pass q pend out outside line nxt t rec mode end w i ch rest
  local open=$'^<<(-?)[[:space:]]*(([A-Za-z_]|\'[^\']*\'|"[^"]*"|\\\\.)([^[:space:];&|()<>\'"\\\\`$]|\'[^\']*\'|"[^"]*"|\\\\.)*)'
  [[ $c == *'<<'* ]] || { printf '%s' "$c"; return; }
  for pass in 1 2; do
    q="" pend="" out="" outside=""
    while IFS= read -r line || [[ -n $line ]]; do
      if [[ -n $pend ]]; then
        rec=${pend%%$'\n'*} mode=${rec%%:*} end=${rec#*:}
        t=${line%$'\r'} # a CRLF command ends the heredoc at `EOF\r`
        t=${t#"${t%%[![:space:]]*}"} # `<<-` strips tabs; stripping any blank only errs toward checking more
        [[ $t == "$end" ]] && pend=${pend#*$'\n'}
        if { ((keepall)) && [[ $mode != quiet ]]; } || [[ $mode == expand && ( $line == *'$'* || $line == *'`'* ) ]]; then
          out+=$line$'\n'
        fi
        continue
      fi
      for ((i = 0; i < ${#line}; i++)); do
        ch=${line:i:1}
        if [[ $q == "'" ]]; then
          [[ $ch == "'" ]] && q=
        elif [[ $ch == '\' ]]; then
          if ((i == ${#line} - 1)) && { IFS= read -r nxt || [[ -n $nxt ]]; }; then
            line=${line:0:i}$nxt
            i=$((i - 1))
          else
            i=$((i + 1))
          fi
        elif [[ -n $q ]]; then
          [[ $ch == '"' ]] && q=
        elif [[ $ch == "'" || $ch == '"' ]]; then
          q=$ch
        elif [[ $ch == '#' ]] && { ((i == 0)) || [[ ${line:i-1:1} == [[:space:]] ]]; }; then
          break
        elif [[ $ch == '<' ]]; then
          rest=${line:i}
          if [[ $rest == '<<<'* ]]; then
            i=$((i + 2))
          elif [[ $rest =~ $open ]]; then
            w=${BASH_REMATCH[2]}
            i=$((i + ${#BASH_REMATCH[0]} - 1))
            end=${w//$sq/}
            end=${end//\"/}
            end=${end//\\/}
            mode=expand
            [[ $w != "$end" ]] && mode=drop
            [[ -n $quiet && $line =~ $quiet ]] && mode=quiet
            pend+=$mode:$end$'\n'
          elif [[ $rest == '<<'* ]]; then
            i=$((i + 1))
          fi
        fi
      done
      out+=$line$'\n'
      outside+=$line$'\n'
    done <<<"$c"
    if ((pass == 1)) && runs_script "$outside"; then keepall=1; else break; fi
  done
  printf '%s' "${out%$'\n'}"
}

read_command() {
  local c seg="" separator="" operator char next i
  c=$(strip_quotes "$(unwrap_shell "$(strip_heredocs "$(jq -r '.tool_input.command // empty' <<<"$1")")")")
  SEGMENTS=()
  SEGMENT_SEPARATORS=()

  for ((i = 0; i < ${#c}; i++)); do
    char=${c:i:1}
    case $char in
      ';'|'&'|'|'|'('|')'|'`'|$'\n')
        if [[ -n ${seg//[[:space:]]/} ]]; then
          seg=$(normalize_segment "$seg")
          if [[ -n $seg ]]; then
            SEGMENTS+=("$seg")
            SEGMENT_SEPARATORS+=("$separator")
          fi
        fi
        seg=""
        operator=$char
        next=${c:i+1:1}
        if [[ $char == '&' && $next == '&' ]] \
          || [[ $char == '|' && ( $next == '|' || $next == '&' ) ]]; then
          operator+=$next
          i=$((i + 1))
        fi
        # `(` and `)` group commands, they do not separate them. A subshell
        # around a pipeline stage (`producer | (rg x)`) must keep the pipe as
        # the separator, or the downstream-pipeline exemption never applies.
        [[ $char == '(' || $char == ')' ]] || separator=$operator
        ;;
      *) seg+=$char ;;
    esac
  done

  if [[ -n ${seg//[[:space:]]/} ]]; then
    seg=$(normalize_segment "$seg")
    if [[ -n $seg ]]; then
      SEGMENTS+=("$seg")
      SEGMENT_SEPARATORS+=("$separator")
    fi
  fi
  return 0
}
