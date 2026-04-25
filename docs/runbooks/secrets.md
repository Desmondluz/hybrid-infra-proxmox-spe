# Runbook — Secrets (SOPS + Vault)

**Propriétaire** : GR46 · **Dernière revue** : 2026-04-18 · **Criticité** : S1

Deux mécanismes complémentaires :

- **SOPS + age** : secrets versionnés dans le dépôt (TF vars, vault tokens
  opérateurs, certs publics). Chiffrement transparent via les règles de
  `.sops.yaml`.
- **HashiCorp Vault** : secrets dynamiques et à forte rotation (mots de
  passe applicatifs, tokens API pfSense, PKI OpenVPN).

## 1. Bootstrap age (nouvel admin)

```bash
age-keygen -o ~/.config/sops/age/keys.txt
grep "public key" ~/.config/sops/age/keys.txt
# => age1xxxxxxxxxxxxxxx
```

Puis PR sur `.sops.yaml` ajoutant la clef publique dans `creation_rules`.
Re-chiffrer les fichiers affectés :

```bash
sops updatekeys ansible/group_vars/all/secrets.sops.yml
sops updatekeys terraform/siteA/terraform.tfvars.sops
```

Commit uniquement une fois la CI verte.

## 2. Édition d'un secret SOPS

```bash
sops ansible/group_vars/all/secrets.sops.yml
# ouvre $EDITOR, chiffre à la sauvegarde
git diff --stat   # la ligne "encrypted" change seulement
git commit -am "secrets: rotate elastic_admin_password"
```

NE JAMAIS :
- `cat` > `tee` un `.sops.yml` en clair.
- Committer `.decrypted.yml` (gitignored).

## 3. Bootstrap Vault

```bash
export VAULT_ADDR=https://vault.s1.lan:8200
./vault/scripts/init-vault.sh
# sort 5 unseal keys + root token -> ~/.cia-vault-keys.json (chmod 600)
# IMPORTANT : imprimer les unseal keys et les distribuer à 5 personnes.
```

Distribution recommandée :
1. lead tech
2. lead sécurité
3. sponsor projet
4. archive offline (coffre)
5. hors bande (enveloppe scellée)

## 4. Unseal après restart

```bash
export VAULT_ADDR=https://vault.s1.lan:8200
for admin in lead_tech lead_sec archive; do
  # chaque admin saisit sa clef
  vault operator unseal
done
```

## 5. Rotation d'un secret Vault

### Token API pfSense

```bash
export VAULT_TOKEN=<root>
NEW=$(openssl rand -hex 32)
vault kv put kv/cia/pfsense/siteA/api-token token="${NEW}"
ansible-playbook -i ansible/inventories/siteA.ini ansible/playbooks/siteA.yml --tags pfsense
```

### Mot de passe elastic

Voir [elasticsearch.md §8](elasticsearch.md#8-rotation-du-mot-de-passe-elastic).

### Cert OpenVPN

Voir [vpn.md §4.5](vpn.md#45-renouvellement-certs).

## 6. Audit / scan de fuite

- Pré-commit : `gitleaks` bloque tout commit contenant `BEGIN PRIVATE KEY`,
  `aws_access_key_id`, etc.
- CI : workflow `.github/workflows/security-scan.yml` lance `gitleaks`,
  `checkov`, `tflint`.
- Audit annuel : `grep -rE "(password|secret|token)=\"[^\"]{6,}\"" .`
  (hors fichiers SOPS chiffrés — vérifiables par `sops --show-master-keys`).

## 7. Perte d'une clef age

1. Générer nouvelle paire pour l'utilisateur touché (§1).
2. `sops updatekeys` sur tous les fichiers chiffrés.
3. Retirer l'ancienne clef publique de `.sops.yaml`.
4. Commit + annoncer la compromission au #ops.

## 8. Perte des unseal keys Vault

Grave — bascule sur DRP §4 "Vault rebuild" : export kv via token root
stocké hors bande (si disponible), re-init vault neuf, restore des secrets.
Sinon : reseed manuel (voir `docs/drp/drp.md` scénario #5).
