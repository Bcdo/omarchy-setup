# Pomodoro Module Fix

## Problem
The Waybar pomodoro module wasn't appearing after running the setup script on a fresh Omarchy install, even after restarting the computer.

## Root Cause
The `waybar-module-pomodoro` binary was installed to `~/.local/bin`, but this directory wasn't in the PATH for processes launched by Hyprland. The setup script only added it to `~/.bashrc`, which doesn't affect graphical sessions started by the display manager.

## Solution
Created `configs/hypr/envs.conf` that adds `~/.local/bin` to the PATH at the Hyprland level:

```
# Extra env variables
# Add ~/.local/bin to PATH for custom binaries (e.g., waybar-module-pomodoro)
env = PATH,$HOME/.local/bin:$PATH
```

This ensures all processes launched by Hyprland (including Waybar) can find the custom binaries.

## Changes Made

1. **Created `configs/hypr/envs.conf`** - New file that sets PATH in Hyprland environment
2. **Updated `setup.sh`** - Modified completion message to inform users they need to reload Hyprland

## Testing
After running the setup script on a fresh install:
1. The script will copy `envs.conf` to `~/.config/hypr/envs.conf`
2. Run `hyprctl reload` or log out and back in
3. Waybar will restart with the correct PATH
4. The pomodoro module should now appear in the bar

## Verification
To verify the fix is working:
```bash
# Check if waybar can see ~/.local/bin in its PATH
ps eww $(pgrep waybar) | tr ' ' '\n' | grep "^PATH="
```

You should see `/home/YOUR_USERNAME/.local/bin` in the PATH.
