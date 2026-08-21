#!/bin/sh
# Installs the Claude Code status-line helper and wires it into ~/.claude/settings.json.
# Re-running is safe. Pass --force to replace a different statusLine you already have.
set -eu

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

SRC="$(cd "$(dirname "$0")" && pwd)/claude-statusline.sh"
CLAUDE_DIR="$HOME/.claude"
DEST="$CLAUDE_DIR/ai-usage-statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
PAYLOAD="{\"type\":\"command\",\"command\":\"$DEST\"}"

command -v plutil >/dev/null 2>&1 || { echo "error: plutil not found; this script is macOS-only." >&2; exit 1; }
[ -f "$SRC" ] || { echo "error: $SRC not found; run this from the repo checkout." >&2; exit 1; }

mkdir -p "$CLAUDE_DIR"
cp "$SRC" "$DEST"
chmod 755 "$DEST"
echo "installed helper: $DEST"

if [ ! -f "$SETTINGS" ]; then
    printf '%s\n' "{\"statusLine\":$PAYLOAD}" > "$SETTINGS"
    echo "created $SETTINGS with statusLine"
    exit 0
fi

plutil -lint -s -- "$SETTINGS" >/dev/null 2>&1 || {
    echo "error: $SETTINGS is not valid JSON. Fix it, then re-run." >&2; exit 1
}

CURRENT="$(plutil -extract statusLine.command raw -o - -- "$SETTINGS" 2>/dev/null || true)"
if [ "$CURRENT" = "$DEST" ]; then
    echo "statusLine already points at the helper; nothing to change."
    exit 0
fi
if [ -n "$CURRENT" ] && [ "$FORCE" -eq 0 ]; then
    echo "error: settings.json already has a statusLine command:" >&2
    echo "         $CURRENT" >&2
    echo "       Re-run with --force to replace it (a backup is kept), or merge by hand." >&2
    exit 1
fi

BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$BACKUP"
TMP="$(mktemp -t ai-usage-settings)"
trap 'rm -f "$TMP"' EXIT
plutil -replace statusLine -json "$PAYLOAD" -o "$TMP" -- "$SETTINGS"
plutil -convert json -r -o "$SETTINGS" -- "$TMP"
echo "updated $SETTINGS (backup: $BACKUP)"
echo "Send one Claude request, then open the menu bar app."
