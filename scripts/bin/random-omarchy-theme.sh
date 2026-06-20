#!/usr/bin/env bash
set -euo pipefail

THEMES_DIR="$HOME/.config/omarchy/themes"

if [ ! -d "$THEMES_DIR" ]; then
  echo "No Omarchy themes dir found at $THEMES_DIR" >&2
  exit 1
fi

# load theme names into array (only actual directories, not broken symlinks)
mapfile -t THEMES < <(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
[ ${#THEMES[@]} -gt 0 ] || { echo "No themes found in $THEMES_DIR" >&2; exit 1; }

# choose random
RANDOM=${RANDOM:-$(date +%s)}
CHOICE="${THEMES[$(( RANDOM % ${#THEMES[@]} ))]}"

echo "Switching Omarchy theme → $CHOICE"

# Preferred: use omarchy helper if available (runs additional hooks)
if command -v omarchy-theme-set >/dev/null 2>&1; then
  # Skip omarchy's own background launch; we pick a random one below.
  # Avoids two racing swaybg spawns within the same service cgroup.
  OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy-theme-set "$CHOICE"

  THEME_BACKGROUNDS_PATH="$HOME/.config/omarchy/current/theme/backgrounds/"
  USER_BACKGROUNDS_PATH="$HOME/.config/omarchy/backgrounds/$CHOICE/"
  CURRENT_BACKGROUND_LINK="$HOME/.config/omarchy/current/background"

  mapfile -d '' -t BACKGROUNDS < <(
    find -L "$USER_BACKGROUNDS_PATH" "$THEME_BACKGROUNDS_PATH" \
      -maxdepth 1 \
      -type f \
      -print0 2>/dev/null | sort -z
  )

  if (( ${#BACKGROUNDS[@]} > 0 )); then
    NEW_BACKGROUND="${BACKGROUNDS[$(( RANDOM % ${#BACKGROUNDS[@]} ))]}"

    CURRENT_BACKGROUND=""
    [[ -L "$CURRENT_BACKGROUND_LINK" ]] && CURRENT_BACKGROUND=$(readlink "$CURRENT_BACKGROUND_LINK")

    if [[ "$NEW_BACKGROUND" != "$CURRENT_BACKGROUND" ]]; then
      ln -nsf "$NEW_BACKGROUND" "$CURRENT_BACKGROUND_LINK"
      pkill -x swaybg 2>/dev/null || true
      setsid uwsm-app -- swaybg -i "$CURRENT_BACKGROUND_LINK" -m fill >/dev/null 2>&1 &
    fi
  fi

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

