#!/bin/bash

# Omarchy Setup - Restore Script (Omarchy 4 "quattro" edition)
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

# Locate the Omarchy install (exported by Hyprland; fall back to the usual places)
if [ -z "$OMARCHY_PATH" ]; then
    for candidate in "$HOME/.local/share/omarchy" /usr/share/omarchy; do
        if [ -d "$candidate/bin" ]; then
            export OMARCHY_PATH="$candidate"
            break
        fi
    done
fi
SHELL_JSON="$HOME/.config/omarchy/shell.json"
SHELL_JSON_DEFAULT="$OMARCHY_PATH/config/omarchy/shell.json"

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

# Apply a jq program to ~/.config/omarchy/shell.json (seeded from the Omarchy
# default when the user file is missing/empty) and ask the shell to reload it.
shell_json_apply() {
    local program="$1"
    shift
    local source="$SHELL_JSON"
    [ -s "$source" ] || source="$SHELL_JSON_DEFAULT"
    if [ ! -f "$source" ]; then
        echo "   ⚠️  No shell.json found (is Omarchy 4 installed?), skipping"
        return 1
    fi
    mkdir -p "$(dirname "$SHELL_JSON")"
    local tmp
    tmp=$(mktemp)
    jq -S "$@" "$program" "$source" > "$tmp"
    mv "$tmp" "$SHELL_JSON"
    omarchy-shell shell reloadConfig >/dev/null 2>&1 || true
}

echo "=== Omarchy Setup (quattro) ==="
echo

# Require Omarchy 4+ (this branch targets the quickshell-based quattro release)
OMARCHY_VERSION=$(cat "$OMARCHY_PATH/version" 2>/dev/null || omarchy-version 2>/dev/null || echo "0")
if [[ "${OMARCHY_VERSION%%.*}" =~ ^[0-9]+$ ]] && [ "${OMARCHY_VERSION%%.*}" -lt 4 ]; then
    echo "⚠️  Omarchy $OMARCHY_VERSION detected, but this setup targets Omarchy 4 (quattro)."
    echo "   Use the 'master' branch for older versions, or run omarchy-upgrade-to-quattro first."
    read -p "Continue anyway? (y/n): " continue_anyway
    [[ "$continue_anyway" =~ ^[Yy]$ ]] || exit 1
    echo
fi

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
        # 1Password also ships a Chromium extension; let Omarchy clean that up
        if [[ "$PKGS_TO_REMOVE" =~ 1password ]] && command -v omarchy-remove-service-1password &>/dev/null; then
            omarchy-remove-service-1password
        fi
        if command -v omarchy-pkg-drop &>/dev/null; then
            omarchy-pkg-drop $PKGS_TO_REMOVE
        else
            sudo pacman -Rns --noconfirm $PKGS_TO_REMOVE
        fi
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
            # omarchy-webapp-remove also deletes the icon; fall back to plain rm
            if command -v omarchy-webapp-remove &>/dev/null; then
                OMARCHY_REMOVE_NOTIFY=false omarchy-webapp-remove "$webapp" >/dev/null 2>&1 || rm -f "$DESKTOP_FILE"
            else
                rm -f "$DESKTOP_FILE"
            fi
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
if [ -f configs/omarchy/idle-desktop.json ] || [ -f configs/omarchy/idle-laptop.json ]; then
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

