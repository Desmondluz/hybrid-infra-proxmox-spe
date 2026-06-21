# Vault — Documentation complète (CIA Hybrid Infra)

## Résumé

- But : centraliser, protéger et fournir les secrets pour OpenVPN, Bastion (SSH), Proxmox, NetBox et l'accès global d'Ansible.
- Moteur KV : KV v2 monté sur `secret/`.
- Authentification recommandée pour l'automatisation : AppRole (rôle `ansible` fourni).
- Structure du répertoire `vault/` :
  - `policies/` — fichiers HCL (une policy par service)
  - `scripts/` — helpers (init, seed, generate-certs.sh)
  - `README.md` — bref aperçu
  - `secrets/` — exemples / placeholders (NE PAS UTILISER EN PROD)

## Organisation des secrets (convention)

- Règle : 1 service = 1 chemin (KV v2)
- Chemins et clés (KV v2, base `secret/`)

| Service   | Chemin KV v2         | Clés attendues |
|-----------|----------------------|----------------|
| OpenVPN   | secret/openvpn       | ca_cert, server_cert, server_key |
| Bastion   | secret/bastion       | ssh_private_key, ssh_public_key |
| Proxmox   | secret/proxmox       | api_token, url |
| NetBox    | secret/netbox        | username, password |
| Ansible   | (utilise AppRole)    | read/list sur `secret/data/*` via policy |

> Principe : chaque service possède son propre chemin et sa propre policy pour appliquer le principe de moindre privilège.

## Exemples CLI (écriture / lecture)

- Écrire un secret (fichiers avec `@` pour upload) :

```bash
vault kv put secret/openvpn ca_cert=@/path/to/ca.crt server_cert=@/path/to/server.crt server_key=@/path/to/server.key
vault kv put secret/bastion ssh_private_key=@/path/to/id_rsa ssh_public_key=@/path/to/id_rsa.pub
vault kv put secret/proxmox api_token="VALEUR_DU_TOKEN" url="https://proxmox.example.local:8006"
vault kv put secret/netbox username="netbox_user" password="S3cretP@ss" 
```

- Lire un secret :

```bash
vault kv get secret/proxmox
vault kv get -format=json secret/openvpn
```

## Politiques (fichiers dans `vault/policies/`)

- Principe : une policy par service. Chacune ne peut lire QUE son chemin.
- Exemples (KV v2 syntax) :

```hcl
# openvpn-policy.hcl
path "secret/data/openvpn" {
  capabilities = ["read"]
}
```

```hcl
# ansible-policy.hcl
path "secret/data/*" {
  capabilities = ["read", "list"]
}
```

- Déployer les policies :

```bash
vault policy write openvpn-policy vault/policies/openvpn-policy.hcl
vault policy write bastion-policy vault/policies/bastion-policy.hcl
vault policy write proxmox-policy vault/policies/proxmox-policy.hcl
vault policy write netbox-policy vault/policies/netbox-policy.hcl
vault policy write ansible-policy vault/policies/ansible-policy.hcl
```

## Initialisation & AppRole (ansible)

- Activer AppRole :

```bash
vault auth enable approle
vault write auth/approle/role/ansible token_policies="ansible-policy"
```

- Récupérer `role_id` et `secret_id` :

```bash
vault read auth/approle/role/ansible/role-id
vault write -f auth/approle/role/ansible/secret-id
```

- Login AppRole pour obtenir token :

```bash
vault write -format=json auth/approle/login role_id="<role_id>" secret_id="<secret_id>"
# ou
export VAULT_TOKEN=$(vault write -field=client_token auth/approle/login role_id="<role_id>" secret_id="<secret_id>")
```

> Remarque : `init-vault.sh` fourni dans `vault/` automatise l'activation du moteur KV v2, l'installation des policies et la création du rôle AppRole `ansible`. Exécutez ce script en étant authentifié avec un token ayant les droits d'administration.

## Scripts fournis

