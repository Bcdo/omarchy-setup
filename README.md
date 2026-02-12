# Omarchy Custom Setup

Personal setup for Omarchy Linux. Run `./setup.sh` to deploy configs to a new system.

## Usage

```bash
./setup.sh
```

The script installs packages, deploys configs, and sets up systemd timers. It prompts for laptop vs desktop (for hypridle config) and optionally installs slow-building AUR packages and debloats inspired by [debloat script](https://github.com/DanielCoffey1/a-la-carchy).

## Structure

- `configs/` - Hyprland, Waybar, Mako, Neovim, systemd configs → `~/.config/`
- `scripts/bin/` - Custom binaries → `~/.local/bin/`
- `webapps/` - .desktop files → `~/.local/share/applications/`
- `theme-repos.txt` - Git URLs for themes → cloned to `~/.config/omarchy/themes/`
- `packages.txt`, `aur-packages.txt`, `aur-packages-slow.txt` - Package lists
- `npm-packages.txt` - Global npm packages

## Notes

- Backups are created as `filename.bak.YYYY-MM-DD_HH-MM-SS` before overwriting
- After setup, edit `~/.config/hypr/monitors.conf` for your displays
- The `waybar-module-pomodoro` binary is custom as it was the only way to change the message. Edit `configs/mako/config` to change styling only
