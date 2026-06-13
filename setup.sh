#!/bin/bash

# Omarchy Setup - Restore Script
# Restores configuration from this repository to the system

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "Error: Do not run this script as root!"
    echo "The script will ask for sudo password when needed."
    exit 1
fi

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

# Update Omarchy first (ensures fresh package databases and applies migrations)
read -p "Run omarchy-update first? (recommended) (y/n): " do_update
if [[ "$do_update" =~ ^[Yy]$ ]]; then
    omarchy-update -y
    echo
fi

# Remove unwanted packages (debloat)
echo "🗑️  Removing unwanted packages..."
if [ -f remove-packages.txt ]; then
    PKGS_TO_REMOVE=""
    while IFS= read -r pkg; do
        # Skip empty lines and comments
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
        # Check if package is installed
        if pacman -Qi "$pkg" &>/dev/null; then
            PKGS_TO_REMOVE="$PKGS_TO_REMOVE $pkg"
        fi
    done < remove-packages.txt
    
    if [ -n "$PKGS_TO_REMOVE" ]; then
        sudo pacman -Rns --noconfirm $PKGS_TO_REMOVE
        echo "   → Removed:$PKGS_TO_REMOVE"
    else
        echo "   → No packages to remove (already uninstalled)"
    fi
else
    echo "   → No remove-packages.txt found, skipping"
fi

