variable "pve_endpoint" {
  description = "URL de l'API Proxmox du site A (ex: https://pve-s1.lan:8006/)."
  type        = string
}

variable "pve_username" {
  description = "User Proxmox avec droits VM.Allocate/VM.Config.* (ex: terraform@pve)."
  type        = string
  default     = "terraform@pve"
}

variable "pve_node" {
  description = "Nom du nœud Proxmox site A."
  type        = string
  default     = "pve-s1"
}

variable "pve_insecure" {
  description = "Ignorer la vérification TLS (lab uniquement)."
  type        = bool
  default     = false
}

variable "ubuntu_template_id" {
  description = "VMID du template cloud-init Ubuntu 22.04+ sur le nœud."
  type        = number
}

variable "pfsense_template_id" {
  description = "VMID du template pfSense pré-installé sur le nœud."
  type        = number
}

variable "datastore_id" {
  description = "Datastore de stockage VM."
  type        = string
  default     = "local-lvm"
}

# Variables consommées par terraform/siteA/netbox.tf.disabled (réactivé en FW3,
# une fois NetBox provisionné). Conservées ici pour figer le contrat d'API.
# tflint-ignore: terraform_unused_declarations
variable "netbox_endpoint" {
  description = "URL API NetBox (ex: https://netbox.s1.lan/)."
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "netbox_site_id" {
  description = "ID NetBox du site A."
  type        = number
  default     = 1
}

variable "admin_ssh_keys" {
  description = "Clés publiques SSH des admins injectées par cloud-init."
  type        = list(string)
}

variable "dns_servers" {
  description = "Serveurs DNS distribués via cloud-init (ordre = priorité)."
  type        = list(string)
  default     = ["10.10.10.30", "192.168.0.30"]
}

variable "dns_domain" {
  description = "Domaine interne du site A."
  type        = string
  default     = "s1.lan"
}

# tflint-ignore: terraform_unused_declarations
variable "netbox_enabled" {
  description = "Enregistrer les VLAN/préfixes dans NetBox. Désactivé tant que NetBox n'est pas déployé (réactivation FW3 + renommer netbox.tf.disabled)."
  type        = bool
  default     = false
}
