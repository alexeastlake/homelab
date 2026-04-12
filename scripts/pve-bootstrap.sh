#!/bin/bash
set -euo pipefail

# Proxmox VE host bootstrap script — idempotent, safe to re-run.
# Run after fresh Proxmox install: bash pve-bootstrap.sh
# Network config is hardware-specific — see manual steps at the end.

echo "=== PVE Bootstrap ==="

# --- Repos: disable enterprise, enable no-subscription ---
echo "Configuring apt repos..."
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
    sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
fi
if [ -f /etc/apt/sources.list.d/ceph.list ]; then
    sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/ceph.list
fi
NOSUB="/etc/apt/sources.list.d/pve-no-subscription.list"
NOSUB_LINE="deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription"
grep -qxF "$NOSUB_LINE" "$NOSUB" 2>/dev/null || echo "$NOSUB_LINE" > "$NOSUB"
apt-get update -qq

# --- Base packages ---
echo "Installing base packages..."
apt-get install -y -qq wpasupplicant nfs-common > /dev/null

# --- Disable lid suspend (for laptop servers) ---
echo "Configuring lid suspend..."
if grep -q '#HandleLidSwitch=' /etc/systemd/logind.conf; then
    sed -i 's/#HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
    systemctl restart systemd-logind
fi

# --- QUIC UDP buffer sizes (required for cloudflared in unprivileged LXCs) ---
echo "Configuring QUIC UDP buffer sizes..."
grep -qxF 'net.core.rmem_max=7500000' /etc/sysctl.conf || echo 'net.core.rmem_max=7500000' >> /etc/sysctl.conf
grep -qxF 'net.core.wmem_max=7500000' /etc/sysctl.conf || echo 'net.core.wmem_max=7500000' >> /etc/sysctl.conf
sysctl -p -q

# --- NFS mount points ---
echo "Configuring NFS mounts..."
mkdir -p /mnt/nfs-data /mnt/nfs-backups
grep -q '/mnt/nfs-data' /etc/fstab || echo '10.10.10.10:/srv/data /mnt/nfs-data nfs rw,sync,hard,intr 0 0' >> /etc/fstab
grep -q '/mnt/nfs-backups' /etc/fstab || echo '10.10.10.10:/srv/backup /mnt/nfs-backups nfs ro,sync,hard,intr 0 0' >> /etc/fstab

# --- External backup storage ---
# Mount point only — the fstab entry is hardware-specific (see manual steps below).
echo "Configuring external backup storage mount point..."
mkdir -p /mnt/usb

# --- LXC template ---
echo "Ensuring Debian 12 LXC template is available..."
pveam update -qq 2>/dev/null || true
if ! pveam list local 2>/dev/null | grep -q 'debian-12-standard'; then
    TEMPLATE=$(pveam available --section system 2>/dev/null | grep 'debian-12-standard' | awk '{print $2}' | tail -1)
    if [ -n "$TEMPLATE" ]; then
        pveam download local "$TEMPLATE"
    else
        echo "  Warning: could not find Debian 12 template to download"
    fi
fi

echo ""
echo "=== Bootstrap complete ==="
cat <<'MSG'

Manual steps remaining:

1. Configure /etc/network/interfaces for your hardware:
   - WiFi interface: static IP on your LAN
   - vmbr0: 10.10.10.1/24, bridge-ports none, NAT masquerade

   Example (adjust interface names and IPs for your setup):

   auto wlp2s0
   iface wlp2s0 inet static
       address 192.168.68.14/24
       gateway 192.168.68.1
       wpa-ssid "YOUR_SSID"
       wpa-psk "YOUR_PSK"

   auto vmbr0
   iface vmbr0 inet static
       address 10.10.10.1/24
       bridge-ports none
       bridge-stp off
       bridge-fd 0
       post-up iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o wlp2s0 -j MASQUERADE
       post-up echo 1 > /proc/sys/net/ipv4/ip_forward
       post-down iptables -t nat -D POSTROUTING -s 10.10.10.0/24 -o wlp2s0 -j MASQUERADE

2. Add external backup storage to /etc/fstab (find UUID with blkid):
   echo 'UUID=<YOUR-USB-UUID> /mnt/usb exfat defaults,nofail,uid=0,gid=0,umask=000 0 0' >> /etc/fstab
   Update backup_sync_mount/backup_sync_dir in ansible group_vars if changing the mount path.

3. Reboot, then continue with:
   cd terraform && terraform apply
   cd ansible && ansible-playbook site.yml

4. Mount NFS (after storage LXC is created):
   mount -a
MSG
