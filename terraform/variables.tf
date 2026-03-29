# --- Proxmox ---

variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g. https://192.168.68.XX:8006)"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox username (e.g. root@pam)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox root password"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

# --- Common LXC ---

variable "lxc_template" {
  description = "LXC template file ID"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
}

variable "storage" {
  description = "Proxmox storage pool for LXC disks"
  type        = string
  default     = "local-lvm"
}

variable "gateway" {
  description = "Default gateway for vmbr0 subnet"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers for LXC containers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "ssh_public_key" {
  description = "SSH public key for root access to LXCs"
  type        = string
}

# --- Storage LXC (CT100) ---

variable "storage_lxc_ip" {
  description = "Static IP for the storage LXC in CIDR notation"
  type        = string
  default     = "10.10.10.10/24"
}

# --- DNS LXC (CT101) ---

variable "dns_lxc_ip" {
  description = "Static IP for the DNS LXC in CIDR notation"
  type        = string
  default     = "10.10.10.20/24"
}

# --- Caddy LXC (CT102) ---

variable "caddy_lxc_ip" {
  description = "Static IP for the Caddy LXC in CIDR notation"
  type        = string
  default     = "10.10.10.30/24"
}

# --- Tunnel LXC (CT103) ---

variable "tunnel_lxc_ip" {
  description = "Static IP for the tunnel LXC in CIDR notation"
  type        = string
  default     = "10.10.10.40/24"
}

# --- Docker Host LXC (CT104) ---

variable "lxc_ip" {
  description = "Static IP for the Docker host LXC in CIDR notation"
  type        = string
  default     = "10.10.10.50/24"
}

# --- LXC resource specs ---

variable "lxc_specs" {
  description = "Per-container resource specs (cores, memory_mb, swap_mb, disk_gb)"
  type = map(object({
    cores     = number
    memory_mb = number
    swap_mb   = number
    disk_gb   = number
  }))
  default = {
    storage = { cores = 1, memory_mb = 512, swap_mb = 256, disk_gb = 30 }
    dns     = { cores = 1, memory_mb = 256, swap_mb = 256, disk_gb = 2 }
    caddy   = { cores = 1, memory_mb = 256, swap_mb = 256, disk_gb = 2 }
    tunnel  = { cores = 2, memory_mb = 512, swap_mb = 256, disk_gb = 2 }
    docker  = { cores = 4, memory_mb = 4096, swap_mb = 1024, disk_gb = 24 }
  }
}

# --- Cloudflare ---

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zero Trust + Tunnel permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "cloudflare_user_email" {
  description = "Email for WARP device profile match rule"
  type        = string
}

variable "tunnel_name" {
  description = "Name of the Cloudflare tunnel"
  type        = string
  default     = "homelab"
}
