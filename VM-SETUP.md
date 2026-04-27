# QEMU / Virt-Manager Setup

The packages `qemu-full` and `virt-manager` are installed by `setup.sh`, but they require manual post-install configuration.

## 1. Install dependencies

`python-gobject` is required for virt-manager to launch:

```bash
sudo pacman -S python-gobject
```

If you use a Python version manager (e.g. mise, pyenv), virt-manager may fail with `ModuleNotFoundError: No module named 'gi'` because it picks up the non-system Python. Fix by pointing virt-manager to the system Python:

```bash
sudo sed -i '1s|.*|#!/usr/bin/python3|' /usr/bin/virt-manager
```

Note: a pacman upgrade of `virt-manager` will revert this — just re-apply it.

## 2. Enable services and user group

```bash
# Add your user to the libvirt group
sudo usermod -aG libvirt $(whoami)

# Enable and start libvirtd
sudo systemctl enable --now libvirtd

# Arch uses modular libvirt daemons — enable these sockets too
sudo systemctl enable --now virtnetworkd.socket
sudo systemctl enable --now virtqemud.socket
sudo systemctl enable --now virtstoraged.socket
```

Log out and back in for the group change to take effect.

## 3. Enable the default NAT network

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

## 4. UFW firewall fix (if UFW is enabled)

UFW's default `deny incoming` and `deny routed` policies block DHCP and routing for VMs. Allow traffic on the virtual bridge:

```bash
# Allow all input from the virtual bridge (DHCP, DNS, etc.)
sudo ufw allow in on virbr0

# Allow routing from VM to internet (replace wlan0 with your interface)
sudo ufw route allow in on virbr0 out on wlan0
```

Without this, VMs will fail to get an IP address via DHCP.

## 5. Creating a Kali Linux VM

Recommended specs (for a host with 8 threads / 32GB RAM):
- **vCPUs**: 4
- **RAM**: 8192 MB
- **Disk**: 60–80 GB

Download the **pre-built QEMU image** (`.7z` archive) from [kali.org/get-kali](https://www.kali.org/get-kali/#kali-virtual-machines) — choose the **QEMU** option. Then extract and import it:

```bash
# Extract the QCOW2 image (requires p7zip)
7z x ~/Downloads/kali-linux-*-qemu-amd64.7z -o ~/Downloads/kali-fresh

# Move it to the libvirt images pool
sudo mv ~/Downloads/kali-fresh/*.qcow2 /var/lib/libvirt/images/
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/kali-*.qcow2
rm -rf ~/Downloads/kali-fresh
```

Then create the VM in virt-manager:
1. Open `virt-manager` → **Create a new virtual machine**
2. Choose **Import existing disk image**
3. Browse to `/var/lib/libvirt/images/kali-linux-*-qemu-amd64.qcow2`
4. Set OS to **Debian 12** (closest match)
5. Allocate 4 CPUs and 8192 MB RAM
6. Network: **Virtual network 'default' : NAT**

The pre-built image boots directly with default credentials (kali / kali) and comes with guest agents pre-installed.

### Alternative: ISO install

If you prefer a fresh install, download the installer ISO from [kali.org/get-kali](https://www.kali.org/get-kali/#kali-installer-images) and copy it to the images pool first (avoids permission issues):

```bash
sudo cp ~/Downloads/kali-*-installer-amd64.iso /var/lib/libvirt/images/
```

If the installer reports "Network autoconfiguration failed", configure manually:
- IP: `192.168.122.100`, Netmask: `255.255.255.0`, Gateway: `192.168.122.1`, DNS: `8.8.8.8`

## 6. Kali post-install customization (optional)

To set up a red-team toolkit, shell config (zsh + powerlevel10k + tmux), and browser/Burp policies:

```bash
git clone https://github.com/haxowl/kaliconfig.git
cd kaliconfig
chmod +x install.sh
./install.sh
```

See [haxowl.com/blog/kaliconfig](https://www.haxowl.com/blog/kaliconfig) for details. Run on a fresh Kali install.

## Troubleshooting

- **virt-manager won't launch**: Install `python-gobject`. If using mise/pyenv, fix the shebang (see step 1)
- **Default Kali credentials**: kali / kali
- **Forgot password**: Boot into GRUB recovery mode, run `passwd kali`
- **VM has no network**: Check `virsh net-list --all` — if `default` is inactive, start it. Also check UFW (step 4)
- **No storage pool in virt-manager**: Make sure `virtstoraged.socket` is enabled (step 2)
- **Network state inconsistent**: Kill stale dnsmasq, delete virbr0, flush nftables (`sudo nft delete table ip libvirt_network`), then restart the network
