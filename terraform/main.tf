resource "proxmox_virtual_environment_container" "docker_host" {
  node_name   = var.proxmox_node
  description = "Docker host for homelab services"
  tags        = ["homelab", "docker"]

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  cpu {
    cores = var.lxc_cores
  }

  memory {
    dedicated = var.lxc_memory_mb
    swap      = var.lxc_swap_mb
  }

  features {
    nesting = true # required for Docker inside LXC
    keyctl  = true # required for Docker inside LXC
  }

  unprivileged = true # unprivileged is more secure; nesting+keyctl is enough for Docker

  disk {
    datastore_id = var.storage
    size         = var.disk_gb
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
    order = 1
  }

  start_on_boot = true
}

# --- Cloudflare Tunnel LXC ---

resource "proxmox_virtual_environment_container" "tunnel" {
  node_name   = var.proxmox_node
  description = "Cloudflare tunnel connector"
  tags        = ["homelab", "tunnel"]

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 512
    swap      = 256
  }

  unprivileged = true

  disk {
    datastore_id = var.storage
    size         = 2
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
    order = 0 # start before docker host
  }

  start_on_boot = true
}
