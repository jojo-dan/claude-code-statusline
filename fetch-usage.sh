#!/bin/bash
# Fetch account-level quota from Anthropic OAuth API and cache it.
# Requires Claude Code CLI to be authenticated (macOS Keychain).
# Exits silently (exit 0) when token is unavailable — quota display is optional.
CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_MAX_AGE=60  # seconds

# Skip if cache is fresh
if [ -f "$CACHE_FILE" ]; then
  AGE=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
  [ "$AGE" -lt "$CACHE_MAX_AGE" ] && exit 0
fi

# Graceful fallback: if token cannot be retrieved, skip quota display silently
TOKEN=$(security find-generic-password -s "Claude Code-credentials" -a "$(whoami)" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken' 2>/dev/null)
[ -z "$TOKEN" ] && exit 0

RESP=$(curl -s --max-time 5 \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  https://api.anthropic.com/api/oauth/usage 2>/dev/null)

[ -z "$RESP" ] && exit 0
echo "$RESP" > "$CACHE_FILE"
chmod 600 "$CACHE_FILE"
