# Conformité aux 29 + 4 critères d'évaluation — CIA

Projet : **Hybrid Infrastructure — Proxmox / pfSense / OpenVPN / NetBox / Elastic / Vault**
Groupe : **GR46** · École : Epitech · Année : 2025-2026

Chaque critère est rattaché à une **preuve vérifiable dans le dépôt**
(fichier, tâche Ansible, ressource Terraform, diagramme, runbook ou workflow
CI). Les critères bonus sont traités comme obligatoires.

> **Lecture du document — important.**
> Ce fichier prouve que le **code, la configuration, les diagrammes et la
> documentation existent et sont auditables**. L'**état de déploiement
> live** (ce qui tourne effectivement sur Proxmox au jour J, prêt pour la
> démo jury) est suivi séparément dans
> [`docs/STATUS.md`](docs/STATUS.md), mis à jour à chaque jalon
> (FW1 / FW2 / FW3 / Final). Pour chaque critère, deux dimensions :
>
> - 📝 **Code livré** : présent, lintable, versionné, testé en CI ;
> - 🚀 **Déployé live** : effectivement provisionné/exécuté sur l'infra
>   cible et démontrable en moins de 5 minutes devant le jury.
>
> Les deux dimensions ne progressent pas au même rythme : tout le code
> peut être prêt avant qu'une seule machine ne soit allumée. Cette
> distinction est explicite dans la synthèse en bas de page.

Légende des statuts unitaires :
`✅` = implémenté et prouvé (code livré + lintable) · `🟡` = en place,
à jouer en démo · `🔵` = bonus.

---

## 1. Infrastructure

### ✅ `infra_delivery` — Infrastructure hybride livrée et fonctionnelle
- Provisioning : `terraform/siteA/` + `terraform/siteB/` (3 VMs/site)
- Configuration : `ansible/playbooks/siteA.yml`, `ansible/playbooks/siteB.yml`
- Preuves config : `configs/pfsense/siteA-config.xml`, `configs/pfsense/siteB-config.xml`
- Diagramme : `docs/architecture/infra.drawio` + fallback Mermaid

### ✅ `infra_spec` — Services requis présents et fonctionnels
Services : pfSense, OpenVPN, Bastion, NetBox, Elastic (ES+Kibana+Logstash),
DNS forwarder (unbound), webapp interne, filebeat, Caddy, Vault.
- Rôles Ansible : `ansible/roles/{common,pfsense,openvpn,netbox,elasticsearch,kibana,logstash,bastion,dns-forwarder,webapp,filebeat}`
- Runbooks correspondants : `docs/runbooks/*.md`

### ✅ `infra_scalability` — Ajout facile d'un site
- Modules TF réutilisables : `terraform/modules/{proxmox-vm,network}`
- Golden path : `docs/onboarding-new-site.md`
- Variables centralisées : `ansible/group_vars/all.yml` + `siteX.yml`

### ✅ `infra_choices` — Stack maintenue / supportée
Justifications détaillées (ADR condensés) : `docs/tech-choices.md`
— 14 décisions avec contexte, alternatives écartées, trade-offs.

---

## 2. Diagrammes

### ✅ `diagram_delivery` — Diagramme présenté au FU1
- `docs/architecture/infra.drawio` + capture dans `docs/backlog/followup1.md`

### ✅ `diagram_quality` — 2 sites, réseaux, VPN, bastion, DNS, IPAM, obs
- Infra : `docs/architecture/infra.drawio`
- VPN : `docs/architecture/vpn.drawio`
- Règles firewall : `docs/architecture/firewall-rules.drawio`
- Fallback Mermaid : `docs/architecture/README.md`

---

## 3. Infrastructure-as-Code

### ✅ `iac_delivery` — Infrastructure déployable par scripts
- TF : `terraform/siteA/`, `terraform/siteB/`, modules partagés
- Ansible : `ansible/playbooks/site.yml` (master) + per-site playbooks
- Bootstrap : section "Démarrage rapide" du `README.md`

### ✅ `iac_quality` — Scripts maintenables, modulaires, versionnés
- Modules TF paramétrés (`variables.tf`, `outputs.tf`, `versions.tf`)
- Rôles Ansible avec `defaults/`, `handlers/`, `templates/`, `meta/`
- Lint en CI : `ansible-lint`, `tflint`, `terraform validate`
- Conventions : `CONTRIBUTING.md`

### ✅ `iac_automation` — Déploiement reproductible sans intervention manuelle
- Idempotence : `terraform plan` → "No changes" après apply
- Ansible check mode validé en CI
- Secrets injectés via SOPS + Vault — pas de saisie interactive

---

## 4. Réseau

### ✅ `network_segmentation` — VLAN / sous-réseaux séparés par usage
- Plan : `networking/addressing.yml` (LAN, ADMIN, SERVICES séparés)
- Règles pfSense : `LAN → ADMIN` bloqué explicitement
- Matrice auditable : `docs/access-matrix.md`

