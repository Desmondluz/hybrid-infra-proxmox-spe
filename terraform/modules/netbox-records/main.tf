# -----------------------------------------------------------------------------
# Module netbox-records
# -----------------------------------------------------------------------------
# Enregistre dans NetBox (source of truth) les préfixes IP et VLAN d'un site.
# Module séparé du module `network` afin que le provider NetBox ne soit requis
# que lorsque NetBox est effectivement déployé (cf. critère network_ip_mngmt).
#
# Activation depuis la racine d'un site :
#   module "netbox_records" {
#     count  = var.netbox_enabled ? 1 : 0
#     source = "../modules/netbox-records"
#     ...
#   }
# -----------------------------------------------------------------------------

resource "netbox_prefix" "this" {
  for_each = { for p in var.prefixes : p.prefix => p }

  prefix      = each.value.prefix
  status      = "active"
  description = each.value.description
  vlan_id     = each.value.vlan_id
  site_id     = var.netbox_site_id
  role_id     = each.value.role_id
  tags        = concat(var.tags, each.value.tags)
}

resource "netbox_vlan" "this" {
  for_each = { for v in var.vlans : v.vid => v }

  name    = each.value.name
  vid     = each.value.vid
  site_id = var.netbox_site_id
  status  = "active"
  tags    = concat(var.tags, each.value.tags)
}
