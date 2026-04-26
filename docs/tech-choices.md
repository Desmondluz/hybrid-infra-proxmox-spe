# Choix techniques — CIA

**Propriétaire** : GR46 · **Dernière revue** : 2026-04-18

Ce document est le journal des décisions d'architecture (ADR condensés).
Chaque entrée liste le **contexte**, le **choix**, les **alternatives**
écartées et le **trade-off**.

## 1. Virtualisation : Proxmox VE 8

- **Contexte** : sujet impose bare-metal, max 3 VM/site, besoin API TF.
- **Choix** : Proxmox VE 8 (open-source, qemu-KVM, API REST, cloud-init).
- **Alternatives** : VMware ESXi (licence payante), libvirt seul (pas
  d'UI prête).
- **Trade-off** : upgrade moins fluide que ESXi mais gratuit, stack
  communauté active, provider TF `bpg/proxmox` mature.

## 2. Firewall : pfSense CE

- **Contexte** : besoin pare-feu L4 + OpenVPN server/client + routing.
- **Choix** : pfSense CE 2.7+ (API REST via paquet `pfSense-pkg-API`).
- **Alternatives** : OPNsense (plus moderne mais API tierce moins stable),
  vyOS (CLI only, pas d'UI de secours).
- **Trade-off** : pfSense reste FreeBSD donc ressources un peu plus
  lourdes, mais documentation & communauté imbattables.

## 3. Tunnel inter-sites : OpenVPN site-à-site

- **Contexte** : sites hétérogènes, NAT à traverser, audit cipher requis.
- **Choix** : OpenVPN UDP/1194, AES-256-GCM + SHA256, tls-crypt, topologie
  p2p `172.16.0.0/30`.
- **Alternatives** : WireGuard (plus rapide, mais pfSense-pkg encore
  jeune au T1 2026), IPsec IKEv2 (config lourde, peu lisible).
- **Trade-off** : OpenVPN plus gourmand CPU mais intégration pfSense
  mature, PKI Vault propre.

## 4. IPAM source de vérité : NetBox

- **Contexte** : besoin documentation auditable du plan d'adressage.
- **Choix** : NetBox 3.x en Docker Compose sur Site A.
- **Alternatives** : phpIPAM (moins de modèle DCIM), spreadsheet (refusé).
- **Trade-off** : ressources dédiées (DB Postgres), mais API riche et
  idempotent → seed automatisable via `seed_netbox.py`.

## 5. Observabilité : Elastic Stack (ELK)

- **Contexte** : volume modéré (~5 GB/jour), besoin recherche full-text.
- **Choix** : Elasticsearch 8 single-node + Kibana + Logstash + Filebeat.
- **Alternatives** : Grafana Loki + Promtail (pas de full-text parsing
  avancé), Graylog (UI moins soignée), OpenSearch (fork mais incertitude
  plugin long terme).
- **Trade-off** : SPOF sur obs s1 accepté en MVP, ILM 30 j acceptable,
  migration SIEM future possible.

## 6. Bastion : hôte Linux + PAM TOTP

- **Contexte** : exposition SSH depuis Internet refusée, besoin SSO léger.
- **Choix** : bastion minimaliste `bastion-s2`, PAM + Google Authenticator,
  fail2ban agressif (3 tentatives = ban 1 h).
- **Alternatives** : Boundary HashiCorp (lourd), Teleport (payant au-delà
  d'un certain nb d'users).
- **Trade-off** : gestion manuelle des seeds TOTP, simple mais efficace.

## 7. IaC : Terraform

- **Contexte** : provisioning VM + VLAN via Proxmox API.
- **Choix** : Terraform 1.7 + `bpg/proxmox` + `e-breuninger/netbox`
  - `carlpett/sops`.
- **Alternatives** : OpenTofu (compat TF mais encore jeune), Pulumi
  (overkill pour ce projet).
- **Trade-off** : Terraform → license BSL depuis 2023 ; on maintient
  la version 1.5.x (dernière MPL2). OpenTofu reste en option si besoin.

## 8. Configuration : Ansible

- **Contexte** : pas d'agent pré-installé, besoin idempotence.
- **Choix** : Ansible 2.16, collections `community.sops`,
  `community.docker`, `netbox.netbox`, `pfsensible.core`.
- **Alternatives** : Salt (master/minion lourd), Chef (agent requis),
  shell scripts (pas idempotent).
- **Trade-off** : vitesse modeste (SSH), mais simple et auditable.

## 9. Secrets : SOPS + age + Vault

- **Contexte** : séparation secrets statiques (en git) / dynamiques (rotatifs).
- **Choix** :
  - SOPS + age → variables TF, mots de passe admin initial, ansible vars.
  - Vault KV-v2 + PKI → tokens API, certs OpenVPN, rotation.
- **Alternatives** : git-crypt (moins flexible), Ansible Vault natif
  (moins d'outillage).
- **Trade-off** : deux systèmes à comprendre, mais chaque outil est
  meilleur dans son rôle.

## 10. DNS : unbound + forwarding conditionnel

- **Contexte** : besoin résolveur interne, segmentation des domaines
  `s1.lan` / `s2.lan`.
- **Choix** : unbound (côté pfSense + VM Linux), forward-zone
  conditionnelle via tunnel VPN.
- **Alternatives** : BIND9 (plus complexe), dnsmasq (moins fonctionnel).
- **Trade-off** : unbound orienté résolveur récursif, adapté à notre
  usage.

## 11. Reverse proxy : Caddy

- **Contexte** : exposer NetBox en TLS auto-signé.
- **Choix** : Caddy 2, `tls internal` (CA locale), gzip, logs JSON.
- **Alternatives** : nginx (cert manuel), Traefik (overkill).
- **Trade-off** : pas de support HTTP/3 production-ready, mais suffisant
  en LAN.

## 12. CI/CD : GitHub Actions

- **Contexte** : repo GitHub, besoin lint + scan sécurité.
- **Choix** : workflows `.github/workflows/{terraform,ansible,security}.yml`.
- **Alternatives** : GitLab CI (nécessite self-host), Jenkins (surdim.).
- **Trade-off** : minutes CI GitHub limitées mais suffisantes pour ce
  volume.

## 13. Pré-commit hooks

- **Contexte** : bloquer les fuites et les erreurs de format avant push.
- **Choix** : pre-commit.com + terraform_fmt, ansible-lint, yamllint,
  markdownlint, gitleaks, shellcheck.
- **Alternatives** : husky (JS-centric).
- **Trade-off** : un petit setup à faire (`pre-commit install`), mais
  effet massif sur la qualité.

## 14. Journal de révision

| Date        | Auteur | Changement                               |
|-------------|--------|------------------------------------------|
| 2026-04-18  | GR46   | Version initiale post follow-up #1       |
