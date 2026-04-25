# CIA — GR46 — Keynote finale

**Durée cible** : 20 minutes + 10 minutes Q&R
**Public** : jury Epitech (Silya, Valentin, + panel)
**Support** : Slides + démo live `terraform`/`ansible`/Kibana

---

## 1. Script — time-coded

### 0:00 — Accroche (1 min)

- Contexte : l'entreprise déploie 2 sites distants, doit garantir
  confidentialité, intégrité, audit.
- Objectif du projet : **infra hybride sécurisée, reproductible, traçable**.
- Parti pris : tout-code (Terraform + Ansible), tout-version (git),
  tout-audit (NetBox + Kibana).

### 1:00 — Architecture (2 min)

- Slide : schéma `docs/architecture/infra.drawio` (version exportée PNG).
- 2 sites Proxmox, 3 VM/site, tunnel OpenVPN AES-256-GCM.
- Zones : LAN, ADMIN, SERVICES, VPN — segmentation par règles pfSense.

### 3:00 — Plan d'adressage (1 min)

- Slide : `networking/addressing.yml` rendu schéma IPAM.
- Source de vérité : NetBox (démo rapide de l'UI avec sites + prefixes).

### 4:00 — Démo — idempotence Terraform (2 min)

- Terminal : `cd terraform/siteA && terraform plan`
- Message : "No changes. Your infrastructure matches the configuration."
- Ouvrir `modules/proxmox-vm/main.tf` — montrer que c'est générique.

### 6:00 — Démo — configuration Ansible (3 min)

- Terminal : `ansible-playbook -i inventories/siteA.ini playbooks/siteA.yml --check`
- Expliquer le check mode, l'ordre d'exécution (common → pfSense → openvpn
  → netbox → elastic → kibana → logstash).
- Ouvrir 2 rôles au hasard (pfsense + netbox) pour montrer la qualité.

### 9:00 — Sécurité (3 min)

- **Bastion SSH MFA** (`roles/bastion`) : clef + TOTP.
- **Vault + SOPS** (`.sops.yaml`, policies HCL) : secrets statiques vs.
  dynamiques.
- **Killswitch** : démo live.
  - Kibana dashboard "Egress" avant
  - `ansible-playbook killswitch.yml -e killswitch_state=active -e site=siteB`
  - `curl` depuis LAN → bloqué
  - Revert

### 12:00 — Observabilité (2 min)

- Kibana dashboards (SSH, pfSense, OpenVPN, NetBox audit).
- ILM policy `cia-30d` : rétention contrôlée.
- Événement live : un ping échoué génère un log filterlog.

### 14:00 — Qualité & CI/CD (1 min)

- `.pre-commit-config.yaml` + workflows GitHub Actions.
- Security-scan : gitleaks, tflint, checkov.
- Conventional commits + PR template + reviewers obligatoires.

### 15:00 — DRP — exercice joué (2 min)

- Enregistrement vidéo de l'exercice DRP #1 (perte VM services-s1).
- Chronométrage affiché.
- Montrer le rapport `docs/drp/reports/2026-XX-XX-scenario-1.md`.

### 17:00 — Golden path "nouveau site" (1 min)

- Défiler `docs/onboarding-new-site.md`.
- Montrer la commande unique `./scripts/bootstrap-new-site.sh siteC`.

### 18:00 — Bilan + retour d'expérience (1 min)

- **Ce qui a marché** : modules réutilisables, NetBox comme source de
  vérité, runbooks au fil de l'eau.
- **Ce qui a coincé** : PKI pfSense → Vault, apprentissage des API
  pfSense, arbitrage Terraform BSL vs. OpenTofu.
- **Ce qu'on ferait différemment** : commencer par Vault + secrets dès
  J+1, écrire runbooks en même temps que les rôles.

### 19:00 — Ouverture (1 min)

- Multi-site horizontal : Site C en un run.
- Migration OpenTofu.
- Détection comportementale (bonus v3).

### 20:00 — Q&R (10 min)

---

## 2. Support visuel

- Slides : 15 max, ratio 16:9.
- Palette : noir / bleu #38bdf8 (cohérence avec webapp).
- Schéma principal exporté depuis `infra.drawio` en SVG haute résolution.
- Démos live capturées en backup (OBS) au cas où réseau KO.

---

## 3. Checklist logistique

- [ ] Vidéo DRP enregistrée & montée (3 min max)
- [ ] Slides exportées en PDF (backup)
- [ ] 2e laptop prêt (backup démo)
- [ ] SSH multiplexing activé (pas de password prompts live)
- [ ] Kibana dashboards verrouillés (pas de saisie live foireuse)
- [ ] Clé MFA physique de secours (YubiKey bastion)
- [ ] Repo synchro GitHub + miroir local

---

## 4. Répartition

| Membre GR46 | Intervention                           |
|-------------|----------------------------------------|
| Dév infra   | §1, §2, §4, §16 + démo TF              |
| Dév sécu    | §9, §15 + killswitch                   |
| Dév obs     | §3, §12, §14                           |
| PO          | §0, §17, §18, Q&R                      |

---

## 5. Temps de répétition

- Première répétition : 1 semaine avant Final.
- Seconde répétition : 48 h avant, avec chrono.
- Répétition technique (matériel, réseau) : J-1, sur site.

---

*GR46 — CIA Epitech 2025-2026*
