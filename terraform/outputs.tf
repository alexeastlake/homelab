output "storage_id" {
  description = "Proxmox container ID for the storage LXC"
  value       = proxmox_virtual_environment_container.storage.id
}

output "storage_ip" {
  description = "IP address of the storage LXC"
  value       = var.storage_lxc_ip
}

output "dns_id" {
  description = "Proxmox container ID for the DNS LXC"
  value       = proxmox_virtual_environment_container.dns.id
}

output "dns_ip" {
  description = "IP address of the DNS LXC"
  value       = var.dns_lxc_ip
}

output "caddy_id" {
  description = "Proxmox container ID for the Caddy LXC"
  value       = proxmox_virtual_environment_container.caddy.id
}

output "caddy_ip" {
  description = "IP address of the Caddy LXC"
  value       = var.caddy_lxc_ip
}

output "tunnel_id" {
  description = "Proxmox container ID for the tunnel LXC"
  value       = proxmox_virtual_environment_container.tunnel.id
}

output "tunnel_ip" {
  description = "IP address of the tunnel LXC"
  value       = var.tunnel_lxc_ip
}

output "docker_host_id" {
  description = "Proxmox container ID for the Docker host LXC"
  value       = proxmox_virtual_environment_container.docker_host.id
}

output "docker_host_ip" {
  description = "IP address of the Docker host LXC"
  value       = var.lxc_ip
}

output "tunnel_token" {
  description = "Cloudflare tunnel token (add to Ansible vault as vault_cloudflared_tunnel_token)"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token
  sensitive   = true
}
