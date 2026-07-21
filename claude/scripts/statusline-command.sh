#!/bin/bash

# Read Claude Code context from stdin
input=$(cat)

# ---------------------------------------------------------------------------
# Parse all JSON fields in a single jq call
# ---------------------------------------------------------------------------
# NOTE: tab is whitespace to `read`, so a possibly-empty field mid-list gets
# collapsed and shifts later fields. Keep `effort_level` (which can be empty
# when the model has no effort param) LAST; cost is always numeric.
IFS=$'\t' read -r model_name current_dir project_dir context_pct remaining_pct effort_level <<< "$(
    echo "$input" | jq -r '[
        .model.display_name // "Claude",
        .workspace.current_dir // "",
        .workspace.project_dir // "",
        (.context_window.used_percentage // 0 | floor),
        (.context_window.remaining_percentage // -1 | floor),
        .effort.level // ""
    ] | @tsv'
)"

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
    elif $in_worktree && [[ "$dir_name" == .worktrees/* ]]; then
        # Worktree subdir mirrors branch name — suppress to avoid redundancy
        dir_name=""
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

C_OPUS_LOW="\033[38;2;255;220;180m"
C_OPUS_MEDIUM="\033[38;2;255;190;130m"
C_OPUS_HIGH="\033[38;2;255;160;70m"
C_OPUS_XHIGH="\033[38;2;255;140;20m"
C_OPUS_MAX="\033[38;2;220;100;0m"

C_SONNET_LOW="\033[38;2;255;220;235m"
C_SONNET_MEDIUM="\033[38;2;255;190;220m"
C_SONNET_HIGH="\033[38;2;255;150;200m"
C_SONNET_XHIGH="\033[38;2;255;110;180m"
C_SONNET_MAX="\033[38;2;220;60;140m"

C_FABLE_LOW="\033[38;2;200;225;255m"
C_FABLE_MEDIUM="\033[38;2;140;190;255m"
C_FABLE_HIGH="\033[38;2;80;150;245m"
C_FABLE_XHIGH="\033[38;2;40;110;230m"
C_FABLE_MAX="\033[38;2;20;70;190m"

color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 80 ]; then printf "%s" "$C_RED"
    elif [ "$pct" -ge 50 ]; then printf "%s" "$C_YEL"
    else printf "%s" "$C_GRN"
    fi
}

color_by_effort() {
    local effort=$1 c_low=$2 c_medium=$3 c_high=$4 c_xhigh=$5 c_max=$6
    case "$effort" in
        low) printf "%s" "$c_low" ;;
        medium) printf "%s" "$c_medium" ;;
        high) printf "%s" "$c_high" ;;
        xhigh) printf "%s" "$c_xhigh" ;;
        max) printf "%s" "$c_max" ;;
        *) printf "%s" "$c_medium" ;;
    esac
}

color_for_model() {
    local name=$1 effort=$2
    case "$name" in
        *Opus*) color_by_effort "$effort" "$C_OPUS_LOW" "$C_OPUS_MEDIUM" "$C_OPUS_HIGH" "$C_OPUS_XHIGH" "$C_OPUS_MAX" ;;
        *Sonnet*) color_by_effort "$effort" "$C_SONNET_LOW" "$C_SONNET_MEDIUM" "$C_SONNET_HIGH" "$C_SONNET_XHIGH" "$C_SONNET_MAX" ;;
        *Fable*) color_by_effort "$effort" "$C_FABLE_LOW" "$C_FABLE_MEDIUM" "$C_FABLE_HIGH" "$C_FABLE_XHIGH" "$C_FABLE_MAX" ;;
        *) printf "%s" "$C_DIM" ;;
    esac
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
# Args: $1=utilization% $2=resets_at $3=label $4=date_fmt
# ---------------------------------------------------------------------------
render_window() {
    local usage=$1 resets_at=$2 label=$3 date_fmt=$4
    [ -z "$usage" ] && return
    local reset_epoch reset_label=""

    reset_epoch=$(date -juf "%Y-%m-%dT%H:%M:%S" \
        "$(echo "$resets_at" | cut -d. -f1 | sed 's/+.*//')" +%s 2>/dev/null)

    if [ -n "$reset_epoch" ]; then
        reset_label=$(date -r "$reset_epoch" +"$date_fmt" 2>/dev/null \
            | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    fi

    local color reset_str=""
    color=$(color_for_pct "$usage")
    [ -n "$reset_label" ] && reset_str="→${reset_label}"
    printf "%s" "${color}${label}${reset_str} ${usage}%${C_RST}"
}

# ---------------------------------------------------------------------------
# Read all usage cache fields in a single jq call
# ---------------------------------------------------------------------------
usage_now=""     # short-horizon (line 2, next to ctx): the 5-hour session
usage_period=""  # long-horizon (line 3): weekly caps + monthly overage
if [ -f "$USAGE_CACHE" ]; then
    # Fable's weekly-scoped sub-cap lives in .limits[] (a weekly_scoped entry
    # with scope.model.display_name == "Fable"), NOT in .seven_day — the API
    # exposes no per-model spend, but it does expose per-model utilization here.
    # resets_fable is kept LAST (may be empty; read collapses empty tab fields —
    # see top comment); usage_fable is always numeric so it's safe mid-list.
    IFS=$'\t' read -r usage_5h resets_5h usage_7d resets_7d usage_fable resets_fable <<< "$(
        jq -r '
            ([.limits[]? | select(.scope.model.display_name == "Fable")][0]) as $fable |
            [
                (.five_hour.utilization // -1 | floor),
                .five_hour.resets_at // "",
                (.seven_day.utilization // -1 | floor),
                .seven_day.resets_at // "",
                ($fable.percent // -1 | floor),
                ($fable.resets_at // "")
            ] | @tsv' "$USAGE_CACHE" 2>/dev/null
    )"

    # Line 2 — current 5-hour session window
    if [ "$usage_5h" -ge 0 ] 2>/dev/null && [ -n "$resets_5h" ]; then
        usage_now=$(render_window "$usage_5h" "$resets_5h" "5hr" '%H%M')
    fi

    # Line 3 — all-models weekly window
    if [ "$usage_7d" -ge 0 ] 2>/dev/null && [ -n "$resets_7d" ]; then
        usage_period=$(render_window "$usage_7d" "$resets_7d" "wk" '%a %H%M')
    fi

    # Line 3 — Fable weekly sub-cap (model-specific, ~50% of the weekly limit).
    if [ "$usage_fable" -ge 0 ] 2>/dev/null && [ -n "$resets_fable" ]; then
        [ -n "$usage_period" ] && usage_period="${usage_period}${C_SEP}"
        usage_period="${usage_period}$(render_window "$usage_fable" "$resets_fable" "fable" '%a %H%M')"
    fi

    # ---------------------------------------------------------------------------
    # Extra-usage (overage) spend — REAL charges, unlike the notional session
    # cost. Credits only burn once plan limits (5hr/wk) are exhausted, so this
    # figure climbing mid-session means you're on paid overage. Monthly-cumulative
    # against a cap; shown only when the account has extra usage enabled.
    # amount_minor / 10^exponent = whole-dollar amount.
    # ---------------------------------------------------------------------------
    IFS=$'\t' read -r spend_enabled spend_pct spend_used_minor spend_used_exp spend_limit_minor spend_limit_exp <<< "$(
        jq -r '[
            (.spend.enabled // false),
            (.spend.percent // 0 | floor),
            (.spend.used.amount_minor // 0),
            (.spend.used.exponent // 2),
            (.spend.limit.amount_minor // 0),
            (.spend.limit.exponent // 2)
        ] | @tsv' "$USAGE_CACHE" 2>/dev/null
    )"
    if [ "$spend_enabled" = "true" ]; then
        used_div=1; limit_div=1
        for ((i=0; i<spend_used_exp; i++)); do used_div=$(( used_div * 10 )); done
        for ((i=0; i<spend_limit_exp; i++)); do limit_div=$(( limit_div * 10 )); done
        used_dollars=$(( spend_used_minor / used_div ))
        limit_dollars=$(( spend_limit_minor / limit_div ))
        # Compact the cap in k-notation with up to 2 decimals (resolution $10),
        # trailing zero trimmed: 1010 -> $1.01k, 1500 -> $1.5k, 1000 -> $1k.
        # Sub-$1000 caps stay in whole dollars (k-notation reads oddly there).
        if [ "$limit_dollars" -lt 1000 ]; then
            limit_str="\$${limit_dollars}"
        else
            k_whole=$(( limit_dollars / 1000 ))
            k_dec=$(( (limit_dollars % 1000) / 10 ))   # hundredths of $1k = $10 units
            if [ "$k_dec" -eq 0 ]; then
                limit_str="\$${k_whole}k"
            else
                [ "$k_dec" -lt 10 ] && dec="0${k_dec}" || dec="${k_dec}"
                dec="${dec%0}"                          # trim one trailing zero: 50->5, 20->2
                limit_str="\$${k_whole}.${dec}k"
            fi
        fi
        ovr_color=$(color_for_pct "$spend_pct")
        [ -n "$usage_period" ] && usage_period="${usage_period}${C_SEP}"
        usage_period="${usage_period}${ovr_color}ovr \$${used_dollars}/${limit_str} ${spend_pct}%${C_RST}"
    fi
fi

# ---------------------------------------------------------------------------
# Compose status line — single line, all segments │-delimited
# ---------------------------------------------------------------------------

# Row 1: branch + dir │ model │ tokens
if [ -n "$branch" ] && [ -n "$dir_name" ]; then
    row1="${C_DCYAN}[${branch}] ${dir_name}${C_RST}"
elif [ -n "$branch" ]; then
    row1="${C_DCYAN}[${branch}]${C_RST}"
else
    row1="${C_DCYAN}${dir_name}${C_RST}"
fi
# Reasoning effort level from the live session payload (.effort.level).
# Absent when the model doesn't support the effort parameter.
if [ -n "$effort_level" ]; then
    effort_label=" ${effort_level}"
else
    effort_label=""
fi

model_color=$(color_for_model "$model_name" "$effort_level")
row1="${row1}${C_SEP}${model_color}${model_name}${effort_label}${C_RST}"

# Row 2: context/compaction bar + short-horizon session usage (5hr)
# Row 3: long-horizon usage — weekly caps + monthly overage
row2=""
row3=""

# Compaction indicator
# CLAUDE_AUTOCOMPACT_PCT_OVERRIDE (set in settings.local.json) controls when
# compaction fires, as a percentage of the full context window (1M = ~450K at 45%).
# Fallback below matches Claude Code's own default (~95%) if the env var is unset.
COMPACT_AT="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-95}"
if [ "$remaining_pct" -ge 0 ] 2>/dev/null; then
    compact_left=$(( COMPACT_AT - context_pct ))
    [ "$compact_left" -lt 0 ] && compact_left=0
    if [ "$compact_left" -le 5 ]; then
        ctx_color="$C_RED"
    elif [ "$compact_left" -le 20 ]; then
        ctx_color="$C_YEL"
    else
        ctx_color="$C_GRN"
    fi
    row2="${ctx_color}ctx ${compact_left}% to compact${C_RST}"
fi

# Row 2: append the short-horizon (5hr session) usage next to ctx
if [ -n "$usage_now" ]; then
    [ -n "$row2" ] && row2="${row2}${C_SEP}"
    row2="${row2}${usage_now}"
fi

# Row 3: long-horizon usage (weekly caps + monthly overage)
row3="$usage_period"

# Output
line="$row1"
[ -n "$row2" ] && line="${line}${C_SEP}${row2}"
[ -n "$row3" ] && line="${line}${C_SEP}${row3}"
echo -e "$line"
