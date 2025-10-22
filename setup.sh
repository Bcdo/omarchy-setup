#!/bin/bash

# Omarchy Setup - Restore Script
# Restores configuration from this repository to the system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
CHANGES_MADE=()

# Helper function to backup and copy files
backup_and_copy() {
    local src="$1"
    local dest="$2"
    
    if [ -f "$dest" ]; then
        local backup="${dest}.bak.${TIMESTAMP}"
        cp "$dest" "$backup"
        CHANGES_MADE+=("📝 Backed up: $dest → ${backup}")
    fi
    
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    CHANGES_MADE+=("✏️  Restored: $dest")
}

echo "=== Omarchy Setup Restore ==="
echo

# Install missing packages
echo "📦 Installing packages..."
if [ -f packages.txt ]; then
    MISSING_PKGS=$(comm -23 <(sort packages.txt) <(pacman -Qq | sort))
    if [ -n "$MISSING_PKGS" ]; then
        echo "$MISSING_PKGS" | sudo pacman -S --needed -
        CHANGES_MADE+=("📦 Installed official packages: $(echo "$MISSING_PKGS" | wc -l) packages")
    else
        echo "   → All official packages already installed"
    fi
fi

# Install missing AUR packages
if [ -f aur-packages.txt ] && [ -s aur-packages.txt ]; then
    echo
    echo "📦 Installing AUR packages..."
    MISSING_AUR=$(comm -23 <(sort aur-packages.txt) <(yay -Qq | sort))
    if [ -n "$MISSING_AUR" ]; then
        echo "$MISSING_AUR" | yay -S --needed -
        CHANGES_MADE+=("📦 Installed AUR packages: $(echo "$MISSING_AUR" | wc -l) packages")
    else
        echo "   → All AUR packages already installed"
    fi
fi

# Restore Hyprland config
echo
echo "⌨️  Restoring Hyprland configuration..."
if [ -d configs/hypr ] && [ "$(ls -A configs/hypr)" ]; then
    mkdir -p ~/.config/hypr
    
    # Ask about machine type for hypridle config
    if [ -f configs/hypr/hypridle-desktop.conf ] || [ -f configs/hypr/hypridle-laptop.conf ]; then
        echo
        read -p "Is this a laptop or desktop? (l/d): " machine_type
        case "$machine_type" in
            l|L|laptop)
                if [ -f configs/hypr/hypridle-laptop.conf ]; then
                    backup_and_copy configs/hypr/hypridle-laptop.conf ~/.config/hypr/hypridle.conf
                    CHANGES_MADE+=("💻 Applied laptop hypridle config")
                fi
                ;;
            d|D|desktop|*)
                if [ -f configs/hypr/hypridle-desktop.conf ]; then
                    backup_and_copy configs/hypr/hypridle-desktop.conf ~/.config/hypr/hypridle.conf
                    CHANGES_MADE+=("🖥️  Applied desktop hypridle config")
                fi
                ;;
        esac
    fi
    
    # Copy all other hypr configs (except hypridle variants)
    for file in configs/hypr/*; do
        filename=$(basename "$file")
        if [[ "$filename" != "hypridle-desktop.conf" && "$filename" != "hypridle-laptop.conf" ]]; then
            [ -f "$file" ] && backup_and_copy "$file" ~/.config/hypr/$filename
        fi
    done
    echo "   → Hyprland config restored"
else
    echo "   → No Hyprland config to restore"
fi

# Restore systemd services/timers
echo
echo "⏰ Restoring systemd services and timers..."
if [ -d configs/systemd ] && [ "$(ls -A configs/systemd)" ]; then
    mkdir -p ~/.config/systemd/user
    for file in configs/systemd/*; do
        [ -f "$file" ] && backup_and_copy "$file" ~/.config/systemd/user/$(basename "$file")
    done
    
    # Enable and start timers
    for timer in configs/systemd/*.timer; do
        if [ -f "$timer" ]; then
            TIMER_NAME=$(basename "$timer")
            systemctl --user enable "$TIMER_NAME" 2>/dev/null || true
            systemctl --user start "$TIMER_NAME" 2>/dev/null || true
            CHANGES_MADE+=("⏰ Enabled: $TIMER_NAME")
        fi
    done
    
    systemctl --user daemon-reload
    echo "   → Systemd configs restored and enabled"
else
    echo "   → No systemd configs to restore"
fi

# Restore Waybar config
echo
echo "📊 Restoring Waybar configuration..."
if [ -d configs/waybar ] && [ "$(ls -A configs/waybar)" ]; then
    mkdir -p ~/.config/waybar
    for file in configs/waybar/*; do
        [ -f "$file" ] && backup_and_copy "$file" ~/.config/waybar/$(basename "$file")
    done
    echo "   → Waybar config restored"
else
    echo "   → No Waybar config to restore"
fi

# Restore custom binaries (pomodoro module, etc.)
echo
echo "🔧 Restoring custom binaries..."
if [ -d scripts/bin ] && [ "$(ls -A scripts/bin)" ]; then
    mkdir -p ~/.local/bin
    for file in scripts/bin/*; do
        if [ -f "$file" ]; then
            cp "$file" ~/.local/bin/$(basename "$file")
            chmod +x ~/.local/bin/$(basename "$file")
            CHANGES_MADE+=("🔧 Installed: $(basename "$file")")
        fi
    done
    echo "   → Custom binaries installed"
else
    echo "   → No custom binaries to restore"
fi

# Restore webapps (.desktop files)
echo
echo "🌐 Restoring web apps..."
if [ -d webapps ] && [ "$(ls -A webapps/*.desktop 2>/dev/null)" ]; then
    mkdir -p ~/.local/share/applications
    for file in webapps/*.desktop; do
        [ -f "$file" ] && backup_and_copy "$file" ~/.local/share/applications/$(basename "$file")
    done
    echo "   → Web apps restored"
else
    echo "   → No web apps to restore"
fi

# Summary
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

if [ ${#CHANGES_MADE[@]} -gt 0 ]; then
    echo "Changes made:"
    for change in "${CHANGES_MADE[@]}"; do
        echo "  $change"
    done
else
    echo "No changes were needed - system already up to date!"
fi

echo
echo "⚠️  MANUAL CONFIGURATION NEEDED:"
echo "   • Edit ~/.config/hypr/monitor.conf to match your display setup"
echo "   • Run 'hyprctl monitors' to see available monitors"
echo
echo "You may need to reload Hyprland (Super+Shift+R) or restart to see all changes."
