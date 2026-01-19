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

echo "=== Omarchy Setup ==="
echo

# Ask about machine type upfront (before installations)
MACHINE_TYPE="desktop"
if [ -f configs/hypr/hypridle-desktop.conf ] || [ -f configs/hypr/hypridle-laptop.conf ]; then
  read -p "Is this a (l)aptop or (d)esktop? (l/d): " machine_type_input
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

# Install missing npm packages
if [ -f npm-packages.txt ] && [ -s npm-packages.txt ]; then
    echo
    echo "📦 Installing npm packages..."
    if command -v npm &> /dev/null; then
        while IFS= read -r package; do
            # Skip empty lines and comments
            [[ -z "$package" || "$package" =~ ^# ]] && continue
            
            # Check if package is already installed globally
            if npm list -g "$package" &> /dev/null; then
                echo "   → $package already installed"
            else
                echo "   → Installing $package..."
                npm install -g "$package"
            fi
        done < npm-packages.txt
    else
        echo "   ⚠️  npm not found. Install Node.js/npm first."
    fi
fi


# Install Hyprland config
echo
echo "⌨️  Installing Hyprland configuration..."
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

# Install systemd services/timers
echo
echo "⏰ Installing systemd services and timers..."
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

# Install Waybar config
echo
echo "📊 Installing Waybar configuration..."
if [ -d configs/waybar ] && [ "$(ls -A configs/waybar)" ]; then
    mkdir -p ~/.config/waybar
    for file in configs/waybar/*; do
        [ -f "$file" ] && backup_and_copy "$file" ~/.config/waybar/$(basename "$file")
    done
    echo "   → Waybar config applied (custom clock format + Pomodoro module)"
else
    echo "   → No Waybar config to apply"
fi

# Install mako config
echo
echo "🔔 Installing mako notification configuration..."
if [ -f configs/mako/config ]; then
    mkdir -p ~/.config/mako
    # Remove the existing symlink if it exists
    [ -L ~/.config/mako/config ] && rm ~/.config/mako/config
    backup_and_copy configs/mako/config ~/.config/mako/config
    echo "   → Mako config applied (custom Pomodoro notifications)"
else
    echo "   → No mako config to apply"
fi

# Install nvim config
echo
echo "✏️  Installing Neovim configuration..."
if [ -d configs/nvim ]; then
    # Restore lazyvim.json (extras configuration)
    if [ -f configs/nvim/lazyvim.json ]; then
        backup_and_copy configs/nvim/lazyvim.json ~/.config/nvim/lazyvim.json
        echo "   → LazyVim extras configuration applied"
    fi
    
    # Restore config files
    if [ -d configs/nvim/lua/config ] && [ "$(ls -A configs/nvim/lua/config)" ]; then
        mkdir -p ~/.config/nvim/lua/config
        for file in configs/nvim/lua/config/*; do
            [ -f "$file" ] && backup_and_copy "$file" ~/.config/nvim/lua/config/$(basename "$file")
        done
        echo "   → Custom config files applied"
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

# Install custom binaries (pomodoro module, etc.)
echo
echo "🔧 Installing custom binaries..."
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
    
    # Ensure ~/.local/bin is in PATH
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo "   → Adding ~/.local/bin to PATH in ~/.bashrc"
        echo '' >> ~/.bashrc
        echo '# Add ~/.local/bin to PATH for custom binaries' >> ~/.bashrc
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    echo "   → Custom binaries installed (PATH configured in Hyprland envs)"
else
    echo "   → No custom binaries to install"
fi

# Install webapps (.desktop files)
echo
echo "🌐 Installing web apps..."
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

# Install themes from GitHub
echo
echo "🎨 Installing Omarchy themes..."
if [ -f theme-repos.txt ]; then
    mkdir -p ~/.config/omarchy/themes
    THEMES_INSTALLED=0
    THEMES_SKIPPED=0
    
    while IFS= read -r repo_url; do
        # Skip empty lines and comments
        [[ -z "$repo_url" || "$repo_url" =~ ^# ]] && continue
        
        # Extract theme name from repo URL
        THEME_NAME=$(basename "$repo_url" .git)
        # Remove common prefixes/suffixes
        THEME_NAME=${THEME_NAME#omarchy-}
        THEME_NAME=${THEME_NAME%-theme}
        
        THEME_PATH=~/.config/omarchy/themes/"$THEME_NAME"
        
        # Skip if already installed
        if [ -d "$THEME_PATH" ]; then
            ((THEMES_SKIPPED++)) || true
        else
            echo "   → Installing $THEME_NAME..."
            if git clone --depth 1 --quiet "$repo_url" "$THEME_PATH" 2>/dev/null; then
                ((THEMES_INSTALLED++)) || true
            else
                echo "   ⚠️  Failed to install $THEME_NAME"
            fi
        fi
    done < theme-repos.txt
    
    echo "   → Installed $THEMES_INSTALLED theme(s), skipped $THEMES_SKIPPED already installed"
else
    echo "   → No theme-repos.txt found, skipping theme installation"
fi

# Set Firefox as default browser
echo
echo "🌐 Setting Firefox as default browser..."
if command -v firefox &> /dev/null; then
    xdg-settings set default-web-browser firefox.desktop
    echo "   → Firefox set as default browser"
elif command -v firefox-developer-edition &> /dev/null; then
    xdg-settings set default-web-browser firefox-developer-edition.desktop
    echo "   → Firefox Developer Edition set as default browser"
else
    echo "   → Firefox not installed, skipping"
fi

# Restart Waybar if running
echo
echo "🔄 Restarting Waybar..."
if pgrep -x waybar > /dev/null; then
    killall waybar
    echo "   → Waybar restarted (will be relaunched by Hyprland)"
else
    echo "   → Waybar not running, skipping restart"
fi

echo
echo "✅ Setup Complete!"
echo
echo "⚠️  MANUAL CONFIGURATION NEEDED:"
echo "   • Edit ~/.config/hypr/monitor.conf to match your display setup"
echo "   • Run 'hyprctl monitors' to see available monitors"
echo
echo "⚠️  TO APPLY ALL CHANGES:"
echo "   • Log out and log back in, or run: hyprctl reload"
echo "   • This is needed for Waybar to pick up the custom binaries (like Pomodoro)"

# Check for slow AUR packages
if [ -f aur-packages-slow.txt ] && [ -s aur-packages-slow.txt ]; then
    MISSING_SLOW_AUR=$(comm -23 <(sort aur-packages-slow.txt) <(yay -Qq | sort))
    if [ -n "$MISSING_SLOW_AUR" ]; then
        echo
        echo "📦 Slow-building AUR packages available"
        read -p "Do you want to install slow-building AUR packages now? (y/n): " install_slow
        
        if [[ "$install_slow" =~ ^[Yy]$ ]]; then
            "$SCRIPT_DIR/install-slow-packages.sh"
        else
            echo "   → Skipped. Run './install-slow-packages.sh' anytime to install them."
        fi
    fi
fi
