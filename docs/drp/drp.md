# Plan de Reprise d'Activité (DRP) — CIA

**Propriétaire** : GR46 · **Version** : 1.0 · **Dernière revue** : 2026-04-18

Ce document décrit les scénarios de sinistre retenus, les procédures de
reprise associées, les RTO/RPO visés et les responsabilités.

## 1. Portée

| Élément protégé                       | Criticité | RTO    | RPO    |
|---------------------------------------|-----------|--------|--------|
| Tunnel VPN site-à-site                | S1        | 15 min | 0      |
| Firewall pfSense (A ou B)             | S1        | 30 min | 0      |
| NetBox (IPAM)                         | S2        | 2 h    | 24 h   |
| Stack Elastic (logs)                  | S2        | 4 h    | 15 min |
| Bastion SSH Site B                    | S1        | 30 min | 0      |
| Vault (secrets)                       | S1        | 1 h    | 1 h    |

## 2. Équipe & rôles

- **DRP coordinator** : lead tech GR46 (on-call rotatif).
- **Security lead** : valide l'ouverture de tout killswitch.
- **Infra lead** : restaure Proxmox/VM.
- **Communication** : annonce sur #ops Slack + email stakeholders.

## 3. Scénarios

### Scénario #1 — Perte d'une VM (Proxmox intact)

**Probabilité** : élevée · **Exemple** : disque corrompu `services-s1`.

1. Vérifier Proxmox healthy :

   ```bash
   ssh root@proxmox-s1 "qm list; pvesm status"
   ```

2. Détruire la VM corrompue :

   ```bash
   cd terraform/siteA && terraform destroy -target=module.services_s1
   ```

3. Recréer :

   ```bash
   terraform apply -target=module.services_s1
   ```

4. Reconfigurer avec Ansible :

   ```bash
   cd ../../ansible
   ansible-playbook -i inventories/siteA.ini playbooks/siteA.yml --limit services-s1
   ```

5. Restaurer NetBox DB si besoin (runbook `netbox.md` §5).

**RTO visé** : 30 min après détection.

### Scénario #2 — Perte totale d'un site (A ou B)

**Probabilité** : faible · **Exemple** : incendie DC.

1. Si Site A perdu : Site B continue d'autonome (LAN, bastion, services B).
   Les logs s'accumulent localement sur `services-s2`.
2. Commander/provisionner nouveau cluster Proxmox Site A.
3. `./scripts/bootstrap-new-site.sh siteA` (voir `docs/onboarding-new-site.md`).
4. Rétablir DNS public vers la nouvelle IP WAN Site A.
5. Renouveler certs OpenVPN (CN reste `cia-vpn-server-siteA`).
6. Relancer tunnel (runbook `vpn.md` §4.1).

**RTO visé** : 4 h (si matériel disponible).

### Scénario #3 — Compromis détecté (killswitch)

**Probabilité** : moyenne · **Exemple** : brute-force SSH ou anomalie log.

1. Déclencher killswitch sur le site concerné (runbook `killswitch.md`).
2. Geler les snapshots Proxmox en cours :

   ```bash
   ssh root@proxmox-s1 "for id in 100 101 102; do qm snapshot $id forensic-$(date +%F-%H%M); done"
   ```

3. Rotation IMMÉDIATE des secrets exposés :
   - clefs SSH admin (génération via §DRP secrets)
   - tokens Vault opérateurs
   - cert OpenVPN (régénère via `vault/scripts/generate-certs.sh`)
4. Forensic : export logs bruts Elasticsearch fenêtre [-24h, now] :

   ```bash
   curl -u elastic:${ES_PW} "http://localhost:9200/cia-*/_search?size=10000&q=..." \
     > docs/forensic/snapshot-$(date +%F).ndjson
   ```

5. Rapport sous 48 h.

**RTO visé** : 1 h isolation ; 24 h reprise contrôlée.

### Scénario #4 — Corruption config pfSense

**Probabilité** : moyenne · **Exemple** : mauvaise règle appliquée, pfctl KO.

Voir runbook `pfsense.md` §6 (restauration depuis git).

**RTO visé** : 10 min.

### Scénario #5 — Perte Vault (unseal keys OU données)

**Probabilité** : faible · **Exemple** : VM Vault corrompue, unseal keys
perdues.

Deux branches :

- **Unseal keys retrouvées** : restore backup snapshot Proxmox +
  `vault operator unseal` (3/5 keys).
- **Unseal keys perdues** : rebuild vault from scratch (voir
  `runbooks/secrets.md §8`).
  1. `./vault/scripts/init-vault.sh` (nouveau vault).
  2. Réinjecter secrets depuis sources canoniques :
     - SOPS : `sops -d ansible/group_vars/all/secrets.sops.yml`
     - Certs publics (pas sensibles) → `configs/openvpn/pki/ca.crt`
     - Mots de passe → rotation forcée de tous les comptes.
  3. Re-run `ansible-playbook site.yml` pour pousser nouveaux tokens.

**RTO visé** : 4 h.

## 4. Tests & exercices

Semestriels, plan :

| # | Scénario                         | Date cible  | Portée   |
|---|----------------------------------|-------------|----------|
| 1 | Perte VM services-s1             | 2026-06-15  | Site A   |
| 2 | Killswitch Site B                | 2026-07-01  | Site B   |
| 3 | Restore pfSense config depuis git| 2026-09-15  | Site A   |
| 4 | Rotation cert OpenVPN            | 2026-11-01  | Les deux |

Chaque exercice génère un compte-rendu commité sous `docs/drp/reports/`.

## 5. Sauvegardes

| Artefact                       | Localisation                     | Rétention |
|--------------------------------|----------------------------------|-----------|
| NetBox pg_dump                 | `/var/backups/netbox/` + offsite | 30 j      |
| pfSense XML                    | git `configs/pfsense/`           | illimité  |
| Terraform state                | Backend distant chiffré          | illimité  |
| Secrets SOPS                   | git (chiffré)                    | illimité  |
| Vault raft snapshots           | `/var/backups/vault/` + offsite  | 30 j      |
| Elasticsearch snapshots        | S3 compat (à configurer v2)      | 30 j      |

## 6. Contacts

| Rôle              | Canal                          |
|-------------------|--------------------------------|
| DRP coordinator   | #ops + téléphone on-call       |
| Infra provider    | Proxmox support                |
| ISP               | N° commercial (cf. contrats)   |
| Stakeholders      | <stakeholders@cia.lan>           |

## 7. Journal de révision

| Date        | Auteur | Changement                              |
|-------------|--------|-----------------------------------------|
| 2026-04-18  | GR46   | Version initiale post follow-up #1      |
