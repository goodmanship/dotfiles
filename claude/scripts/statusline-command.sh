#!/bin/bash

# Read Claude Code context from stdin
input=$(cat)

# ---------------------------------------------------------------------------
# Parse all JSON fields in a single jq call
# ---------------------------------------------------------------------------
IFS=$'\t' read -r model_name current_dir project_dir context_pct remaining_pct tokens_in tokens_out <<< "$(
    echo "$input" | jq -r '[
        .model.display_name // "Claude",
        .workspace.current_dir // "",
        .workspace.project_dir // "",
        (.context_window.used_percentage // 0 | floor),
        (.context_window.remaining_percentage // -1 | floor),
        .context_window.current_usage.input_tokens // 0,
        .context_window.current_usage.output_tokens // 0
    ] | @tsv'
)"

# Token formatter — pure bash, no bc dependency
fmt_k() {
    local n=$1
    if [ "$n" -ge 1000 ]; then
        local int=$(( n / 1000 )) frac=$(( (n % 1000) / 100 ))
        printf "%d.%dk" "$int" "$frac"
    else
        printf "%d" "$n"
    fi
}
tok_str="↑$(fmt_k "$tokens_in") ↓$(fmt_k "$tokens_out")"

# Git branch
branch=$(git -C "$current_dir" --no-optional-locks branch --show-current 2>/dev/null)
if [ -z "$branch" ]; then
    branch=$(git -C "$current_dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
fi

# Short path: relative to project_dir, or just basename.
# In worktrees the dir name mirrors the branch — skip it to avoid redundancy.
in_worktree=false
[[ "$current_dir" == *"/.worktrees/"* ]] && in_worktree=true

if [ -n "$project_dir" ] && [[ "$current_dir" == "$project_dir"* ]]; then
    dir_name="${current_dir#"$project_dir"}"
    dir_name="${dir_name#/}"
    if [ -z "$dir_name" ]; then
        # At project root — show basename unless worktree (branch says it all)
        $in_worktree || dir_name=$(basename "$project_dir")
    fi
elif [ -n "$current_dir" ]; then
    dir_name=$(basename "$current_dir")
else
    dir_name=$(basename "$(pwd)")
fi

# ---------------------------------------------------------------------------
# ANSI color constants
# ---------------------------------------------------------------------------
C_RED="\033[91m"
C_YEL="\033[33m"
C_GRN="\033[32m"
C_DIM="\033[2m"
C_DCYAN="${C_DIM}\033[96m"
C_RST="\033[0m"
C_SEP="${C_DIM} │ ${C_RST}"

color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 80 ]; then printf "%s" "$C_RED"
    elif [ "$pct" -ge 50 ]; then printf "%s" "$C_YEL"
    else printf "%s" "$C_GRN"
    fi
}

# ---------------------------------------------------------------------------
# Progress bar with optional pacing marker
# Uses same █ character throughout — distinguishes states via ANSI color only
# Args: $1=pct $2=target_pct $3=width $4=fill_color (ANSI escape)
# ---------------------------------------------------------------------------
C_EMPTY="\033[90m"   # dark grey for empty
C_PACE="\033[37m"    # white for pacing marker

make_bar() {
    local pct=$1 target=${2:-} width=${3:-8} fill_color=${4:-$C_GRN}
    local filled=$(( pct * width / 100 ))
    [ "$pct" -gt 0 ] && [ "$filled" -eq 0 ] && filled=1
    [ "$filled" -gt "$width" ] && filled=$width
    local target_pos=-1
    if [ -n "$target" ] && [ "$target" -ge 0 ] 2>/dev/null && [ "$target" -le 100 ]; then
        target_pos=$(( target * width / 100 ))
        [ "$target_pos" -ge "$width" ] && target_pos=$(( width - 1 ))
    fi
    local bar=""
    for ((i=0; i<width; i++)); do
        if [ "$i" -lt "$filled" ]; then
            bar="${bar}${fill_color}█"
        elif [ "$i" -eq "$target_pos" ]; then
            bar="${bar}${C_PACE}█"
        else
            bar="${bar}${C_EMPTY}█"
        fi
    done
    bar="${bar}${C_RST}"
    printf "%s" "$bar"
}

# ---------------------------------------------------------------------------
# Fetch plan usage from Anthropic OAuth API (cached, background refresh)
# ---------------------------------------------------------------------------
USAGE_CACHE="/tmp/claude-statusline-usage.json"
USAGE_CACHE_TTL=60

fetch_usage() {
    local creds token response
    creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || return 1
    token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty') || return 1
    [ -z "$token" ] || [ "$token" = "null" ] && return 1
    response=$(curl -s --max-time 3 "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Content-Type: application/json" 2>/dev/null) || return 1
    echo "$response" | jq -e '.error' >/dev/null 2>&1 && return 1
    echo "$response" > "$USAGE_CACHE"
}

NOW_EPOCH=$(date +%s)

if [ -f "$USAGE_CACHE" ]; then
    cache_age=$(( NOW_EPOCH - $(stat -f%m "$USAGE_CACHE" 2>/dev/null || echo 0) ))
else
    cache_age=99999
fi
if [ "$cache_age" -gt "$USAGE_CACHE_TTL" ]; then
    fetch_usage 2>/dev/null &
