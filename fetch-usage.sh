#!/bin/bash
# Fetch account-level quota from Anthropic OAuth API and cache it.
# Requires Claude Code CLI to be authenticated (macOS Keychain).
# Exits silently (exit 0) when token is unavailable — quota display is optional.
CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_MAX_AGE=60  # seconds
LOCK_DIR="/tmp/claude-usage-fetch.lock"
COOLDOWN_FILE="/tmp/claude-usage-cooldown"
COOLDOWN_SEC=120  # back off 2 min on API error

# Cooldown: skip API calls entirely after a recent failure
if [ -f "$COOLDOWN_FILE" ]; then
  CD_AGE=$(( $(date +%s) - $(date -r "$COOLDOWN_FILE" +%s) ))
  [ "$CD_AGE" -lt "$COOLDOWN_SEC" ] && exit 0
  rm -f "$COOLDOWN_FILE"
fi

# Single-process guard (mkdir is atomic on macOS APFS — losers exit immediately)
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # Stale lock detection: check if owner PID is alive
  OWNER_PID=$(cat "$LOCK_DIR/pid" 2>/dev/null)
  if [ -n "$OWNER_PID" ] && kill -0 "$OWNER_PID" 2>/dev/null; then
    exit 0  # Lock holder alive — skip
  fi
  # Stale lock — clean up and retry once
  rm -rf "$LOCK_DIR"
  mkdir "$LOCK_DIR" 2>/dev/null || exit 0
fi
echo $$ > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR" 2>/dev/null' EXIT

# Skip if valid cache is fresh
if [ -f "$CACHE_FILE" ]; then
  if ! jq -e '.error' "$CACHE_FILE" >/dev/null 2>&1; then
    AGE=$(( $(date +%s) - $(date -r "$CACHE_FILE" +%s) ))
    [ "$AGE" -lt "$CACHE_MAX_AGE" ] && exit 0
  fi
fi

# Graceful fallback: if token cannot be retrieved, skip quota display silently
TOKEN=$(security find-generic-password -s "Claude Code-credentials" -a "$(whoami)" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken' 2>/dev/null)
[ -z "$TOKEN" ] && exit 0

RESP=$(curl -s --max-time 5 \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  https://api.anthropic.com/api/oauth/usage 2>/dev/null)

[ -z "$RESP" ] && exit 0

# Only cache valid responses atomically; on error, set cooldown and preserve previous good cache
if echo "$RESP" | jq -e '.five_hour' >/dev/null 2>&1; then
  TMPFILE=$(mktemp "/tmp/.claude-usage-cache.XXXXXX") || exit 0
  echo "$RESP" > "$TMPFILE"
  chmod 600 "$TMPFILE"
  mv "$TMPFILE" "$CACHE_FILE"
  rm -f "$COOLDOWN_FILE"
else
  touch "$COOLDOWN_FILE"
fi
