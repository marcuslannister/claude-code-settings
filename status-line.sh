#!/bin/bash
#
# Claude Code Status Line
# A clean, informative status bar for Claude Code CLI
#
# ─────────────────────────────────────────────────────────────────────────────
# Dependencies
# ─────────────────────────────────────────────────────────────────────────────
#
#   Required:
#     jq        JSON parser for reading Claude's input
#               Install: brew install jq (macOS) | apt install jq (Linux)
#     curl      Used by the API usage segment (silently skipped if missing)
#
#   Optional:
#     git       For branch/dirty status (skip if not in a repo)
#     security  macOS Keychain reader for OAuth token (built-in on macOS)
#
#   Built-in (no install needed):
#     awk, grep, stat, date, basename
#
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

BAR_WIDTH=5
CONTEXT_WARN_PCT=70
CONTEXT_CRIT_PCT=90
DEFAULT_CTX_LIMIT=200000
CTX_LIMIT_1M=1000000

USAGE_BAR_WIDTH=5
USAGE_CACHE_FILE="$HOME/.claude/.usage-cache.json"
USAGE_CACHE_TTL=300
USAGE_API_URL="https://api.anthropic.com/api/oauth/usage"

# Colors (using $'...' for proper escape sequence interpretation)
C_RESET=$'\033[0m'
C_BOLD_GREEN=$'\033[1;32m'
C_CYAN=$'\033[0;36m'
C_BLUE=$'\033[1;34m'
C_RED=$'\033[0;31m'
C_YELLOW=$'\033[0;33m'
C_GREEN=$'\033[0;32m'
C_MAGENTA=$'\033[0;35m'
C_DIM=$'\033[2m'

# ─────────────────────────────────────────────────────────────────────────────
# Cross-flavor stat/date helpers (GNU coreutils may shadow BSD on macOS)
# ─────────────────────────────────────────────────────────────────────────────

file_mtime() {
    local f=$1 m
    m=$(stat -c %Y "$f" 2>/dev/null)
    [[ "$m" =~ ^[0-9]+$ ]] && { echo "$m"; return 0; }
    m=$(stat -f %m "$f" 2>/dev/null)
    [[ "$m" =~ ^[0-9]+$ ]] && { echo "$m"; return 0; }
    return 1
}

file_btime() {
    local f=$1 m
    m=$(stat -c %W "$f" 2>/dev/null)
    [[ "$m" =~ ^[0-9]+$ && "$m" -gt 0 ]] && { echo "$m"; return 0; }
    m=$(stat -f %B "$f" 2>/dev/null)
    [[ "$m" =~ ^[0-9]+$ && "$m" -gt 0 ]] && { echo "$m"; return 0; }
    file_mtime "$f"
}

fmt_epoch() {
    local epoch=$1 fmt=$2
    date -d "@$epoch" "$fmt" 2>/dev/null || date -r "$epoch" "$fmt" 2>/dev/null
}

parse_rfc3339() {
    local ts=$1 epoch="" clean
    epoch=$(date -d "$ts" +%s 2>/dev/null)
    [[ "$epoch" =~ ^[0-9]+$ ]] && { echo "$epoch"; return 0; }
    clean="${ts%.*}"
    clean="${clean/Z/+0000}"
    if [[ "$clean" =~ ^(.*[+-][0-9]{2}):([0-9]{2})$ ]]; then
        clean="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    fi
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$clean" +%s 2>/dev/null)
    [[ "$epoch" =~ ^[0-9]+$ ]] && echo "$epoch"
}

# ─────────────────────────────────────────────────────────────────────────────
# Input Parsing
# ─────────────────────────────────────────────────────────────────────────────

INPUT=$(cat)

MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "unknown"')
MODEL_ID=$(echo "$INPUT" | jq -r '.model.id // ""')
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // "."')

# Detect 1M context models (Anthropic, Vertex, Bedrock all use "1m" in model ID)
if echo "$MODEL_ID" | grep -qi '1m'; then
    CTX_LIMIT=$CTX_LIMIT_1M
else
    CTX_LIMIT=$DEFAULT_CTX_LIMIT
fi
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')
DIR=$(basename "$CWD")

# ─────────────────────────────────────────────────────────────────────────────
# Git Status
# ─────────────────────────────────────────────────────────────────────────────

