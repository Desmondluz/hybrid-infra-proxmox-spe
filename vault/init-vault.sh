#!/usr/bin/env bash
set -euo pipefail

# init-vault.sh
# Bootstrapping script to configure Vault for the project:
# - Enable KV v2 at secret/
# - Write service policies
# - Enable AppRole auth method and create ansible role
# - Print commands to fetch role_id and secret_id

if ! command -v vault >/dev/null 2>&1; then
  echo "vault CLI not found in PATH"
  exit 1
fi

echo "1) Enable KV v2 at mount 'secret' (idempotent)"
vault secrets enable -path=secret -version=2 kv || true

echo "2) Install policies from ./policies"
for f in ./policies/*.hcl; do
  name=$(basename "$f" .hcl)
  echo "Writing policy $name"
  vault policy write "$name" "$f"
done

echo "3) Enable approle auth method (idempotent)"
vault auth enable approle || true

echo "4) Create AppRole 'ansible' bound to 'ansible-policy'"
vault write auth/approle/role/ansible token_policies=ansible-policy || true

echo "To retrieve role_id and secret_id run the following commands and store them securely:"
echo "  vault read auth/approle/role/ansible/role-id"
echo "  vault write -f auth/approle/role/ansible/secret-id"

echo "Init complete."
