# =============================================================================
# Vault policy — openvpn
# -----------------------------------------------------------------------------
# Permet aux hôtes pfSense (Site A / Site B) de récupérer leurs certificats
# OpenVPN et la clef tls-crypt. Lecture seule.
# Appliquer avec :
#   vault policy write openvpn vault/policies/openvpn.hcl
# =============================================================================

# PKI — émission de certificats serveur/client CIA-VPN
path "pki_cia_vpn/issue/openvpn-server" {
  capabilities = ["create", "update"]
}

path "pki_cia_vpn/issue/openvpn-client" {
  capabilities = ["create", "update"]
}

# Téléchargement de la CA et CRL pour validation mutuelle
path "pki_cia_vpn/cert/ca" {
  capabilities = ["read"]
}

path "pki_cia_vpn/cert/crl" {
  capabilities = ["read"]
}

# Static secrets : tls-crypt key + dhparams
path "kv/data/cia/openvpn/tls-crypt" {
  capabilities = ["read"]
}

path "kv/data/cia/openvpn/dh" {
  capabilities = ["read"]
}

# Token self-renew
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
