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

variable "lxc_template" {
  description = "LXC template file ID (e.g. local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst)"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
}

variable "lxc_cores" {
  description = "Number of CPU cores for the LXC container"
  type        = number
  default     = 4
}

variable "lxc_memory_mb" {
  description = "Memory in MB for the LXC container"
  type        = number
  default     = 5120
}

variable "lxc_swap_mb" {
  description = "Swap in MB for the LXC container"
  type        = number
  default     = 1024
}

variable "disk_gb" {
  description = "Root disk size in GB"
  type        = number
  default     = 200
}

variable "storage" {
  description = "Proxmox storage pool for the LXC disk"
  type        = string
  default     = "local-lvm"
}

variable "lxc_ip" {
  description = "Static IP for the LXC container in CIDR notation (e.g. 192.168.68.10/24)"
  type        = string
}

variable "gateway" {
  description = "Default gateway (e.g. 192.168.68.1)"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers for the LXC container"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "ssh_public_key" {
  description = "SSH public key for root access to the LXC"
  type        = string
}
