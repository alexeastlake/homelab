# Homelab

IaC-managed homelab running on Proxmox VE. Terraform provisions infrastructure (LXC containers + Cloudflare tunnel), Ansible configures and deploys services.

## Architecture

```
Proxmox VE (laptop, 192.168.68.14 via WiFi)
│
├── vmbr0 bridge (10.10.10.0/24, NATed through WiFi)
│
├── CT100 — Storage (10.10.10.10)              privileged, 30GB disk
│   ├── NFS server (/srv/data + /srv/backup exported to 10.10.10.0/24)
│   └── BorgBackup (daily backups of /srv/data)
│
├── CT101 — DNS (10.10.10.20)                  unprivileged, 2GB disk
│   └── AdGuard Home (standalone binary, systemd)
│
├── CT102 — Reverse Proxy (10.10.10.30)        unprivileged, 2GB disk
│   └── Caddy (apt package, shared root CA from vault)
│
├── CT103 — Tunnel (10.10.10.40)               unprivileged, 2GB disk
│   └── cloudflared (QUIC tunnel to Cloudflare edge)
│
└── CT104 — Docker Host (10.10.10.50)          unprivileged, 24GB disk
    ├── NFS bind mount from PVE (/mnt/nfs-data → /srv/data)
    ├── AdventureLog    travel logging
    ├── Gramps Web      genealogy
    ├── Koillection     collection management
    ├── Portainer       container management
    ├── Uptime Kuma     uptime monitoring
    ├── Homepage        dashboard (Caddy basic auth)
    └── FileBrowser     web file manager
```

### Networking

- **Proxmox host:** WiFi (`wlp2s0`) with static IP `192.168.68.14`
- **vmbr0 bridge:** Private `10.10.10.0/24` subnet, NAT/masquerade through WiFi
- **Services:** Accessed via `<service>.alexserver.home.arpa` through Caddy
- **Remote access:** Cloudflare WARP with split tunnel routing `10.10.10.0/24` through the tunnel. Local domain fallback resolves `*.alexserver.home.arpa` via AdGuard DNS (10.10.10.20). Only devices enrolled in the Zero Trust profile (by email) can connect.

### Access Flow (WARP)

```
Device (WARP) → Cloudflare → Tunnel (CT103) → 10.10.10.0/24
  DNS:    *.alexserver.home.arpa → AdGuard (10.10.10.20:53) → 10.10.10.30
  HTTPS:  browser → Caddy (10.10.10.30:443) → Docker Host (10.10.10.50:<port>)
```

## Prerequisites

- Proxmox VE installed on the host
- Terraform and Ansible installed (currently run from the Proxmox host)
- Cloudflare account with Zero Trust enabled
- Cloudflare API token with Zero Trust + Tunnel permissions

## Setup

### 1. Proxmox Host

After installing Proxmox, run the bootstrap script (idempotent, safe to re-run):

```bash
bash scripts/pve-bootstrap.sh
```

This configures repos, installs packages, sets sysctl values, prepares NFS mount points, and downloads the LXC template. Then manually configure `/etc/network/interfaces` for your hardware (the script prints an example) and reboot.

### 2. Terraform — Provision Infrastructure

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

Creates:
- **Storage LXC** (CT100) — privileged (NFS server), 1 core / 512MB RAM / 30GB disk
- **DNS LXC** (CT101) — unprivileged, 1 core / 256MB RAM / 2GB disk
- **Caddy LXC** (CT102) — unprivileged, 1 core / 256MB RAM / 2GB disk
- **Tunnel LXC** (CT103) — unprivileged, 2 cores / 512MB RAM / 2GB disk
- **Docker Host LXC** (CT104) — unprivileged, nesting + keyctl, NFS bind mount, 4 cores / 4GB RAM / 24GB disk
- **Cloudflare tunnel** with private network route (`10.10.10.0/24`)
- **Cloudflare WARP device profile** with split tunnel include and local domain fallback

