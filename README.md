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
│   ├── mako/                 # Notification daemon config
│   │   └── config
│   ├── nvim/                 # Neovim customizations
│   │   ├── lua/plugins/       # Custom plugin configs
│   │   └── snippets/          # Custom code snippets
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
- Apply Mako config to `~/.config/mako/` (notification styling, including Pomodoro timer notifications)
- Apply Neovim configs to `~/.config/nvim/` (custom plugins, snippets, surround rules)
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

### Customize Pomodoro Notifications

The Pomodoro timer sends notifications styled via `configs/mako/config`. To customize:

1. Edit `~/.config/mako/config` (or `configs/mako/config` in this repo)
2. Modify the `[summary="🍅 Pomodoro Timer"]` section (size, font, position, etc.)
3. Reload mako: `makoctl reload`

### Neovim Customizations

This setup includes custom Neovim configurations on top of Omarchy's base nvim setup:

- **LazyVim Extras**: Pre-configured language support and plugins:
  - AI: GitHub Copilot & Copilot Chat
  - Coding: mini-surround, yanky (clipboard manager)
  - Editor: neo-tree (file explorer)
  - Formatting: Prettier
  - Languages: Astro, C#/.NET, Git, JSON, Markdown, Python, Tailwind, TypeScript, Vue
  - Linting: ESLint
  - Utils: mini-hipatterns
- **Custom Surround**: Added `sac` keybinding to surround text with `{{ }}` (double curly braces with spaces)
- **Custom Snippets**: C# snippets in `configs/nvim/snippets/cs.json`

These configs are applied to `~/.config/nvim/`.

## Notes

- **Backups**: All replaced files get timestamped backups: `filename.bak.YYYY-MM-DD_HH-MM-SS`
- **Manual config needed**: After setup, edit `~/.config/hypr/monitors.conf` for your displays (use `hyprctl monitors` to see available displays)
- **Reload required**: You may need to reload Hyprland (`Super+Shift+R`) or restart to see changes
