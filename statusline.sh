#!/bin/bash

BARS="▁▂▃▄▅▆▇█"
bar() { printf '%s' "${BARS:$(( ${1:-0} * 8 / 101 )):1}"; }
ctxcolor() {
    local v=${1:-0}
    if [ "$v" -ge 80 ]; then printf '\033[1;31m'
    elif [ "$v" -ge 50 ]; then printf '\033[1;33m'
    else printf '\033[90m'; fi
}
pacecolor() {
    local delta=${1:-0}
    if [ "$delta" -gt 30 ]; then printf '\033[1;31m'
    elif [ "$delta" -gt 10 ]; then printf '\033[1;33m'
    else printf '\033[90m'; fi
}
R=$'\033[0m'

input=$(cat)
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
MODEL=$(echo "$input" | jq -r '.model.id // ""' | sed 's/claude-//;s/-[0-9].*//;s/-latest//')

# Usage quota (cached 5 min)
CACHE="$HOME/.cache/claude-usage.json"
if [ ! -f "$CACHE" ] || [ $(($(date +%s) - $(stat -f%m "$CACHE"))) -gt 300 ]; then
    TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // empty')
    [ -n "$TOKEN" ] && curl -sf "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $TOKEN" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -o "$CACHE" 2>/dev/null
fi

USAGE=""
if [ -f "$CACHE" ]; then
    NOW=$(date +%s)
    H5=$(jq -r '.five_hour.utilization // 0' "$CACHE" | cut -d. -f1)
    D7=$(jq -r '.seven_day.utilization // 0' "$CACHE" | cut -d. -f1)
    H5_RESET=$(date -jf "%Y-%m-%dT%H:%M:%S" "$(jq -r '.five_hour.resets_at // ""' "$CACHE" | cut -d. -f1)" +%s 2>/dev/null || echo 0)
    D7_RESET=$(date -jf "%Y-%m-%dT%H:%M:%S" "$(jq -r '.seven_day.resets_at // ""' "$CACHE" | cut -d. -f1)" +%s 2>/dev/null || echo 0)
    if [ "$H5_RESET" -gt 0 ]; then
        H5_ELAPSED=$(( (NOW - (H5_RESET - 18000)) * 100 / 18000 ))
        H5_DELTA=$(( H5 - H5_ELAPSED ))
    else H5_DELTA=$H5; fi
    if [ "$D7_RESET" -gt 0 ]; then
        D7_ELAPSED=$(( (NOW - (D7_RESET - 604800)) * 100 / 604800 ))
        D7_DELTA=$(( D7 - D7_ELAPSED ))
    else D7_DELTA=$D7; fi
    [ "$H5_DELTA" -lt 0 ] && H5_DELTA=0; [ "$H5_DELTA" -gt 100 ] && H5_DELTA=100
    [ "$D7_DELTA" -lt 0 ] && D7_DELTA=0; [ "$D7_DELTA" -gt 100 ] && D7_DELTA=100
    USAGE=" $(pacecolor "$H5_DELTA")$(bar "$H5")$(pacecolor "$D7_DELTA")$(bar "$D7")${R}"
fi

printf '%s%s %s%s%s\n' "$(ctxcolor "$PCT")" "$MODEL" "$(bar "$PCT")" "$R" "$USAGE"
