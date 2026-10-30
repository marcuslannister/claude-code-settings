#!/bin/bash
set -euo pipefail
# Blocks printing a file that holds secrets (AGENTS.MD: secrets): compose files, .env files,
# and any file named *secret*, *token*, *credential*, or *passw*. Also `docker compose config`,
# which prints the expanded environment.
# This hook reads the raw command, not the parsed segments: read_command drops quoted text,
# and the reader often sits inside `ssh host '...'`.
# A filter such as `| rg -v 'SECRET|TOKEN'` marks the output as redacted and passes.
source "$(dirname "$0")/lib.sh"
command=$(jq -r '.tool_input.command // empty' <<<"$(cat)")
kept= end=
while IFS= read -r line; do
  if [[ -n $end ]]; then
    [[ ${line#"${line%%[![:space:]]*}"} == "$end" ]] && end=
    continue
  fi
  kept+=$line$'\n'
  [[ $line =~ ^[[:space:]]*cat[[:space:]]*\>\>?.*\<\<-?[[:space:]]*[\'\"]?([A-Za-z_]+) ]] && end=${BASH_REMATCH[1]}
done <<<"$command"
command=$kept

SQ="'"
NAME="[^[:space:];&|\"$SQ]*"
READER='(^|[;&|(`[:space:]])(cat|bat|head|tail|less|more|nl)[[:space:]]+([^;&|]*[[:space:]])?'
SECRET_FILE="$NAME(compose$NAME\\.ya?ml|\\.env$NAME|(secret|token|credential|passw)$NAME)"
REDACTED='(rg|grep)[[:space:]]+-[A-Za-z]*v'

[[ $command =~ $REDACTED ]] && guard_allow

if [[ $command =~ $READER$SECRET_FILE ]] \
  || [[ $command =~ docker[[:space:]]+compose[[:space:]]+([^;&|]*[[:space:]])?config([[:space:]]|$) ]]; then
  guard_deny "Blocked: this command prints a file that can hold secret values.
Never reveal a secret value, not even an internal one. Filter the values out, for example \`rg -v 'SECRET|TOKEN|KEY|PASSWORD' <file>\`, or print the key names only."
fi

guard_allow
