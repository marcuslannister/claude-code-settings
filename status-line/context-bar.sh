#!/bin/bash

# Color theme: gray, orange, blue, teal, green, lavender, rose, gold, slate, cyan,
# modus (light background, 24-bit color - see the modus block below)
COLOR="modus"

# Segment icons - swap these for text labels (e.g. E_MODEL="Model:") if your
# terminal font renders emoji poorly
E_MODEL="🤖"
E_THINKING="💭"
E_PATH="📁"
E_BRANCH="🌿"
E_CONTEXT="🪟"
E_CACHE="💾"

# Color codes
# Defaults are 256-color and assume a dark terminal background. A theme may
# override any of them; anything left unset falls back to the accent color.
C_RESET='\033[0m'
C_VALUE='\033[38;5;245m'   # gray for values and separators
C_BAR_EMPTY='\033[38;5;238m'
C_ADDED='\033[38;5;71m'     # green for added lines
C_DELETED='\033[38;5;173m'  # orange for deleted lines
C_UNTRACKED='\033[38;5;179m' # gold for the untracked file count
C_SEP=""      # separators between segments
C_BRANCH=""   # git branch segment
C_BAR_FILL="" # filled part of the context bar
C_BAR_WARN="" # bar fill past BAR_WARN_PCT, and the cache bar under 20% left (empty = no threshold colors)
C_BAR_ERR=""  # bar fill past BAR_ERR_PCT
BAR_WARN_PCT=80
BAR_ERR_PCT=90

case "$COLOR" in
    orange)   C_ACCENT='\033[38;5;173m' ;;
    blue)     C_ACCENT='\033[38;5;74m' ;;
    teal)     C_ACCENT='\033[38;5;66m' ;;
    green)    C_ACCENT='\033[38;5;71m' ;;
    lavender) C_ACCENT='\033[38;5;139m' ;;
    rose)     C_ACCENT='\033[38;5;132m' ;;
    gold)     C_ACCENT='\033[38;5;136m' ;;
    slate)    C_ACCENT='\033[38;5;60m' ;;
    cyan)     C_ACCENT='\033[38;5;37m' ;;
    modus)
        # modus-operandi-tinted (Emacs), for a light terminal on bg-main #fbf7f0.
        # Each slot maps to one of the theme's semantic colors:
        #   labels     keyword          blue              #0031a9
        #   values     fg-dim                             #595959
        #   separator  border                             #9f9690
        #   branch     name             magenta           #721045
        #   added      fg-added-intense                   #006700
        #   deleted    fg-removed-intense                 #aa2222
        #   untracked  fg-changed                         #553d00
        #   bar fill   accent-3/yellow/red-intense  orange, yellow 80%+, red 90%+
        #   bar track  fg-dim                             #595959
        C_ACCENT='\033[38;2;0;49;169m'
        C_VALUE='\033[38;2;89;89;89m'
        C_SEP='\033[38;2;159;150;144m'
        C_BRANCH='\033[38;2;114;16;69m'
        C_ADDED='\033[38;2;0;103;0m'
        C_DELETED='\033[38;2;170;34;34m'
        C_UNTRACKED='\033[38;2;85;61;0m'
        C_BAR_FILL='\033[38;2;137;64;0m'
        C_BAR_WARN='\033[38;2;196;160;0m'  # yellow #c4a000
        C_BAR_ERR='\033[38;2;208;0;0m'
        C_BAR_EMPTY='\033[38;2;89;89;89m'
        ;;
    *)        C_ACCENT="$C_VALUE" ;;  # gray: all same color
esac

# Unset slots follow the accent color, keeping the simpler themes single-accent
C_SEP="${C_SEP:-$C_VALUE}"
C_BRANCH="${C_BRANCH:-$C_ACCENT}"
C_BAR_FILL="${C_BAR_FILL:-$C_ACCENT}"

input=$(cat)

# Extract model, thinking effort, and cwd
# Drop the "(1M context)" suffix - the context bar already shows the window size
model=$(echo "$input" | jq -r '(.model.display_name // .model.id // "?") | sub(" *\\(1M context\\)$"; "")')
cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "$cwd" 2>/dev/null || echo "?")

