#!/bin/sh
# Removes Peek's PermissionRequest hook from ~/.claude/settings.json, leaving everything else.
set -eu

SETTINGS="$HOME/.claude/settings.json"
HOOK="$HOME/.peek/permission-hook.sh"

command -v jq >/dev/null || { echo "jq is required (brew install jq)"; exit 1; }
[ -f "$SETTINGS" ] || { echo "No $SETTINGS; nothing to do."; exit 0; }

cp "$SETTINGS" "$SETTINGS.bak-peek"
tmp="$(mktemp)"
jq --arg h "$HOOK" '
  if .hooks.PermissionRequest then
    .hooks.PermissionRequest |= (map(.hooks |= map(select(.command != $h))) | map(select(.hooks | length > 0)))
    | if (.hooks.PermissionRequest | length) == 0 then del(.hooks.PermissionRequest) else . end
  else . end' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "Removed Peek's hook. Backup: $SETTINGS.bak-peek"
