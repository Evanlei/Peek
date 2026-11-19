#!/bin/sh
# Adds Peek's PermissionRequest hook to ~/.claude/settings.json.
# Safe to re-run: existing hooks (including other apps' PermissionRequest hooks) are kept,
# and Peek's entry is only added once. A backup is written next to the settings file.
set -eu

SETTINGS="$HOME/.claude/settings.json"
HOOK="$HOME/.peek/permission-hook.sh"

command -v jq >/dev/null || { echo "jq is required (brew install jq)"; exit 1; }
[ -x "$HOOK" ] || { echo "Launch Peek once first — it writes $HOOK"; exit 1; }

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
jq empty "$SETTINGS" || { echo "$SETTINGS is not valid JSON; not touching it"; exit 1; }

if jq -e --arg h "$HOOK" '[.hooks.PermissionRequest[]?.hooks[]?.command] | index($h)' "$SETTINGS" >/dev/null; then
  echo "Peek hook already installed."
  exit 0
fi

cp "$SETTINGS" "$SETTINGS.bak-peek"
tmp="$(mktemp)"
jq --arg h "$HOOK" \
  '.hooks.PermissionRequest = ((.hooks.PermissionRequest // []) + [{"matcher":"*","hooks":[{"type":"command","command":$h,"timeout":600}]}])' \
  "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "Installed. Backup: $SETTINGS.bak-peek"
echo "New Claude Code sessions will send permission requests to Peek."
