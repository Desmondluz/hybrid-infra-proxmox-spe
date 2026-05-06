#!/usr/bin/env bash
set -euo pipefail

# seed-secrets.sh
# Example script to write placeholder secrets to Vault KV v2 engine at `secret/`.
# WARNING: For development / bootstrap only. Do NOT store real secrets in the repo.

if ! command -v vault >/dev/null 2>&1; then
  echo "vault CLI not found in PATH"
  exit 1
fi

echo "Writing example secrets to Vault (KV v2 at secret/)"

vault kv put secret/openvpn \
  ca_cert=@secrets/openvpn/ca.crt \
  server_cert=@secrets/openvpn/server.crt \
  server_key=@secrets/openvpn/server.key || true

vault kv put secret/bastion \
  ssh_private_key=@secrets/bastion/id_rsa \
  ssh_public_key=@secrets/bastion/id_rsa.pub || true

vault kv put secret/proxmox \
  api_token="REPLACE_WITH_PROXMOX_API_TOKEN" \
  url="https://proxmox.example.local:8006" || true

vault kv put secret/netbox \
  username="netbox_user" \
  password="REPLACE_WITH_NETBOX_PASSWORD" || true

echo "Done. Replace placeholder values with real secrets using 'vault kv put' or CI/CD secret injection."
