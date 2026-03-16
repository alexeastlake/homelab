output "docker_host_id" {
  description = "Proxmox container ID"
  value       = proxmox_virtual_environment_container.docker_host.id
}

output "docker_host_ip" {
  description = "IP address of the Docker host LXC (use this in Ansible inventory)"
  value       = var.lxc_ip
}
