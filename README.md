# Homelab

IaC-managed homelab running on Proxmox VE. Terraform provisions infrastructure (LXC containers + Cloudflare tunnel), Ansible configures and deploys services.

## Architecture

```
Proxmox VE (laptop, 192.168.68.14 via WiFi)
│
├── vmbr0 bridge (10.10.10.0/24, NATed through WiFi)
│
├── CT100 — Docker Host (10.10.10.10)
│   ├── Caddy          reverse proxy, *.alexserver.home.arpa + pve.alexserver.home.arpa
│   ├── AdGuard Home   DNS with IaC-managed rewrites
│   ├── AdventureLog   travel logging
│   ├── Gramps Web     genealogy
│   ├── Koillection    collection management
│   ├── Portainer      container management
│   ├── Uptime Kuma    uptime monitoring
│   ├── Homepage       dashboard with Proxmox/Portainer widgets
│   ├── FileBrowser    web file manager
│   └── Samba          SMB file sharing
│
└── CT101 — Tunnel (10.10.10.20)
    └── cloudflared    Cloudflare WARP tunnel connector (systemd service)
```

### Networking

- **Proxmox host:** WiFi (`wlp2s0`) with static IP `192.168.68.14`
- **vmbr0 bridge:** Private `10.10.10.0/24` subnet, NAT/masquerade through WiFi
- **Services:** Accessed via `<service>.alexserver.home.arpa` through Caddy
- **Remote access:** Cloudflare WARP with split tunnel routing `10.10.10.0/24` through the tunnel. Local domain fallback resolves `*.alexserver.home.arpa` via AdGuard DNS on the Docker host. Only devices enrolled in the Zero Trust profile (by email) can connect.

### Access Flow (WARP)

```
Device (WARP) → Cloudflare → Tunnel (CT101) → 10.10.10.0/24
  DNS:    *.alexserver.home.arpa → AdGuard (10.10.10.10:53) → 10.10.10.10
  HTTP:   browser → 10.10.10.10:443 → Caddy → container
```

## Prerequisites

- Proxmox VE installed on the host
- Debian 12 LXC template downloaded in Proxmox
- Terraform and Ansible installed (currently run from the Proxmox host)
- Cloudflare account with Zero Trust enabled
- Cloudflare API token with Zero Trust + Tunnel permissions

## Setup

### 1. Proxmox Host

After installing Proxmox:

- Disable enterprise repos, enable `pve-no-subscription` repo
- Install `wpasupplicant` for WiFi
- Configure `/etc/network/interfaces`:
  - `wlp2s0`: static IP on LAN (e.g. `192.168.68.14`)
  - `vmbr0`: `10.10.10.1/24`, `bridge-ports none`, NAT masquerade through WiFi
- Disable lid suspend: `HandleLidSwitch=ignore` in `/etc/systemd/logind.conf`

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
- **Docker Host LXC** (CT100) — unprivileged, nesting + keyctl, 4 cores / 4GB RAM / 45GB disk
- **Tunnel LXC** (CT101) — unprivileged, 1 core / 256MB RAM / 2GB disk
- **Cloudflare tunnel** with private network route (`10.10.10.0/24`)
- **Cloudflare WARP device profile** with split tunnel include and local domain fallback

Note: Proxmox uses username/password auth (not API tokens) because API tokens cannot set feature flags on containers.

### 3. Ansible — Configure and Deploy

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

#### Docker Host roles (in order):
1. **common** — base packages, timezone (Pacific/Auckland), auto-upgrades
2. **docker** — Docker CE + compose plugin
3. **directories** — `/srv/data`, `/srv/secrets`, `/srv/backup`
4. **docker_network** — shared `proxy` Docker network
5. **caddy** — reverse proxy config (Caddyfile templated from `caddy_sites` in all.yml)
6. **stacks** — syncs compose files, templates .env and config files, deploys all services
7. **borgbackup** — daily backups of `/srv/data`

#### Tunnel Host roles:
1. **common** — base packages
2. **cloudflared** — installs cloudflared, configures systemd service with tunnel token

### 4. Restore Data (if migrating)

```bash
# Copy backup archive to the LXC
scp backup.tar.gz root@10.10.10.10:/tmp/
ssh root@10.10.10.10 tar xf /tmp/backup.tar.gz -C /
ssh root@10.10.10.10 rm /tmp/backup.tar.gz

# Re-deploy stacks to pick up restored data
ansible-playbook site.yml
```

### 5. Post-Deploy

- **AdGuard:** DNS rewrites are IaC-managed via Ansible template. Filter lists and other UI settings are manual.
- **Uptime Kuma:** Create monitors and status pages via the UI. Config persists in `/srv/data/uptime-kuma/`.
- **Portainer:** Generate an API key (My Account → Access tokens) and add it to the vault as `vault_portainer_api_key`.
- **Homepage:** Proxmox API token must be created manually in the Proxmox UI (Datacenter → Permissions → API Tokens) and added to the vault.
- **Caddy root CA:** Install `/data/caddy/pki/authorities/local/root.crt` from the Caddy container on your devices to trust internal HTTPS certs.

## Secrets

| Location | Purpose | Encrypted |
|---|---|---|
| `ansible/.vault_pass` | Decrypts vault.yml | No (gitignored) |
| `ansible/.../vault.yml` | Service passwords, tokens, keys | Yes (ansible-vault) |
| `terraform/terraform.tfvars` | Proxmox + Cloudflare credentials | No (gitignored) |

See `vault.yml.example` and `terraform.tfvars.example` for all required variables.

## Backups

- **BorgBackup** — daily at 14:00 UTC, backs up `/srv/data/` with 7 daily / 4 weekly / 6 monthly retention. Stored at `/srv/backup/borg` inside the Docker Host LXC.
- **Proxmox vzdump** — (planned) weekly full container snapshots

Note: Backups are currently on the same disk. Off-site/off-disk backup target is planned.

## Current Hardware

2018 MacBook Pro (i5 quad-core, 8GB RAM, 128GB SSD)

| Resource | Proxmox Host | Docker Host LXC | Tunnel LXC |
|---|---|---|---|
| CPU | shared | 4 cores | 1 core |
| RAM | ~4GB | 4GB | 256MB |
| Disk | 38GB (root) | 45GB (thin) | 2GB (thin) |

## Future Plans

- Move Caddy and AdGuard DNS to their own LXCs (not reliant on Docker host)
- Migrate to better hardware with ethernet (remove WiFi NAT, use direct bridge)
- Dedicated bootstrap machine (currently Proxmox host runs Terraform/Ansible)
- Off-disk backup target (NAS, external drive, or cloud)
- Cloudflare tunnel and WARP config fully as IaC (device profiles, split tunnels)
- Ollama + Open-WebUI when hardware allows
