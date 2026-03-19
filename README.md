# Homelab

IaC-managed homelab running on Proxmox VE. Terraform provisions infrastructure, Ansible configures and deploys Docker services.

## Architecture

```
Proxmox VE (laptop, 192.168.68.14 via WiFi)
├── LXC Container - Docker Host (10.10.10.10 on vmbr0, NATed through WiFi)
│   ├── Caddy (reverse proxy, *.alexserver.home.arpa)
│   ├── Cloudflared (Cloudflare tunnel for external access)
│   ├── AdGuard Home (DNS ad-blocking)
│   ├── AdventureLog (travel logging)
│   ├── Gramps Web (genealogy)
│   ├── Koillection (collection management)
│   ├── Portainer (container management)
│   ├── Dozzle (Docker log viewer)
│   ├── Uptime Kuma (uptime monitoring)
│   ├── Homepage (dashboard)
│   ├── FileBrowser (web file manager)
│   └── Samba (SMB file sharing)
└── (Planned) LXC Container - Cloudflare Tunnel
```

### Networking

- Proxmox host is on WiFi (`wlp2s0`) with static IP `192.168.68.14`
- `vmbr0` bridge on a private `10.10.10.0/24` subnet (NAT/masquerade through WiFi)
- LXC containers get `10.10.10.x` IPs and route through Proxmox
- Services accessed via `<service>.alexserver.home.arpa` through Caddy
- External access via Cloudflare tunnel

## Prerequisites

- Proxmox VE installed on the host
- Terraform installed on the bootstrap machine
- Ansible installed on the bootstrap machine
- Debian 12 LXC template downloaded in Proxmox (`local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst`)
- Proxmox API credentials (username/password auth — API tokens can't set feature flags on unprivileged containers)

## Setup

### 1. Terraform — Provision LXC

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

This creates an unprivileged Debian 12 LXC container with Docker support (nesting + keyctl enabled).

### 2. Ansible — Configure and Deploy

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

# Run the playbook
ansible-playbook site.yml
```

Ansible runs these roles in order:
1. **common** — base packages, timezone, auto-upgrades
2. **docker** — Docker CE installation
3. **directories** — `/srv/data`, `/srv/secrets`, `/srv/backup`
4. **docker_network** — shared `proxy` Docker network
5. **caddy** — reverse proxy config (Caddyfile from template)
6. **stacks** — syncs compose files, templates .env files, deploys all services
7. **borgbackup** — daily backups of `/srv/data` with retention policy

### 3. Restore Data (if migrating)

```bash
scp -r /path/to/backup/srv/data/* root@10.10.10.10:/srv/data/
# Re-deploy stacks to pick up restored data
ansible-playbook playbooks/deploy_stacks.yml
```

## Secrets

Secrets are managed via Ansible Vault (`vault.yml`, encrypted, safe to commit). The vault password file (`.vault_pass`) is gitignored. See `vault.yml.example` for required variables.

Terraform variables (`terraform.tfvars`) are also gitignored — see `terraform.tfvars.example`.

## Backups

- **BorgBackup** — daily at 14:00 UTC, backs up `/srv/data/` with 7 daily / 4 weekly / 6 monthly retention
- **Proxmox vzdump** — (planned) weekly full container snapshots

## Current Hardware

2018 MacBook Pro (i5, 8GB RAM, 128GB SSD). LXC configured for 4 cores, 4GB RAM, 45GB disk.

## Future Plans

- Separate LXC for Cloudflare tunnel (resilient remote access independent of Docker host)
- Move Caddy to its own LXC (not reliant on Docker host)
- Migrate to better hardware with ethernet (remove WiFi NAT workaround, use direct bridge)
- Dedicated bootstrap/management machine (currently Proxmox host doubles as bootstrap)
- Off-disk backup target (NAS, external drive, or cloud)
- Proxmox accessible via Cloudflare tunnel for remote management
