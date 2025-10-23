#!/bin/bash

# Omarchy Setup - Restore Script
# Restores configuration from this repository to the system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Helper function to backup and copy files
backup_and_copy() {
    local src="$1"
    local dest="$2"
    
    if [ -f "$dest" ]; then
        local backup="${dest}.bak.${TIMESTAMP}"
        cp "$dest" "$backup"
        echo "   📝 Backup: $(basename "$dest") → $(basename "$dest").bak"
    fi
    
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
}

echo "=== Omarchy Setup Restore ==="
echo

# Ask about machine type upfront (before installations)
MACHINE_TYPE="desktop"
if [ -f configs/hypr/hypridle-desktop.conf ] || [ -f configs/hypr/hypridle-laptop.conf ]; then
    read -p "Is this a laptop or desktop? (l/d): " machine_type_input
    case "$machine_type_input" in
        l|L|laptop)
            MACHINE_TYPE="laptop"
            ;;
        d|D|desktop|*)
            MACHINE_TYPE="desktop"
            ;;
    esac
    echo
fi

# Install missing packages
echo "📦 Installing packages..."
if [ -f packages.txt ]; then
    MISSING_PKGS=$(comm -23 <(sort packages.txt) <(pacman -Qq | sort))
    if [ -n "$MISSING_PKGS" ]; then
        echo "$MISSING_PKGS" | sudo pacman -S --needed -
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
        echo "$MISSING_AUR" | yay -S --needed --answerdiff None --answerclean None --removemake -
    else
        echo "   → All AUR packages already installed"
    fi
fi

