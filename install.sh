#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SCRIPT_NAME="statusline-command.sh"
RAW_BASE="https://raw.githubusercontent.com/simoneanam/ozn-cc-statusline/main"
DEST_DIR="$HOME/.claude"
DEST_SCRIPT="$DEST_DIR/$SCRIPT_NAME"
SETTINGS="$DEST_DIR/settings.json"
SETTINGS_BAK="$DEST_DIR/settings.json.bak"

STATUS_LINE_BLOCK='{
  "type": "command",
  "command": "bash \"$HOME/.claude/statusline-command.sh\""
}'

uninstall() {
  echo "Uninstalling claude-statusline..."

  if [ -f "$DEST_SCRIPT" ]; then
    rm "$DEST_SCRIPT"
    echo "  Removed $DEST_SCRIPT"
  fi

  if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
    jq 'del(.statusLine)' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "  Removed statusLine from $SETTINGS"
  fi

  echo "Done."
  exit 0
}

# ── parse args ────────────────────────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    --uninstall|-u) uninstall ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ── check dependencies ────────────────────────────────────────────────────────

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  echo "  macOS:  brew install jq"
  echo "  Linux:  apt install jq  /  dnf install jq"
  exit 1
fi

# ── install ───────────────────────────────────────────────────────────────────

echo "Installing claude-statusline..."

mkdir -p "$DEST_DIR"

# backup existing settings
if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS_BAK"
  echo "  Backed up $SETTINGS → $SETTINGS_BAK"
fi

# get the status line script:
#   - cloned repo  → copy the local file next to this installer
#   - curl | bash  → only install.sh was fetched, so download the script too
if [ -f "$SCRIPT_DIR/$SCRIPT_NAME" ]; then
  cp "$SCRIPT_DIR/$SCRIPT_NAME" "$DEST_SCRIPT"
else
  echo "  Fetching $SCRIPT_NAME from repo..."
  curl -fsSL "$RAW_BASE/$SCRIPT_NAME" -o "$DEST_SCRIPT"
fi
chmod +x "$DEST_SCRIPT"
echo "  Installed $DEST_SCRIPT"

# merge statusLine into settings.json
if [ -f "$SETTINGS" ]; then
  jq --argjson sl "$STATUS_LINE_BLOCK" '. + {statusLine: $sl}' "$SETTINGS" \
    > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
else
  jq -n --argjson sl "$STATUS_LINE_BLOCK" '{statusLine: $sl}' > "$SETTINGS"
fi
echo "  Merged statusLine into $SETTINGS"

echo "Done. Restart Claude Code to activate the status line."
