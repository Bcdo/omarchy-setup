# Omarchy Custom Setup

Personal configuration and customizations for Omarchy Linux. Use this to set up a new system or sync changes across machines.

## Structure

```
omarchy-setup/
├── packages.txt              # Official pacman packages
├── aur-packages.txt          # AUR packages
├── configs/
│   ├── hypr/                 # Hyprland configuration
│   │   ├── bindings.conf
│   │   ├── monitors.conf
│   │   ├── input.conf
│   │   ├── hypridle-desktop.conf
│   │   └── hypridle-laptop.conf
│   ├── waybar/               # Waybar status bar
│   │   ├── config.jsonc
│   │   └── style.css
│   └── systemd/              # Custom systemd services/timers
├── scripts/
│   └── bin/                  # Custom binaries (installed to ~/.local/bin)
├── themes/                   # Custom Omarchy themes
├── webapps/                  # .desktop files for web applications
└── setup.sh                  # Restore configuration to system
```

## Usage

### Apply Configuration

```bash
./setup.sh
```

The script will first ask if this is a laptop or desktop (for `hypridle` configuration), then:

- Install missing packages from `packages.txt` (official repos)
- Install missing AUR packages from `aur-packages.txt`
- Apply Hyprland configs to `~/.config/hypr/` (keybindings, idle behavior, etc.)
- Apply Waybar config to `~/.config/waybar/` (custom clock format + Pomodoro timer module)
- Install custom binaries to `~/.local/bin/` (waybar-module-pomodoro)
- Install systemd daily theme randomizer timer to `~/.config/systemd/user/`
- Install custom Omarchy themes to `~/.config/omarchy/themes/`
- Install webapp .desktop files to `~/.local/share/applications/`
- Create timestamped backups before overwriting existing files

### Test What Would Be Installed

```bash
# Check what official packages would be installed
comm -23 <(sort packages.txt) <(pacman -Qq | sort)

# Check what AUR packages would be installed
comm -23 <(sort aur-packages.txt) <(yay -Qq | sort)
```

### Manage Systemd Timers

```bash
# Check status of custom timers
systemctl --user status random-omarchy-theme.timer

# View timer logs
journalctl --user -u random-omarchy-theme.service
```

## Notes

- **Backups**: All replaced files get timestamped backups: `filename.bak.YYYY-MM-DD_HH-MM-SS`
- **Manual config needed**: After setup, edit `~/.config/hypr/monitors.conf` for your displays (use `hyprctl monitors` to see available displays)
- **Reload required**: You may need to reload Hyprland (`Super+Shift+R`) or restart to see changes
