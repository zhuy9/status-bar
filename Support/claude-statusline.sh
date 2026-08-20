#!/bin/sh
set -eu

DIR="$HOME/Library/Application Support/AIUsage"
DEST="$DIR/claude-status.json"

mkdir -p "$DIR"
chmod 700 "$DIR" 2>/dev/null || true

TMP="$(mktemp "$DIR/claude-status.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP"
chmod 600 "$TMP" 2>/dev/null || true
mv -f "$TMP" "$DEST"
trap - EXIT

printf 'AI Usage'
