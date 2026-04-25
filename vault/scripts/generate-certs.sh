#!/usr/bin/env bash
# =============================================================================
# generate-certs.sh — génère les certificats OpenVPN CIA via Vault PKI
# -----------------------------------------------------------------------------
# Produit sous configs/openvpn/pki/ :
#   - ca.crt        (CA racine CIA VPN)
#   - server.crt + server.key           (Site A, CN=cia-vpn-server-siteA)
#   - client-siteB.crt + client-siteB.key (Site B, CN=cia-vpn-client-siteB)
#   - dh2048.pem    (Diffie-Hellman 2048 bits)
#   - tls-crypt.key (clef statique OpenVPN --tls-crypt)
#
# Tous les artefacts sensibles (.key, .pem, tls-crypt) sont ignorés par .gitignore.
# =============================================================================
set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set (policy=openvpn)}"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${REPO_ROOT}/configs/openvpn/pki"
mkdir -p "${OUT_DIR}"
chmod 700 "${OUT_DIR}"

log() { printf '\033[1;34m[certs]\033[0m %s\n' "$*"; }

# --- 1. CA ----------------------------------------------------------------
log "Téléchargement de la CA CIA-VPN"
curl -sSf --cacert /etc/ssl/certs/ca-certificates.crt \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  "${VAULT_ADDR}/v1/pki_cia_vpn/ca/pem" \
  > "${OUT_DIR}/ca.crt"

# --- 2. Server cert Site A ------------------------------------------------
log "Émission du certificat serveur Site A"
RESP=$(curl -sSf -X POST \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -d '{"common_name":"cia-vpn-server-siteA","ttl":"8760h"}' \
  "${VAULT_ADDR}/v1/pki_cia_vpn/issue/openvpn-server")
echo "${RESP}" | jq -r '.data.certificate'  > "${OUT_DIR}/server.crt"
echo "${RESP}" | jq -r '.data.private_key'  > "${OUT_DIR}/server.key"
echo "${RESP}" | jq -r '.data.issuing_ca'   >> "${OUT_DIR}/ca.crt"  # chain
chmod 600 "${OUT_DIR}/server.key"

# --- 3. Client cert Site B ------------------------------------------------
log "Émission du certificat client Site B"
RESP=$(curl -sSf -X POST \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -d '{"common_name":"cia-vpn-client-siteB","ttl":"8760h"}' \
  "${VAULT_ADDR}/v1/pki_cia_vpn/issue/openvpn-client")
echo "${RESP}" | jq -r '.data.certificate' > "${OUT_DIR}/client-siteB.crt"
echo "${RESP}" | jq -r '.data.private_key' > "${OUT_DIR}/client-siteB.key"
chmod 600 "${OUT_DIR}/client-siteB.key"

# --- 4. DH params ---------------------------------------------------------
if [[ ! -s "${OUT_DIR}/dh2048.pem" ]]; then
  log "Génération dh2048.pem (5-10 min sur CPU modeste)"
  openssl dhparam -out "${OUT_DIR}/dh2048.pem" 2048
fi

# --- 5. tls-crypt key -----------------------------------------------------
if [[ ! -s "${OUT_DIR}/tls-crypt.key" ]]; then
  log "Génération tls-crypt.key"
  openvpn --genkey secret "${OUT_DIR}/tls-crypt.key"
  chmod 600 "${OUT_DIR}/tls-crypt.key"
fi

# --- 6. Stockage dans Vault KV pour consommation Ansible ------------------
log "Push tls-crypt key dans Vault (kv/cia/openvpn/tls-crypt)"
vault kv put kv/cia/openvpn/tls-crypt content=@"${OUT_DIR}/tls-crypt.key" >/dev/null

log "Fait. Artefacts sous ${OUT_DIR}"
ls -l "${OUT_DIR}"