- `init-vault.sh` : active KV v2 à `secret/`, écrit toutes les policies présentes dans `vault/policies/`, active `approle` et crée le rôle `ansible` lié à la policy `ansible-policy`.
- `seed-secrets.sh` : script d'exemple qui utilise `vault kv put` pour insérer des placeholders (UTILISER uniquement en dev/BOOTSTRAP — ne pas committer de réels secrets).
- `scripts/generate-certs.sh` : script de génération de certificats OpenVPN via le moteur PKI Vault (dans le dépôt il est placé sous `vault/scripts/generate-certs.sh`).

### Détails `generate-certs.sh`

- Ce script :
  - télécharge la CA depuis l'endpoint PKI (`/v1/pki_cia_vpn/ca/pem`)
  - émet un certificat serveur (endpoint `issue/openvpn-server`)
  - émet un certificat client (endpoint `issue/openvpn-client`)
  - génère DH params et la clef `tls-crypt`
  - pousse `tls-crypt.key` dans un chemin KV (dans l'exemple : `kv/cia/openvpn/tls-crypt`).

- Variables d'environnement requises :
  - `VAULT_ADDR` (ex: https://vault.example.local:8200)
  - `VAULT_TOKEN` (token avec droits sur le moteur PKI / policy openvpn)

> Important : vérifier que le mount PKI `pki_cia_vpn` existe et que les policies permettent l'accès pour l'utilisateur/token exécutant le script.

## Intégration Ansible

- Approche recommandée : Ansible (control node ou CI) s'authentifie via AppRole, exporte `VAULT_TOKEN` puis utilise le lookup `community.hashi_vault.hashi_vault` pour lire les secrets.
- Exemple dans un playbook :

```yaml
- name: Read Proxmox token
  set_fact:
    proxmox_token: "{{ lookup('community.hashi_vault.hashi_vault', 'secret=secret/data/proxmox', 'key=api_token') }}"
```

- Variante : demander un token AppRole au début du playbook via `uri` ou `community.hashi_vault` module d'auth, puis réutiliser le token pour toutes les opérations.

## Sécurité & bonnes pratiques

- Principe de moindre privilège : 1 service = 1 policy limitant l'accès à son seul chemin.
- Ne commitez jamais de secrets en clair. `vault/secrets/` contient uniquement des exemples/README.
- Rotation : automatiser la rotation des tokens/secret-id et des credentials applicatifs lorsque possible.
- Audit : activer et consulter les devices d'audit Vault en production.
- Backups et HA : configurer snapshot/replication et procédures de restauration si Vault est en production.
- Permissions FS : les scripts qui écrivent des clés privées doivent créer des répertoires en 700 et fichiers en 600.

## Opérations courantes & troubleshooting

- Vérifier les mounts et moteurs secrets :
```bash
vault secrets list
vault mounts
```
- Vérifier les policies installées :
```bash
vault policy list
vault policy read openvpn-policy
```
- Vérifier AppRole et IDs :
```bash
vault read auth/approle/role/ansible/role-id
vault write -f auth/approle/role/ansible/secret-id
```
- Vérifier permissions : utiliser `vault token lookup` et `vault token capabilities` pour diagnostiquer si un token a accès à un chemin donné.

## Notes spécifiques au dépôt

- Le script `generate-certs.sh` attend un backend PKI nommé `pki_cia_vpn`. Si ce mount n'existe pas, le script échouera — il faut créer/configurer le mount PKI avant exécution.
- Valider et harmoniser le chemin KV utilisé par `generate-certs.sh` (ex. `kv/cia/openvpn/tls-crypt`) avec les policies : soit adapter la policy `openvpn-policy` pour permettre la lecture sur ce chemin, soit modifier le script pour utiliser `secret/openvpn`.

## Références rapides

- CLI KV v2 : https://www.vaultproject.io/docs/commands/kv
- AppRole : https://www.vaultproject.io/docs/auth/approle
- Ansible lookup plugin : community.hashi_vault — https://docs.ansible.com/

## Contact opérationnel & modification

- Pour modifier les chemins, politiques ou le rôle AppRole : éditer les fichiers dans `vault/policies/` puis exécuter `vault policy write ...` ou relancer `vault/init-vault.sh` (en prenant soin d'avoir un token administrateur).

---

Documentation générée automatiquement le : 2026-06-21
