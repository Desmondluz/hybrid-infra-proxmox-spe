output "bridge_names" {
  description = "Noms des bridges créés."
  value       = [for b in proxmox_network_linux_bridge.this : b.name]
}
