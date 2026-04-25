# =============================================================================
# Vault policy — proxmox
# -----------------------------------------------------------------------------
# Fournit à Terraform (pipeline CI/CD et runs manuels) les credentials Proxmox
# nécessaires pour piloter les clusters Site A / Site B.
# Accès en lecture, rotation manuelle hors de ce périmètre.
# =============================================================================

# Terraform provider bpg/proxmox consomme endpoint + token
path "kv/data/cia/proxmox/siteA/endpoint" {
  capabilities = ["read"]
}
path "kv/data/cia/proxmox/siteA/api-token" {
  capabilities = ["read"]
}

path "kv/data/cia/proxmox/siteB/endpoint" {
  capabilities = ["read"]
}
path "kv/data/cia/proxmox/siteB/api-token" {
  capabilities = ["read"]
}

# Empreinte TLS du cluster (vérification strict TLS activée)
path "kv/data/cia/proxmox/+/tls-fingerprint" {
  capabilities = ["read"]
}

# Clef SSH injectée dans cloud-init (terraform.tfvars.ssh_public_keys)
path "kv/data/cia/ssh/admin-public-key" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
