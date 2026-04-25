# CIA — GR46 — Résumé Follow-up 1
**Date :** 11 mars 2026
**Intervenant·e :** Silya
**Groupe :** GR46
**Projet :** Deployment & Securing of a Hybrid Infrastructure with Proxmox

---

## Ce qu'on a présenté

Lors du Follow-up 1, nous avons présenté à Silya l'ensemble du travail de scoping réalisé depuis le début du projet :

- Le **schéma d'architecture** de l'infrastructure hybride (2 sites Proxmox interconnectés via VPN)
- Le **diagramme de Gantt** couvrant les 7 phases du projet de février à juillet 2026
- Les **choix technologiques** et leurs justifications (pfSense, OpenVPN, NetBox, Elasticsearch)

---

## Ce que Silya a validé

| Livrable | Statut |
|---|---|
| Schéma d'architecture (2 sites, VPN, Bastion, NetBox, Elasticsearch) | ✅ Validé |
| Diagramme de Gantt (7 phases, 4 jalons FW1/FW2/FW3/Final) | ✅ Validé |
| Choix techniques (pfSense, OpenVPN, NetBox, Elasticsearch) | ✅ Validé |

---

## Questions et remarques de Silya

### Bastion SSH
Silya a posé des questions sur le Bastion SSH — notamment pourquoi on en a besoin et comment il fonctionne. Nous avons expliqué que le Bastion est le **seul point d'entrée** pour accéder à l'infrastructure depuis l'extérieur, avec authentification par clé SSH uniquement et MFA. Cela évite d'exposer directement les VMs sur internet.

### NetBox & Elasticsearch
Des questions ont été posées sur le rôle de ces deux outils dans l'architecture. NetBox est notre **source de vérité** pour la gestion des IPs et des machines. Elasticsearch centralise **tous les logs** de l'infrastructure (pfSense, Bastion, VMs) pour la surveillance et l'audit.

### Contrainte 3 VMs maximum par site
Silya a vérifié que notre architecture respectait bien la contrainte de **3 VMs maximum par site Proxmox**. Nous avons confirmé notre découpage :
- Site 1 : pfSense · VM Services (NetBox) · Elasticsearch
- Site 2 : pfSense · VM Services · Bastion SSH

### Bridges réseau Proxmox
Des questions sur notre organisation réseau et les bridges Proxmox. Nous avons expliqué la convention Epitech : `vmbr0` = WAN internet partagé, `vmbr146` = LAN privé isolé pour GR46.

---

## Action demandée par Silya

> ⚠️ **Faire valider le schéma d'architecture par Valentin avant le FW2.**

Le schéma a été approuvé par Silya mais nécessite une validation complémentaire de **Valentin** avant d'être considéré comme définitif.

---

## Prochaines étapes — avant FW2

Suite aux échanges du FW1, voici ce qu'on s'engage à livrer pour le FW2 :

### Priorité 1 — Bloquants
- [ ] Configurer le NAT pfSense Site 1 → débloquer l'installation Ubuntu
- [ ] Finaliser l'installation Ubuntu sur VM1-GR46
- [ ] Configurer pfSense Site 2 (LAN 10.2.0.1/24)
- [ ] Mettre en place le tunnel OpenVPN site-à-site (S1 ↔ S2)

### Priorité 2 — Services
- [ ] Installer NetBox sur VM1 Site 1
- [ ] Installer Elasticsearch sur VM2 Site 1
- [ ] Déployer le Bastion SSH sur VM3 Site 2
- [ ] Configurer le DNS Forwarding inter-sites

### Priorité 3 — Documentation
- [ ] Faire valider l'architecture par Valentin
- [ ] Mettre à jour les repos GitOps avec les configs
- [ ] Compléter le runbook Site 1

---

*Résumé rédigé par GR46 — CIA Epitech 2025-2026*
