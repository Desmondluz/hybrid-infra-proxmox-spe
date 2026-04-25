variable "pve_endpoint" {
  description = "URL de l'API Proxmox du site B."
  type        = string
}

variable "pve_username" {
  description = "User Proxmox pour Terraform."
  type        = string
  default     = "terraform@pve"
}

variable "pve_node" {
  description = "Nom du nœud Proxmox site B."
  type        = string
  default     = "pve-s2"
}

variable "pve_insecure" {
  description = "Ignorer la vérification TLS."
  type        = bool
  default     = false
}

variable "ubuntu_template_id" {
  description = "VMID du template cloud-init Ubuntu."
  type        = number
}

variable "pfsense_template_id" {
  description = "VMID du template pfSense."
  type        = number
}

variable "datastore_id" {
  description = "Datastore de stockage VM."
  type        = string
  default     = "local-lvm"
}

variable "netbox_endpoint" {
  description = "URL API NetBox."
  type        = string
}

variable "netbox_site_id" {
  description = "ID NetBox du site B."
  type        = number
  default     = 2
}

variable "admin_ssh_keys" {
  description = "Clés publiques SSH des admins."
  type        = list(string)
}

variable "dns_servers" {
  description = "DNS distribués via cloud-init."
  type        = list(string)
  default     = ["192.168.0.30", "10.10.10.30"]
}

variable "dns_domain" {
  description = "Domaine interne Site B."
  type        = string
  default     = "s2.lan"
}

variable "bastion_wan_port" {
  description = "Port SSH exposé sur Internet pour le bastion (non-standard)."
  type        = number
  default     = 2222
}

variable "netbox_enabled" {
  description = "Enregistrer les VLAN/préfixes dans NetBox. Désactivé tant que NetBox n'est pas déployé."
  type        = bool
  default     = false
}
