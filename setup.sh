#!/bin/bash
# claude-code-statusline installer
# Creates a wrapper in ~/.claude/hud/ and registers statusLine in settings.json

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HUD_DIR="$CLAUDE_DIR/hud"
SETTINGS="$CLAUDE_DIR/settings.json"
WRAPPER="$HUD_DIR/statusline.sh"

echo "Installing claude-code-statusline..."

# Create wrapper that delegates to this repo's statusline.sh
mkdir -p "$HUD_DIR"
cat > "$WRAPPER" << WRAPPER_EOF
#!/bin/bash
exec "${REPO_DIR}/statusline.sh"
WRAPPER_EOF
chmod +x "$WRAPPER"
echo "  Wrapper created: $WRAPPER"

# Register statusLine in settings.json
if [ ! -f "$SETTINGS" ]; then
  echo "{}" > "$SETTINGS"
fi

HAS_STATUSLINE=$(jq 'has("statusLine")' "$SETTINGS" 2>/dev/null)
if [ "$HAS_STATUSLINE" = "true" ]; then
  echo "  statusLine already configured — skipping"
else
  jq ". + {\"statusLine\": {\"type\": \"command\", \"command\": \"${WRAPPER}\"}}" "$SETTINGS" > "${SETTINGS}.tmp" \
    && mv "${SETTINGS}.tmp" "$SETTINGS"
  echo "  statusLine registered in $SETTINGS"
fi

echo ""
echo "Done. Restart Claude Code to see the statusline."
