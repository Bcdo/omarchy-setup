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

echo "⚠️  The following packages can take a very long time to compile and install:"
echo "$MISSING_SLOW_AUR"
echo

PACKAGES_TO_INSTALL=()
while IFS= read -r pkg <&3; do
    read -p "Install $pkg? (y/n): " confirm_pkg
    if [[ "$confirm_pkg" =~ ^[Yy]$ ]]; then
        PACKAGES_TO_INSTALL+=("$pkg")
    fi
done 3<<< "$MISSING_SLOW_AUR"

if [ ${#PACKAGES_TO_INSTALL[@]} -eq 0 ]; then
    echo "   → No packages selected for installation"
    exit 0
fi

echo
echo "📦 Installing selected slow AUR packages..."
yay -S --needed --answerdiff None --answerclean None --removemake "${PACKAGES_TO_INSTALL[@]}"
echo
echo "✅ Slow packages installation complete!"
