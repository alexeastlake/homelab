output "docker_host_id" {
  description = "Proxmox container ID"
  value       = proxmox_virtual_environment_container.docker_host.id
}

output "docker_host_ip" {
  description = "IP address of the Docker host LXC (use this in Ansible inventory)"
  value       = var.lxc_ip
}

output "tunnel_id" {
  description = "Proxmox container ID for the tunnel LXC"
  value       = proxmox_virtual_environment_container.tunnel.id
}

output "tunnel_ip" {
  description = "IP address of the tunnel LXC"
  value       = var.tunnel_lxc_ip
}

output "tunnel_token" {
  description = "Cloudflare tunnel token (add to Ansible vault as vault_cloudflared_tunnel_token)"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token
  sensitive   = true
}
