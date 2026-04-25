# -----------------------------------------------------------------------------
# Module proxmox-vm
# -----------------------------------------------------------------------------
# Paramétré pour déployer une VM Linux sur Proxmox VE via le provider
# bpg/proxmox. La VM est clonée depuis un template cloud-init existant sur
# l'hyperviseur, configurée via cloud-init (user, ssh-key, network), puis
# démarrée.
#
# Usage :
#   module "vm_netbox" {
#     source          = "../modules/proxmox-vm"
#     name            = "netbox-s1"
#     target_node     = var.pve_node
#     template_id     = var.ubuntu_template_id
#     cores           = 2
#     memory          = 4096
#     disk_size       = 40
#     ip_address      = "10.10.10.20/24"
#     gateway         = "10.10.10.1"
#     vlan_tag        = 10
#     bridge          = "vmbr146"
#     ssh_public_keys = [var.admin_ssh_key]
#     tags            = ["site-a", "services", "netbox"]
#   }
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  description = var.description
  tags        = var.tags
  node_name   = var.target_node
  vm_id       = var.vm_id

  clone {
    vm_id = var.template_id
    full  = true
  }

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores   = var.cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size
    file_format  = "raw"
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge   = var.bridge
    model    = "virtio"
    vlan_id  = var.vlan_tag
    firewall = var.enable_vm_firewall
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.datastore_id
    interface    = "ide2"

    user_account {
      username = var.cloud_init_user
      keys     = var.ssh_public_keys
    }

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }
  }

  started = var.started

  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
      disk[0].file_format,
    ]
  }
}
