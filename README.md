# Omarchy Custom Setup

Personal configuration and customizations for my Omarchy Linux system.

## Structure

```
omarchy-setup/
├── packages.txt              # Official pacman packages
├── aur-packages.txt          # AUR packages
├── configs/
│   ├── hypr/                 # Hyprland configuration
│   ├── systemd/              # Custom systemd services/timers
│   └── other/                # Other config files
├── webapps/                  # Custom .desktop files
├── scripts/                  # Utility scripts
├── capture.sh                # Capture current system state
└── setup.sh                  # Restore configuration to system
```

## Usage

### Capture Current Configuration
```bash
./capture.sh
```
This will collect your current packages, configs, and customizations into this repo.

### Restore Configuration
```bash
./setup.sh
```
This will:
- Install missing packages (official + AUR)
- Restore configuration files (with timestamped backups)
- Enable custom systemd services
- Show summary of changes

## Notes

- Backups are created with timestamp: `filename.bak.YYYY-MM-DD_HH-MM-SS`
- Review captured files before committing—remove Omarchy defaults you don't need
