# WARP.md

Personal dotfiles for Omarchy Linux (Arch-based). Run `./setup.sh` to deploy.

## Structure

- `configs/` - Config files deployed to `~/.config/` (hypr, waybar, mako, nvim, systemd)
- `scripts/bin/` - Custom binaries deployed to `~/.local/bin/`
- `webapps/` - .desktop files for web apps
- `packages.txt`, `aur-packages.txt`, `aur-packages-slow.txt` - Package lists
- `npm-packages.txt` - Global npm packages
- `theme-repos.txt` - Git URLs for custom themes (cloned to `~/.config/omarchy/themes/`)

## Key Notes

- `hypridle-desktop.conf` / `hypridle-laptop.conf` - Script prompts which to deploy
- `waybar-module-pomodoro` - Custom compiled binary with modified notification messages (not the stock version)
- `setup.sh` creates timestamped `.bak.*` backups before overwriting files
- After setup, edit `~/.config/hypr/monitors.conf` for your displays
