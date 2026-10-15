#!/bin/bash

# Omarchy Setup - Slow Package Installer
# Installs slow-building AUR packages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Slow-Building AUR Package Installer ==="
echo

if [ ! -f aur-packages-slow.txt ] || [ ! -s aur-packages-slow.txt ]; then
    echo "No slow packages configured in aur-packages-slow.txt"
    exit 0
fi

MISSING_SLOW_AUR=$(comm -23 <(sort aur-packages-slow.txt) <(yay -Qq | sort))

if [ -z "$MISSING_SLOW_AUR" ]; then
    echo "✅ All slow-building packages are already installed!"
    exit 0
fi

echo "⚠️  These packages can take a very long time to compile and install."
echo

# Space toggles, Enter confirms; Enter with nothing selected (or Esc) picks none
mapfile -t PACKAGES_TO_INSTALL < <(echo "$MISSING_SLOW_AUR" \
    | fzf --multi --no-sort --layout=reverse --height=~15 \
        --header="Slow AUR packages to install (Space: select, Enter: install, Enter with none selected: skip)" \
        --bind 'space:toggle+down' \
        --bind 'enter:transform:[ "$FZF_SELECT_COUNT" -eq 0 ] && echo abort || echo accept' \
    || true)

if [ ${#PACKAGES_TO_INSTALL[@]} -eq 0 ]; then
    echo "   → No packages selected. Run './install-slow-packages.sh' anytime to install them."
    exit 0
fi

echo
echo "📦 Installing selected slow AUR packages..."
yay -S --needed --answerdiff None --answerclean None --removemake "${PACKAGES_TO_INSTALL[@]}"
echo
echo "✅ Slow packages installation complete!"
