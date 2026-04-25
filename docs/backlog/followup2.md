# CIA — GR46 — Préparation Follow-up 2

**Date cible** : avril 2026
**Groupe** : GR46
**Projet** : Deployment & Securing of a Hybrid Infrastructure with Proxmox

---

## 1. Engagements FW1 → état

| Action (FW1)                                     | État      | Preuve                                           |
|--------------------------------------------------|-----------|--------------------------------------------------|
| NAT pfSense Site 1 + Ubuntu                      | ✅ Fait    | `configs/pfsense/siteA-config.xml`               |
| pfSense Site 2 (LAN + ADMIN)                     | ✅ Fait    | `configs/pfsense/siteB-config.xml`               |
| Tunnel OpenVPN site-à-site                       | ✅ Fait    | `configs/openvpn/{server,client}.conf` + runbook |
| NetBox Site 1                                    | ✅ Fait    | `ansible/roles/netbox/` + Caddy TLS              |
| Elasticsearch Site 1                             | ✅ Fait    | `ansible/roles/elasticsearch/` + Kibana          |
| Bastion Site 2 + MFA                             | ✅ Fait    | `ansible/roles/bastion/` + `setup-mfa.sh.j2`     |
| DNS forwarding inter-sites                       | ✅ Fait    | `ansible/roles/dns-forwarder/templates/`         |
| Validation Valentin                              | 🟡 À faire | Créneau à caler semaine du 21/04                 |

---

## 2. Livrables FW2

### 2.1 Infrastructure (M / S)
- [x] Terraform modules `proxmox-vm` + `network` réutilisables
- [x] 3 VMs provisionnées par site (respecte contrainte)
- [x] Bridges Proxmox + VLAN TF
- [x] Ansible roles complets (common, pfSense, openvpn, netbox, elastic,
      kibana, logstash, bastion, dns-forwarder, webapp, filebeat)

### 2.2 Réseau / Firewall / VPN
- [x] Schéma `docs/architecture/infra.drawio` + variante `vpn.drawio`
- [x] Matrice d'accès `docs/access-matrix.md`
- [x] Killswitch opérationnel + runbook
- [x] Règles firewall cohérentes audit cross-sites
- [x] Tunnel AES-256-GCM + SHA256 + tls-crypt

### 2.3 Sécurité
- [x] Bastion SSH MFA (TOTP Google Authenticator)
- [x] fail2ban sur tous les hôtes Linux
- [x] Auditd règles custom (pfsense, netbox, openvpn)
- [x] sshd hardening (no PasswordAuth, ForceCommand bastion)
- [x] Vault + SOPS documentés `docs/runbooks/secrets.md`

### 2.4 Observabilité
- [x] Filebeat déployé partout
- [x] Pipelines Logstash : pfSense, SSH, OpenVPN, NetBox
- [x] ILM policy `cia-30d`
- [x] Dashboards Kibana de base (SSH, pfSense, NetBox, Overview)

### 2.5 Documentation
- [x] 7 runbooks : vpn, pfsense, bastion, elasticsearch, killswitch,
      netbox, secrets
- [x] DRP avec 5 scénarios `docs/drp/drp.md`
- [x] ADR `docs/tech-choices.md`
- [x] Golden path nouveau site `docs/onboarding-new-site.md`

### 2.6 CI/CD + qualité
- [x] `.pre-commit-config.yaml` (gitleaks, lint, fmt)
- [x] Workflows `terraform`, `ansible`
- [ ] Workflow `security-scan` (tflint + checkov + gitleaks)
- [x] Templates PR/Issue

---

## 3. Points ouverts à discuter avec Silya / Valentin

1. **Validation architecture finale** : confirmer que le tunnel en
   topologie hub Site A convient (vs. full-mesh si +1 site).
2. **Monitoring avancé** : critère bonus — OK pour notifications Slack
   sur règles de détection Kibana ? (fallback : email smtp externe).
3. **Rétention logs** : 30 jours trop court / trop long ? Impact stockage
   Elastic single-node.
4. **Rotation cert** : automatique par cron (proposé) vs. manuelle via
   runbook.

---

## 4. Démo prévue

Durée 15 min, structure :

1. **Topologie live** (2 min) — schéma + `terraform plan` sans changement
   (preuve idempotence).
2. **Création d'un user bastion** (3 min) — édit `group_vars/all.yml` →
   `ansible-playbook` → login TOTP.
3. **Killswitch** (2 min) — activation, test `curl` bloqué, désactivation.
4. **Kibana dashboards** (3 min) — SSH + pfSense + OpenVPN.
5. **Onboarding Site C** (3 min) — walkthrough `onboarding-new-site.md`.
6. **Q&R** (2 min).

---

## 5. Risques identifiés

| Risque                                      | Mitigation                             |
|---------------------------------------------|----------------------------------------|
| Valentin indisponible avant FW2             | Demander validation async par écrit    |
| Démo live échoue (réseau école)             | Backup : capture vidéo + screenshots   |
| Pression temps FW3                          | Prioriser DRP exercice + keynote       |

---

## 6. Todo post-FW2

- Jouer scénario DRP #1 (perte VM) avec Valentin présent
- Intégrer retours Silya/Valentin dans `docs/backlog/followup3.md`
- Upgrade Terraform → plan migration OpenTofu

---

*GR46 — CIA Epitech 2025-2026*
