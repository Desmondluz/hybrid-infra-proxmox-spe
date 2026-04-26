# -----------------------------------------------------------------------------
# Site B — 3 VMs (contrainte SPE)
# -----------------------------------------------------------------------------
#   VM1 : pfsense-s2  → pare-feu + terminaison OpenVPN (client/peer)
#   VM2 : bastion-s2  → bastion SSH durci (seul point d'entrée externe)
#   VM3 : services-s2 → Elasticsearch forwarder + app miroir + runner CI
# -----------------------------------------------------------------------------

module "vm_pfsense" {
  source = "../modules/proxmox-vm"

  name         = "pfsense-s2"
  description  = "pfSense Site B — firewall, routeur, OpenVPN peer"
  target_node  = var.pve_node
  template_id  = var.pfsense_template_id
  datastore_id = var.datastore_id

  cores     = 2
  memory    = 2048
  disk_size = 8 # FW2 LAB: 8 GB suffit pour pfSense (image base ~1 GB)

  bridge          = "vmbr0" # WAN
  ip_address      = "192.168.0.1/24"
  gateway         = null
  dns_domain      = var.dns_domain
  dns_servers     = var.dns_servers
  ssh_public_keys = var.admin_ssh_keys

  # pfSense = FreeBSD : pas de cloud-init, pas de QGA dans le template par défaut.
  # La config (WAN/LAN/règles/OpenVPN peer) sera poussée via le rôle Ansible
  # `pfsense` après clone. ip_address ci-dessus est documentaire (cible post-config).
  enable_cloud_init = false
  enable_qemu_agent = false
  os_type           = "other"

  tags = ["site-b", "firewall", "pfsense", "critical"]
}

module "vm_bastion" {
  source = "../modules/proxmox-vm"

  name         = "bastion-s2"
  description  = "Site B — bastion SSH durci (MFA + clés + audit)"
  target_node  = var.pve_node
  template_id  = var.ubuntu_template_id
  datastore_id = var.datastore_id

  cores     = 1
  memory    = 1024
  disk_size = 8 # FW2 LAB: bastion = sshd + audit, ~3 GB en run

  bridge          = "vmbr146"
  vlan_tag        = 22 # DMZ
  ip_address      = "192.168.0.10/24"
  gateway         = "192.168.0.1"
  dns_domain      = var.dns_domain
  dns_servers     = var.dns_servers
  ssh_public_keys = var.admin_ssh_keys

  tags = ["site-b", "bastion", "security", "critical"]
}

module "vm_services" {
  source = "../modules/proxmox-vm"

  name         = "services-s2"
  description  = "Site B — App mirror + log forwarder + CI runner"
  target_node  = var.pve_node
  template_id  = var.ubuntu_template_id
  datastore_id = var.datastore_id

  cores     = 2
  memory    = 4096
  disk_size = 12 # FW2 LAB: 12 GB pour Elastic forwarder + app (à passer à 40 pour FW3 prod)

  bridge          = "vmbr146"
  vlan_tag        = 21 # services
  ip_address      = "192.168.10.20/24"
  gateway         = "192.168.10.1"
  dns_domain      = var.dns_domain
  dns_servers     = var.dns_servers
  ssh_public_keys = var.admin_ssh_keys

  tags = ["site-b", "services", "forwarder"]
}
