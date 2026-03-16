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

  unprivileged = false # privileged LXC for full Docker compatibility

  disk {
    datastore_id = var.storage
    size         = var.disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  initialization {
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