# Restore Hyprland config
echo
echo "⌨️  Restoring Hyprland configuration..."
if [ -d configs/hypr ] && [ "$(ls -A configs/hypr)" ]; then
    mkdir -p ~/.config/hypr
    
    # Apply hypridle config based on machine type
    if [ "$MACHINE_TYPE" = "laptop" ] && [ -f configs/hypr/hypridle-laptop.conf ]; then
        backup_and_copy configs/hypr/hypridle-laptop.conf ~/.config/hypr/hypridle.conf
    elif [ -f configs/hypr/hypridle-desktop.conf ]; then
        backup_and_copy configs/hypr/hypridle-desktop.conf ~/.config/hypr/hypridle.conf
    fi
    
    # Copy all other hypr configs (except hypridle variants)
    for file in configs/hypr/*; do
        filename=$(basename "$file")
        if [[ "$filename" != "hypridle-desktop.conf" && "$filename" != "hypridle-laptop.conf" ]]; then
            [ -f "$file" ] && backup_and_copy "$file" ~/.config/hypr/$filename
        fi
    done
    echo "   → Hyprland config applied"
else
    echo "   → No Hyprland config to apply"
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
        fi
    done
    
    systemctl --user daemon-reload
    echo "   → Daily theme randomizer timer enabled"
else
    echo "   → No systemd configs to apply"
fi

# Restore Waybar config
echo
echo "📊 Restoring Waybar configuration..."
if [ -d configs/waybar ] && [ "$(ls -A configs/waybar)" ]; then
    mkdir -p ~/.config/waybar
    for file in configs/waybar/*; do
        [ -f "$file" ] && backup_and_copy "$file" ~/.config/waybar/$(basename "$file")
    done
    echo "   → Waybar config applied (custom clock format + Pomodoro module)"
else
    echo "   → No Waybar config to apply"
fi

# Restore mako config
echo
echo "🔔 Restoring mako notification configuration..."
if [ -f configs/mako/config ]; then
    mkdir -p ~/.config/mako
    # Remove the existing symlink if it exists
    [ -L ~/.config/mako/config ] && rm ~/.config/mako/config
    backup_and_copy configs/mako/config ~/.config/mako/config
    echo "   → Mako config applied (custom Pomodoro notifications)"
else
    echo "   → No mako config to apply"
fi

# Restore nvim config
echo
echo "✏️  Restoring Neovim configuration..."
if [ -d configs/nvim ]; then
    # Restore lazyvim.json (extras configuration)
    if [ -f configs/nvim/lazyvim.json ]; then
        backup_and_copy configs/nvim/lazyvim.json ~/.config/nvim/lazyvim.json
        echo "   → LazyVim extras configuration applied"
    fi
    
    # Restore plugin configs
    if [ -d configs/nvim/lua/plugins ] && [ "$(ls -A configs/nvim/lua/plugins)" ]; then
        mkdir -p ~/.config/nvim/lua/plugins
        for file in configs/nvim/lua/plugins/*; do
            [ -f "$file" ] && backup_and_copy "$file" ~/.config/nvim/lua/plugins/$(basename "$file")
        done
        echo "   → Custom plugin configs applied"
    fi
    
    # Restore snippets
    if [ -d configs/nvim/snippets ] && [ "$(ls -A configs/nvim/snippets)" ]; then
        mkdir -p ~/.config/nvim/snippets
        for file in configs/nvim/snippets/*; do
            [ -f "$file" ] && backup_and_copy "$file" ~/.config/nvim/snippets/$(basename "$file")
        done
        echo "   → Custom snippets applied"
    fi
else
    echo "   → No nvim config to apply"
fi

# Restore custom binaries (pomodoro module, etc.)
echo
echo "🔧 Restoring custom binaries..."
if [ -d scripts/bin ] && [ "$(ls -A scripts/bin)" ]; then
    mkdir -p ~/.local/bin
    for file in scripts/bin/*; do
        if [ -f "$file" ]; then
            DEST=~/.local/bin/$(basename "$file")
            if ! cp "$file" "$DEST" 2>/dev/null; then
                echo "   ⚠️  Skipped $(basename "$file") (currently running)"
            else
                chmod +x "$DEST"
            fi
        fi
    done
    echo "   → Custom binaries installed"
else
    echo "   → No custom binaries to install"
fi

# Restore webapps (.desktop files)
echo
echo "🌐 Restoring web apps..."
if [ -d webapps ] && [ "$(ls -A webapps/*.desktop 2>/dev/null)" ]; then
    mkdir -p ~/.local/share/applications
    for file in webapps/*.desktop; do
        if [ -f "$file" ]; then
            DEST=~/.local/share/applications/$(basename "$file")
            if [ ! -f "$DEST" ]; then
                cp "$file" "$DEST"
            else
                echo "   → Skipped $(basename "$file") (already installed)"
            fi
        fi
    done
    echo "   → Web apps installed"
else
    echo "   → No web apps to install"
fi

# Restore themes
echo
echo "🎨 Restoring Omarchy themes..."
if [ -d themes ] && [ "$(ls -A themes)" ]; then
    mkdir -p ~/.config/omarchy/themes
    for theme_dir in themes/*/; do
        if [ -d "$theme_dir" ]; then
            THEME_NAME=$(basename "$theme_dir")
            # Skip if it's a symlink in the config dir (system theme)
            if [ -L ~/.config/omarchy/themes/"$THEME_NAME" ]; then
                echo "   → Skipped $THEME_NAME (system theme)"
            elif [ -d ~/.config/omarchy/themes/"$THEME_NAME" ]; then
                echo "   → Skipped $THEME_NAME (already installed)"
            else
                cp -r "$theme_dir" ~/.config/omarchy/themes/
            fi
        fi
    done
    echo "   → Themes installed"
else
    echo "   → No themes to install"
fi

echo
echo "✅ Setup Complete!"
echo
echo "⚠️  MANUAL CONFIGURATION NEEDED:"
echo "   • Edit ~/.config/hypr/monitor.conf to match your display setup"
echo "   • Run 'hyprctl monitors' to see available monitors"
echo
echo "You may need to restart to see all changes."
