# =============================================================================
# Vault policy — pfsense
# -----------------------------------------------------------------------------
# Permet au rôle Ansible `pfsense` et aux scripts d'ops de récupérer :
#   - le mot de passe admin pfSense
#   - le token API pfSense
#   - les secrets annexes (syslog cert, user passwords)
# =============================================================================

path "kv/data/cia/pfsense/siteA/admin" {
  capabilities = ["read"]
}

path "kv/data/cia/pfsense/siteB/admin" {
  capabilities = ["read"]
}

path "kv/data/cia/pfsense/siteA/api-token" {
  capabilities = ["read"]
}

path "kv/data/cia/pfsense/siteB/api-token" {
  capabilities = ["read"]
}

# Écriture réservée au workflow d'enrôlement initial (rotation trimestrielle)
path "kv/data/cia/pfsense/+/api-token" {
  capabilities = ["update"]
  allowed_parameters = {
    "data" = []
  }
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
