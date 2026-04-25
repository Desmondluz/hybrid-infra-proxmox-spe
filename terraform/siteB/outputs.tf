output "site_b_vms" {
  description = "Récapitulatif des VMs du Site B."
  value = {
    pfsense  = { id = module.vm_pfsense.id, ip = module.vm_pfsense.ipv4 }
    bastion  = { id = module.vm_bastion.id, ip = module.vm_bastion.ipv4 }
    services = { id = module.vm_services.id, ip = module.vm_services.ipv4 }
  }
}

output "site_b_network" {
  description = "Bridges Proxmox déclarés pour le Site B."
  value = {
    bridges = module.network.bridge_names
  }
}

# NB : les outputs `site_b_netbox_*` (préfixes / VLANs enregistrés) sont
# déclarés dans terraform/siteB/netbox.tf et n'apparaissent que lorsque ce
# fichier est actif (NetBox déployé).
