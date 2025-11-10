#!/usr/bin/env bash
set -euo pipefail

THEMES_DIR="$HOME/.config/omarchy/themes"

if [ ! -d "$THEMES_DIR" ]; then
  echo "No Omarchy themes dir found at $THEMES_DIR" >&2
  exit 1
fi

# load theme names into array
mapfile -t THEMES < <(ls -1 "$THEMES_DIR")
[ ${#THEMES[@]} -gt 0 ] || { echo "No themes found in $THEMES_DIR" >&2; exit 1; }

# choose random
RANDOM=${RANDOM:-$(date +%s)}
CHOICE="${THEMES[$(( RANDOM % ${#THEMES[@]} ))]}"

echo "Switching Omarchy theme → $CHOICE"

# Preferred: use omarchy helper if available (runs additional hooks)
if command -v omarchy-theme-set >/dev/null 2>&1; then
  omarchy-theme-set "$CHOICE"
  exit 0
fi

# Fallback: switch symlink and reload common pieces
ln -snf "$THEMES_DIR/$CHOICE" "$HOME/.config/omarchy/current"

# trigger reloads (best-effort)
touch "$HOME/.config/alacritty/alacritty.toml" 2>/dev/null || true
hyprctl reload 2>/dev/null || true
pkill -USR2 waybar 2>/dev/null || true
pkill -HUP mako 2>/dev/null || true

notify-send "Omarchy theme" "Applied: $CHOICE"

