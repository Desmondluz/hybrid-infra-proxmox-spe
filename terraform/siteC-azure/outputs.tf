output "resource_group" {
  description = "Nom du Resource Group créé."
  value       = azurerm_resource_group.rg.name
}

output "public_ip" {
  description = "IP publique de la VM Site C (utilisée pour SSH et l'endpoint OpenVPN serveur)."
  value       = azurerm_public_ip.pip.ip_address
}

output "ssh_command" {
  description = "Commande SSH prête à coller pour atteindre la VM."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "ansible_inventory_entry" {
  description = "Ligne à copier dans ansible/inventories/prod.ini sous le groupe [siteC]."
  value       = "siteC-vm ansible_host=${azurerm_public_ip.pip.ip_address} ansible_user=${var.admin_username}"
}