fi

# ---------------------------------------------------------------------------
# Build usage window section — reusable for 5h and 7d windows
# Args: $1=utilization% $2=resets_at $3=window_secs $4=label $5=date_fmt
# ---------------------------------------------------------------------------
render_window() {
    local usage=$1 resets_at=$2 window=$3 label=$4 date_fmt=$5
    [ -z "$usage" ] && return
    local reset_epoch target="" reset_label=""

    reset_epoch=$(date -juf "%Y-%m-%dT%H:%M:%S" \
        "$(echo "$resets_at" | cut -d. -f1 | sed 's/+.*//')" +%s 2>/dev/null)

    if [ -n "$reset_epoch" ]; then
        local elapsed=$(( NOW_EPOCH - (reset_epoch - window) ))
        [ "$elapsed" -lt 0 ] && elapsed=0
        [ "$elapsed" -gt "$window" ] && elapsed=$window
        target=$(( elapsed * 100 / window ))
        reset_label=$(date -r "$(( (reset_epoch + 1800) / 3600 * 3600 ))" +"$date_fmt" 2>/dev/null \
            | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    fi

    local color bar reset_str=""
    color=$(color_for_pct "$usage")
    bar=$(make_bar "$usage" "$target" 8 "$color")
    [ -n "$reset_label" ] && reset_str="→${reset_label}"
    printf "%s" "${color}${label}${reset_str} ${C_RST}${bar}${color} ${usage}%${C_RST}"
}

# ---------------------------------------------------------------------------
# Read all usage cache fields in a single jq call
# ---------------------------------------------------------------------------
usage_parts=""
if [ -f "$USAGE_CACHE" ]; then
    IFS=$'\t' read -r usage_5h resets_5h usage_7d resets_7d <<< "$(
        jq -r '[
            (.five_hour.utilization // -1 | floor),
            .five_hour.resets_at // "",
            (.seven_day.utilization // -1 | floor),
            .seven_day.resets_at // ""
        ] | @tsv' "$USAGE_CACHE" 2>/dev/null
    )"

    if [ "$usage_5h" -ge 0 ] 2>/dev/null && [ -n "$resets_5h" ]; then
        usage_parts=$(render_window "$usage_5h" "$resets_5h" $((5 * 3600)) "5hr" '%-l%p')
    fi

    if [ "$usage_7d" -ge 0 ] 2>/dev/null && [ -n "$resets_7d" ]; then
        [ -n "$usage_parts" ] && usage_parts="${usage_parts}${C_SEP}"
        usage_parts="${usage_parts}$(render_window "$usage_7d" "$resets_7d" $((7 * 86400)) "wk" '%a %-l%p')"
    fi
fi

# ---------------------------------------------------------------------------
# Compose status line
# Single row: session info + context bar + rate-limit usage bars
# ---------------------------------------------------------------------------

# Session info: branch + dir │ model │ tokens
if [ -n "$branch" ] && [ -n "$dir_name" ]; then
    row1="${C_DCYAN}[${branch}] ${dir_name}${C_RST}"
elif [ -n "$branch" ]; then
    row1="${C_DCYAN}[${branch}]${C_RST}"
else
    row1="${C_DCYAN}${dir_name}${C_RST}"
fi
# Thinking mode from settings (doesn't reflect mid-session Tab toggles)
thinking=$(jq -r '.alwaysThinkingEnabled // false' ~/.claude/settings.json 2>/dev/null)
if [ "$thinking" = "true" ]; then
    think_label=" +think"
else
    think_label=""
fi

row1="${row1}${C_SEP}${C_DIM}${model_name}${think_label}${C_RST}${C_SEP}${C_DIM}${tok_str}${C_RST}"

# Inline details: context bar + rate-limit usage bars
row2=""

# Compaction indicator
# The API's used_percentage hits ~83% when compaction fires (200K - 33K buffer).
# Default 80 gives a slight early-warning margin. Override with CLAUDE_AUTOCOMPACT_PCT_OVERRIDE.
COMPACT_AT="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-80}"
if [ "$remaining_pct" -ge 0 ] 2>/dev/null; then
    compact_fill=$(( context_pct * 100 / COMPACT_AT ))
    [ "$compact_fill" -gt 100 ] && compact_fill=100
    compact_left=$(( COMPACT_AT - context_pct ))
    [ "$compact_left" -lt 0 ] && compact_left=0
    if [ "$compact_left" -le 5 ]; then
        ctx_color="$C_RED"
    elif [ "$compact_left" -le 20 ]; then
        ctx_color="$C_YEL"
    else
        ctx_color="$C_GRN"
    fi
    local_bar=$(make_bar "$compact_fill" "" 6 "$ctx_color")
    row2="${ctx_color}ctx ${C_RST}${local_bar}${ctx_color} ${compact_left}%${C_RST}"
fi

# Append rate-limit usage bars
if [ -n "$usage_parts" ]; then
    [ -n "$row2" ] && row2="${row2}${C_SEP}"
    row2="${row2}${usage_parts}"
fi

# Output
if [ -n "$row2" ]; then
    echo -e "${row1}${C_SEP}${row2}"
else
    echo -e "$row1"
fi
