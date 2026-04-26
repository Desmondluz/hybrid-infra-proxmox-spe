# -----------------------------------------------------------------------------
# Site A — 3 VMs (contrainte SPE : 3 VMs max par site)
# -----------------------------------------------------------------------------
#   VM1 : pfsense-s1        → pare-feu + terminaison OpenVPN (serveur)
#   VM2 : services-s1       → NetBox + site web interne (Docker)
#   VM3 : observability-s1  → Elasticsearch + Kibana + Logstash
# -----------------------------------------------------------------------------

# --- VM1 : pfSense (firewall + OpenVPN server) -----------------------------
module "vm_pfsense" {
  source = "../modules/proxmox-vm"

  name         = "pfsense-s1"
  description  = "pfSense Site A — firewall, routeur, OpenVPN server"
  target_node  = var.pve_node
  template_id  = var.pfsense_template_id
  datastore_id = var.datastore_id

  cores     = 2
  memory    = 2048
  disk_size = 20

  bridge          = "vmbr146"
  ip_address      = "10.10.10.1/24"
  gateway         = null # pfSense gère sa propre route par défaut
  dns_domain      = var.dns_domain
  dns_servers     = var.dns_servers
  ssh_public_keys = var.admin_ssh_keys

  # pfSense = FreeBSD : pas de cloud-init, pas de QGA dans le template par défaut.
  # La config (WAN/LAN/règles/OpenVPN) sera poussée via le rôle Ansible `pfsense`
  # après clone. ip_address ci-dessus est purement documentaire (cible post-config).
  enable_cloud_init = false
  enable_qemu_agent = false
  os_type           = "other"

  tags = ["site-a", "firewall", "pfsense", "critical"]
}

# --- VM2 : Services (NetBox + site web interne) ----------------------------
module "vm_services" {
  source = "../modules/proxmox-vm"

  name         = "services-s1"
  description  = "Site A — NetBox (IPAM) + site web interne"
  target_node  = var.pve_node
  template_id  = var.ubuntu_template_id
  datastore_id = var.datastore_id

  cores     = 2
  memory    = 4096
  disk_size = 40

  bridge          = "vmbr146"
  vlan_tag        = 11 # admin
  ip_address      = "10.10.10.20/24"
  gateway         = "10.10.10.1"
  dns_domain      = var.dns_domain
  dns_servers     = var.dns_servers
  ssh_public_keys = var.admin_ssh_keys

  tags = ["site-a", "services", "netbox", "webapp"]
}

# --- VM3 : Observability (Elastic + Kibana + Logstash) ---------------------
module "vm_observability" {
  source = "../modules/proxmox-vm"

  name         = "observability-s1"
  description  = "Site A — Elastic stack (ES + Kibana + Logstash)"
  target_node  = var.pve_node
  template_id  = var.ubuntu_template_id
  datastore_id = var.datastore_id

  cores     = 4
  memory    = 6144
  disk_size = 80

  bridge          = "vmbr146"
  vlan_tag        = 11
  ip_address      = "10.10.10.40/24"
  gateway         = "10.10.10.1"
  dns_domain      = var.dns_domain
  dns_servers     = var.dns_servers
  ssh_public_keys = var.admin_ssh_keys

  tags = ["site-a", "observability", "elastic"]
}
