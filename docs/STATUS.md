# État du déploiement — CIA / Hybrid Infra Proxmox

**Projet** : T-NSA-810-REP25 — Deployment and Securing of a Hybrid Infrastructure
**Groupe** : GR46 · **École** : Epitech · **Année** : 2025-2026
**Date de la photo** : 2026-04-26 · **Phase courante** : **FW2** (deuxième follow-up — clôturé côté GR46, validation jury à venir)
**Propriétaire du document** : GR46 · **Cadence de mise à jour** : à chaque jalon (FW1 / FW2 / FW3 / Final) et après chaque étape Terraform/Ansible significative

---

## Pourquoi ce document existe

Le `README.md` décrit l'architecture **cible** et le `CRITERES.md` recense les
**preuves auditables dans le dépôt** (code, configs, diagrammes, runbooks).
Aucun de ces deux documents ne dit *ce qui tourne réellement sur l'infra
aujourd'hui*. C'est ce que `STATUS.md` apporte : la photo runtime, mise à
jour à chaque étape, opposable au jury, sans gonfler ni minimiser.

Lecture conjointe :

- **CRITERES.md** → "le code et la doc sont prêts, vérifiables, et passent
  en CI" (📝 Code livré).
- **STATUS.md** → "voilà, à la minute, ce qui est déployé sur Proxmox,
  prêt pour la démo, et ce qui ne l'est pas encore" (🚀 Déployé live).

---

## Légende

- ✅ **Livré et démontrable** : tourne en runtime, démontrable en moins
  de 5 min devant le jury, output Terraform / sortie SSH / dashboard
  visible.
- 🟡 **En cours** : démarré mais pas finalisé (bloqué, en attente d'un
  pré-requis, ou mid-rollout).
- ⏳ **Planifié** : prochaine fenêtre de travail identifiée, non démarré.
- ❌ **Non démarré** : aucune action runtime, dépend d'un livrable amont.

Les éléments marqués 🟡 et ❌ référencent toujours la prochaine action
concrète et son owner.

---

## Synthèse exécutive (à lire en 30 secondes)

| Domaine | 📝 Code | 🚀 Live | Commentaire |
|---|---|---|---|
| Terraform IaC (modules + sites) | ✅ | ✅ | Modules + siteA/siteB écrits ; **Site B applied live**, plan idempotent, state propre |
| Ansible (rôles + playbooks) | ✅ | 🟡 | 11 rôles + 7 playbooks lintés + syntax-check CI vert ; apply réel reporté FW3 (volontaire — pas dans le scope FW2) |
| Configurations de référence (pfSense, OpenVPN, DNS, Elastic) | ✅ | 🟡 | Configurations versionnées et auditables ; pfSense-s2 cloné depuis vraie image, configs OpenVPN/DNS appliquées en FW3 |
| Site B (DEV nested VMware) | ✅ | ✅ | Proxmox up, bridges déployés, **3 VMs running**, pfsense-s2 cloné depuis VMID 9100 (vraie image pfSense) |
| Site A (Epitech physique) | ✅ | ❌ | Code prêt ; déploiement physique programmé FW3 |
| Tunnel OpenVPN site-à-site | ✅ | ❌ | Configs + role prêts ; nécessite les deux pfSense up |
| NetBox (IPAM) | ✅ | ❌ | Rôle + seed script prêts ; nécessite services-s1 |
| Stack Elastic (ES + Kibana + Logstash + Filebeat) | ✅ | ❌ | 4 rôles + pipelines prêts ; nécessite observability-s1 |
| Bastion SSH (MFA + audit) | ✅ | ❌ | Rôle + templates PAM/sshd prêts ; nécessite bastion-s2 booté |
| Killswitch | ✅ | ❌ | Playbook prêt ; nécessite pfSense up et règle floating provisionnée |
| Documentation (runbooks, ADR, DRP, onboarding) | ✅ | N/A | 7 runbooks + 14 ADR + DRP + onboarding-new-site complets |
| CI/CD GitHub Actions | ✅ | ✅ | 4 workflows (terraform, ansible, quality, security-scan) verts |

