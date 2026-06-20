variable "prefix" {
  description = "Préfixe utilisé pour le nommage de toutes les ressources Azure."
  type        = string
  default     = "cia-gr46"
}

variable "location" {
  description = "Région Azure (proche de l'Europe pour faible latence vers l'école)."
  type        = string
  default     = "westeurope"
}

variable "vnet_cidr" {
  description = "Espace d'adressage du VNet Site C (différent de Site A 10.1.0.0/24 et Site B 10.2.0.0/24)."
  type        = string
  default     = "10.3.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR du sous-réseau public hébergeant la VM."
  type        = string
  default     = "10.3.1.0/24"
}

variable "vm_size" {
  description = "Taille de la VM Azure. B2s = 2 vCPU + 4 Go RAM, gratuit 750h/mois avec Azure for Students."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Nom du compte admin Linux créé par Azure au déploiement."
  type        = string
  default     = "desmon"
}

variable "ssh_public_key_path" {
  description = "Chemin local vers la clé publique SSH à injecter dans la VM (généralement ~/.ssh/cia_gr46.pub)."
  type        = string
}
