#!/usr/bin/env bash
# =============================================================================
# init-vault.sh — bootstrap du Vault CIA
# -----------------------------------------------------------------------------
# - Initialise le vault si nécessaire (5 keys, seuil 3)
# - Unseal interactif
# - Active les moteurs : kv-v2 (secrets applicatifs), pki (CA CIA-VPN), userpass
# - Applique les policies depuis vault/policies/
# - Crée les rôles PKI openvpn-server / openvpn-client
# - Crée un token par rôle opérationnel (proxmox, pfsense, openvpn)
#
# PRÉ-REQUIS : binaire `vault` installé, VAULT_ADDR exporté, curl, jq.
# USAGE     : ./vault/scripts/init-vault.sh [--skip-init]
# =============================================================================
set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR must be set, e.g. https://vault.s1.lan:8200}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
POLICY_DIR="${REPO_ROOT}/vault/policies"
KEYS_FILE="${VAULT_KEYS_FILE:-${HOME}/.cia-vault-keys.json}"

log() { printf '\033[1;34m[vault]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[vault]\033[0m %s\n' "$*" >&2; exit 1; }

command -v vault >/dev/null || err "vault CLI manquant"
command -v jq    >/dev/null || err "jq manquant"

# --- 1. INIT --------------------------------------------------------------
if [[ "${1:-}" != "--skip-init" ]]; then
  if vault status -format=json 2>/dev/null | jq -e '.initialized == false' >/dev/null; then
    log "Initialisation (5 keys, seuil 3)…"
    vault operator init -key-shares=5 -key-threshold=3 -format=json > "${KEYS_FILE}"
    chmod 600 "${KEYS_FILE}"
    log "Clefs écrites dans ${KEYS_FILE} — SAUVEGARDEZ-LES HORS DU DÉPÔT !"
  else
    log "Vault déjà initialisé — on passe à l'unseal."
  fi
fi

# --- 2. UNSEAL ------------------------------------------------------------
if vault status -format=json | jq -e '.sealed == true' >/dev/null; then
  log "Unseal — fournir 3 clefs"
  for i in 0 1 2; do
    KEY="$(jq -r ".unseal_keys_b64[$i]" "${KEYS_FILE}")"
    vault operator unseal "${KEY}"
  done
fi

ROOT_TOKEN="$(jq -r '.root_token' "${KEYS_FILE}")"
export VAULT_TOKEN="${ROOT_TOKEN}"

# --- 3. MOTEURS -----------------------------------------------------------
enable_if_missing() {
  local type="$1" path="$2" ; shift 2
  if ! vault secrets list -format=json | jq -e --arg p "${path}/" '.[$p]' >/dev/null; then
    log "Activation engine ${type} @ ${path}"
    vault secrets enable -path="${path}" "$@" "${type}"
  fi
}

enable_if_missing kv-v2 kv
enable_if_missing pki   pki_cia_vpn -max-lease-ttl=87600h

if ! vault auth list -format=json | jq -e '."userpass/"' >/dev/null; then
  log "Activation auth userpass"
  vault auth enable userpass
fi

# --- 4. PKI CIA-VPN -------------------------------------------------------
if ! vault read pki_cia_vpn/cert/ca 2>/dev/null | grep -q BEGIN; then
  log "Génération CA racine CIA-VPN (validité 10 ans)"
  vault write -field=certificate pki_cia_vpn/root/generate/internal \
    common_name="CIA VPN Root CA" ttl=87600h > "${REPO_ROOT}/vault/secrets/.ca.crt"
  vault write pki_cia_vpn/config/urls \
    issuing_certificates="${VAULT_ADDR}/v1/pki_cia_vpn/ca" \
    crl_distribution_points="${VAULT_ADDR}/v1/pki_cia_vpn/crl"
fi

log "Rôles PKI openvpn-server / openvpn-client"
vault write pki_cia_vpn/roles/openvpn-server \
  allowed_domains="cia-vpn-server-siteA,cia-vpn-server-siteB" \
  allow_bare_domains=true server_flag=true client_flag=false \
  max_ttl=8760h key_bits=2048 key_type=rsa
vault write pki_cia_vpn/roles/openvpn-client \
  allowed_domains="cia-vpn-client-siteB" \
  allow_bare_domains=true server_flag=false client_flag=true \
  max_ttl=8760h key_bits=2048 key_type=rsa

# --- 5. POLICIES ----------------------------------------------------------
for f in "${POLICY_DIR}"/*.hcl; do
  name="$(basename "$f" .hcl)"
  log "Policy ${name}"
  vault policy write "${name}" "$f"
done

# --- 6. TOKENS PAR RÔLE ---------------------------------------------------
log "Tokens opérationnels (TTL 720h, renouvelables)"
for role in proxmox pfsense openvpn; do
  token=$(vault token create -policy="${role}" -ttl=720h -renewable=true -display-name="cia-${role}" -format=json | jq -r '.auth.client_token')
  printf 'CIA_%s_TOKEN=%s\n' "$(echo "${role}" | tr '[:lower:]' '[:upper:]')" "${token}"
done > "${REPO_ROOT}/vault/secrets/.operator-tokens.env"
chmod 600 "${REPO_ROOT}/vault/secrets/.operator-tokens.env"

log "Bootstrap terminé. Tokens → vault/secrets/.operator-tokens.env (gitignored)"
