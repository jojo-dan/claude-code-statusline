#!/bin/bash
# Claude Code OAuth usage API → 캐시
# Claude Code 로그인 시 OS credential store에 저장된 토큰을 자동으로 읽는다.
# Rate limit 악순환 방지: 에러 시에도 touch로 캐시 mtime 갱신하여 재호출 간격 유지

CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_MAX_AGE=120  # seconds

# --- 크로스플랫폼 file mtime ---
file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Skip if cache is fresh
if [ -f "$CACHE_FILE" ]; then
  AGE=$(( $(date +%s) - $(file_mtime "$CACHE_FILE") ))
  [ "$AGE" -lt "$CACHE_MAX_AGE" ] && exit 0
fi

# --- 토큰 획득: OS credential store 자동 감지 ---
TOKEN=""

# 1. macOS Keychain
if [ -z "$TOKEN" ] && command -v security >/dev/null 2>&1; then
  TOKEN=$(security find-generic-password -s "Claude Code-credentials" -a "$(whoami)" -w 2>/dev/null \
    | python3 -c "
import sys, json, subprocess

raw_bytes = sys.stdin.buffer.read()

def extract_token(text):
    idx = text.find('{')
    if idx < 0: return None
    for end in range(idx+1, len(text)+1):
        try:
            obj = json.loads(text[idx:end])
            if 'claudeAiOauth' in obj:
                return obj['claudeAiOauth'].get('accessToken', '')
            return obj.get('accessToken', '')
        except: continue
    return None

token = extract_token(raw_bytes.decode('utf-8', errors='ignore'))

if not token:
    try:
        decoded = subprocess.run(['xxd', '-r', '-p'], input=raw_bytes, capture_output=True)
        if decoded.returncode == 0:
            token = extract_token(decoded.stdout.decode('utf-8', errors='ignore'))
    except: pass

if token:
    print(token)
    sys.exit(0)
sys.exit(1)
" 2>/dev/null)
fi

# 2. Linux secret-tool (libsecret / GNOME Keyring)
if [ -z "$TOKEN" ] && command -v secret-tool >/dev/null 2>&1; then
  TOKEN=$(secret-tool lookup service "Claude Code-credentials" 2>/dev/null \
    | python3 -c "
import sys, json

raw = sys.stdin.read().strip()
if not raw: sys.exit(1)

def extract_token(text):
    idx = text.find('{')
    if idx < 0: return None
    for end in range(idx+1, len(text)+1):
        try:
            obj = json.loads(text[idx:end])
            if 'claudeAiOauth' in obj:
                return obj['claudeAiOauth'].get('accessToken', '')
            return obj.get('accessToken', '')
        except: continue
    return None

token = extract_token(raw)
if token:
    print(token)
    sys.exit(0)
sys.exit(1)
" 2>/dev/null)
fi

# 3. 환경변수 폴백
[ -z "$TOKEN" ] && TOKEN="${CLAUDE_OAUTH_TOKEN:-}"

# 토큰 없으면 종료 (5H/7D 미표시, statusline 정상 동작)
[ -z "$TOKEN" ] && exit 1

# --- API 호출 ---
RESP=$(curl -s --max-time 5 \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  https://api.anthropic.com/api/oauth/usage 2>/dev/null)

[ -z "$RESP" ] && { touch "$CACHE_FILE"; exit 1; }

# JSON 검증
if ! echo "$RESP" | python3 -c "import json, sys; json.loads(sys.stdin.read())" 2>/dev/null; then
  touch "$CACHE_FILE"; exit 1
fi

# API 에러 응답 체크
if echo "$RESP" | jq -e '.error' >/dev/null 2>&1; then
  touch "$CACHE_FILE"; exit 1
fi

echo "$RESP" > "$CACHE_FILE"
