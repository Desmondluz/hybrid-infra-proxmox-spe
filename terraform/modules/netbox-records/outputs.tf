output "prefix_ids" {
  description = "IDs NetBox des préfixes créés."
  value       = [for p in netbox_prefix.this : p.id]
}

output "vlan_ids" {
  description = "IDs NetBox des VLANs créés."
  value       = [for v in netbox_vlan.this : v.id]
}
