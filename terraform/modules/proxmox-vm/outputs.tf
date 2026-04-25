output "id" {
  description = "VMID Proxmox généré."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  description = "Nom de la VM."
  value       = proxmox_virtual_environment_vm.this.name
}

output "ipv4" {
  description = "Adresse IPv4 de la VM (sans le /mask)."
  value       = split("/", var.ip_address)[0]
}

output "node" {
  description = "Nœud Proxmox hôte."
  value       = proxmox_virtual_environment_vm.this.node_name
}

output "tags" {
  description = "Tags appliqués."
  value       = proxmox_virtual_environment_vm.this.tags
}
