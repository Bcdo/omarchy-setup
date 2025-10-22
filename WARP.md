# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This repository manages personal configuration and customizations for an Omarchy Linux system (Arch-based distribution). It functions as a dotfiles/system configuration repository with a bidirectional sync approach:
- **Capture** (not yet implemented): Would collect current system state into this repo
- **Restore** (`setup.sh`): Deploys configurations from this repo to the system

## Key Commands

### Restore configuration to system
```bash
./setup.sh
```
This is the primary command. It:
- Installs missing pacman packages from `packages.txt`
- Installs missing AUR packages from `aur-packages.txt` (using `yay`)
- Restores Hyprland configs to `~/.config/hypr/`
- Restores Waybar configs to `~/.config/waybar/`
- Installs custom binaries to `~/.local/bin/`
- Installs systemd user services/timers to `~/.config/systemd/user/`
- Restores custom Omarchy themes to `~/.config/omarchy/themes/`
- Installs webapp .desktop files to `~/.local/share/applications/`
- Creates timestamped backups (`.bak.YYYY-MM-DD_HH-MM-SS`) before overwriting files

**Interactive prompts**: The script asks whether the system is a laptop or desktop to deploy the appropriate `hypridle` configuration variant.

### Test package installation (dry run)
```bash
# Check what official packages would be installed
comm -23 <(sort packages.txt) <(pacman -Qq | sort)

# Check what AUR packages would be installed
comm -23 <(sort aur-packages.txt) <(yay -Qq | sort)
```

### Manage systemd timers
```bash
# Check status of custom timers
systemctl --user status random-omarchy-theme.timer

# View timer logs
journalctl --user -u random-omarchy-theme.service
```

## Architecture

### Repository Structure
```
configs/
  hypr/                    # Hyprland window manager configs
    bindings.conf          # Keyboard shortcuts and app launches
    monitors.conf          # Display configuration
    input.conf             # Input device settings
    hypridle-desktop.conf  # Desktop idle/lock settings
    hypridle-laptop.conf   # Laptop idle/lock settings (with suspend)
  waybar/                  # Status bar configuration
    config.jsonc           # Module configuration
    style.css              # Styling
  systemd/                 # User systemd services and timers
scripts/
  bin/                     # Custom executables (installed to ~/.local/bin)
    waybar-module-pomodoro # Compiled binary for Pomodoro timer module
themes/                    # Custom Omarchy themes (29 themes)
  aetheria/                # Example theme directory
  crimson-gold/
  cyberpunk/
  ...
webapps/                   # .desktop files for web applications
packages.txt               # Official Arch packages
aur-packages.txt           # AUR packages
setup.sh                   # Main restore script
```

### Configuration Philosophy

**Machine-specific configs**: The `hypridle-{desktop,laptop}.conf` files are variants for different hardware. The setup script prompts the user to select which variant to deploy as `hypridle.conf`.

**Omarchy integration**: This is built on top of Omarchy Linux, which provides:
- `omarchy-*` utilities (e.g., `omarchy-menu`, `omarchy-launch-browser`, `omarchy-cmd-terminal-cwd`)
- Custom terminal: `$TERMINAL` variable and `uwsm` session manager
- Pre-configured Hyprland/Waybar base setup

**Custom extensions**: This repo adds user-specific customizations:
- Additional packages not in base Omarchy
- Custom keybindings (see `configs/hypr/bindings.conf`)
- Custom Waybar modules (e.g., Pomodoro timer)
- Systemd automation (e.g., theme randomization timer)
- Webapp launchers (.desktop files)

### Important Patterns

**Backup strategy**: The `backup_and_copy()` function in `setup.sh` creates timestamped backups automatically. Never modify this pattern without preserving backup functionality.

**Systemd timer activation**: The setup script automatically enables and starts any `.timer` files found in `configs/systemd/`. The corresponding `.service` files must have matching names.

**Binary installation**: Files in `scripts/bin/` are copied to `~/.local/bin/` and made executable. The Pomodoro module is a compiled ELF binary, not a script.

## Development Workflow

### Adding a new package
1. Add package name to `packages.txt` (for official repos) or `aur-packages.txt` (for AUR)
2. Run `./setup.sh` to install

### Adding a new config file
1. Create the file in the appropriate `configs/` subdirectory
2. Update `setup.sh` if it's a new config category (not Hyprland/Waybar/systemd)
3. Test by running `./setup.sh`

### Adding a custom binary/script
1. Place executable in `scripts/bin/`
2. Run `./setup.sh` to install to `~/.local/bin/`
3. Reference in configs (e.g., Waybar modules) using the base filename

### Creating systemd automation
1. Create `.service` and `.timer` files in `configs/systemd/`
2. Ensure filenames match (e.g., `foo.service` and `foo.timer`)
3. Run `./setup.sh` to install and enable the timer

### Adding or updating themes
1. Place theme directory in `themes/`
2. Run `./setup.sh` to copy to `~/.config/omarchy/themes/`
3. Use `omarchy-menu` to switch themes or the systemd timer will randomize

**Note**: System themes (catppuccin, gruvbox, nord, etc.) are symlinked from `~/.local/share/omarchy/themes/` and should not be included in this repo.

## Important Notes

- **Manual display configuration required**: After running setup, users must edit `~/.config/hypr/monitor.conf` for their specific displays. Use `hyprctl monitors` to discover available monitors.
- **Hyprland reload**: Changes may require `Super+Shift+R` or a full restart to take effect.
- **No capture script yet**: The README references `capture.sh` but it doesn't exist. Any work on capturing system state would need to create this script.
- **Backup files are gitignored**: The `.gitignore` excludes `*.bak.*` files created by the setup script.
