#!/bin/bash
FAST_MODE=$(jq -r '.fastMode // false' ~/.claude/settings.json 2>/dev/null)
EFFORT_LEVEL=$(jq -r '.effortLevel // "high"' ~/.claude/settings.json 2>/dev/null)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
input=$(cat)

# --- Session data ---
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

USED_K=$(awk "BEGIN{printf \"%.0f\", ($PCT * $CTX_SIZE / 100) / 1000}")
TOTAL_K=$(awk "BEGIN{printf \"%.0f\", $CTX_SIZE / 1000}")

# Colors
RST='\033[0m'; DIM='\033[2m'; BOLD='\033[1m'
GRN='\033[32m'; YLW='\033[33m'; RED='\033[31m'; CYN='\033[36m'; MGT='\033[35m'; BLU='\033[34m'

# Helper: 15-char thin bar
make_bar() {
  local pct=$1 color=$2
  local f=$((pct * 15 / 100)); [ "$f" -gt 15 ] && f=15
  local e=$((15 - f))
  printf '%b' "${color}$(printf "%${f}s" | tr ' ' '▰')${DIM}$(printf "%${e}s" | tr ' ' '▱')${RST}"
}

# Helper: time remaining
time_remaining() {
  local reset_at="$1"
  [ -z "$reset_at" ] && return
  local ts
  ts=$(date -juf "%Y-%m-%dT%H:%M:%S" "${reset_at%%.*}" "+%s" 2>/dev/null)
  [ -z "$ts" ] && return
  local diff=$(( ts - $(date +%s) ))
  [ "$diff" -le 0 ] && echo "now" && return
  local d=$((diff / 86400)) h=$(((diff % 86400) / 3600)) m=$(((diff % 3600) / 60))
  if [ "$d" -gt 0 ]; then echo "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then echo "${h}h${m}m"
  else echo "${m}m"; fi
}

# Git branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Context color
if [ "$PCT" -ge 90 ]; then CC="$RED"
elif [ "$PCT" -ge 70 ]; then CC="$YLW"
else CC="$CYN"; fi

# Quota — fetch in background, read from cache if available
"$SCRIPT_DIR/fetch-usage.sh" 2>/dev/null &
CACHE="/tmp/claude-usage-cache.json"
H5=""; D7=""
if [ -f "$CACHE" ]; then
  H5=$(jq -r '.five_hour.utilization // 0' "$CACHE" | cut -d. -f1)
  D7=$(jq -r '.seven_day.utilization // 0' "$CACHE" | cut -d. -f1)
  RESET_5H=$(jq -r '.five_hour.resets_at // empty' "$CACHE")
  RESET_7D=$(jq -r '.seven_day.resets_at // empty' "$CACHE")
  if [ "$H5" -ge 80 ] 2>/dev/null; then H5C="$RED"; elif [ "$H5" -ge 50 ] 2>/dev/null; then H5C="$YLW"; else H5C="$GRN"; fi
  if [ "$D7" -ge 80 ] 2>/dev/null; then D7C="$RED"; elif [ "$D7" -ge 50 ] 2>/dev/null; then D7C="$MGT"; else D7C="$BLU"; fi
  R5=$(time_remaining "$RESET_5H")
  R7=$(time_remaining "$RESET_7D")
  EX_ENABLED=$(jq -r '.extra_usage.is_enabled // false' "$CACHE")
  if [ "$EX_ENABLED" = "true" ]; then
    EX_UTIL=$(jq -r '.extra_usage.utilization // 0' "$CACHE" | cut -d. -f1)
    EX_USED_RAW=$(jq -r '.extra_usage.used_credits // 0' "$CACHE")
    EX_LIMIT_RAW=$(jq -r '.extra_usage.monthly_limit // 0' "$CACHE")
    EX_USED_D=$(awk "BEGIN{printf \"%.2f\", $EX_USED_RAW / 100}")
    EX_LIMIT_D=$(awk "BEGIN{printf \"%.2f\", $EX_LIMIT_RAW / 100}")
    if [ "$EX_UTIL" -ge 80 ] 2>/dev/null; then EXC="$RED"
    elif [ "$EX_UTIL" -ge 50 ] 2>/dev/null; then EXC="$YLW"
    else EXC="$GRN"; fi
  fi
fi

# chart_row: label(3 left, bold+color) + bar(15) + pct(4) + suffix
chart_row() {
  local label="$1" pct="$2" color="$3" label_color="$4" suffix="$5"
  local lbl=$(printf '%-3s' "$label")
  local num=$(printf '%3s' "$pct")
  printf '%b' "${BOLD}${label_color}${lbl}${RST} "
  make_bar "$pct" "$color"
  printf '%b' " ${color}${num}%${RST}"
  [ -n "$suffix" ] && printf '%b' "  ${DIM}${suffix}${RST}"
  printf '\n'
}

# --- Line 1: CWD + Model + Fast + Context size + Git branch ---
CWD=$(echo "$input" | jq -r '.cwd // empty' | sed "s|$HOME|~|")
MODEL_ID=$(echo "$input" | jq -r '.model.id // empty')

MODEL_SHORT=""
case "$MODEL_ID" in
  *opus-4-6*)   MODEL_SHORT="opus4.6" ;;
  *opus*)       MODEL_SHORT="opus" ;;
  *sonnet-4-6*) MODEL_SHORT="sonnet4.6" ;;
  *sonnet*)     MODEL_SHORT="sonnet" ;;
  *haiku-4-5*)  MODEL_SHORT="haiku4.5" ;;
  *haiku*)      MODEL_SHORT="haiku" ;;
  *)            MODEL_SHORT="$MODEL_ID" ;;
esac

CTX_LABEL="${TOTAL_K}k"

if [ -n "$CWD" ]; then
  printf '%b' "📂 ${BOLD}${CWD}${RST}"
  [ -n "$MODEL_SHORT" ] && printf '%b' "  ${CYN}${MODEL_SHORT}${RST}"
  case "$EFFORT_LEVEL" in
    low)    printf '%b' " ${DIM}⚡lo${RST}" ;;
    medium) printf '%b' " ${DIM}⚡md${RST}" ;;
    *)      printf '%b' " ${DIM}⚡hi${RST}" ;;
  esac
  [ "$FAST_MODE" = "true" ] && printf '%b' " ${YLW}↯fast${RST}"
  printf '%b' " ${DIM}${CTX_LABEL}${RST}"
  [ -n "$BRANCH" ] && printf '%b' "  ${MGT}🔀 ${BRANCH}${RST}"
  printf '\n'
fi

chart_row "CTX" "$PCT" "$CC" "$CYN" "${USED_K}k/${TOTAL_K}k"
[ -n "$H5" ] && chart_row "5H" "$H5" "$H5C" "$GRN" "${R5:+↻ ${R5}}"
[ -n "$D7" ] && chart_row "7D" "$D7" "$D7C" "$BLU" "${R7:+↻ ${R7}}"
[ -n "$EX_UTIL" ] && chart_row "EX" "$EX_UTIL" "$EXC" "$YLW" "\$${EX_USED_D}/\$${EX_LIMIT_D}"
exit 0
