# CIA — GR46 — Préparation Follow-up 3

**Date cible** : juin 2026
**Groupe** : GR46
**Projet** : Deployment & Securing of a Hybrid Infrastructure with Proxmox

---

## 1. Rappel FW2

Follow-up 2 (avril 2026) a validé :
- l'architecture à 2 sites + tunnel OpenVPN
- les 7 runbooks et le DRP
- la CI/CD Terraform + Ansible + security-scan

Retours Silya : à consigner ici après la session — format "date · auteur ·
décision".

---

## 2. Objectifs FW3 — pré-final

| Thème                            | Engagement FW3                                          |
|----------------------------------|---------------------------------------------------------|
| Exercice DRP réel                | Jouer scénario #1 (perte VM) en session, preuves vidéo  |
| Monitoring avancé (bonus)        | Alerting Kibana → webhook Slack, SLO disponibilité VPN  |
| Multi-site (bonus)               | POC Site C en staging (pas prod)                        |
| Automatisation PKI OpenVPN       | Cron trimestriel rotation                               |
| Hardening supplémentaire         | AppArmor profiles + USBGuard (si pertinent)             |
| Performance Elastic              | Benchmark ingestion 10 k EPS, profiler bottleneck       |

---

## 3. Delta depuis FW2

### À réaliser
- [ ] Script `scripts/rotate-openvpn.sh` + cron Ansible
- [ ] Workflow GitHub `.github/workflows/cert-rotation.yml` (dispatch
      manuel + planifié)
- [ ] Alert rules Kibana (`infra/kibana/alerts.ndjson`) :
      - `ssh_failure rate > 50/5m`
      - `vpn_down for 5m`
      - `es_cluster_status != green`
- [ ] Webhook Slack via `xpack.actions.webhook`
- [ ] Ansible playbook `playbooks/chaos-drill.yml` (nuke une VM, restore)
- [ ] Script `scripts/bootstrap-new-site.sh` (invoqué depuis
      `docs/onboarding-new-site.md`)

### En cours
- [ ] Revue du DRP après exercice réel
- [ ] Intégration feedback qualité Silya/Valentin sur runbooks

### Abandonnés (justifier)
- [ ] Migration OpenTofu → reportée, TF 1.5.x encore supporté par BSL
      pour usage interne non-commercial.

---

## 4. Métriques visées FW3

| Métrique                                   | Cible             |
|--------------------------------------------|-------------------|
| Déploiement from-scratch (bootstrap)       | < 2 h             |
| Rotation certs OpenVPN end-to-end          | < 10 min          |
| Restauration pfSense config depuis git     | < 10 min          |
| DRP #1 (perte VM services-s1)              | < 30 min          |
| Taux de couverture linters (terraform/yaml)| 100 %             |
| Temps moyen d'ingestion log → Kibana       | < 10 s            |

---

## 5. Démo prévue

1. **Rotation PKI live** (3 min) — `./scripts/rotate-openvpn.sh` → re-handshake
   tunnel visible Kibana.
2. **Chaos drill** (4 min) — `qm destroy <vmid>` → `terraform apply` →
   `ansible-playbook` → service UP.
3. **Alerting Slack** (3 min) — déclencher 60 SSH fails → message Slack.
4. **Onboarding Site C** (4 min) — vrai terraform apply dans sandbox.
5. **Q&R** (1 min).

---

## 6. Dépendances externes

- Slack workspace GR46 créé ? → canal `#cia-alerts`.
- Équipement réseau stable : réserver créneau data-room.
- Valentin disponible pour §5.

---

## 7. Risques

| Risque                                          | Parade                       |
|-------------------------------------------------|------------------------------|
| Indispo Slack                                   | Fallback : webhook à un mock |
| Chaos drill → vraie panne                       | Snapshot Proxmox avant       |
| Bonus multi-site impossible (matériel)          | Montrer sim via docker compose|

---

## 8. Livrables finaux après FW3 → Final

- Keynote finale (`docs/backlog/keynote.md`)
- Vidéo démo (3 min)
- Export CRITERES.md à jour avec preuves
- Rapport DRP complet avec exercice réel

---

*GR46 — CIA Epitech 2025-2026*