# Remove unwanted webapps
echo
echo "🗑️  Removing unwanted webapps..."
if [ -f remove-webapps.txt ]; then
    REMOVED_COUNT=0
    while IFS= read -r webapp; do
        # Skip empty lines and comments
        [[ -z "$webapp" || "$webapp" =~ ^# ]] && continue
        DESKTOP_FILE="$HOME/.local/share/applications/$webapp.desktop"
        if [ -f "$DESKTOP_FILE" ]; then
            rm "$DESKTOP_FILE"
            ((REMOVED_COUNT++)) || true
        fi
    done < remove-webapps.txt
    
    if [ $REMOVED_COUNT -gt 0 ]; then
        echo "   → Removed $REMOVED_COUNT webapp(s)"
    else
        echo "   → No webapps to remove (already uninstalled)"
    fi
else
    echo "   → No remove-webapps.txt found, skipping"
fi
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

# Configure libvirt/QEMU (if packages are installed)
if pacman -Qi qemu-full &>/dev/null && pacman -Qi virt-manager &>/dev/null; then
    echo
    echo "🖥️  Configuring libvirt/QEMU..."
    
    # Add user to libvirt group
    if ! groups $(whoami) | grep -qw libvirt; then
        sudo usermod -aG libvirt $(whoami)
        echo "   → Added $(whoami) to libvirt group (log out/in to apply)"
    else
        echo "   → Already in libvirt group"
    fi
    
    # Enable libvirtd and modular sockets
    sudo systemctl enable --now libvirtd 2>/dev/null
    sudo systemctl enable --now virtnetworkd.socket 2>/dev/null
    sudo systemctl enable --now virtqemud.socket 2>/dev/null
    sudo systemctl enable --now virtstoraged.socket 2>/dev/null
    echo "   → libvirtd and sockets enabled"
    
    # Start default NAT network
    if sudo virsh net-info default &>/dev/null; then
        sudo virsh net-autostart default 2>/dev/null || true
        sudo virsh net-start default 2>/dev/null || true
        echo "   → Default network configured"
    else
        echo "   ⚠️  No default network defined — create one manually (see VM-SETUP.md)"
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

# Install battery charge thresholds (laptop only)
if [ "$MACHINE_TYPE" = "laptop" ] && [ -f configs/udev/99-battery-thresholds.rules ]; then
    echo
    echo "🔋 Installing battery charge thresholds..."
    if [ ! -f /etc/udev/rules.d/99-battery-thresholds.rules ] || \
       ! diff -q configs/udev/99-battery-thresholds.rules /etc/udev/rules.d/99-battery-thresholds.rules &>/dev/null; then
        sudo cp configs/udev/99-battery-thresholds.rules /etc/udev/rules.d/99-battery-thresholds.rules
        sudo udevadm control --reload-rules
        echo "   → Battery thresholds set (start: 40%, stop: 80%)"
    else
        echo "   → Battery thresholds already configured"
    fi
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

# Install omarchy branding
echo
echo "🎨 Installing Kodesmien screensaver branding..."
if [ -f configs/omarchy/branding/screensaver.txt ]; then
    mkdir -p ~/.config/omarchy/branding
    backup_and_copy configs/omarchy/branding/screensaver.txt ~/.config/omarchy/branding/screensaver.txt
    echo "   → Screensaver branding applied"
else
    echo "   → No branding config to apply"
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

# Sync Neovim treesitter parsers (prevents query errors from version mismatches)
echo "   → Updating treesitter parsers..."
nvim --headless "+TSUpdateSync" +qa 2>/dev/null && \
    echo "   → Treesitter parsers updated" || \
    echo "   ⚠️  Treesitter update skipped (run :TSUpdate manually in nvim)"

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
    
    # Ensure ~/.local/bin is in session PATH (for Hyprland/waybar to find custom binaries)
    UWSM_DEFAULT="$HOME/.config/uwsm/default"
    if [ -f "$UWSM_DEFAULT" ]; then
        if ! grep -q 'export PATH="\$HOME/.local/bin' "$UWSM_DEFAULT"; then
            echo '' >> "$UWSM_DEFAULT"
            echo '# Add ~/.local/bin to PATH for custom binaries (e.g., waybar-module-pomodoro)' >> "$UWSM_DEFAULT"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$UWSM_DEFAULT"
            echo "   → Added ~/.local/bin to session PATH (uwsm/default)"
        fi
    fi
    
    echo "   → Custom binaries installed"
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

# Offer to update installed themes
if [ -d ~/.config/omarchy/themes ] && [ "$(ls -A ~/.config/omarchy/themes 2>/dev/null)" ]; then
    echo
    read -p "Update installed themes? (recommended) (y/n): " do_theme_update
    if [[ "$do_theme_update" =~ ^[Yy]$ ]]; then
        omarchy-theme-update
    fi
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

# Optional: Android / Expo development setup
if [ -f scripts/setup-android.sh ]; then
    echo
    read -p "Set up Android / Expo development environment? (y/n): " setup_android
    if [[ "$setup_android" =~ ^[Yy]$ ]]; then
        "$SCRIPT_DIR/scripts/setup-android.sh"
    else
        echo "   → Skipped. Run './scripts/setup-android.sh' anytime to set it up."
    fi
fi

# Enable media directories (screenshots/recordings in subdirs)
echo
echo "📁 Configuring media directories..."
UWSM_DEFAULT="$HOME/.config/uwsm/default"
if [ -f "$UWSM_DEFAULT" ]; then
    # Create the directories
    mkdir -p "$HOME/Pictures/Screenshots"
    mkdir -p "$HOME/Videos/Screencasts"
    
    # Uncomment the export lines if they exist and are commented
    if grep -q '^#.*export OMARCHY_SCREENSHOT_DIR=' "$UWSM_DEFAULT"; then
        sed -i 's/^# *\(export OMARCHY_SCREENSHOT_DIR=.*\)/\1/' "$UWSM_DEFAULT"
        sed -i 's/^# *\(export OMARCHY_SCREENRECORD_DIR=.*\)/\1/' "$UWSM_DEFAULT"
        echo "   → Media directories enabled (Screenshots → ~/Pictures/Screenshots)"
    elif grep -q '^export OMARCHY_SCREENSHOT_DIR=' "$UWSM_DEFAULT"; then
        echo "   → Media directories already enabled"
    else
        # Add the lines if they don't exist
        echo '' >> "$UWSM_DEFAULT"
        echo 'export OMARCHY_SCREENSHOT_DIR="$HOME/Pictures/Screenshots"' >> "$UWSM_DEFAULT"
        echo 'export OMARCHY_SCREENRECORD_DIR="$HOME/Videos/Screencasts"' >> "$UWSM_DEFAULT"
        echo "   → Media directories configured"
    fi
else
    echo "   → uwsm config not found, skipping media directories"
fi

# Cleanup: remove orphaned packages and clear cache
echo
echo "🧹 Cleaning up..."
ORPHANS=$(pacman -Qdtq 2>/dev/null)
if [ -n "$ORPHANS" ]; then
    echo "$ORPHANS" | sudo pacman -Rns --noconfirm - 2>/dev/null || true
    echo "   → Removed orphaned packages"
else
    echo "   → No orphaned packages"
fi

# Clear package cache (keep only latest version)
yay -Sc --noconfirm 2>/dev/null || true
echo "   → Cleared package cache"
