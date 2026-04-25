# -----------------------------------------------------------------------------
# Module network
# -----------------------------------------------------------------------------
# Provisionne les bridges Linux Proxmox d'un nœud (vmbr0, vmbr146, …) en
# cohérence avec le plan d'adressage défini dans `networking/addressing.yml`.
#
# La déclaration des préfixes / VLAN dans NetBox a été déplacée dans le module
# dédié `modules/netbox-records` afin que le provider NetBox ne soit requis
# que lorsque NetBox est effectivement déployé.
# -----------------------------------------------------------------------------

resource "proxmox_network_linux_bridge" "this" {
  for_each = { for b in var.bridges : b.name => b }

  node_name  = var.target_node
  name       = each.value.name
  address    = each.value.address
  gateway    = each.value.gateway
  comment    = each.value.comment
  vlan_aware = each.value.vlan_aware
  autostart  = each.value.autostart
  mtu        = each.value.mtu
  ports      = each.value.ports
}
