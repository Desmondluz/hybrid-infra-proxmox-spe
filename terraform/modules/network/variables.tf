variable "target_node" {
  description = "Nom du nœud Proxmox."
  type        = string
}

variable "bridges" {
  description = "Liste de bridges Linux à créer ou managés sur le nœud Proxmox."
  type = list(object({
    name       = string
    address    = optional(string)
    gateway    = optional(string)
    comment    = optional(string, "")
    mtu        = optional(number, 1500)
    ports      = optional(list(string), [])
    vlan_aware = optional(bool, true)
    autostart  = optional(bool, true)
  }))
  default = []
}
