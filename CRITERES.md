# 🎯 Conformité aux 29 critères du SPE  
Projet : Hybrid Infrastructure – Proxmox / pfSense / OpenVPN / NetBox / Elastic / Vault  
Groupe : PAR_25

Ce document démontre la conformité du projet aux 29 critères d’évaluation du SPE.  
Chaque critère est associé aux éléments du dépôt qui prouvent sa validation.

---

# 1. Infrastructure

## ✔️ infra_delivery  
**Une infrastructure hybride est livrée et fonctionnelle.**  
➡️ Preuves :  
- `terraform/siteA/` + `terraform/siteB/`  
- `ansible/roles/*`  
- `configs/pfsense/`, `configs/openvpn/`  
- Diagrammes : `docs/architecture/infra.drawio`

---

## ✔️ infra_spec  
**La majorité des services requis sont présents et fonctionnels.**  
➡️ Services : pfSense, OpenVPN, Bastion, NetBox, Elastic, Vault  
➡️ Preuves :  
- `ansible/roles/`  
- `configs/`  
- `docs/runbooks/`

---

## ✔️ infra_scalability  
**L’infrastructure est scalable : ajout facile d’un site.**  
➡️ Preuves :  
- `terraform/modules/`  
- Architecture multi‑site dans `docs/architecture/infra.drawio`

---

## ✔️ infra_choices  
**Stack technique maintenue et supportée par la communauté.**  
➡️ Preuves :  
- pfSense, Proxmox, OpenVPN, Vault, NetBox, Elastic (tous open-source)  
- Justification dans `README.md`

---

# 2. Diagrammes

## ✔️ diagram_delivery  
**Diagramme présenté au FU1.**  
➡️ Preuves :  
- `docs/architecture/infra.drawio`  
- `docs/backlog/followup1.md`

---

## ✔️ diagram_quality  
**Diagramme complet : 2 sites, réseaux, VPN, bastion, DNS, IPAM, observabilité.**  
➡️ Preuves :  
- `docs/architecture/infra.drawio`  
- `docs/architecture/vpn.drawio`  
- `docs/architecture/firewall-rules.drawio`

---

# 3. Infrastructure as Code

## ✔️ iac_delivery  
**La majorité des ressources sont déployées via IaC.**  
➡️ Preuves :  
- `terraform/siteA/`  
- `terraform/siteB/`

---

## ✔️ iac_quality  
**Code lisible, structuré, conforme aux bonnes pratiques.**  
➡️ Preuves :  
- `terraform/modules/`  
- CI Terraform (`.github/workflows/terraform.yml`)

---

# 4. Réseau

## ✔️ network_spec1  
**Site on‑prem accessible uniquement en interne.**  
➡️ Preuves :  
- pfSense Site A (`configs/pfsense/`)  
- `networking/addressing.yml`

---

## ✔️ network_spec2  
**Site remote accessible depuis l’extérieur.**  
➡️ Preuves :  
- Bastion (`ansible/roles/bastion/`)  
- pfSense Site B (`configs/pfsense/`)

---

## ✔️ network_vpn  
**VPN sécurisé interconnectant les deux sites.**  
➡️ Preuves :  
- `configs/openvpn/`  
- `ansible/roles/openvpn/`  
- `docs/runbooks/vpn.md`

---

## ✔️ network_firewall  
**Firewall sur chaque site, règles correctement configurées.**  
➡️ Preuves :  
- `configs/pfsense/`  
- `networking/firewall-rules.yml`  
- `docs/runbooks/pfsense.md`

---

## ✔️ network_dns  
**DNS forwarding entre les deux sites.**  
➡️ Preuves :  
- `configs/dns/`  
- pfSense DNS Forwarder

---

## ✔️ network_ip_mngmt  
**IPAM automatisé via NetBox.**  
➡️ Preuves :  
- `ansible/roles/netbox/`  
- `networking/addressing.yml`

---

# 5. Sécurité

## ✔️ sec_access  
**Least privilege correctement appliqué.**  
➡️ Preuves :  
- `vault/policies/`  
- Bastion + accès restreint

---

## ✔️ sec_bastion  
**Accès au site remote via un bastion sécurisé.**  
➡️ Preuves :  
- `ansible/roles/bastion/`  
- `docs/runbooks/bastion.md`

---

## ✔️ sec_credentials  
**Gestion sécurisée des secrets (Vault).**  
➡️ Preuves :  
- `vault/secrets/`  
- `vault/policies/`  
- `vault/scripts/init-vault.sh`

---

# 6. Incidents & Reprise

## ✔️ incident_killswitch  
**Kill switch opérationnel.**  
➡️ Preuves :  
- `configs/pfsense/`  
- `docs/runbooks/pfsense.md`

---

## ✔️ incident_recovery  
**DRP complet, reproductible.**  
➡️ Preuves :  
- `docs/drp/drp.md`  
- `docs/runbooks/`

---

# 7. Logs & Observabilité

## ✔️ log_centralisation  
**Centralisation des logs.**  
➡️ Preuves :  
- `ansible/roles/elasticsearch/`  
- `configs/elasticsearch/`

---

## ✔️ log_observability  
**Observabilité complète (logs + indicateurs).**  
➡️ Preuves :  
- Elastic + dashboards  
- `docs/runbooks/elasticsearch.md`

---

## ✔️ log_analysis  
**Analyse pertinente des données.**  
➡️ Preuves :  
- Dashboards Elastic  
- `docs/runbooks/elasticsearch.md`

---

## ✔️ log_visuals  
**Visualisation des données.**  
➡️ Preuves :  
- Kibana dashboards  
- Screenshots dans `docs/runbooks/`

---

# 8. Repository & Documentation

## ✔️ repo_practices  
**Bonnes pratiques Git : branches, commits, gitignore.**  
➡️ Preuves :  
- `.github/workflows/`  
- Historique Git

---

## ✔️ repo_doc  
**Documentation claire et structurée.**  
➡️ Preuves :  
- `docs/`  
- `README.md`

---

## ✔️ repo_content  
**Code source + configurations.**  
➡️ Preuves :  
- `terraform/`  
- `ansible/`  
- `configs/`  
- `networking/`

---

# 9. Gestion de projet

## ✔️ proj_subdivision  
**Projet découpé en phases + Gantt.**  
➡️ Preuves :  
- `docs/gantt/gantt.png`  
- `docs/backlog/followup1.md`

---

## ✔️ proj_planning  
**Backlog complet et mis à jour.**  
➡️ Preuves :  
- `docs/backlog/`

---

## ✔️ proj_presentation  
**Présentation professionnelle.**  
➡️ Preuves :  
- `docs/backlog/keynote.md`  
- Slides de soutenance

---

# ✅ Conclusion

L’ensemble du dépôt répond **intégralement** aux 29 critères du SPE.  
Chaque exigence est couverte par :  
- un dossier  
- un fichier  
- un rôle Ansible  
- un module Terraform  
- un runbook  
- un diagramme  
- ou un élément de CI/CD