get_git_info() {
    git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || return 0

    local branch dirty=""
    branch=$(git -C "$CWD" --no-optional-locks branch --show-current 2>/dev/null)
    [[ -z "$branch" ]] && branch="detached"

    # Check for uncommitted changes
    if ! git -C "$CWD" --no-optional-locks diff --quiet 2>/dev/null ||
       ! git -C "$CWD" --no-optional-locks diff --cached --quiet 2>/dev/null ||
       [[ -n $(git -C "$CWD" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null) ]]; then
        dirty=" ${C_YELLOW}✗"
    fi

    printf " ${C_BLUE}git:(${C_RED}%s${C_BLUE})%s${C_RESET}" "$branch" "$dirty"
}

# ─────────────────────────────────────────────────────────────────────────────
# Token & Usage Metrics
# ─────────────────────────────────────────────────────────────────────────────

get_token_metrics() {
    [[ ! -f "$TRANSCRIPT" ]] && echo "0 0" && return 0

    local in_tok cache_read cache_create out_tok total_in

    in_tok=$(grep -oE '"input_tokens":[0-9]+' "$TRANSCRIPT" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
    cache_read=$(grep -oE '"cache_read_input_tokens":[0-9]+' "$TRANSCRIPT" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
    cache_create=$(grep -oE '"cache_creation_input_tokens":[0-9]+' "$TRANSCRIPT" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
    out_tok=$(grep -oE '"output_tokens":[0-9]+' "$TRANSCRIPT" 2>/dev/null | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}')

    # Default to 0 if empty
    in_tok=${in_tok:-0}
    cache_read=${cache_read:-0}
    cache_create=${cache_create:-0}
    out_tok=${out_tok:-0}

    total_in=$((in_tok + cache_read + cache_create))
    echo "$total_in $out_tok"
}

# ─────────────────────────────────────────────────────────────────────────────
# Session Duration
# ─────────────────────────────────────────────────────────────────────────────

get_session_duration() {
    [[ ! -f "$TRANSCRIPT" ]] && echo "0m" && return 0

    local start_time now elapsed hours mins

    start_time=$(file_btime "$TRANSCRIPT")
    [[ -z "$start_time" || "$start_time" -le 0 ]] 2>/dev/null && echo "0m" && return 0

    now=$(date +%s)
    elapsed=$((now - start_time))
    hours=$((elapsed / 3600))
    mins=$(((elapsed % 3600) / 60))

    if [[ $hours -gt 0 ]]; then
        echo "${hours}h${mins}m"
    else
        echo "${mins}m"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Cost Calculation
# ─────────────────────────────────────────────────────────────────────────────

calculate_cost() {
    local total_in=$1 out_tok=$2
    local price_in price_out

    case "$MODEL_ID" in
        *opus*)   price_in=15;   price_out=75 ;;
        *haiku*)  price_in=0.25; price_out=1.25 ;;
        *)        price_in=3;    price_out=15 ;;  # sonnet/default
    esac

    awk "BEGIN {printf \"%.2f\", ($total_in * $price_in / 1000000) + ($out_tok * $price_out / 1000000)}"
}

# ─────────────────────────────────────────────────────────────────────────────
# API Usage Segment (5-hour utilization, reset clock — Anthropic OAuth only)
# ─────────────────────────────────────────────────────────────────────────────

get_oauth_token() {
    local token="" creds_json creds_file

    if [[ "$OSTYPE" == darwin* ]]; then
        creds_json=$(security find-generic-password -a "$USER" -w -s "Claude Code-credentials" 2>/dev/null)
        [[ -n "$creds_json" ]] && token=$(echo "$creds_json" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    fi

    if [[ -z "$token" ]]; then
        creds_file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json"
        [[ -f "$creds_file" ]] && token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
    fi

    echo "$token"
}

fetch_api_usage() {
    local now mtime age token response

    if [[ -f "$USAGE_CACHE_FILE" ]]; then
        mtime=$(file_mtime "$USAGE_CACHE_FILE")
        now=$(date +%s)
        age=$((now - ${mtime:-0}))
        if [[ $age -lt $USAGE_CACHE_TTL ]]; then
            cat "$USAGE_CACHE_FILE"
            return 0
        fi
    fi

    token=$(get_oauth_token)
    if [[ -z "$token" ]]; then
        [[ -f "$USAGE_CACHE_FILE" ]] && cat "$USAGE_CACHE_FILE"
        return 0
    fi

    response=$(curl -fsS --max-time 2 \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: claude-code" \
        "$USAGE_API_URL" 2>/dev/null)

    if [[ -n "$response" ]] && echo "$response" | jq -e . >/dev/null 2>&1; then
        echo "$response" > "$USAGE_CACHE_FILE"
        echo "$response"
    elif [[ -f "$USAGE_CACHE_FILE" ]]; then
        cat "$USAGE_CACHE_FILE"
    fi
}

format_reset_time() {
    local ts=$1 epoch now diff hours
    [[ -z "$ts" || "$ts" == "null" ]] && { echo "?"; return; }

    epoch=$(parse_rfc3339 "$ts")
    [[ -z "$epoch" ]] && { echo "?"; return; }

    now=$(date +%s)
    diff=$((epoch - now))
    [[ $diff -le 0 ]] && { echo "0h"; return; }

    hours=$(( (diff + 1800) / 3600 ))
    echo "${hours}h"
}

build_usage_bar() {
    local response five_h seven_d resets seven_int filled empty bar="" color five_pct reset_str

    response=$(fetch_api_usage)
    [[ -z "$response" ]] && return 0

    read -r five_h seven_d resets <<< "$(echo "$response" | jq -r '"\(.five_hour.utilization // "") \(.seven_day.utilization // "") \(.five_hour.resets_at // "")"' 2>/dev/null)"
    [[ -z "$five_h" || "$five_h" == "null" || -z "$seven_d" || "$seven_d" == "null" ]] && return 0

    seven_int=${seven_d%.*}
    seven_int=${seven_int:-0}

    filled=$(awk "BEGIN {printf \"%.0f\", ($seven_d / 100) * $USAGE_BAR_WIDTH}")
    filled=${filled:-0}
    [[ $filled -gt $USAGE_BAR_WIDTH ]] && filled=$USAGE_BAR_WIDTH
    empty=$((USAGE_BAR_WIDTH - filled))

    if [[ $seven_int -ge $CONTEXT_CRIT_PCT ]]; then
        color=$C_RED
    elif [[ $seven_int -ge $CONTEXT_WARN_PCT ]]; then
        color=$C_YELLOW
    else
        color=$C_GREEN
    fi

    for ((i = 0; i < filled; i++)); do bar+="█"; done
    for ((i = 0; i < empty; i++)); do bar+="░"; done

    five_pct=$(awk "BEGIN {printf \"%.0f\", $five_h}")
    reset_str=$(format_reset_time "$resets")

    printf " %b[%s %s%% · %s]%b" "$color" "$bar" "$five_pct" "$reset_str" "$C_RESET"
}

# ─────────────────────────────────────────────────────────────────────────────
# Context Progress Bar
# ─────────────────────────────────────────────────────────────────────────────

build_progress_bar() {
    local pct=$1
    local pct_int filled empty bar="" color

    pct_int=${pct%.*}
    pct_int=${pct_int:-0}

    filled=$(awk "BEGIN {printf \"%.0f\", ($pct / 100) * $BAR_WIDTH}")
    filled=${filled:-0}
    empty=$((BAR_WIDTH - filled))

    # Color based on usage level
    if [[ $pct_int -ge $CONTEXT_CRIT_PCT ]]; then
        color=$C_RED
    elif [[ $pct_int -ge $CONTEXT_WARN_PCT ]]; then
        color=$C_YELLOW
    else
        color=$C_GREEN
    fi

    for ((i = 0; i < filled; i++)); do bar+="█"; done
    for ((i = 0; i < empty; i++)); do bar+="░"; done

    printf "%b[%s %s%%]%b" "$color" "$bar" "$pct" "$C_RESET"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    local total_in out_tok ctx_pct duration cost git_info

    read -r total_in out_tok <<< "$(get_token_metrics)"
    total_in=${total_in:-0}
    out_tok=${out_tok:-0}

    ctx_pct=$(awk "BEGIN {printf \"%.1f\", ($total_in / $CTX_LIMIT) * 100}")
    duration=$(get_session_duration)
    cost=$(calculate_cost "$total_in" "$out_tok")
    git_info=$(get_git_info)

    # Output
    printf "%b➜%b  %b%s%b%s %b[%s]%b %b[↑%dk/↓%dk \$%s]%b %s%s %b⏱ %s%b" \
        "$C_BOLD_GREEN" "$C_RESET" \
        "$C_CYAN" "$DIR" "$C_RESET" \
        "$git_info" \
        "$C_DIM" "$MODEL" "$C_RESET" \
        "$C_DIM" "$((total_in / 1000))" "$((out_tok / 1000))" "$cost" "$C_RESET" \
        "$(build_progress_bar "$ctx_pct")" \
        "$(build_usage_bar)" \
        "$C_CYAN" "$duration" "$C_RESET"
}

main
