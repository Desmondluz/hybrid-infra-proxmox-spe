# Runbook — NetBox auto-sync (IPAM as code)

**Propriétaire** : GR46
**Dernière revue** : 2026-06-21
**Criticité** : S2 (impact moyen — affecte la source de vérité, pas la production directe)
**Couvre les critères** : `network_ipam` (alimenté automatiquement)

---

## 1. Vue d'ensemble

Le projet CIA traite **`networking/addressing.yml` comme la seule source de
vérité** pour l'IPAM. NetBox est un *miroir* de ce fichier, pas l'inverse :
toute modification d'IP ou de réseau passe d'abord par un commit sur
`addressing.yml`, validé en CI, puis poussé vers NetBox via Ansible.

```text
┌──────────────────────────────┐
│  networking/addressing.yml   │  ← source de vérité (Git)
│  (sites, networks, hosts)    │
└──────────────┬───────────────┘
               │
               │ git push
               ▼
┌──────────────────────────────┐
│  CI : netbox-validate.yml    │  ← schéma + CIDR + mock seed
│  (.github/workflows/)        │
└──────────────┬───────────────┘
               │
               │ ansible-playbook --tags netbox-sync
               ▼
┌──────────────────────────────┐
│  Ansible role netbox/        │
│  seed_netbox.py (idempotent) │
└──────────────┬───────────────┘
               │
               │ POST /api/dcim/sites/  (get-or-create)
               │ POST /api/ipam/prefixes/
               │ POST /api/ipam/ip-addresses/
               ▼
┌──────────────────────────────┐
│  NetBox 4.x (Caddy + Docker) │
│  https://netbox.s1.lan       │
└──────────────────────────────┘
```

**Bénéfice** : pas de divergence drift entre la doc, le code Ansible/Terraform
qui consomme NetBox via lookup, et l'UI NetBox affichée au jury.

## 2. Topologie technique

| Composant | Rôle | Code |
|---|---|---|
| `networking/addressing.yml` | Source de vérité Git (sites + networks + hosts) | `networking/` |
| `scripts/netbox/validate-addressing.py` | Validateur de schéma + CIDR (CI + Ansible) | `scripts/netbox/` |
| `.github/workflows/netbox-validate.yml` | CI déclenchée sur changement de l'IPAM | `.github/workflows/` |
| `ansible/roles/netbox/files/seed_netbox.py` | Client API NetBox idempotent (get-or-create) | `ansible/roles/netbox/files/` |
| `ansible/roles/netbox/tasks/seed.yml` | Orchestre validate + seed via Ansible | `ansible/roles/netbox/tasks/` |
| `ansible/roles/netbox/tasks/install.yml` | Installation Docker + NetBox + Caddy | `ansible/roles/netbox/tasks/` |
| `ansible/roles/netbox/defaults/main.yml` | Variables par défaut (toggles, URL, token) | `ansible/roles/netbox/defaults/` |

## 3. Procédure standard — Ajouter un host à NetBox

1. Édite `networking/addressing.yml` :

   ```yaml
   siteA:
     hosts:
       # nouveau host : observability-s1
       observability-s1:
         ip: 10.10.0.40
         description: >
           VM d'observabilité Site A : héberge Elasticsearch single-node,
           Kibana et Logstash. Reçoit les logs Filebeat des autres VMs.
   ```

2. Commit + push :

   ```bash
   git add networking/addressing.yml
   git commit -m "feat(ipam): add observability-s1 to Site A"
   git push origin main
   ```

3. **La CI valide automatiquement** :
   - schéma OK (clés requises présentes)
   - CIDR valide
   - IP dans une range existante du site
   - pas d'overlap avec un autre prefix
   - seed dry-run contre un mock NetBox

4. **Si la CI est verte, applique vers le vrai NetBox** :

   ```bash
   ansible-playbook -i ansible/inventories/siteA.ini \
       ansible/playbooks/siteA.yml --tags netbox-sync
   ```

   Le tag `netbox-sync` exécute uniquement la phase seed (sans réinstaller
   Docker ni NetBox). Durée typique : 5 secondes pour ~10 hosts.

