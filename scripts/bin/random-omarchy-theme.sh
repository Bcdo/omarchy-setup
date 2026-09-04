#!/usr/bin/env bash
# Apply a random user-installed Omarchy theme and a random background from it.
# Written for Omarchy 4 (quattro): the shell owns the background, so this only
# needs the omarchy-theme-* commands.
set -euo pipefail

THEMES_DIR="$HOME/.config/omarchy/themes"
STATE_DIR="$HOME/.local/state/omarchy/current"

if [ ! -d "$THEMES_DIR" ]; then
  echo "No Omarchy themes dir found at $THEMES_DIR" >&2
  exit 1
fi

# Only real directories (skips broken symlinks and stray files).
mapfile -t THEMES < <(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
[ ${#THEMES[@]} -gt 0 ] || { echo "No themes found in $THEMES_DIR" >&2; exit 1; }

CHOICE="${THEMES[$(( RANDOM % ${#THEMES[@]} ))]}"
echo "Switching Omarchy theme → $CHOICE"

# Let omarchy-theme-set stage the theme and retint apps, but pick the background
# ourselves so it is random rather than "next in the list".
OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy-theme-set "$CHOICE"

mapfile -d '' -t BACKGROUNDS < <(
  find -L "$HOME/.config/omarchy/backgrounds/$CHOICE/" "$STATE_DIR/theme/backgrounds/" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) \
    -print0 2>/dev/null | sort -z
)

if (( ${#BACKGROUNDS[@]} > 0 )); then
  omarchy-theme-bg-set "${BACKGROUNDS[$(( RANDOM % ${#BACKGROUNDS[@]} ))]}"
else
  echo "No backgrounds found for $CHOICE" >&2
fi
