#!/bin/bash
[ "${CLAUDE_STATUSLINE_OFF}" = "1" ] && exit 0

# Claude Code statusline — context window, quota bars, model info, git branch & phase
# https://github.com/jojo-dan/claude-code-statusline

# --- settings.json 읽기 ---
read -r FAST_MODE EFFORT_LEVEL SL_CTX SL_5H SL_7D SL_BRANCH <<< $(jq -r '[
  (.fastMode // false),
  (.effortLevel // "high"),
  (if .statusline.ctx == null then true else .statusline.ctx end),
  (if .statusline["5h"] == null then true else .statusline["5h"] end),
  (if .statusline["7d"] == null then true else .statusline["7d"] end),
  (if .statusline.branch == null then true else .statusline.branch end)
] | join(" ")' ~/.claude/settings.json 2>/dev/null || echo "false high true true true true")

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
input=$(cat)

# --- Session root (stable project directory) ---
SESSION_ROOT=$(echo "$input" | jq -r '.workspace.project_dir // empty')
[ -z "$SESSION_ROOT" ] && SESSION_ROOT=$(echo "$input" | jq -r '.workspace.current_dir // empty')
[ -z "$SESSION_ROOT" ] && SESSION_ROOT="$PWD"

# --- 프로젝트명 추출 (범용) ---
PROJECT_NAME=$(basename "$(git -C "$SESSION_ROOT" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
[ -z "$PROJECT_NAME" ] && PROJECT_NAME=$(basename "$SESSION_ROOT")

# --- Responsive layout ---
W="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
if [ "$W" -ge 60 ]; then MODE=L BAR_W=15
elif [ "$W" -ge 40 ]; then MODE=M BAR_W=10
else MODE=S BAR_W=5; fi

# --- Session data ---
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
PCT=${PCT:-0}
CTX_SIZE=${CTX_SIZE:-200000}

USED_K=$(awk "BEGIN{printf \"%.0f\", ($PCT * $CTX_SIZE / 100) / 1000}")
TOTAL_K=$(awk "BEGIN{printf \"%.0f\", $CTX_SIZE / 1000}")

# --- Colors ---
RST='\033[0m'; DIM='\033[2m'; BOLD='\033[1m'
GRN='\033[32m'; YLW='\033[33m'; RED='\033[31m'; CYN='\033[36m'; MGT='\033[35m'; BLU='\033[34m'

# --- Helpers ---

make_bar() {
  local pct=$1 color=$2 width=${3:-15}
  local f=$((pct * width / 100)); [ "$f" -gt "$width" ] && f=$width
  local e=$((width - f))
  printf '%b' "${color}$(printf "%${f}s" | tr ' ' '▰')${DIM}$(printf "%${e}s" | tr ' ' '▱')${RST}"
}

parse_iso_ts() {
  local dt="${1%%.*}"
  date -juf "%Y-%m-%dT%H:%M:%S" "$dt" "+%s" 2>/dev/null \
    || date -d "$dt" "+%s" 2>/dev/null \
    || echo ""
}

time_remaining() {
  local reset_at="$1"
  [ -z "$reset_at" ] && return
  local ts
  ts=$(parse_iso_ts "$reset_at")
  [ -z "$ts" ] && return
  local diff=$(( ts - $(date +%s) ))
  [ "$diff" -le 0 ] && echo "now" && return
  local d=$((diff / 86400)) h=$(((diff % 86400) / 3600)) m=$(((diff % 3600) / 60))
  if [ "$d" -gt 0 ]; then echo "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then echo "${h}h${m}m"
  else echo "${m}m"; fi
}

is_stale() {
  local reset_at="$1"
  [ -z "$reset_at" ] && return 1
  local ts
  ts=$(parse_iso_ts "$reset_at")
  [ -z "$ts" ] && return 1
  [ "$ts" -le "$(date +%s)" ]
}

chart_row() {
  local label="$1" pct="$2" color="$3" label_color="$4" suffix="$5"
  local lbl=$(printf '%-3s' "$label")
  local num=$(printf '%3s' "$pct")
  printf '%b' "${BOLD}${label_color}${lbl}${RST} "
  make_bar "$pct" "$color" "$BAR_W"
  printf '%b' " ${color}${num}%${RST}"
  [ "$MODE" = "L" ] && [ -n "$suffix" ] && printf '%b' "  ${DIM}${suffix}${RST}"
  printf '\n'
}

# --- Git branch ---
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# --- Context color ---
if [ "$PCT" -ge 90 ]; then CC="$RED"
elif [ "$PCT" -ge 70 ]; then CC="$YLW"
else CC="$CYN"; fi

# --- Quota (background fetch) ---
"$SCRIPT_DIR/fetch-usage.sh" 2>/dev/null &
CACHE="/tmp/claude-usage-cache.json"
H5=""; D7=""
if [ -f "$CACHE" ]; then
  _H5_RAW=$(jq -r '.five_hour.utilization // empty' "$CACHE" 2>/dev/null | cut -d. -f1)
  _D7_RAW=$(jq -r '.seven_day.utilization // empty' "$CACHE" 2>/dev/null | cut -d. -f1)
  [[ "$_H5_RAW" =~ ^[0-9]+$ ]] && H5="$_H5_RAW"
  [[ "$_D7_RAW" =~ ^[0-9]+$ ]] && D7="$_D7_RAW"
  RESET_5H=$(jq -r '.five_hour.resets_at // empty' "$CACHE" 2>/dev/null)
  RESET_7D=$(jq -r '.seven_day.resets_at // empty' "$CACHE" 2>/dev/null)
  if [ "$H5" -ge 80 ] 2>/dev/null; then H5C="$RED"; elif [ "$H5" -ge 50 ] 2>/dev/null; then H5C="$YLW"; else H5C="$GRN"; fi
  if [ "$D7" -ge 80 ] 2>/dev/null; then D7C="$RED"; elif [ "$D7" -ge 50 ] 2>/dev/null; then D7C="$MGT"; else D7C="$BLU"; fi
  R5=$(time_remaining "$RESET_5H")
  R7=$(time_remaining "$RESET_7D")
fi

# --- Line 1: 프로젝트 + 모델 + effort + ctx_size ---
CWD=$(echo "$SESSION_ROOT" | sed "s|$HOME|~|")
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
CWD_SHORT="${PROJECT_NAME:-$CWD}"

if [ "$MODE" = "L" ]; then
  printf '%b' "📂 ${BOLD}${CWD_SHORT}${RST}"
  [ -n "$MODEL_SHORT" ] && printf '%b' "  ${CYN}${MODEL_SHORT}${RST}"
  case "$EFFORT_LEVEL" in
    low)    printf '%b' " ${DIM}⚡lo${RST}" ;;
    medium) printf '%b' " ${DIM}⚡md${RST}" ;;
    *)      printf '%b' " ${DIM}⚡hi${RST}" ;;
  esac
  [ "$FAST_MODE" = "true" ] && printf '%b' " ${YLW}↯fast${RST}"
  printf '%b' " ${DIM}${CTX_LABEL}${RST}"
  printf '\n'
