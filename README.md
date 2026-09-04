# Omarchy Custom Setup (quattro)

Personal setup for Omarchy Linux 4 ("quattro"). Run `./setup.sh` to deploy configs to a new system.

This is the `quattro` branch. For Omarchy 3.x and earlier use the `master` branch.

## Usage

```bash
./setup.sh
```

The script installs packages, deploys configs, and sets up systemd timers. It prompts for laptop vs desktop (for idle/lock timeouts) and optionally installs slow-building AUR packages and debloats inspired by [debloat script](https://github.com/DanielCoffey1/a-la-carchy).

## Structure

- `configs/hypr/` - Hyprland Lua overrides (`bindings.lua`, `input.lua`, `monitors.lua`) → `~/.config/hypr/`
- `configs/omarchy/idle-{desktop,laptop}.json` - Screensaver/lock timeouts merged into `~/.config/omarchy/shell.json`
- `configs/omarchy/bar-settings.txt` - Bar widget settings applied with `omarchy bar set` (clock format)
- `configs/omarchy/branding/` - Screensaver branding
- `configs/nvim/`, `configs/systemd/`, `configs/udev/` - Neovim, systemd timers, battery thresholds
- `scripts/bin/` - Custom binaries → `~/.local/bin/`
- `webapps.txt` - Web apps (`name|url|icon`) installed with `omarchy-webapp-install`
- `plugins.txt` - Shell plugins (`git-url|section`) installed with `omarchy plugin add --enable`
- `theme-repos.txt` - Git URLs for themes → cloned to `~/.config/omarchy/themes/`
- `packages.txt`, `aur-packages.txt`, `aur-packages-slow.txt` - Package lists
- `npm-packages.txt` - Global npm packages

## What changed from the pre-quattro setup

Omarchy 4 replaced Waybar, mako, hypridle and the `.conf` Hyprland files with a Quickshell-based
shell and Lua Hyprland config. This branch adapts to that:

- Hyprland `.conf` overrides became Lua (`hl.config`, `o.bind`, `hl.unbind`). Only the differences
  from Omarchy's defaults are kept (Proton mail/calendar, GitHub on Super+Shift+Alt+G, btop on
  Super+Shift+T, Norwegian layout).
- Idle timeouts are `idle.screensaver` / `idle.lock` in `shell.json` (the shell has no separate
  screen-off/suspend timers, so those were dropped).
- The Waybar clock format is now set on the `omarchy.clock` bar widget. The custom Pomodoro module
  was dropped; bar extras are shell plugins now (see `plugins.txt`).
- mako is gone; notifications are rendered by the shell, so the custom notification styling is dropped.
- Web apps are installed via `omarchy-webapp-install` so icons land in `~/.local/share/icons`.
- `random-omarchy-theme.sh` uses `omarchy-theme-set` + `omarchy-theme-bg-set` (no swaybg).

## Android / Expo Development

Optional setup for React Native / Expo development. Run standalone or choose it during `setup.sh`:

```bash
./scripts/setup-android.sh
```

Installs Android SDK (cmdline-tools, platform-tools, build-tools, emulator, system image), creates a Pixel emulator, and configures `JAVA_HOME`/`ANDROID_HOME`/`PATH` in `~/.bashrc`. Requires `android-studio` (available via `install-slow-packages.sh`).

## QEMU / Virt-Manager Setup

See [VM-SETUP.md](VM-SETUP.md) for the full guide on setting up QEMU, virt-manager, and Kali Linux VMs.

## Notes

- Backups are created as `filename.bak.YYYY-MM-DD_HH-MM-SS` before overwriting
- After setup, edit `~/.config/hypr/monitors.lua` for your displays
- Bar layout can be tweaked live with `omarchy bar ...` and `omarchy plugin ...`
