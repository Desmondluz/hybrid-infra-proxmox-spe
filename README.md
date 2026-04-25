# Hybrid Proxmox Infrastructure — CIA (GR46)

![Terraform](https://img.shields.io/badge/IaC-Terraform%201.7-623CE4)
![Ansible](https://img.shields.io/badge/Automation-Ansible%202.16-EE0000)
![Proxmox](https://img.shields.io/badge/Platform-Proxmox%208-000000)
![OpenVPN](https://img.shields.io/badge/VPN-OpenVPN%20AES--256--GCM-F47B20)
![pfSense](https://img.shields.io/badge/Firewall-pfSense-212121)
![Elastic](https://img.shields.io/badge/Observability-Elastic%208-005571)
![License](https://img.shields.io/badge/license-MIT-green)

![terraform](https://github.com/Desmondluz/hybrid-infra-proxmox-spe/actions/workflows/terraform.yml/badge.svg)
![ansible](https://github.com/Desmondluz/hybrid-infra-proxmox-spe/actions/workflows/ansible.yml/badge.svg)
![quality](https://github.com/Desmondluz/hybrid-infra-proxmox-spe/actions/workflows/quality.yml/badge.svg)
![security-scan](https://github.com/Desmondluz/hybrid-infra-proxmox-spe/actions/workflows/security-scan.yml/badge.svg)

> **Projet Epitech T-NSA-810-REP25 — CIA · Deployment and Securing of a
> Hybrid Infrastructure with Proxmox.** Infrastructure hybride à deux sites
> Proxmox, reliés par un tunnel OpenVPN, entièrement déployée en Infrastructure
> as Code (Terraform + Ansible) et audit-friendly : segmentation, bastion,
> NetBox comme source de vérité IPAM, stack Elastic pour la centralisation
> des logs, killswitch déclenché à la demande, DRP testable, secrets gérés
> via SOPS + Vault.

---

## Sommaire

1. [Architecture](#architecture)
2. [Arborescence du dépôt](#arborescence-du-dépôt)
3. [Pré-requis](#pré-requis)
4. [Démarrage rapide](#démarrage-rapide)
5. [Cycle de déploiement](#cycle-de-déploiement)
6. [Opérations courantes](#opérations-courantes)
7. [Sécurité & secrets](#sécurité--secrets)
8. [Observabilité](#observabilité)
9. [Tests & qualité](#tests--qualité)
10. [Contribuer](#contribuer)
11. [Documentation détaillée](#documentation-détaillée)

---

## Architecture

Deux sites indépendants, reliés par un tunnel OpenVPN site-à-site
(`172.16.0.0/30`, UDP/1194, AES-256-GCM + SHA256 + tls-crypt) :

- **Site A (on-premise)** — 10.10.0.0/24 (LAN) + 10.10.10.0/24 (ADMIN)
  - `pfsense-s1` · firewall + OpenVPN server
  - `services-s1` · NetBox (IPAM) + webapp interne derrière Caddy TLS
  - `observability-s1` · Elasticsearch + Kibana + Logstash
- **Site B (remote)** — 192.168.0.0/24 (LAN) + 192.168.10.0/24 (SERVICES)
  - `pfsense-s2` · firewall + OpenVPN client
  - `bastion-s2` · point d'entrée SSH unique (MFA TOTP, fail2ban, audit)
  - `services-s2` · forwarder DNS, filebeat, services locaux

Contrainte sujet respectée : 3 VMs max par site.

Schémas : [`docs/architecture/README.md`](docs/architecture/README.md)
(fallbacks Mermaid rendus directement par GitHub + sources `.drawio`).

## Arborescence du dépôt

```
.
├── terraform/          # modules réutilisables + stacks siteA / siteB
│   ├── modules/
│   │   ├── proxmox-vm/
│   │   └── network/
│   ├── siteA/
│   └── siteB/
├── ansible/            # rôles, playbooks, inventaires, group_vars
│   ├── roles/          # common, openvpn, pfsense, netbox, elasticsearch,
│   │                   # kibana, logstash, bastion, dns-forwarder, webapp,
│   │                   # filebeat
│   ├── playbooks/      # siteA, siteB, vpn, bastion, elastic, killswitch, site
│   ├── inventories/
│   └── group_vars/
├── configs/            # références auditables (pfSense XML, openvpn, dns, es)
├── vault/              # scripts init + policies HCL (Vault + SOPS)
├── networking/         # addressing.yml · vpn-topology.yml (source de vérité)
├── docs/               # runbooks, architecture, DRP, backlog, onboarding
├── .github/            # workflows + templates PR/Issue
├── CONTRIBUTING.md
├── CRITERES.md         # état des 29 + 4 critères d'évaluation
├── LICENSE
└── README.md
```

## Pré-requis

Outils locaux (versions testées) :

- Terraform `1.7.5`
- Ansible `2.16.x` + collections (`ansible-galaxy install -r ansible/requirements.yml`)
- Python `3.11`
- `sops` `3.9` + `age` `1.1`
- `vault` `1.15` (si bootstrap secrets)
- `pre-commit` `3.7` (`pre-commit install`)

Accès requis :

- API Proxmox (token) pour chaque cluster (token stocké dans Vault).
- Clef publique SSH admin (injectée par cloud-init dans les VM).
- Clef age pour SOPS (`age-keygen`, publique ajoutée à `.sops.yaml`).

## Démarrage rapide

```bash
# 1. Cloner
git clone git@github.com:Desmondluz/hybrid-infra-proxmox-spe.git
cd hybrid-infra-proxmox-spe

# 2. Hooks qualité
pre-commit install

# 3. Variables Terraform (exemple)
cp terraform/siteA/terraform.tfvars.example terraform/siteA/terraform.tfvars
sops terraform/siteA/terraform.tfvars   # chiffré via .sops.yaml

# 4. Provisionner Site A
cd terraform/siteA
terraform init
terraform apply

# 5. Configurer Site A
cd ../../ansible
ansible-playbook -i inventories/siteA.ini playbooks/siteA.yml

# 6. Idem Site B + tunnel VPN
cd ../terraform/siteB && terraform apply
cd ../../ansible
ansible-playbook -i inventories/siteB.ini playbooks/siteB.yml
ansible-playbook playbooks/vpn.yml
```

Temps visé du bootstrap end-to-end : **< 2 h** (cf. `docs/backlog/followup3.md`).

## Cycle de déploiement

```
feature/xxx  →  PR  →  CI (terraform · ansible · quality · security-scan)
                  →  review + approbation
                  →  merge develop
                  →  deploy staging
                  →  merge main
                  →  deploy prod (manuel)
```

Conventions dans [`CONTRIBUTING.md`](CONTRIBUTING.md) : Conventional Commits,
branches courtes, PR template obligatoire.

## Opérations courantes

- **Activer / désactiver le killswitch** : `ansible-playbook playbooks/killswitch.yml -e killswitch_state=active -e site=siteA` — [`runbook`](docs/runbooks/killswitch.md)
- **Rotation cert OpenVPN** : `./vault/scripts/generate-certs.sh` puis `ansible-playbook playbooks/vpn.yml --tags pki` — [`runbook`](docs/runbooks/vpn.md)
- **Restauration pfSense** : `git show <commit>:configs/pfsense/siteA-config.xml` — [`runbook`](docs/runbooks/pfsense.md)
- **Seed NetBox** : `python3 ansible/roles/netbox/files/seed_netbox.py networking/addressing.yml`
- **Onboarding d'un nouveau site** : [`docs/onboarding-new-site.md`](docs/onboarding-new-site.md)

Runbooks couvrant la bonne marche quotidienne :
[vpn](docs/runbooks/vpn.md) · [pfsense](docs/runbooks/pfsense.md) ·
[bastion](docs/runbooks/bastion.md) · [elasticsearch](docs/runbooks/elasticsearch.md) ·
[killswitch](docs/runbooks/killswitch.md) · [netbox](docs/runbooks/netbox.md) ·
[secrets](docs/runbooks/secrets.md).

## Sécurité & secrets

- SSH : clef + MFA TOTP sur le bastion Site B, pas de password auth.
- Firewall : default `block`, règles explicites et commentées ; segmentation
  `LAN` → `ADMIN` interdite. Matrice : [`docs/access-matrix.md`](docs/access-matrix.md).
- OpenVPN : TLS 1.2+, AES-256-GCM, tls-crypt, PKI via Vault.
- Secrets statiques : SOPS + age (`.sops.yaml`). Dynamiques : Vault (KV-v2
  + PKI). Procédure de rotation : [`docs/runbooks/secrets.md`](docs/runbooks/secrets.md).
- `.gitleaks.toml` + pre-commit `gitleaks` bloquent les fuites avant push.

## Observabilité

Stack Elastic (single-node, ILM `cia-30d`) sur `observability-s1`. Filebeat
expédie depuis toutes les VM Linux vers Logstash (port 5044). pfSense envoie
en syslog UDP/5514. Pipelines pré-configurés :

- `cia-pfsense-*` (filterlog parsé)
- `cia-ssh-*` (succès/échecs SSH)
- `cia-openvpn-*` (handshakes, reneg, down)
- `cia-netbox-*` (audit NetBox)

Dashboards Kibana versionnés sous `docs/dashboards/` (snapshots
`saved_objects`).

## Tests & qualité

Tous les PR passent :

- `terraform fmt -check`, `terraform validate`, `tflint`, `terraform plan` à sec.
- `ansible-lint` + `yamllint` + `ansible-playbook --syntax-check` sur tous les sites.
- `pre-commit run --all-files` (fmt, markdownlint, shellcheck, gitleaks).
- `gitleaks`, `trufflehog`, `checkov`, `tfsec` (SARIF remonté dans l'onglet
  *Security* GitHub).

Voir `.github/workflows/` pour le détail.

## Contribuer

Toute contribution passe par une PR. Rappels :

- Une PR = une préoccupation.
- Commits Conventional Commits (`feat:`, `fix:`, `docs:`, `ops:`, `ci:`).
- PR template rempli (motivation, preuves, runbook impacté).
- Vert sur tous les workflows CI.
- Reviewer obligatoire.

Détails : [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Documentation détaillée

- **Architecture** : [`docs/architecture/`](docs/architecture/)
- **Runbooks** : [`docs/runbooks/`](docs/runbooks/)
- **Plan de reprise d'activité** : [`docs/drp/drp.md`](docs/drp/drp.md)
- **Matrice d'accès** : [`docs/access-matrix.md`](docs/access-matrix.md)
- **Choix techniques (ADR)** : [`docs/tech-choices.md`](docs/tech-choices.md)
- **Onboarding nouveau site** : [`docs/onboarding-new-site.md`](docs/onboarding-new-site.md)
- **Backlogs follow-ups** : [`docs/backlog/`](docs/backlog/)
- **Gantt + keynote** : [`docs/gantt/`](docs/gantt/) · [`docs/backlog/keynote.md`](docs/backlog/keynote.md)
- **État des 29 + 4 critères** : [`CRITERES.md`](CRITERES.md)

---

*Projet GR46 — Epitech 2025-2026 — MIT License.*
