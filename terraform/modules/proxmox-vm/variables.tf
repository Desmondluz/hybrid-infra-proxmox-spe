variable "name" {
  description = "Nom de la VM (sera aussi son hostname)."
  type        = string
}

variable "description" {
  description = "Description libre de la VM, visible dans Proxmox."
  type        = string
  default     = "Managed by Terraform"
}

variable "target_node" {
  description = "Nom du nœud Proxmox sur lequel créer la VM."
  type        = string
}

variable "vm_id" {
  description = "VMID numérique Proxmox (optionnel, auto si null)."
  type        = number
  default     = null
}

variable "template_id" {
  description = "VMID du template cloud-init à cloner."
  type        = number
}

variable "cores" {
  description = "Nombre de vCPU."
  type        = number
  default     = 2
  validation {
    condition     = var.cores >= 1 && var.cores <= 16
    error_message = "cores doit être entre 1 et 16."
  }
}

variable "memory" {
  description = "RAM en MiB."
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Taille disque en Go."
  type        = number
  default     = 20
}

variable "datastore_id" {
  description = "Datastore Proxmox pour le disque et cloud-init."
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Bridge réseau Proxmox (ex: vmbr0, vmbr146)."
  type        = string
  default     = "vmbr146"
}

variable "vlan_tag" {
  description = "Tag VLAN (0 = pas de VLAN)."
  type        = number
  default     = 0
}

variable "enable_vm_firewall" {
  description = "Activer le firewall Proxmox natif pour cette VM."
  type        = bool
  default     = true
}

variable "ip_address" {
  description = "IP CIDR cloud-init (ex: 10.10.10.20/24) ou 'dhcp'."
  type        = string
}

variable "gateway" {
  description = "Passerelle par défaut. null pour DHCP ou aucune."
  type        = string
  default     = null
}

variable "dns_domain" {
  description = "Domaine DNS appliqué via cloud-init."
  type        = string
  default     = "lan"
}

variable "dns_servers" {
  description = "Liste de serveurs DNS appliqués via cloud-init."
  type        = list(string)
  default     = ["10.10.10.30", "1.1.1.1"]
}

variable "cloud_init_user" {
  description = "Utilisateur initial créé par cloud-init."
  type        = string
  default     = "admin"
}

variable "ssh_public_keys" {
  description = "Liste de clés publiques SSH injectées pour l'utilisateur cloud-init."
  type        = list(string)
}

variable "tags" {
  description = "Tags Proxmox appliqués à la VM."
  type        = list(string)
  default     = []
}

variable "started" {
  description = "Démarrer la VM après création."
  type        = bool
  default     = true
}