### ✅ `network_vpn` — Tunnel site-à-site opérationnel
- Config : `configs/openvpn/{server,client}.conf`
- Déploiement : `ansible/roles/openvpn/tasks/main.yml` (API pfSense)
- Preuve audit : AES-256-GCM + SHA256 + TLS 1.2+
- Runbook : `docs/runbooks/vpn.md`

### ✅ `network_firewall` — Règles documentées et restrictives
- pfSense XML committé : `configs/pfsense/site{A,B}-config.xml`
- Défaut : `block` sur toutes interfaces, passes explicites commentés
- Règles par rôle : `ansible/roles/pfsense/defaults/main.yml`
- Diagramme : `docs/architecture/firewall-rules.drawio`

### ✅ `network_ipam` — NetBox en source de vérité, alimenté automatiquement
- Déploiement : `ansible/roles/netbox/` (Docker compose + Caddy)
- Seed idempotent : `ansible/roles/netbox/files/seed_netbox.py`
- Lecture depuis `networking/addressing.yml`
- Runbook : `docs/runbooks/netbox.md`

### ✅ `network_dns` — Forwarding inter-sites
- unbound : `ansible/roles/dns-forwarder/` (forward-zone conditionnelle)
- Référence : `configs/dns/named.conf`
- Zones : `s1.lan` (Site A) ↔ `s2.lan` (Site B)

### ✅ `network_webapp` — Webapp interne accessible sur LAN uniquement
- Rôle : `ansible/roles/webapp/` (nginx + `allow/deny` LAN-only)
- Healthcheck `/healthz`, logs filebeat, CSP strict
- Déploiement via `playbooks/siteA.yml`

---

## 5. Sécurité

### ✅ `sec_bastion` — Bastion SSH exposé, porte unique
- Rôle : `ansible/roles/bastion/`
- PAM MFA TOTP (Google Authenticator)
- fail2ban agressif, rsyslog forward vers Logstash
- Exposition : pfSense NAT WAN:2222 → 192.168.10.10:22
- Runbook : `docs/runbooks/bastion.md`

### ✅ `sec_hardening` — Durcissement SSH, services, OS
- sshd hardened : `ansible/roles/common/templates/sshd_config.j2`
- auditd rules custom, unattended-upgrades, timesyncd
- fail2ban sur tous les hôtes
- Policy TLS OpenVPN : TLS 1.2+, ECDHE-RSA-AES-256-GCM

### ✅ `sec_secrets` — Secrets chiffrés, jamais en clair
- SOPS + age : `.sops.yaml` + fichiers `*.sops.yml`
- Vault : `vault/policies/*.hcl`, `vault/scripts/init-vault.sh`
- Pre-commit gitleaks + CI `gitleaks` + `trufflehog`
- Runbook : `docs/runbooks/secrets.md`

### ✅ `sec_killswitch` — Killswitch opérationnel
- Alias pfSense `KILLSWITCH_ACTIVE` (floating rule block out WAN)
- Playbook : `ansible/playbooks/killswitch.yml` (paramètre `site` + `state`)
- Runbook : `docs/runbooks/killswitch.md`

### ✅ `sec_audit` — Audit logs & traces
- auditd : `ansible/roles/common/tasks/main.yml`
- rsyslog forward : bastion + pfSense → Logstash (`5514`)
- Indices Kibana : `cia-ssh-*`, `cia-pfsense-*`, `cia-netbox-*`

---

## 6. Incident response

### ✅ `incident_drp` — Plan de reprise d'activité
- `docs/drp/drp.md` : 5 scénarios, RTO/RPO par asset
- Sauvegardes listées (NetBox pg_dump, pfSense XML, TF state, Vault raft)

### 🟡 `incident_exercise` — DRP testé
- Exercices programmés : `docs/drp/drp.md §4` (4 exercices semestriels)
- Playbook `chaos-drill.yml` planifié (FW3), preuves vidéo à joindre

### ✅ `incident_runbooks` — Runbooks d'intervention
- 7 runbooks : vpn, pfsense, bastion, elasticsearch, killswitch, netbox, secrets
- Format uniforme : propriétaire, criticité, checks, procédures, escalade

---

## 7. Logs & observabilité

### ✅ `log_centralisation` — Logs centralisés
- Elasticsearch 8 : `ansible/roles/elasticsearch/`
- Logstash pipelines : `ansible/roles/logstash/files/pipelines/*.conf`
- Filebeat déployé partout : `ansible/roles/filebeat/`

### ✅ `log_observability` — Dashboards + retention
- Kibana : `ansible/roles/kibana/`
- ILM policy `cia-30d` (rétention 30 jours)
- Dashboards versionnés sous `docs/dashboards/` (exportés saved_objects)

---

## 8. Dépôt & qualité

### ✅ `repo_structure` — Dépôt structuré et lisible
- Voir arborescence dans `README.md`
- `.gitignore`, `.editorconfig`, `.pre-commit-config.yaml`, `.yamllint.yml`,
  `.markdownlint.yml`, `.sops.yaml`, `.gitleaks.toml`
- Templates : `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/task.md`

### ✅ `repo_readme` — README complet et professionnel
- `README.md` avec badges CI, quickstart, opérations, liens doc

