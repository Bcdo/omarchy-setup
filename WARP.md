# WARP.md

Personal dotfiles for Omarchy Linux 4 "quattro" (Arch-based). Run `./setup.sh` to deploy.
The `master` branch targets pre-quattro Omarchy.

## Structure

- `configs/hypr/*.lua` - Hyprland Lua overrides deployed to `~/.config/hypr/` (loaded by Omarchy's `hyprland.lua`)
- `configs/omarchy/idle-*.json` - Idle timeouts merged into `~/.config/omarchy/shell.json`
- `configs/omarchy/bar-settings.txt` - `omarchy bar set` values (clock format)
- `configs/` - nvim, systemd, udev, branding deployed to `~/.config/`
- `scripts/bin/` - Custom binaries deployed to `~/.local/bin/`
- `webapps.txt` - Web apps installed with `omarchy-webapp-install` (`name|url|icon`)
- `plugins.txt` - Shell plugins installed with `omarchy plugin add --yes` then enabled (`git-url|section`)
- `packages.txt`, `aur-packages.txt`, `aur-packages-slow.txt` - Package lists to install
- `remove-packages.txt` - Stock Omarchy packages to uninstall
- `remove-webapps.txt` - Stock Omarchy webapps to remove (via `omarchy-webapp-remove`)
- `npm-packages.txt` - Global npm packages
- `theme-repos.txt` - Git URLs for custom themes (cloned to `~/.config/omarchy/themes/`)

## Key Notes

- Laptop/desktop prompt picks `idle-laptop.json` or `idle-desktop.json` (screensaver + lock seconds)
- Waybar, mako and hypridle no longer exist in quattro; the Quickshell shell owns bar, notifications and idle
- `setup.sh` creates timestamped `.bak.*` backups before overwriting files
- After setup, edit `~/.config/hypr/monitors.lua` for your displays

## Debloat Features (inspired by a-la-carchy)

- Removes unwanted stock packages and webapps automatically
- Enables media directories (screenshots → `~/Pictures/Screenshots`, recordings → `~/Videos/Screencasts`)
- Cleans orphaned packages and package cache at the end
