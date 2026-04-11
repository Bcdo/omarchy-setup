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

## QEMU / Virt-Manager Setup

The packages `qemu-full`, `virt-manager`, `dnsmasq`, and `virt-viewer` are installed by `setup.sh`, but they require manual post-install configuration.

### 1. Enable services and user group

```bash
# Add your user to the libvirt group
sudo usermod -aG libvirt $(whoami)

# Enable and start libvirtd
sudo systemctl enable --now libvirtd

# Arch uses modular libvirt daemons — enable these sockets too
sudo systemctl enable --now virtnetworkd.socket
sudo systemctl enable --now virtqemud.socket
```

Log out and back in for the group change to take effect.

### 2. Enable the default NAT network

```bash
sudo virsh net-autostart default
sudo virsh net-start default
```

Verify with `virsh net-list --all` — it should show `default` as **active**.

If it fails with "network is already in use by interface virbr0", clean up the stale bridge first:

```bash
sudo ip link set virbr0 down
sudo ip link delete virbr0
sudo virsh net-start default
```

### 3. UFW firewall fix (if UFW is enabled)

UFW's default `deny incoming` and `deny routed` policies block DHCP and routing for VMs. Allow traffic on the virtual bridge:

```bash
# Allow all input from the virtual bridge (DHCP, DNS, etc.)
sudo ufw allow in on virbr0

# Allow routing from VM to internet (replace wlan0 with your interface)
sudo ufw route allow in on virbr0 out on wlan0
```

Without this, VMs will fail to get an IP address via DHCP.

### 4. Creating a Kali Linux VM

Recommended specs (for a host with 8 threads / 32GB RAM):
- **vCPUs**: 4
- **RAM**: 8192 MB
- **Disk**: 60–80 GB

The **pre-built QEMU image** is the easiest approach — download the QEMU option from [kali.org/get-kali](https://www.kali.org/get-kali/#kali-virtual-machines). Alternatively, use the installer ISO via virt-manager.

If using the ISO, copy it to `/var/lib/libvirt/images/` first to avoid permission issues:

```bash
sudo cp ~/Downloads/kali-*.iso /var/lib/libvirt/images/
```

If the installer reports "Network autoconfiguration failed", configure manually:
- IP: `192.168.122.100`, Netmask: `255.255.255.0`, Gateway: `192.168.122.1`, DNS: `8.8.8.8`

### 5. Kali post-install customization (optional)

To set up a red-team toolkit, shell config (zsh + powerlevel10k + tmux), and browser/Burp policies:

```bash
git clone https://github.com/haxowl/kaliconfig.git
cd kaliconfig
chmod +x install.sh
./install.sh
```

See [haxowl.com/blog/kaliconfig](https://www.haxowl.com/blog/kaliconfig) for details. Run on a fresh Kali install.

### 6. Troubleshooting

- **Default Kali credentials**: kali / kali
- **Forgot password**: Boot into GRUB recovery mode, run `passwd kali`
- **VM has no network**: Check `virsh net-list --all` — if `default` is inactive, start it. Also check UFW (step 3)
- **Network state inconsistent**: Kill stale dnsmasq, delete virbr0, flush nftables (`sudo nft delete table ip libvirt_network`), then restart the network

## Notes

- Backups are created as `filename.bak.YYYY-MM-DD_HH-MM-SS` before overwriting
- After setup, edit `~/.config/hypr/monitors.conf` for your displays
- The `waybar-module-pomodoro` binary is custom as it was the only way to change the message. Edit `configs/mako/config` to change styling only