### ✅ `repo_ci` — CI active
- Workflows : `terraform.yml`, `ansible.yml`, `quality.yml`, `security-scan.yml`
- Badges visibles en haut du README

### ✅ `repo_changelog` — Historique clair
- Conventional Commits (voir `CONTRIBUTING.md`)
- Release notes conçues à partir des commits

---

## 9. Projet & suivi

### ✅ `proj_gantt` — Gantt projet
- `docs/gantt/CIA_Gantt_GR46-2.pptx` + `docs/gantt/gantt.png`
- 7 phases couvrant février → juillet 2026, jalons FW1/FW2/FW3/Final

### ✅ `proj_backlog` — Backlogs par follow-up
- `docs/backlog/followup1.md` (actés FW1)
- `docs/backlog/followup2.md` (livrables FW2)
- `docs/backlog/followup3.md` (livrables FW3)

### ✅ `proj_keynote` — Keynote finale scriptée
- `docs/backlog/keynote.md` : 20 min time-codées + répartition

---

## Bonus (traités comme obligatoires)

### 🔵 `bonus_cicd` — CI/CD avancée
- `security-scan.yml` : gitleaks + trufflehog + checkov + tfsec + shellcheck
- `quality.yml` : pre-commit + markdownlint
- Badges CI dans README

### 🔵 `bonus_golden_path` — Golden paths fournis
- `docs/onboarding-new-site.md` : recette reproductible Site C
- Opérations quotidiennes : liens directs runbooks dans README

### 🔵 `bonus_advanced_monitoring` — Monitoring avancé
- Pipelines Logstash spécialisés (pfSense filterlog, SSH auth, OpenVPN,
  NetBox audit)
- Index par dataset (`cia-<module>-*`) + ILM `cia-30d`
- Alerting Kibana + webhook Slack prévu FW3 (`followup3.md §3`)

### 🔵 `bonus_multisite` — Multi-site ready
- Variables Ansible `site_id`, `vpn_role`, `vpn_peers` paramétrables
- Modules TF site-agnostic (`terraform/modules/proxmox-vm`,
  `terraform/modules/network`, `terraform/modules/netbox-records`)
- PKI Vault extensible (`pki_cia_vpn/roles/openvpn-client-siteC` au besoin)
- Procédure documentée : [`docs/onboarding-new-site.md`](docs/onboarding-new-site.md)

---

## Synthèse

Tableau à double lecture : `📝 Code livré` mesure ce qui est dans le
dépôt (lintable, testé en CI), `🚀 Déployé live` mesure ce qui tourne
effectivement sur l'infra cible et est démontrable au jury.

| Catégorie         | Critères | 📝 Code livré              | 🚀 Déployé live (au 2026-04-25) |
|-------------------|----------|----------------------------|---------------------------------|
| Infrastructure    | 4/4      | ✅ 100%                    | 🟡 1/4 (bridges Site B)        |
| Diagrammes        | 2/2      | ✅ 100%                    | ✅ 100% (sources versionnées)  |
| IaC               | 3/3      | ✅ 100%                    | 🟡 partiel (apply Site B en cours) |
| Réseau            | 6/6      | ✅ 100%                    | ❌ 0/6 (post-déploiement VMs)   |
| Sécurité          | 5/5      | ✅ 100%                    | ❌ 0/5 (post-bastion + VPN)     |
| Incident          | 3/3      | 🟡 2✅ + DRP exercice live | ❌ 0/3 (FW3)                    |
| Logs              | 2/2      | ✅ 100%                    | ❌ 0/2 (post-Elastic Site A)    |
| Dépôt             | 4/4      | ✅ 100%                    | ✅ 100% (CI verte)              |
| Projet            | 3/3      | ✅ 100%                    | ✅ 100% (Gantt à jour)          |
| **Total**         | **32/33**| **31✅ + 1🟡 (94%)**       | **🟡 ≈ 30% (FW2 en cours)**     |
| Bonus             | 4/4      | 🔵 100%                    | 🟡 partiel (CI 100%, monitoring FW3) |

Lecture rapide :

- **📝 Code livré 94%** : tout le code, les configs, les diagrammes, les
  runbooks et la doc sont écrits, lintés, et passent en CI. Restent
  uniquement des `🟡` qui ne se résolvent qu'en jouant en live (DRP).
- **🚀 Déployé live ≈ 30%** : on est en milieu de FW2. Le pipeline IaC
  est validé (Terraform a déployé les bridges du Site B et cloné les 3
  VMs). Le boot des VMs Site B est bloqué par la nested virt VMware
  (workaround en cours). Site A (physique Epitech) sera démarré au début
  de FW3.

État détaillé par phase, blocages connus et prochaines étapes :
[`docs/STATUS.md`](docs/STATUS.md).

Reste à jouer en démo (indépendant du code) : `incident_exercise`
(scénario DRP #1 tourné live devant le jury pendant FW3 et Final).

---

*GR46 — CIA Epitech 2025-2026 — Dernière maj : 2026-04-25.*