elif [ "$MODE" = "M" ]; then
  printf '%b' "📂 ${BOLD}${CWD_SHORT}${RST}\n"
else
  printf '%b' "📂 ${BOLD}${CWD_SHORT}${RST}\n"
fi

# --- Chart rows ---
[ "$SL_CTX" != "false" ] && chart_row "CTX" "$PCT" "$CC" "$CYN" "${USED_K}k/${TOTAL_K}k"
if [ "$SL_5H" != "false" ] && [ -n "$H5" ]; then
  if is_stale "$RESET_5H"; then
    printf '%b' "${BOLD}${GRN}5H ${RST} ${YLW}⚠ stale${RST}\n"
  else
    chart_row "5H" "$H5" "$H5C" "$GRN" "${R5:+↻ ${R5}}"
  fi
fi
if [ "$SL_7D" != "false" ] && [ -n "$D7" ]; then
  if is_stale "$RESET_7D"; then
    printf '%b' "${BOLD}${BLU}7D ${RST} ${YLW}⚠ stale${RST}\n"
  else
    chart_row "7D" "$D7" "$D7C" "$BLU" "${R7:+↻ ${R7}}"
  fi
fi

# --- Phase + Branch row ---
if [ "$SL_BRANCH" != "false" ] && [ -n "$BRANCH" ]; then
  PHASE=""
  if [ -n "$SESSION_ROOT" ] && [ -f "${SESSION_ROOT}/.phase" ]; then
    PHASE=$(sed -n 's/.*"phase":"\([^"]*\)".*/\1/p' "${SESSION_ROOT}/.phase" 2>/dev/null)
  fi

  if [ -n "$PHASE" ]; then
    case "$PHASE" in
      done)    PHASE_CLR="${GRN}" ;;
      hotfix)  PHASE_CLR="${RED}" ;;
      *)       PHASE_CLR="${CYN}" ;;
    esac
    printf '%b' "${BOLD}${PHASE_CLR}${PHASE}${RST}  ${DIM}${MGT}${BRANCH}${RST}\n"
  else
    printf '%b' "${MGT}${BRANCH}${RST}\n"
  fi
fi

exit 0
