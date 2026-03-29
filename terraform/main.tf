# --- CT100: Storage (NFS server, BorgBackup) ---

resource "proxmox_virtual_environment_container" "storage" {
  node_name   = var.proxmox_node
  vm_id       = 100
  description = "NFS storage server and backup"
  tags        = ["homelab", "storage"]

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  cpu {
    cores = var.lxc_specs["storage"].cores
  }

  memory {
    dedicated = var.lxc_specs["storage"].memory_mb
    swap      = var.lxc_specs["storage"].swap_mb
  }

  # Privileged required for NFS kernel server in LXC
  unprivileged = false

  features {
    nesting = true
  }

  disk {
    datastore_id = var.storage
    size         = var.lxc_specs["storage"].disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = "storage"

    ip_config {
      ipv4 {
        address = var.storage_lxc_ip
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  startup {
    order = 0 # storage starts first
  }

  start_on_boot = true
}

# --- CT101: DNS (AdGuard Home) ---

resource "proxmox_virtual_environment_container" "dns" {
  node_name   = var.proxmox_node
  vm_id       = 101
  description = "AdGuard Home DNS server"
  tags        = ["homelab", "dns"]

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  cpu {
    cores = var.lxc_specs["dns"].cores
  }

  memory {
    dedicated = var.lxc_specs["dns"].memory_mb
    swap      = var.lxc_specs["dns"].swap_mb
  }

  unprivileged = true

  disk {
    datastore_id = var.storage
    size         = var.lxc_specs["dns"].disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = "dns"

    ip_config {
      ipv4 {
        address = var.dns_lxc_ip
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  startup {
    order = 1 # after storage
  }

  start_on_boot = true
}

# --- CT102: Reverse Proxy (Caddy) ---

resource "proxmox_virtual_environment_container" "caddy" {
  node_name   = var.proxmox_node
  vm_id       = 102
  description = "Caddy reverse proxy"
  tags        = ["homelab", "caddy"]

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  cpu {
    cores = var.lxc_specs["caddy"].cores
  }

  memory {
    dedicated = var.lxc_specs["caddy"].memory_mb
    swap      = var.lxc_specs["caddy"].swap_mb
  }

  unprivileged = true

  disk {
    datastore_id = var.storage
    size         = var.lxc_specs["caddy"].disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = "caddy"

    ip_config {
      ipv4 {
        address = var.caddy_lxc_ip
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  startup {
    order = 1 # after storage
  }

  start_on_boot = true
}

# --- CT103: Cloudflare Tunnel ---

resource "proxmox_virtual_environment_container" "tunnel" {
  node_name   = var.proxmox_node
  vm_id       = 103
  description = "Cloudflare tunnel connector"
  tags        = ["homelab", "tunnel"]

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  cpu {
    cores = var.lxc_specs["tunnel"].cores
  }

  memory {
    dedicated = var.lxc_specs["tunnel"].memory_mb
    swap      = var.lxc_specs["tunnel"].swap_mb
  }

  unprivileged = true

  disk {
    datastore_id = var.storage
    size         = var.lxc_specs["tunnel"].disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = "tunnel"

    ip_config {
      ipv4 {
        address = var.tunnel_lxc_ip
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  startup {
    order = 2 # after infra
  }

  start_on_boot = true
}

# --- CT104: Docker Host (stateless) ---

resource "proxmox_virtual_environment_container" "docker_host" {
  node_name   = var.proxmox_node
  vm_id       = 104
  description = "Stateless Docker host for homelab services"
  tags        = ["homelab", "docker"]

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  cpu {
    cores = var.lxc_specs["docker"].cores
  }

  memory {
    dedicated = var.lxc_specs["docker"].memory_mb
    swap      = var.lxc_specs["docker"].swap_mb
  }

  features {
    nesting = true # required for Docker inside LXC
    keyctl  = true # required for Docker inside LXC
  }

  # Bind mount NFS share from PVE host into container
  # Requires: PVE fstab entry mounting NFS to /mnt/nfs-data
  mount_point {
    volume = "/mnt/nfs-data"
    path   = "/srv/data"
  }

  unprivileged = true

  disk {
    datastore_id = var.storage
    size         = var.lxc_specs["docker"].disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
    hostname = "docker-host"

    ip_config {
      ipv4 {
        address = var.lxc_ip
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  startup {
    order = 3 # after infra
  }

  start_on_boot = true
}