All LXC specs (cores, memory, swap, disk) are configurable via the `lxc_specs` variable in `terraform.tfvars`.

Note: Proxmox uses username/password auth (not API tokens) because API tokens cannot create bind mounts on containers.

### 3. Mount NFS on PVE Host

After Terraform creates the storage LXC and Ansible configures NFS exports:

```bash
mount -a
```

This mounts `/mnt/nfs-data` (read-write, used as bind mount for Docker host) and `/mnt/nfs-backups` (read-only, for grabbing backup archives).

### 4. Ansible — Configure and Deploy

```bash
cd ansible/

# Install required collections
ansible-galaxy collection install -r requirements.yml

# Create vault password file
echo "your-vault-password" > .vault_pass
chmod 600 .vault_pass

# Create and populate the encrypted vault
ansible-vault create inventories/production/group_vars/all/vault.yml
# See vault.yml.example for required variables
# Note: tunnel token is from `terraform output -raw tunnel_token`

# Run the playbook
ansible-playbook site.yml
```

#### Playbook execution order (`site.yml`):

1. **Storage** (CT100): `common` → `nfs_server` → `borgbackup`
2. **DNS** (CT101): `common` → `adguard`
3. **Caddy** (CT102): `common` → `caddy`
4. **Tunnel** (CT103): `common` → `cloudflared`
5. **Docker Host** (CT104): `common` → `docker` → `stacks` → `docker_data_backup`

#### Key role details:

- **common** — base packages, timezone (Pacific/Auckland), auto-upgrades
- **nfs_server** — NFS exports (`/srv/data` rw, `/srv/backup` ro), creates stack data dirs with 0777 permissions
- **borgbackup** — daily backups of `/srv/data`, stops all Docker containers for consistent snapshots, exports latest archive as tar
- **adguard** — standalone binary, systemd service, templated config with DNS rewrites
- **caddy** — apt install, shared root CA from vault, Caddyfile templated from `caddy_sites` (supports per-site basic auth)
- **cloudflared** — apt install, templated systemd service with tunnel token from vault
- **docker** — Docker CE + compose plugin from Docker's apt repo
- **stacks** — creates base dirs, syncs compose files, templates .env and config files, deploys all services
- **docker_data_backup** — daily `pg_dump` of PostgreSQL databases + `rsync` of file-based data to NFS (workaround for chown failures on NFS)

### 5. Restore Data (if migrating)

```bash
# Latest backup is always available at /mnt/nfs-backups/latest/latest.tar.gz
# Or copy a backup archive to the storage LXC:
scp backup.tar.gz root@10.10.10.10:/tmp/
ssh root@10.10.10.10 tar xf /tmp/backup.tar.gz -C /
ssh root@10.10.10.10 rm /tmp/backup.tar.gz

# Re-deploy stacks to pick up restored data
ansible-playbook site.yml
```

### 6. Post-Deploy

- **AdGuard:** DNS rewrites are IaC-managed via Ansible template. Filter lists and other UI settings are manual.
- **Uptime Kuma:** Create monitors and status pages via the UI. Config persists in `/srv/data/uptime-kuma/`.
- **Portainer:** Generate an API key (My Account → Access tokens) and add it to the vault as `vault_portainer_api_key`. Used by the Homepage dashboard widget to display container stats.
- **Homepage:** Proxmox API token must be created manually in the Proxmox UI (Datacenter → Permissions → API Tokens) and added to the vault. Protected by Caddy basic auth (credentials in vault).
- **Caddy root CA:** The root CA cert/key are stored in Ansible vault and deployed by the caddy role. Install the root cert on your devices to trust internal HTTPS certs. The vault values must use YAML block scalar (`|`) to preserve PEM newlines.

## Secrets

| Location | Purpose | Encrypted |
|---|---|---|
| `ansible/.vault_pass` | Decrypts vault.yml | No (gitignored) |
| `ansible/.../vault.yml` | Service passwords, tokens, keys, CA cert/key | Yes (ansible-vault) |
| `terraform/terraform.tfvars` | Proxmox + Cloudflare credentials | No (gitignored) |

