output "site_a_vms" {
  description = "Récapitulatif des VMs du Site A."
  value = {
    pfsense       = { id = module.vm_pfsense.id, ip = module.vm_pfsense.ipv4 }
    services      = { id = module.vm_services.id, ip = module.vm_services.ipv4 }
    observability = { id = module.vm_observability.id, ip = module.vm_observability.ipv4 }
  }
}

output "site_a_network" {
  description = "Bridges Proxmox déclarés pour le Site A."
  value = {
    bridges = module.network.bridge_names
  }
}

# NB : les outputs `site_a_netbox_*` (préfixes / VLANs enregistrés) sont
# déclarés dans terraform/siteA/netbox.tf et n'apparaissent que lorsque ce
# fichier est actif (NetBox déployé).