# Thinking effort: .effort.level (low/medium/high) is only present on models
# that support it - fall back to on/off from .thinking.enabled
effort=$(echo "$input" | jq -r '.effort.level // empty')
if [[ -z "$effort" ]]; then
    # Note: `// empty` would swallow `false` here, so test for null explicitly
    thinking_enabled=$(echo "$input" | jq -r 'if .thinking.enabled == null then empty else (.thinking.enabled | tostring) end')
    case "$thinking_enabled" in
        true)  effort="on" ;;
        false) effort="off" ;;
    esac
fi

# Get git branch, uncommitted line changes (+added,-deleted), and untracked count
branch=""
diff_stat=""
if [[ -n "$cwd" && -d "$cwd" ]]; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    if [[ -n "$branch" ]]; then
        # Sum line changes across tracked files (binary files count as 0)
        counts=$(git -C "$cwd" --no-optional-locks diff --numstat HEAD 2>/dev/null |
            awk '{ added += $1; deleted += $2 } END { print added + 0, deleted + 0 }')
        added=$(echo "$counts" | cut -d' ' -f1)
        deleted=$(echo "$counts" | cut -d' ' -f2)

        # `git diff` never reports untracked paths, so count them separately -
        # otherwise a tree whose only work is new files looks clean
        untracked=$(git -C "$cwd" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null |
            wc -l | tr -d ' ')

        parts=""
        if [[ "${added:-0}" -gt 0 || "${deleted:-0}" -gt 0 ]]; then
            parts="${C_ADDED}+${added}${C_SEP},${C_DELETED}-${deleted}"
        fi
        if [[ "${untracked:-0}" -gt 0 ]]; then
            [[ -n "$parts" ]] && { parts+="${C_SEP},"; }
            parts+="${C_UNTRACKED}?${untracked}"
        fi
        if [[ -n "$parts" ]]; then
            diff_stat="${C_SEP}(${parts}${C_SEP})"
        fi
    fi
fi

# Get transcript path for context calculation and last message feature
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Format a token count as 0 / 50k / 1.0M (same rounding as ccstatusline)
format_tokens() {
    local n=$1
    if [[ $n -ge 999950 ]]; then
        awk -v n="$n" 'BEGIN { printf "%.1fM", n / 1000000 }'
    elif [[ $n -ge 1000 ]]; then
        awk -v n="$n" 'BEGIN { printf "%.0fk", n / 1000 }'
    else
        printf '%d' "$n"
    fi
}

# Draw a bar of BAR_WIDTH segments for a percentage
BAR_WIDTH=10
build_bar() {
    local pct=$1 filled i bar="" fill="$C_BAR_FILL"
    [[ -n "$C_BAR_WARN" && $pct -ge $BAR_WARN_PCT ]] && fill="$C_BAR_WARN"
    [[ -n "$C_BAR_ERR" && $pct -ge $BAR_ERR_PCT ]] && fill="$C_BAR_ERR"
    [[ -n "$2" ]] && fill="$2"  # optional fill color from the caller
    filled=$(((pct * BAR_WIDTH + 50) / 100))
    for ((i=0; i<BAR_WIDTH; i++)); do
        if [[ $i -lt $filled ]]; then
            bar+="${fill}█"
        else
            bar+="${C_BAR_EMPTY}░"
        fi
    done
    printf '%s' "$bar"
}

# Get context window size from JSON (accurate), but calculate tokens from transcript
# (more accurate than total_input_tokens which excludes system prompt/tools/memory)
# See: github.com/anthropics/claude-code/issues/13652
max_context=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
max_display=$(format_tokens "$max_context")