5. **Vérifie dans NetBox UI** : `https://netbox.s1.lan/ipam/ip-addresses/`
   doit afficher la nouvelle IP avec sa description.

## 4. Procédure standard — Ajouter un réseau

Pareil que §3, dans la section `networks:` du site :

```yaml
siteA:
  networks:
    monitoring:
      cidr: 10.10.20.0/24
      description: >
        VLAN dédié à la supervision (Prometheus, Zabbix, etc.).
        Isolé par règle pfSense — pas de sortie WAN.
```

→ commit → push → CI verte → `--tags netbox-sync` → vérif UI NetBox prefix.

## 5. Procédure d'urgence — Forcer une re-sync complète

Cas : NetBox a été restauré depuis un backup ancien, les données dérivent.

```bash
# 1. Vérifier que addressing.yml est OK localement (avant Ansible)
python3 scripts/netbox/validate-addressing.py

# 2. Re-sync forcée (idempotente — get-or-create)
ansible-playbook -i ansible/inventories/siteA.ini \
    ansible/playbooks/siteA.yml \
    --tags netbox-sync \
    --extra-vars "netbox_admin_token=$(vault kv get -field=token kv/cia/netbox/admin-token)"

# 3. Vérifier le compte de ressources
curl -s -H "Authorization: Token $TOKEN" \
    https://netbox.s1.lan/api/dcim/sites/?limit=100 | jq '.count'
# attendu : ≥ 2 (siteA + siteB)
```

## 6. Validation locale (avant de pousser)

Toujours faire tourner le validateur en local avant le push :

```bash
python3 scripts/netbox/validate-addressing.py
# →  ✓ 2 sites · 6 networks · 8 hosts
# →  OK
```

Si une erreur apparaît (schéma, CIDR invalide, overlap), corrige avant le
push pour éviter une CI rouge.

## 7. Debugging

### Le script seed échoue avec `KeyError: 'NETBOX_URL'`

Token ou URL absent de l'environnement. En CI, viens du workflow ; en
local, source les variables :

```bash
export NETBOX_URL=https://netbox.s1.lan
export NETBOX_TOKEN=$(vault kv get -field=token kv/cia/netbox/admin-token)
```

### Le script retourne 401 Unauthorized

Le token est expiré ou révoqué. Régénère via NetBox UI →
**Admin → Users → admin → API tokens**. Pousse le nouveau dans Vault :

```bash
vault kv put kv/cia/netbox/admin-token token=<NEW_TOKEN>
```

### Le script retourne 400 Bad Request

Champ obligatoire manquant côté NetBox (changement breaking dans une
version récente). Vérifie le schema réel via :

```bash
curl -s https://netbox.s1.lan/api/dcim/sites/ \
    -H "Authorization: Token $TOKEN" -X OPTIONS | jq .actions.POST
```

Mets à jour `seed_netbox.py` en conséquence.

### Le validateur dit "overlap between..."

Deux prefixes définis dans `addressing.yml` se chevauchent. Cas le plus
fréquent : oublié de mettre le tunnel VPN partagé sur les deux sites,
ou un sous-réseau qui mange un autre. Revois `addressing.yml`.

## 8. Évolutions prévues (post-keynote)

| Évolution | Impact | Effort |
|---|---|---|
| Webhook NetBox → Slack sur change | Notification équipe | 30 min |
| Reverse sync (NetBox → addressing.yml) | Garantir cohérence en cas d'edit UI | 2 h |
| GitHub Actions push direct NetBox (sans Ansible) | Réduction latence drift | 1 h |
| Custom fields pour traçabilité git commit | Audit forensique | 30 min |

## 9. Références

- [`networking/addressing.yml`](../../networking/addressing.yml) — la source
- [`docs/runbooks/netbox.md`](netbox.md) — runbook principal NetBox (déploiement,
  backup, restore, upgrade)
- [`ansible/roles/netbox/`](../../ansible/roles/netbox/) — rôle Ansible
- [`scripts/netbox/`](../../scripts/netbox/) — outils CLI

---

*GR46 — CIA Epitech 2025-2026 — Runbook vivant, mis à jour à chaque changement
notable du pattern auto-sync.*
