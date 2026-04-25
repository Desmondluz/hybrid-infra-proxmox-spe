variable "netbox_site_id" {
  description = "ID du site NetBox (1 = Site A, 2 = Site B…)."
  type        = number
}

variable "prefixes" {
  description = "Préfixes IP à enregistrer dans NetBox."
  type = list(object({
    prefix      = string
    description = string
    vlan_id     = optional(number)
    role_id     = optional(number)
    tags        = optional(list(string), [])
  }))
  default = []
}

variable "vlans" {
  description = "VLANs à enregistrer dans NetBox."
  type = list(object({
    name = string
    vid  = number
    tags = optional(list(string), [])
  }))
  default = []
}

variable "tags" {
  description = "Tags NetBox appliqués à toutes les ressources créées."
  type        = list(string)
  default     = []
}