# Calculate context bar from transcript
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    context_length=$(jq -s '
        map(select(.message.usage and .isSidechain != true and .isApiErrorMessage != true)) |
        last |
        if . then
            (.message.usage.input_tokens // 0) +
            (.message.usage.cache_read_input_tokens // 0) +
            (.message.usage.cache_creation_input_tokens // 0)
        else 0 end
    ' < "$transcript_path")

    # 20k baseline: includes system prompt (~3k), tools (~15k), memory (~300),
    # plus ~2k for git status, env block, XML framing, and other dynamic context
    baseline=20000

    if [[ "$context_length" -gt 0 ]]; then
        used=$context_length
        pct_prefix=""
    else
        # At conversation start, ~20k baseline is already loaded
        used=$baseline
        pct_prefix="~"
    fi
else
    # Transcript not available yet - show baseline estimate
    used=20000
    pct_prefix="~"
fi

pct=$(((used * 200 + max_context) / (2 * max_context)))  # round to nearest percent
[[ $pct -gt 100 ]] && pct=100
used_display=$(format_tokens "$used")
ctx="${C_SEP}[$(build_bar "$pct")${C_SEP}]${C_VALUE} ${used_display}/${max_display} (${pct_prefix}${pct}%)"

# Prompt cache: time left before the cached prefix goes cold. prompt_cache is
# absent until the first API response; missing fields (older versions) are skipped
eval "$(echo "$input" | jq -r '
    def v: if . == null then "" else . end;
    .prompt_cache // empty |
    @sh "cache_warm=\(.warm | tostring) cache_ttl=\(.ttl | v) cache_exp=\(.expires_at | v)",
    @sh "cache_hit=\(.hit_ratio | if . == null then "" else . * 100 | round end)",
    @sh "cache_misses=\(.misses | v) cache_recache=\(.recache_tokens_if_cold | v)",
    @sh "cache_cause=\(.last_miss_cause.causes // [] | join(", "))"
')"
cache=""
if [[ -n "$cache_warm" ]]; then
    cache_left=$(( ${cache_exp:-0} - $(date +%s) ))
    if [[ "$cache_warm" == true && -n "$cache_exp" && $cache_left -gt 0 ]]; then
        case "$cache_ttl" in 5m) cache_total=300 ;; 1h) cache_total=3600 ;; *) cache_total=0 ;; esac
        if [[ $cache_left -ge 60 ]]; then cache_left_display="$((cache_left / 60))m"; else cache_left_display="${cache_left}s"; fi
        if [[ $cache_total -gt 0 ]]; then
            cache_pct=$(( (cache_left * 100 + cache_total / 2) / cache_total ))
            [[ $cache_pct -gt 100 ]] && cache_pct=100
            cache_fill="$C_BAR_FILL"
            [[ $((cache_left * 5)) -lt $cache_total ]] && cache_fill="${C_BAR_WARN:-$C_BAR_FILL}"  # under 20% left
            cache="${C_SEP}[$(build_bar "$cache_pct" "$cache_fill")${C_SEP}]${C_VALUE} ${cache_left_display}/${cache_ttl} (${cache_pct}%)"
        else
            cache="${C_VALUE}${cache_left_display} left"
        fi
        [[ -n "$cache_hit" ]] && cache+=" · hit ${cache_hit}%"
        [[ -n "$cache_misses" ]] && cache+=" · misses ${cache_misses}"
    else
        cache="${C_SEP}[$(build_bar 0)${C_SEP}]${C_BAR_ERR:-$C_VALUE} cold${C_VALUE}"
        [[ -n "$cache_recache" ]] && cache+=" · next message re-caches $(format_tokens "$cache_recache") tokens"
        [[ -n "$cache_cause" ]] && cache+=" · miss: ${cache_cause}"
    fi
fi

# Build output: model | thinking | path | branch(+added,-deleted),
# then context | cache on line 2
sep="${C_SEP} | "
output="${E_MODEL}${C_VALUE} ${model}"
[[ -n "$effort" ]] && output+="${sep}${E_THINKING}${C_VALUE} ${effort}"
[[ -n "$dir" ]] && output+="${sep}${E_PATH}${C_VALUE} ${dir}"
[[ -n "$branch" ]] && output+="${sep}${E_BRANCH}${C_BRANCH} ${branch}${diff_stat}"
output+="${C_RESET}\n${E_CONTEXT}${C_VALUE} ${ctx}"
[[ -n "$cache" ]] && output+="${sep}${E_CACHE} ${cache}"
output+="${C_RESET}"

printf '%b\n' "$output"
