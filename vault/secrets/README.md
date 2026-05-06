DO NOT STORE REAL SECRETS HERE

This folder is for sample placeholder files only to illustrate how `seed-secrets.sh` reads files.

Structure (example)

secrets/
  openvpn/
    ca.crt
    server.crt
    server.key
  bastion/
    id_rsa
    id_rsa.pub

Keep real secrets in Vault only. This folder may be kept empty in the repository.
# vault/secrets/

Ce dossier contient des **exemples de structure** et des **placeholders**
chiffrés via SOPS (age). Les secrets réels ne sont jamais committés.

## Organisation

```
vault/secrets/
├── bastion/   # secrets spécifiques bastion (TOTP seeds, PAM config)
├── openvpn/   # certs OpenVPN (*.crt lisibles, *.key ignorés)
└── proxmox/   # tokens API Proxmox (SOPS chiffré)
```

## Règles d'hygiène

1. Tout fichier `.key`, `.pem`, `.env` est dans `.gitignore`.
2. Les fichiers nommés `*.sops.yml` sont chiffrés via `sops --encrypt --in-place`.
3. Le bootstrap se fait via `vault/scripts/init-vault.sh`.
4. La rotation est documentée dans `docs/runbooks/secrets.md`.

## Voir aussi

- [`vault/policies/`](../policies/) — policies HCL
- [`.sops.yaml`](../../.sops.yaml) — règles de chiffrement