See `vault.yml.example` and `terraform.tfvars.example` for all required variables.

## Backups

Some services (PostgreSQL, FileBrowser) store data on the Docker host's local disk (`/var/lib/docker-data/`) because they need `chown`, which fails on NFS bind mounts in unprivileged LXCs. This data is synced to NFS daily so BorgBackup can pick it up. This workaround goes away when migrating to full VMs.

1. **`docker_data_backup`** (Docker Host, daily 01:00 NZDT) — `pg_dump` for PostgreSQL databases + `rsync` for file-based data → `/srv/data/docker-data/`
2. **BorgBackup** (Storage LXC, daily 02:00 NZDT) — stops all Docker containers, archives `/srv/data/` (including synced data from step 1), restarts containers. Retention: 5 daily / 3 weekly / 3 monthly → `/srv/backup/borg`

Latest backup is always available at `/srv/backup/latest/latest.tar.gz` (or `/mnt/nfs-backups/latest/latest.tar.gz` from the PVE host).

Note: Backups are currently on the same disk. Off-site/off-disk backup target is planned.

## Known Workarounds

| Issue | Workaround | Permanent fix |
|---|---|---|
| QUIC UDP buffers can't be set in unprivileged LXCs | Set `net.core.rmem_max` / `wmem_max` on PVE host (via `pve-bootstrap.sh`) | Migrate to full VMs |
| Unprivileged LXCs can't mount NFS | PVE mounts NFS, bind-mounted into container via Terraform | Migrate to full VMs |
| NFS bind mount permissions (UID mapping) | Stack data dirs created with 0777 | Proper UID mapping with full VMs |
| File mode changes fail on NFS bind mounts | Omit `mode:` from Ansible tasks writing to `/srv/data` | Migrate to full VMs |
| NFS share has no authentication | Network-level isolation (only `10.10.10.0/24` can access) | Add Kerberos auth to NFS + tighten permissions when on full VMs |
| Apps lock SQLite/BoltDB files on NFS | Borg stops all containers before backup, restarts after | Migrate to full VMs (Borg runs locally) |
| PostgreSQL/FileBrowser need chown (fails on NFS) | Data on local disk, synced to NFS daily via `docker_data_backup` | Migrate to full VMs (data lives on NFS directly) |

## Current Hardware

2018 MacBook Pro (i5 quad-core, 8GB RAM, 128GB SSD)

| Container | CPU | RAM | Disk |
|---|---|---|---|
| CT100 Storage | 1 core | 512MB | 30GB |
| CT101 DNS | 1 core | 256MB | 2GB |
| CT102 Caddy | 1 core | 256MB | 2GB |
| CT103 Tunnel | 2 cores | 512MB | 2GB |
| CT104 Docker | 4 cores | 4GB | 24GB |

## Development

Secret scanning is enforced via a [gitleaks](https://github.com/gitleaks/gitleaks) pre-commit hook. Install it once after cloning:

```bash
pip install pre-commit          # or: brew install pre-commit
python -m pre_commit install    # or: pre-commit install (if on PATH)
```

Every `git commit` will now be scanned for accidentally staged secrets.

## Future Plans

- Migrate to better hardware with ethernet (remove WiFi NAT, use direct bridge)
- Migrate from LXCs to full VMs (eliminates all NFS/UID/chown workarounds)
- Dedicated bootstrap machine (currently Proxmox host runs Terraform/Ansible)
- Back up Terraform state (`terraform.tfstate`) and Ansible vault (`vault.yml`, `.vault_pass`) — currently only on PVE host local disk
- Off-disk backup target (NAS, external drive, or cloud)
- NFS authentication (Kerberos) and tightened file permissions (replace 0777)
- Local package mirror / caching proxy for faster Ansible runs
- Ollama + Open-WebUI when hardware allows