**TL;DR** : le **code et la doc sont à 94%** des critères d'évaluation, le
**runtime à environ 55%** post-FW2 (Site B entièrement provisionné, 3 VMs
running, secrets SOPS+age opérationnels, CI verte). Les blocages B1
(nested virt) et B4 (template pfSense absent) sont **résolus**. Le runtime
restant (Ansible apply, NetBox, Elastic, tunnel VPN, Site A physique) est
le scope explicite de FW3.

---

## Détail par domaine

### 1. Infrastructure-as-Code Terraform

| Élément | État | Détail |
|---|---|---|
| Module `proxmox-vm` | ✅ | `terraform/modules/proxmox-vm/` (main, variables, outputs, versions) |
| Module `network` | ✅ | `terraform/modules/network/` — provisionne les bridges Linux Proxmox |
| Module `netbox-records` | ✅ | `terraform/modules/netbox-records/` — préfixes/VLAN dans NetBox (activable via `netbox_enabled`) |
| Stack `terraform/siteA/` | ✅ code | `main.tf`, `vms.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, `netbox.tf.disabled` |
| Stack `terraform/siteB/` | ✅ | Mêmes fichiers, plus `terraform.tfvars` réel + `terraform.tfstate` (~32 KB après l'apply Phase 4) |
| `terraform init` siteA | ⏳ | Sera lancé en début FW3 quand le Proxmox Site A sera accessible |
| `terraform init` siteB | ✅ | `.terraform/` peuplé, `.terraform.lock.hcl` versionné |
| `terraform apply` siteB — bridges (`vmbr0`, `vmbr146`) | ✅ | `vmbr0` importé (ne pas casser la management 192.168.208.50/24), `vmbr146` créé |
| `terraform apply` siteB — clone des 3 VMs | ✅ | VMID 100 (services-s2), 101 (pfsense-s2 depuis 9100), 102 (bastion-s2) clonés et **running** |
| `terraform plan` idempotent post-apply | ✅ | "No changes. Your infrastructure matches the configuration." |

**Aucun blocage Terraform actif post-FW2.** Le `terraform plan`
post-apply est idempotent et le module `proxmox-vm` supporte désormais
les images sans cloud-init via 3 toggles (`enable_cloud_init`,
`enable_qemu_agent`, `os_type`) — extension nécessaire pour pfSense
(FreeBSD), 100 % rétro-compatible avec les VMs Linux.

### 2. Ansible

| Élément | État | Détail |
|---|---|---|
| `ansible/ansible.cfg` + `requirements.yml` | ✅ | Collections déclarées |
| Inventaires `siteA.ini` (43 L), `siteB.ini` (25 L) | ✅ code | Hôtes attendus (à valider quand IPs réelles disponibles) |
| Group_vars `all.yml` (74 L), `siteA.yml` (32 L), `siteB.yml` (31 L) | ✅ code | Variables centralisées, segmentations LAN/ADMIN/SERVICES, paramètres VPN |
| 11 rôles (`common`, `bastion`, `pfsense`, `openvpn`, `netbox`, `dns-forwarder`, `elasticsearch`, `kibana`, `logstash`, `filebeat`, `webapp`) | ✅ code | Tasks + handlers + templates + meta + defaults selon le rôle |
| 7 playbooks (`siteA`, `siteB`, `vpn`, `bastion`, `elastic`, `killswitch`, `site`) | ✅ code | Lint OK (`ansible-lint`, `yamllint` en CI) |
| `ansible-playbook --syntax-check` siteA/siteB | ✅ | Passe en CI (workflow `ansible.yml` vert) |
| Exécution **réelle** d'un playbook contre une VM | ⏳ | Volontairement reporté FW3 — VMs running mais l'apply complet (pfSense + bastion + DNS + Filebeat) est dans le scope FW3 |

### 3. Site A (on-premise — Epitech physique)

| Élément | État | Détail |
|---|---|---|
| Bridges `vmbr0` (WAN/management), `vmbr10` (LAN), `vmbr11` (ADMIN) | ⏳ | Tâche P3.1 — fenêtre FW3 |
| VM `pfsense-s1` (firewall + OpenVPN server) | ⏳ | Tâche P3.2 — clone template pfSense + apply Ansible |
| VM `services-s1` (NetBox + webapp) | ⏳ | Tâche P4.1 — clone + Ansible |
| VM `observability-s1` (Elastic stack) | ⏳ | Tâche P4.2 — clone + Ansible |

Pré-requis Site A : accès physique Proxmox Epitech, template Ubuntu cloud-init clonable, accès API Proxmox (token).

### 4. Site B (remote — DEV nested VMware Workstation)

| Élément | État | Détail |
|---|---|---|
| Hôte Proxmox VE 8.4 (50 GB → 48 GB après extension à chaud, 8 GB RAM, nested virt active) | ✅ | Disque étendu via `growpart` + `pvresize` + `lvextend` + `resize2fs`. KVM disponible (`/dev/kvm`) |
| Bridge `vmbr0` (WAN/management 192.168.208.50/24) | ✅ | Importé dans le state Terraform sans rupture de management |
| Bridge `vmbr146` (LAN isolé GR46, vlan-aware) | ✅ | Créé par Terraform |
| VM `pfsense-s2` (VMID 101) | ✅ | Clonée depuis VMID 9100 (vraie image pfSense), **running**, IP 192.168.0.1/24 |
| VM `bastion-s2` (VMID 102) | ✅ | Clonée depuis VMID 9000 (Ubuntu cloud-init), **running** |
| VM `services-s2` (VMID 100) | ✅ | Clonée depuis VMID 9000, **running** |
| Template Ubuntu 22.04 cloud-init (VMID 9000, 2.2 GB) | ✅ | Présent et utilisable |
| Template pfSense (VMID 9100) | ✅ | Créé manuellement (pfSense 2.7 ISO + import disque), `pfsense_template_id = 9100` |

### 5. Sécurité

| Critère | 📝 Code | 🚀 Live | Détail |
|---|---|---|---|
| Bastion SSH durci (MFA TOTP, fail2ban, audit) | ✅ | ❌ | `ansible/roles/bastion/` ; nécessite VM bootée |
| Hardening sshd / OS / TLS | ✅ | ❌ | `ansible/roles/common/templates/sshd_config.j2` |
| Secrets SOPS + age | ✅ | ✅ | `secrets/siteA.enc.yml`, `secrets/siteB.enc.yml`, `.sops.yaml`, clé age générée |
| Vault (KV-v2 + PKI) | ✅ code | ❌ | `vault/policies/*.hcl`, `vault/scripts/init-vault.sh` ; bootstrap Vault planifié FW3 |
| Killswitch pfSense | ✅ code | ❌ | `ansible/playbooks/killswitch.yml` ; nécessite pfSense up |
| Audit logs (auditd, rsyslog forward) | ✅ code | ❌ | `ansible/roles/common/tasks/main.yml` ; nécessite Elastic up |
| Pre-commit `gitleaks` + scan CI | ✅ | ✅ | `.gitleaks.toml`, workflow `security-scan.yml` |

### 6. Observabilité

| Composant | 📝 Code | 🚀 Live |
|---|---|---|
| Elasticsearch 8 single-node | ✅ | ❌ |
| Kibana | ✅ | ❌ |
| Logstash + pipelines (`pfsense`, `ssh`, `openvpn`, `netbox`) | ✅ | ❌ |
| Filebeat (déploiement sur toutes les VMs Linux) | ✅ | ❌ |
| ILM `cia-30d` | ✅ | ❌ |
| Dashboards Kibana versionnés | ⏳ | ❌ — exports prévus FW3 |

### 7. Documentation

| Document | Lignes | État |
|---|---|---|
| `README.md` | 228 | ✅ — badges CI, architecture, quickstart, runbooks |
| `CONTRIBUTING.md` | 98 | ✅ — Conventional Commits, pre-commit, PR template |
| `CRITERES.md` | ~270 | ✅ — 32+4 critères + colonne État de preuve |
| Gantt PowerPoint (`docs/gantt/`) | — | ✅ — 7 phases fév→juil 2026, jalons FW1/FW2/FW3/Final |
| `docs/tech-choices.md` (ADR) | 133 | ✅ — 14 décisions documentées |
| `docs/onboarding-new-site.md` | 135 | ✅ — golden path Site C |
| `docs/access-matrix.md` | 85 | ✅ — matrice accès LAN/ADMIN/SERVICES |
| `docs/drp/drp.md` | 154 | ✅ — 5 scénarios + RTO/RPO |
| `docs/runbooks/*.md` | 7 fichiers (73-129 L) | ✅ — bastion, elasticsearch, killswitch, netbox, pfsense, secrets, vpn |
| `docs/architecture/*.drawio` | 3 | ✅ — infra, vpn, firewall-rules + fallback Mermaid |
| `docs/backlog/followup{1,2,3}.md` | 3 | ✅ — bilan FW1, livrables FW2, plan FW3 |
| `docs/gantt/CIA_Gantt_GR46-2.pptx` | — | ✅ — 7 phases fév→juil 2026 |

### 8. CI/CD GitHub Actions

| Workflow | Fichier | État |
|---|---|---|
| Terraform fmt + validate + tflint + plan | `.github/workflows/terraform.yml` | ✅ vert |
| Ansible lint + syntax-check | `.github/workflows/ansible.yml` | ✅ vert |
| Pre-commit + markdownlint + yamllint | `.github/workflows/quality.yml` | ✅ vert |
| Gitleaks + trufflehog + checkov + tfsec | `.github/workflows/security-scan.yml` | ✅ vert |

---

## Blocages connus et workarounds

### B1 — Nested virtualization VMware Workstation 🟢 résolu

- **Symptôme initial** : `qm start` retournait *KVM virtualisation configured, but not available*.
- **Cause** : Hyper-V + WSL2 + VirtualMachinePlatform monopolisaient VT-x.
- **Workaround appliqué** : conversion WSL2→WSL1, `bcdedit /set hypervisorlaunchtype off`, désactivation `VirtualMachinePlatform` + `Microsoft-Hyper-V-All` + Memory Integrity, reboot Windows, activation *Virtualize Intel VT-x/EPT* dans VMware Workstation. KVM disponible (`/dev/kvm`), les 3 VMs Site B démarrent correctement.

### B2 — Storage Proxmox initial trop petit 🟢 résolu

- **Cause** : installeur Proxmox a partitionné `sda3` à 7.5 GB sur un VMDK de 50 GB (~42 GB d'espace non alloué).
- **Workaround appliqué** (à chaud, sans reboot Proxmox) : `growpart /dev/sda 3` → `pvresize` → `lvextend -l +100%FREE /dev/pve/root` → `resize2fs`. Résultat : `pve-root` passé de 6.5 GB à 48 GB, 41 GB libres.

### B3 — RAM Proxmox initiale insuffisante 🟢 résolu

- **Cause** : VM Proxmox VMware configurée à 2 GB. Insuffisant pour démarrer 3 VMs invitées (2+1+4 = 7 GB).
- **Workaround appliqué** : passage à 8 GB RAM dans VMware Workstation.

### B4 — Template pfSense (VMID 9100) absent 🟢 résolu

- **Symptôme initial** : `pfsense_template_id = 9000` clonait une image Ubuntu, pas pfSense.
- **Workaround appliqué** : création manuelle du template pfSense 2.7 (VMID 9100) sur Proxmox (ISO vanille + import disque). Module `proxmox-vm` étendu avec 3 toggles (`enable_cloud_init=false`, `enable_qemu_agent=false`, `os_type="other"`) pour gérer FreeBSD. `pfsense_template_id` passé à 9100, `pfsense-s2` re-cloné en Phase 4.

### B5 — DRP exercice live non joué 🟡

- **Cause** : critère `incident_exercise` exige une simulation live devant le jury (scénario "perte du Site A" ou "fuite de credentials").
- **Plan** : `chaos-drill.yml` à écrire en FW3 + capture vidéo de l'exécution.
- **Owner** : GR46 · **ETA** : FW3.

### B6 — Validation Valentin pas encore obtenue 🟡

- **Cause** : créneau Valentin pas posé en FW2 (Phase 7 reportée par décision GR46).
- **Plan** : demander une validation async par écrit à Valentin sur la fenêtre démo FW2 + planifier session live FW3.
- **Owner** : Desmond · **ETA** : avant FW3 kickoff.

---

## Prochaines actions concrètes (ordre d'exécution post-FW2)

| # | Action | Pré-requis | Owner | ETA |
|---|---|---|---|---|
| 1 | Démo FW2 devant le jury (s'appuyer sur `docs/demo/fw2-demo-walkthrough.md`) | tag `fw2-2026-04` | Desmond | semaine courante |
| 2 | Validation async Valentin sur livrables FW2 | — | Desmond | <1 semaine |
| 3 | Apply Ansible siteB réel (`siteB.yml`) sur les 3 VMs running | démo passée | Desmond | début FW3 |
| 4 | Demande accès physique Proxmox Site A (Epitech) | Validation Valentin | Desmond + GR46 | FW3 |
| 5 | `terraform apply` siteA + `ansible-playbook playbooks/siteA.yml` | (4) | GR46 | FW3 |
| 6 | Monter le tunnel OpenVPN site-à-site (`vpn.yml`) | (3) + (5) | GR46 | FW3 |
| 7 | Déployer NetBox + Elastic stack Site A | (5) | GR46 | FW3 |
| 8 | Jouer DRP exercice live + capturer vidéo | (7) | GR46 | FW3/Final |
| 9 | Rotation password `terraform@pve` post-démo (compte de démo) | démo passée | Desmond | <24h après démo |

---

## Inventaire runtime (à la date de la photo)

```text
Hôte Windows (DESMOND)
└── VMware Workstation 17 (VT-x/EPT exposé)
    └── VM proxmox-s1   (PVE 8.4 — 192.168.208.50)
        ├── Storage local : 48 GB / ~36 GB libres
        ├── RAM : 8 GB
        ├── Bridge vmbr0 (WAN, ports=ens33, IP=192.168.208.50/24)
        ├── Bridge vmbr146 (LAN GR46, vlan-aware, VLAN 20/21/22)
        ├── Template VMID 9000 (Ubuntu 22.04 cloud-init, 2.2 GB)
        ├── Template VMID 9100 (pfSense 2.7, ~1.6 GB)
        ├── VM 100 services-s2 (running, 192.168.10.20)
        ├── VM 101 pfsense-s2  (running, 192.168.0.1, depuis VMID 9100)
        └── VM 102 bastion-s2  (running, 192.168.0.10:2222)
```

---

## Liens utiles

- Architecture cible : [`README.md`](../README.md) · diagrammes : [`docs/architecture/`](architecture/)
- Conformité critères : [`CRITERES.md`](../CRITERES.md)
- Roadmap & Gantt : [`docs/gantt/`](gantt/)
- Backlog par follow-up : [`docs/backlog/followup1.md`](backlog/followup1.md) · [`followup2.md`](backlog/followup2.md) · [`followup3.md`](backlog/followup3.md)
- Runbooks opérationnels : [`docs/runbooks/`](runbooks/)
- Plan de reprise d'activité : [`docs/drp/drp.md`](drp/drp.md)
- Choix techniques (ADR) : [`docs/tech-choices.md`](tech-choices.md)

---

*GR46 — CIA Epitech 2025-2026 — Document vivant, mis à jour à chaque jalon.*
*Dernière revue : 2026-04-26 (clôture FW2 côté GR46).*
