# -----------------------------------------------------------------------------
# Site B (remote) — racine Terraform
# -----------------------------------------------------------------------------
# Provisionne les bridges Proxmox, déploie les 3 VMs du site (contrainte SPE :
# 3 VMs max/site), et — dès que NetBox est up — enregistre les VLAN/préfixes
# dans NetBox (cf. terraform/siteB/netbox.tf et var netbox_enabled).
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.60.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = ">= 1.0.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

data "sops_file" "secrets" {
  source_file = "../../secrets/siteB.enc.yml"
}

provider "proxmox" {
  endpoint = var.pve_endpoint
  username = var.pve_username
  password = data.sops_file.secrets.data["pve_password"]
  insecure = var.pve_insecure

  ssh {
    agent    = true
    username = "root"
  }
}

module "network" {
  source = "../modules/network"

  target_node = var.pve_node

  bridges = [
    # vmbr0 = bridge WAN du Proxmox (créé par l'installeur, importé dans
    # le state Terraform). Porte l'IP de management 192.168.208.50/24
    # accessible depuis l'hôte via le VMware NAT (VMnet8). Toute modif
    # ici DOIT préserver ces valeurs sous peine de perdre l'accès au PVE.
    {
      name       = "vmbr0"
      comment    = "WAN Internet (management PVE)"
      address    = "192.168.208.50/24"
      gateway    = "192.168.208.2"
      ports      = ["ens33"]
      vlan_aware = false # WAN : pas de tagging
    },
    # vmbr146 = bridge LAN isolé du groupe GR46. Pas d'IP côté hôte
    # (pfSense porte la passerelle 192.168.0.1 sur ce bridge).
    {
      name       = "vmbr146"
      comment    = "GR46 - LAN isolé"
      vlan_aware = true # LAN : tag VLAN 20/21/22
    },
  ]
}
