# Vault for hybrid-infra-proxmox-spe

This directory contains Vault policies, example commands and helper scripts to bootstrap a secure HashiCorp Vault setup for the project.

Goals
- Securely store secrets for OpenVPN, Bastion (SSH), Proxmox, NetBox and provide Ansible with read access.
- Use KV v2 engine mounted at `secret/`.
- One service = one secret path and one policy.

Structure
- `policies/` : policy HCL files per service
- `secrets/` : optional directory to store example secret files (not real secrets)
- `init-vault.sh` : helper script to enable kv, create policies and AppRole for Ansible
- `seed-secrets.sh` : optional script showing how to write secrets (for bootstrapping only)

Security principles
- Least privilege: each service policy only grants read to its own path.
- Separation of access: Ansible has a dedicated policy that can read/list all secret paths.
- No hardcoded secrets in code: use environment variables and Vault for runtime secrets.

Quickstart
1. Start or unseal Vault and authenticate (e.g. with `vault login` using a root/token with policy write privileges).
2. Run the initializer (one-time):

```bash
chmod +x init-vault.sh seed-secrets.sh
./init-vault.sh
```

3. If you want example data inserted (development only):

```bash
./seed-secrets.sh
```

Files created by the scripts
- policies installed with `vault policy write <name> <file>`
- approle role `ansible` created under `auth/approle/role/ansible` (if `init-vault.sh` is used)

Useful example CLI commands

- Write a secret (KV v2):

```bash
# single value keys
vault kv put secret/proxmox api_token="<token>" url="https://proxmox.example:8006"

# binary / file values (example for certs)
vault kv put secret/openvpn ca_cert=@/path/to/ca.crt server_cert=@/path/to/server.crt server_key=@/path/to/server.key
```

- Read a secret:

```bash
vault kv get -format=json secret/openvpn
vault kv get secret/proxmox
```

- Write policies manually:

```bash
vault policy write openvpn-policy vault/policies/openvpn-policy.hcl
vault policy write bastion-policy vault/policies/bastion-policy.hcl
vault policy write proxmox-policy vault/policies/proxmox-policy.hcl
vault policy write netbox-policy vault/policies/netbox-policy.hcl
vault policy write ansible-policy vault/policies/ansible-policy.hcl
```

- AppRole (create and retrieve credentials):

```bash
# create role_id
vault read auth/approle/role/ansible/role-id

# create a secret-id (one-time) and show it
vault write -f auth/approle/role/ansible/secret-id

# Using the role_id and secret_id to login (example):
vault write auth/approle/login role_id="<role_id>" secret_id="<secret_id>"
```

Ansible integration (short)

Use the community.hashi_vault lookup plugin (or hashivault lookup) to fetch secrets during runs. Example in an Ansible task:

```yaml
- name: Get Proxmox token from Vault
	set_fact:
		proxmox_secret: "{{ lookup('community.hashi_vault.hashi_vault', 'secret=secret/data/proxmox', 'key=api_token') }}"
```

Notes on security
- Keep AppRole secret_ids tightly controlled and rotate them.
- Prefer dynamic secrets when possible (Vault database/PKI/Cloud engines) for better rotation.

Notes
- Review and rotate secrets regularly.
- Do not commit real secrets to the repository. `secrets/` should contain sample placeholders only.
