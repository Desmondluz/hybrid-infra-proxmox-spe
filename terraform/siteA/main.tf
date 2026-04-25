# -----------------------------------------------------------------------------
# Site A (on-prem) — racine Terraform
# -----------------------------------------------------------------------------
# Provisionne les bridges Proxmox, déploie les 3 VMs du site (contrainte SPE :
# 3 VMs max/site), et — dès que NetBox est up — enregistre les VLAN/préfixes
# dans NetBox (cf. terraform/siteA/netbox.tf et var netbox_enabled).
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

  # Backend local chiffré par défaut. Remplacer par un backend distant
  # (S3, Terraform Cloud, GitLab) pour un usage équipe.
  backend "local" {
    path = "terraform.tfstate"
  }
}

# --- Secrets (SOPS) --------------------------------------------------------
data "sops_file" "secrets" {
  source_file = "../../secrets/siteA.enc.yml"
}

# --- Providers -------------------------------------------------------------
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

# --- Réseau (bridges) ------------------------------------------------------
module "network" {
  source = "../modules/network"

  target_node = var.pve_node

  bridges = [
    {
      name    = "vmbr146"
      comment = "GR46 - LAN isolé"
    },
  ]
}