# Install Hyprland config (Lua overrides loaded by ~/.config/hypr/hyprland.lua)
echo
echo "⌨️  Installing Hyprland configuration..."
if [ -d configs/hypr ] && [ "$(ls -A configs/hypr)" ]; then
    mkdir -p ~/.config/hypr
    for file in configs/hypr/*.lua; do
        [ -f "$file" ] && backup_and_copy "$file" ~/.config/hypr/$(basename "$file")
    done
    echo "   → Hyprland config applied (bindings, input, monitors)"
else
    echo "   → No Hyprland config to apply"
fi

# Idle timeouts (screensaver/lock) live in shell.json now that hypridle is gone
echo
echo "💤 Configuring idle timeouts ($MACHINE_TYPE)..."
IDLE_FILE="configs/omarchy/idle-$MACHINE_TYPE.json"
if [ -f "$IDLE_FILE" ]; then
    if shell_json_apply '.idle = (.idle // {}) + $idle.idle' --argjson idle "$(cat "$IDLE_FILE")"; then
        echo "   → Screensaver after $(jq -r .idle.screensaver "$IDLE_FILE")s, lock after $(jq -r .idle.lock "$IDLE_FILE")s"
    fi
else
    echo "   → No idle profile for $MACHINE_TYPE, keeping Omarchy defaults"
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
    
    systemctl --user daemon-reload

    # Enable and start timers
    for timer in configs/systemd/*.timer; do
        if [ -f "$timer" ]; then
            TIMER_NAME=$(basename "$timer")
            systemctl --user enable "$TIMER_NAME" 2>/dev/null || true
            systemctl --user start "$TIMER_NAME" 2>/dev/null || true
        fi
    done
    
    echo "   → Daily theme randomizer timer enabled"
else
    echo "   → No systemd configs to apply"
fi

# Configure the Omarchy shell bar (replaces the old Waybar config)
echo
echo "📊 Configuring bar widgets..."
if [ -f configs/omarchy/bar-settings.txt ]; then
    while IFS='|' read -r widget key value; do
        [[ -z "$widget" || "$widget" =~ ^# ]] && continue
        if command -v omarchy-bar &>/dev/null && omarchy-bar set "$widget" "$key" "$value" >/dev/null 2>&1; then
            echo "   → $widget: $key = $value"
        else
            # Shell not running (e.g. over SSH): edit shell.json directly
            if shell_json_apply '(.bar.layout[]?[]? | select(.id == $id)) |= (.[$key] = $value)' \
                --arg id "$widget" --arg key "$key" --arg value "$value"; then
                echo "   → $widget: $key = $value (written to shell.json)"
            fi
        fi
    done < configs/omarchy/bar-settings.txt
else
    echo "   → No bar settings to apply"
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

# Install custom binaries (theme randomizer, pomodoro CLI, etc.)
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
    
    # Ensure ~/.local/bin is in session PATH (for Hyprland/shell to find custom binaries)
    UWSM_DEFAULT="$HOME/.config/uwsm/default"
    if [ -f "$UWSM_DEFAULT" ]; then
        if ! grep -q 'export PATH="\$HOME/.local/bin' "$UWSM_DEFAULT"; then
            echo '' >> "$UWSM_DEFAULT"
            echo '# Add ~/.local/bin to PATH for custom binaries' >> "$UWSM_DEFAULT"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$UWSM_DEFAULT"
            echo "   → Added ~/.local/bin to session PATH (uwsm/default)"
        fi
    fi
    
    echo "   → Custom binaries installed"
else
    echo "   → No custom binaries to install"
fi

# Install web apps (via omarchy-webapp-install so icons land in the right place)
echo
echo "🌐 Installing web apps..."
if [ -f webapps.txt ]; then
    WEBAPPS_INSTALLED=0
    while IFS='|' read -r name url icon; do
        [[ -z "$name" || "$name" =~ ^# ]] && continue
        DEST="$HOME/.local/share/applications/$name.desktop"
        if [ -f "$DEST" ]; then
            echo "   → Skipped $name (already installed)"
        elif omarchy-webapp-install "$name" "$url" "$icon" >/dev/null 2>&1; then
            ((WEBAPPS_INSTALLED++)) || true
        else
            echo "   ⚠️  Failed to install $name"
        fi
    done < webapps.txt
    echo "   → Installed $WEBAPPS_INSTALLED web app(s)"
else
    echo "   → No webapps.txt found, skipping"
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
        
        # Extract theme name from repo URL (same normalization as omarchy-theme-install)
        THEME_NAME=$(basename "$repo_url" .git | sed -E 's/^omarchy-//; s/-theme$//' | tr '[:upper:]' '[:lower:]')
        
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
if command -v firefox &> /dev/null && command -v omarchy-default-browser &> /dev/null; then
    omarchy-default-browser firefox
    echo "   → Firefox set as default browser"
elif command -v firefox &> /dev/null; then
    env -u BROWSER xdg-settings set default-web-browser firefox.desktop
    echo "   → Firefox set as default browser"
elif command -v firefox-developer-edition &> /dev/null; then
    env -u BROWSER xdg-settings set default-web-browser firefox-developer-edition.desktop
    echo "   → Firefox Developer Edition set as default browser"
else
    echo "   → Firefox not installed, skipping"
fi

# Reload Hyprland so the new Lua config takes effect
echo
echo "🔄 Reloading Hyprland..."
if hyprctl reload >/dev/null 2>&1; then
    echo "   → Hyprland config reloaded"
else
    echo "   → Hyprland not running, skipping reload"
fi

echo
echo "✅ Setup Complete!"
echo
echo "⚠️  MANUAL CONFIGURATION NEEDED:"
echo "   • Edit ~/.config/hypr/monitors.lua to match your display setup"
echo "   • Run 'hyprctl monitors' to see available monitors"
echo
echo "⚠️  TO APPLY ALL CHANGES:"
echo "   • Log out and log back in (needed for PATH and shell changes)"

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
