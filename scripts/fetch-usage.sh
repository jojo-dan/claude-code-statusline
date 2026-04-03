#!/bin/bash
# Claude Code OAuth usage API → cache
# Reads the OAuth token stored in the OS credential store on Claude Code login.
# Rate limit protection: touch cache mtime on error to maintain fetch interval.

CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_MAX_AGE=120  # seconds

# --- Cross-platform file mtime ---
file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Skip if cache is fresh
if [ -f "$CACHE_FILE" ]; then
  AGE=$(( $(date +%s) - $(file_mtime "$CACHE_FILE") ))
  [ "$AGE" -lt "$CACHE_MAX_AGE" ] && exit 0
fi

# --- Token retrieval: auto-detect OS credential store ---
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

# 3. Environment variable fallback
[ -z "$TOKEN" ] && TOKEN="${CLAUDE_OAUTH_TOKEN:-}"

# No token — exit (5H/7D hidden, statusline works normally)
[ -z "$TOKEN" ] && exit 1

# --- API call ---
RESP=$(curl -s --max-time 5 \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  https://api.anthropic.com/api/oauth/usage 2>/dev/null)

[ -z "$RESP" ] && { touch "$CACHE_FILE"; exit 1; }

# Validate JSON
if ! echo "$RESP" | python3 -c "import json, sys; json.loads(sys.stdin.read())" 2>/dev/null; then
  touch "$CACHE_FILE"; exit 1
fi

# Check for API error response
if echo "$RESP" | jq -e '.error' >/dev/null 2>&1; then
  touch "$CACHE_FILE"; exit 1
fi

echo "$RESP" > "$CACHE_FILE"
