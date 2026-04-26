# Projet CIA — Feuille de route complète

Infrastructure hybride Proxmox sécurisée — du jour 1 à la keynote finale.

Toutes les étapes sont numérotées et cochables. Chaque étape indique entre crochets le ou les critères d'évaluation qu'elle valide.

---

## PHASE 0 — Préparation et organisation (Jours 1-3)

### 0.1 Constitution de l'équipe et des rôles

- [ ] 0.1.1 — Réunion de kickoff interne, partage du PDF du sujet, lecture commune.
- [ ] 0.1.2 — Définir les rôles fonctionnels (non exclusifs) : Lead archi, Lead réseau/sécurité, Lead IaC, Lead observabilité, Lead doc/projet.
- [ ] 0.1.3 — Créer un canal Discord/Slack/Teams dédié au projet.
- [ ] 0.1.4 — Planifier les créneaux de travail réguliers et les dailys (même 15 min/jour).

### 0.2 Choix des outils de collaboration

- [ ] 0.2.1 — Créer un compte GitHub (ou GitLab) organisation pour l'équipe.
- [ ] 0.2.2 — Créer le repo `cia-infra` privé avec accès pour tous les membres et les mentors/instructeurs.
- [ ] 0.2.3 — Activer GitHub Projects (ou GitLab Boards) sur le repo.
- [ ] 0.2.4 — Choisir l'outil de diagrammes : draw.io (desktop/web) + Excalidraw pour les schémas rapides.
- [ ] 0.2.5 — Choisir l'outil de slides : Marp (markdown versionné) ou Google Slides/PowerPoint.

### 0.3 Setup initial du repository `[repo_practices, repo_content]`

- [ ] 0.3.1 — Créer l'arborescence cible :

  ```
  cia-infra/
  ├── .github/workflows/          (ou .gitlab-ci.yml)
  ├── docs/
  ├── diagrams/
  ├── runbooks/
  ├── infra/
  │   ├── terraform/
  │   │   ├── modules/
  │   │   ├── sites/
  │   │   └── global/
  │   ├── ansible/
  │   │   ├── roles/
  │   │   ├── inventories/
  │   │   └── playbooks/
  │   └── ipam/
  ├── secrets/                    (chiffré via SOPS)
  ├── ci/
  ├── .gitignore
  ├── .editorconfig
  ├── .pre-commit-config.yaml
  ├── README.md
  ├── CONTRIBUTING.md
  ├── ARCHITECTURE.md
  └── LICENSE
  ```

- [ ] 0.3.2 — Rédiger un `.gitignore` complet (terraform state, .env, clés SSH, artefacts compilés, éditeurs IDE, OS files).
- [ ] 0.3.3 — Rédiger le `README.md` initial avec : présentation, stack, comment démarrer, comment contribuer, liens docs.
- [ ] 0.3.4 — Rédiger `CONTRIBUTING.md` avec la convention de commits (`feat:`, `fix:`, `docs:`, `ci:`, `refactor:`, `test:`), la stratégie de branches, le process de PR.
- [ ] 0.3.5 — Protéger la branche `main` : interdiction de push direct, PR obligatoire avec 1 reviewer minimum, CI green requis.
- [ ] 0.3.6 — Créer la branche `develop` comme branche d'intégration.
- [ ] 0.3.7 — Installer les hooks `pre-commit` (ansible-lint, tflint, yamllint, markdownlint, trailing whitespace).
- [ ] 0.3.8 — Ajouter un template de Pull Request et un template d'issue.
- [ ] 0.3.9 — Donner les droits en lecture aux mentors/instructeurs.

### 0.4 Setup du project management `[proj_planning, proj_subdivision]`

- [ ] 0.4.1 — Créer un GitHub Project « CIA — Backlog » avec colonnes : Icebox / Backlog / To do / In progress / Review / Done.
- [ ] 0.4.2 — Définir les labels : `criterion:*`, `phase:1-4`, `chantier:network/security/iac/obs/docs`, `priority:high/med/low`, `size:S/M/L`.
- [ ] 0.4.3 — Définir les jalons (milestones) : Follow-up 1, Follow-up 2, Follow-up 3, Keynote.

### 0.5 Recherche initiale `[infra_choices]`

- [ ] 0.5.1 — Rassembler la documentation officielle : Proxmox VE, pfSense, OpenVPN, NetBox, Elastic Stack.
- [ ] 0.5.2 — Pour chaque brique, noter : dernière version stable, date de release, activité du repo GitHub (commits, issues), licence.
- [ ] 0.5.3 — Rédiger `docs/tech-choices.md` avec un tableau comparatif et la justification de chaque choix (pourquoi pfSense plutôt qu'OPNsense, pourquoi OpenVPN plutôt que WireGuard, pourquoi Elastic plutôt qu'OpenSearch, etc.).
- [ ] 0.5.4 — Identifier les prérequis matériels (RAM/CPU/disque) pour chaque VM.
- [ ] 0.5.5 — POC local : installer un Proxmox sur une machine de test ou en nested virtualization, créer une VM pfSense, vérifier que tout tourne. Noter les blockers éventuels.

---

## PHASE 1 — Design et Follow-up 1 (Semaines 1-3)

### 1.1 Conception de l'architecture `[diagram_quality, infra_scalability]`

- [ ] 1.1.1 — Définir la répartition des 3 VMs par site :
  - **S1 on-prem** : VM1 = pfSense, VM2 = NetBox + PostgreSQL + site web interne (conteneurs), VM3 = Elasticsearch + Kibana + Logstash.
  - **S2 remote** : VM1 = pfSense, VM2 = Bastion SSH, VM3 = App tier + CI runner + NetBox read-replica optionnel.
- [ ] 1.1.2 — Définir la segmentation réseau par site : VLANs ADMIN, SERVICES, USERS/LAN, DMZ.
- [ ] 1.1.3 — Définir le plan d'adressage scalable `10.<site_id>.<vlan>.<host>` :
  - Site 1 = `10.1.0.0/16`, Site 2 = `10.2.0.0/16`, Site 3 futur = `10.3.0.0/16`.
  - VLAN 10 = ADMIN, VLAN 20 = SERVICES, VLAN 30 = USERS, VLAN 40 = DMZ.
- [ ] 1.1.4 — Définir la topologie VPN : OpenVPN en mode routé (tun), certificats PKI, terminaison sur les pfSense, subnets annoncés.
- [ ] 1.1.5 — Définir les zones DNS : `s1.lan` et `s2.lan`, forwarders sur pfSense/unbound, forward conditionnel croisé.
- [ ] 1.1.6 — Définir la stratégie de sauvegarde : snapshots Proxmox hebdos + backup config pfSense + dump NetBox.

### 1.2 Production des diagrammes `[diagram_delivery, diagram_quality]`

- [ ] 1.2.1 — Diagramme principal d'architecture (draw.io) montrant S1 + S2, réseaux segmentés, VPN (terminaisons + subnets routés + chiffrement), pare-feux avec règles clés annotées, bastion avec flux/auth/logging, NetBox + Elasticsearch avec flux d'accès, DNS forwarding.
- [ ] 1.2.2 — Diagramme de flux d'authentification (depuis Internet → bastion → cibles).
- [ ] 1.2.3 — Diagramme du plan d'adressage (tableau visuel + allocation).
- [ ] 1.2.4 — Diagramme de la topologie VPN (détail crypto, routes).
- [ ] 1.2.5 — Diagramme du pipeline CI/CD et du flux GitOps.
- [ ] 1.2.6 — Versionner les sources (`.drawio`, `.excalidraw`) et les exports PNG dans `diagrams/`.

### 1.3 Planification `[proj_subdivision, proj_planning]`

- [ ] 1.3.1 — Rédiger le Gantt complet en Mermaid (`docs/gantt.md`) couvrant les 4 follow-ups avec dépendances.
- [ ] 1.3.2 — Générer l'export PNG/PDF du Gantt pour les slides.
- [ ] 1.3.3 — Éclater le projet en ~60-80 tickets dans le backlog, chacun lié à 1 ou plusieurs critères d'évaluation.
- [ ] 1.3.4 — Prioriser les tickets pour le Follow-up 2 (sprint 1 technique).
- [ ] 1.3.5 — Assigner les tickets du sprint 1 aux membres de l'équipe.
- [ ] 1.3.6 — Estimer chaque ticket (S/M/L).

### 1.4 Préparation de la review 1 `[proj_presentation]`

- [ ] 1.4.1 — Créer les slides du Follow-up 1 : intro sujet, équipe, stack retenue avec justifications, diagramme d'archi, plan d'adressage, Gantt, backlog preview, blockers identifiés, liste tickets du prochain sprint.
- [ ] 1.4.2 — Préparer une démo : repo + board Kanban + diagrammes zoomables.
- [ ] 1.4.3 — Répéter la présentation (chronomètre, répartition du temps de parole).
- [ ] 1.4.4 — **Review 1** : présenter, recueillir les retours, les transformer en tickets.

---

## PHASE 2 — Fondations réseau (Semaines 3-5)

### 2.1 Installation Proxmox `[infra_delivery, infra_spec]`

- [ ] 2.1.1 — Préparer l'ISO Proxmox VE (dernière LTS).
- [ ] 2.1.2 — Installer Proxmox sur le serveur Site 1, configurer hostname, FQDN, interfaces réseau physiques.
- [ ] 2.1.3 — Installer Proxmox sur le serveur Site 2, mêmes étapes adaptées.
- [ ] 2.1.4 — Désactiver le repo enterprise, activer le repo no-subscription, mettre à jour.
- [ ] 2.1.5 — Configurer les bridges réseau (`vmbr0` WAN, `vmbr1` LAN, `vmbr2` ADMIN, `vmbr3` DMZ) sur les deux hyperviseurs.
- [ ] 2.1.6 — Configurer les VLANs tagués sur les bridges selon le plan d'adressage.
- [ ] 2.1.7 — Créer un utilisateur admin dédié (non-root), activer 2FA sur l'interface web Proxmox.
- [ ] 2.1.8 — Générer une clé API Proxmox pour Terraform.
- [ ] 2.1.9 — Configurer le stockage (local-lvm ou ZFS selon disponibilité).
- [ ] 2.1.10 — Tester la connectivité Internet des deux hyperviseurs.

### 2.2 Déploiement pfSense `[network_firewall]`

- [ ] 2.2.1 — Uploader l'ISO pfSense sur le storage Proxmox.
- [ ] 2.2.2 — Créer la VM pfSense Site 1 (2 vCPU, 2 GB RAM, 20 GB disk, 4 interfaces réseau : WAN, LAN, ADMIN, DMZ).
- [ ] 2.2.3 — Installer pfSense, configurer les interfaces et les adresses IP selon le plan.
- [ ] 2.2.4 — Accéder à l'interface web pfSense via LAN, changer mot de passe admin par défaut.
- [ ] 2.2.5 — Répéter pour pfSense Site 2.
- [ ] 2.2.6 — Documenter les adresses IP, ports admin, credentials (dans SOPS).
- [ ] 2.2.7 — Désactiver l'admin pfSense sur WAN, ne l'autoriser que depuis VLAN ADMIN.
- [ ] 2.2.8 — Activer les backups config automatiques pfSense (pkg `AutoConfigBackup`).

### 2.3 Site-to-site VPN OpenVPN `[network_vpn]`

- [ ] 2.3.1 — Générer la CA OpenVPN sur pfSense Site 1 (dans Cert Manager).
- [ ] 2.3.2 — Générer le certificat serveur OpenVPN Site 1.
- [ ] 2.3.3 — Générer un certificat client pour Site 2.
- [ ] 2.3.4 — Exporter le bundle CA + cert client vers pfSense Site 2.
- [ ] 2.3.5 — Configurer le serveur OpenVPN sur pfSense Site 1 : mode peer-to-peer SSL/TLS, UDP port 1194, AES-256-GCM, SHA256 auth, DH 2048+, compression off, tunnel réseau `10.99.0.0/30`, routes poussées vers LAN S2.
- [ ] 2.3.6 — Configurer le client OpenVPN sur pfSense Site 2 pointant vers l'IP publique S1, avec les routes vers LAN S1.
- [ ] 2.3.7 — Créer les règles firewall sur l'interface OpenVPN des deux pfSense : autoriser le trafic entre subnets routés.
- [ ] 2.3.8 — Tester la connectivité : `ping` depuis une IP LAN S1 vers une IP LAN S2 et inverse.
- [ ] 2.3.9 — Capturer un tcpdump sur WAN montrant le trafic chiffré (pour la démo).
- [ ] 2.3.10 — Documenter la procédure complète dans `runbooks/vpn-setup.md`.

### 2.4 DNS forwarding `[network_dns]`

- [ ] 2.4.1 — Activer le resolver unbound sur pfSense Site 1, créer la zone `s1.lan`.
- [ ] 2.4.2 — Activer le resolver unbound sur pfSense Site 2, créer la zone `s2.lan`.
- [ ] 2.4.3 — Configurer le forward conditionnel : `*.s2.lan` → IP resolver S2, `*.s1.lan` → IP resolver S1.
- [ ] 2.4.4 — Ajouter les host overrides pour les services critiques (netbox.s1.lan, kibana.s1.lan, bastion.s2.lan, web.s1.lan).
- [ ] 2.4.5 — Tester `dig @resolver-s1 bastion.s2.lan` et inverse.
- [ ] 2.4.6 — Documenter dans `runbooks/dns-forwarding.md`.

### 2.5 Règles firewall de base `[network_firewall, sec_access]`

- [ ] 2.5.1 — Sur les deux pfSense : deny all par défaut sur toutes les interfaces.
- [ ] 2.5.2 — Règles par interface :
  - **LAN** : autoriser sortie Internet (http/https/dns), autoriser vers SERVICES et ADMIN (filtré), refuser le reste.
  - **SERVICES** : autoriser réponses aux LAN autorisés, autoriser sortie vers Internet pour updates, refuser le reste.
  - **ADMIN** : autoriser vers toutes les interfaces admin, refuser l'inverse.
  - **DMZ** : autoriser Internet vers bastion sur le port SSH choisi, refuser tout autre entrant, refuser DMZ → LAN/SERVICES sauf exceptions.
  - **OpenVPN** : autoriser LAN↔LAN entre sites.
- [ ] 2.5.3 — Activer le logging sur toutes les règles clés.
- [ ] 2.5.4 — Exporter la config pfSense (`config.xml`) et la versionner (chiffrée) dans le repo.

---

## PHASE 3 — Services core (Semaines 4-6)

### 3.1 Provisioning des VMs via Terraform `[iac_delivery, iac_quality]`

- [ ] 3.1.1 — Installer Terraform localement, initialiser `infra/terraform/`.
- [ ] 3.1.2 — Configurer le provider Proxmox (`bpg/proxmox`) avec les credentials via variables d'env ou SOPS.
- [ ] 3.1.3 — Créer le module `modules/vm` (paramètres : name, cpu, ram, disk, networks, template).
- [ ] 3.1.4 — Créer le module `modules/network` (bridges, VLANs).
- [ ] 3.1.5 — Créer le module `modules/site` qui compose les deux précédents.
- [ ] 3.1.6 — Créer des templates de VM cloud-init pour Debian/Ubuntu sur les deux Proxmox.
- [ ] 3.1.7 — Instancier les VMs Site 1 (netbox-vm, elastic-vm) via `sites/s1/main.tf`.
- [ ] 3.1.8 — Instancier les VMs Site 2 (bastion-vm, app-vm) via `sites/s2/main.tf`.
- [ ] 3.1.9 — Valider `terraform plan` puis `terraform apply`.
- [ ] 3.1.10 — Stocker le state Terraform dans un backend distant chiffré (ou local chiffré SOPS, ou Terraform Cloud gratuit).

### 3.2 Configuration Ansible des VMs `[iac_delivery, iac_quality]`

- [ ] 3.2.1 — Initialiser `infra/ansible/` avec `ansible.cfg`, `requirements.yml`, structure d'inventaires.
- [ ] 3.2.2 — Créer les inventaires `inventories/s1/hosts.yml` et `inventories/s2/hosts.yml` (dynamiques via NetBox plus tard).
- [ ] 3.2.3 — Rôle `common` : mises à jour, utilisateurs, SSH keys, timezone, NTP, fail2ban, ufw/iptables baseline, auditd.
- [ ] 3.2.4 — Jouer `common` sur toutes les VMs.
- [ ] 3.2.5 — Vérifier l'idempotence : relancer, zéro change.

### 3.3 Installation NetBox `[network_ip_mngmt]`

- [ ] 3.3.1 — Rôle Ansible `netbox` : installation via Docker compose officiel ou installation native.
- [ ] 3.3.2 — Configurer le reverse proxy (Caddy ou Nginx) en front de NetBox avec HTTPS (certificat self-signed ou Let's Encrypt via DNS-01 si le domaine interne le permet).
- [ ] 3.3.3 — Créer les utilisateurs NetBox + tokens API (un par usage : Terraform, Ansible, webhook).
- [ ] 3.3.4 — Importer le plan d'adressage dans NetBox : sites, VLANs, prefixes, IP addresses, devices, VMs.
- [ ] 3.3.5 — Automatiser l'import via un script Python consommant `infra/ipam/plan.yaml` → API NetBox.
- [ ] 3.3.6 — Configurer les webhooks NetBox pour notifier un endpoint Ansible/AWX ou un job CI sur changement.
- [ ] 3.3.7 — Configurer un job périodique qui scanne Proxmox via son API et synchronise les VMs dans NetBox (détection de drift).
- [ ] 3.3.8 — Utiliser l'inventaire dynamique `netbox.netbox.nb_inventory` pour Ansible.
- [ ] 3.3.9 — Documenter la procédure dans `runbooks/netbox.md`.

### 3.4 Bastion host `[sec_bastion, sec_access]`

- [ ] 3.4.1 — Créer la VM bastion via Terraform (Debian minimale).
- [ ] 3.4.2 — Rôle Ansible `bastion` : durcissement SSH (port non-standard, `PermitRootLogin no`, `PasswordAuthentication no`, `MaxAuthTries 3`, clés only).
- [ ] 3.4.3 — Installer et configurer `fail2ban` avec jails SSH agressives.
- [ ] 3.4.4 — Installer `libpam-google-authenticator`, forcer MFA TOTP pour tous les users.
- [ ] 3.4.5 — Créer les comptes utilisateurs nommés (pas de compte partagé), chaque membre avec sa clé SSH et son TOTP.
- [ ] 3.4.6 — Configurer `sudoers` avec `NOPASSWD` réservé uniquement aux commandes non-admin strictement nécessaires.
- [ ] 3.4.7 — Activer `auditd` et logger toutes les commandes exécutées.
- [ ] 3.4.8 — Configurer le forward des logs vers Elasticsearch (via Filebeat).
- [ ] 3.4.9 — **Bonus** : mettre en place une CA SSH interne signant des certificats courte durée (2h) pour l'accès aux cibles.
- [ ] 3.4.10 — Tester : connexion depuis Internet → bastion (OK), connexion de bastion → serveurs internes via tunnel SSH (OK), connexion directe Internet → serveurs internes (KO).
- [ ] 3.4.11 — Documenter `runbooks/bastion-access.md` avec procédure de déclaration d'un nouvel utilisateur.

### 3.5 Site web interne `[network_spec1]`

- [ ] 3.5.1 — Choisir le stack du site web (nginx + site statique ou Python/Node simple, peu importe).
- [ ] 3.5.2 — Rôle Ansible `webapp` pour déployer le site sur la VM services S1.
- [ ] 3.5.3 — Configurer le reverse proxy interne pour exposer le site sur `web.s1.lan`.
- [ ] 3.5.4 — Vérifier que le site est uniquement accessible depuis VLAN LAN/USERS (pas DMZ, pas Internet).
- [ ] 3.5.5 — Tester l'accès depuis Site 2 via VPN : doit fonctionner.
- [ ] 3.5.6 — Tester l'accès depuis Internet : doit être refusé.
- [ ] 3.5.7 — Documenter la démonstrabilité : scripts de test `tests/connectivity/` qui prouvent l'isolement.

### 3.6 Preparation Follow-up 2

- [ ] 3.6.1 — Mettre à jour le Gantt et le backlog.
- [ ] 3.6.2 — Préparer les slides et la démo live : VPN up, DNS cross-site, NetBox rempli, site web accessible uniquement en interne.
- [ ] 3.6.3 — **Review 2** : présenter, blockers, prochains tickets.

---

## PHASE 4 — Observabilité complète (Semaines 6-8)

### 4.1 Elasticsearch + Kibana `[log_centralisation, log_observability]`

- [ ] 4.1.1 — Rôle Ansible `elasticsearch` (installation via APT officiel, single-node mode, sécurité activée).
- [ ] 4.1.2 — Configurer l'authentification (xpack.security) avec utilisateurs/rôles.
- [ ] 4.1.3 — Installer Kibana, le connecter à Elasticsearch.
- [ ] 4.1.4 — Reverse proxy HTTPS devant Kibana, accessible uniquement depuis ADMIN.
- [ ] 4.1.5 — Créer les ILM policies (index lifecycle management) pour retention 30/90 jours selon type.
- [ ] 4.1.6 — Documenter dans `runbooks/elastic.md`.

### 4.2 Collecte de logs partout `[log_centralisation]`

- [ ] 4.2.1 — Rôle Ansible `filebeat` déployé sur **toutes** les VMs Linux, modules system / auth / syslog activés.
- [ ] 4.2.2 — Configurer syslog remote sur les deux pfSense → Logstash (ou Filebeat).
- [ ] 4.2.3 — Installer Logstash sur la VM Elastic, pipelines dédiés :
  - pipeline `pfsense` : parser les logs filterlog (règles, actions, src/dst/port).
  - pipeline `ssh` : extraire les tentatives d'auth.
  - pipeline `netbox` : logs audit API.
  - pipeline `openvpn` : connexions, déconnexions, erreurs.
- [ ] 4.2.4 — Installer Metricbeat sur toutes les VMs : modules system, docker, postgresql, nginx.
- [ ] 4.2.5 — Connecter l'API Proxmox à Metricbeat (module `proxmox`).
- [ ] 4.2.6 — Vérifier que tous les logs arrivent dans Elastic (Discover Kibana).

### 4.3 Dashboards Kibana `[log_analysis, log_visuals]`

- [ ] 4.3.1 — Dashboard **Sécurité** : tentatives SSH top IP, règles pfSense bloquées top src/dst, événements OpenVPN, alertes fail2ban.
- [ ] 4.3.2 — Dashboard **Santé infra** : CPU/RAM/disk par VM, uptime, statut services critiques, IOPS disques Proxmox.
- [ ] 4.3.3 — Dashboard **Trafic VPN** : volume up/down, sessions actives, durée moyenne, latence inter-sites.
- [ ] 4.3.4 — Dashboard **Applicatif** : hits site web, requêtes API NetBox, queries Elastic lentes.
- [ ] 4.3.5 — Exporter les dashboards en JSON versionné (`infra/ansible/roles/kibana/files/dashboards/*.ndjson`) pour les rejouer.

### 4.4 Alerting `[log_observability]`

- [ ] 4.4.1 — Configurer Kibana Alerting (ou ElastAlert si version free) avec règles :
  - SSH brute force (>10 échecs en 5 min).
  - Tunnel VPN down > 2 min.
  - Disque > 85% sur n'importe quelle VM.
  - Spike règle fw (>100 hits/min sur une règle deny).
  - Service down (systemd status).
- [ ] 4.4.2 — Connecter les alertes à un webhook Discord/Slack/Mattermost.
- [ ] 4.4.3 — Tester chaque alerte en provoquant la condition.

### 4.5 Traces APM `[log_observability]`

- [ ] 4.5.1 — Installer Elastic APM Server.
- [ ] 4.5.2 — Instrumenter le site web interne avec l'agent APM correspondant (Python/Node/PHP).
- [ ] 4.5.3 — Vérifier que les traces remontent dans Kibana APM.
- [ ] 4.5.4 — Créer une vue APM dans le dashboard applicatif.

---

## PHASE 5 — Sécurité et résilience (Semaines 7-9)

### 5.1 Gestion des secrets `[sec_credentials]`

- [ ] 5.1.1 — Installer SOPS + age localement.
- [ ] 5.1.2 — Générer une clé `age` par membre de l'équipe, stocker les publiques dans `.sops.yaml`.
- [ ] 5.1.3 — Créer `secrets/` avec sous-fichiers chiffrés : `pfsense.yml`, `netbox.yml`, `elastic.yml`, `vpn-ca.yml`, `ssh-ca.yml`.
- [ ] 5.1.4 — Intégrer SOPS avec Ansible via `community.sops` plugin.
- [ ] 5.1.5 — Intégrer SOPS avec Terraform via provider `carlpett/sops`.
- [ ] 5.1.6 — Vérifier qu'aucun secret en clair n'est committé : ajouter `gitleaks` ou `detect-secrets` au pre-commit et au CI.
- [ ] 5.1.7 — Documenter `runbooks/secrets-management.md` avec rotation des clés.

### 5.2 Matrice RBAC et least privilege `[sec_access]`

- [ ] 5.2.1 — Créer `docs/access-matrix.md` tableau : qui accède à quoi, depuis quel réseau, avec quelle auth.
- [ ] 5.2.2 — Appliquer la matrice via pfSense (règles par interface + par source IP/alias).
- [ ] 5.2.3 — Appliquer côté Linux : groupes sudo dédiés, pas de root SSH, sudo granulaire.
- [ ] 5.2.4 — Appliquer côté NetBox : permissions par rôle, tokens limités à des scopes.
- [ ] 5.2.5 — Appliquer côté Elastic : spaces Kibana + role-based access.
- [ ] 5.2.6 — Audit : exécuter un scan avec `lynis` sur toutes les VMs, corriger les findings criticals.

### 5.3 Kill switch `[incident_killswitch]`

- [ ] 5.3.1 — Définir la stratégie : une règle floatante prioritaire sur les deux pfSense qui bloque tout le trafic traversant sauf l'admin local console.
- [ ] 5.3.2 — Créer l'alias pfSense `KILLSWITCH_ACTIVE` (0 ou 1) contrôlant l'activation de la règle.
- [ ] 5.3.3 — Créer un playbook `playbooks/killswitch.yml` avec tags `enable` / `disable` qui bascule l'alias via l'API pfSense.
- [ ] 5.3.4 — Tester : activer → plus aucun trafic inter-sites, Internet coupé sur LAN. Désactiver → retour nominal.
- [ ] 5.3.5 — S'assurer que l'admin Proxmox console reste accessible (accès out-of-band ou via interface ADMIN séparée).
- [ ] 5.3.6 — Documenter `runbooks/killswitch.md` avec quand l'activer, comment, comment récupérer.

### 5.4 Disaster Recovery Plan `[incident_recovery]`

- [ ] 5.4.1 — Créer `runbooks/disaster-recovery.md` structuré en 5 scénarios :
  - **DR-01** : perte complète Site 1.
  - **DR-02** : perte complète Site 2.
  - **DR-03** : compromission du bastion.
  - **DR-04** : corruption / perte de NetBox.
  - **DR-05** : perte du cluster Elastic.
- [ ] 5.4.2 — Pour chaque scénario, rédiger : déclencheurs de détection, actions immédiates (confinement), procédure de reconstruction step-by-step avec commandes exactes, critères de validation post-reprise, RTO cible.
- [ ] 5.4.3 — Backups : automatiser snapshots Proxmox hebdos, export config pfSense quotidien, dump NetBox DB quotidien, snapshot index Elastic.
- [ ] 5.4.4 — Stocker une copie des backups sur Site 2 (et vice-versa) via script rsync over VPN.
- [ ] 5.4.5 — Tester au moins le scénario **DR-04** (perte NetBox) en conditions réelles : supprimer la VM, rejouer Terraform + Ansible + restore DB, chronométrer.

### 5.5 Preparation Follow-up 3

- [ ] 5.5.1 — Mettre à jour Gantt et backlog.
- [ ] 5.5.2 — Préparer démo : kill switch live, accès bastion avec MFA, dashboards Kibana, alertes qui partent sur Discord.
- [ ] 5.5.3 — **Review 3 (Beta)** : présenter, recevoir feedback, ajuster.

---

## PHASE 6 — CI/CD et golden paths (Semaines 9-10) *(bonus traité comme obligatoire)*

### 6.1 Pipeline CI complet `[iac_quality + bonus]`

- [ ] 6.1.1 — Créer `.github/workflows/ci.yml` (ou `.gitlab-ci.yml`) avec stages :
  - **lint** : `tflint`, `terraform fmt -check`, `ansible-lint`, `yamllint`, `markdownlint`, `gitleaks`.
  - **validate** : `terraform validate`, `ansible-playbook --syntax-check` sur tous les playbooks.
  - **test** : Molecule sur rôles critiques (bastion, common, pfsense-config).
  - **plan** : sur PR vers develop/main, `terraform plan` posté en commentaire.
  - **deploy** : sur merge vers main, déploiement manuel avec approval (si env staging disponible).
- [ ] 6.1.2 — Configurer les secrets CI (token NetBox, creds Proxmox) via GitHub Secrets chiffrés.
- [ ] 6.1.3 — Ajouter un badge CI au `README.md`.

### 6.2 Golden paths `[bonus]`

- [ ] 6.2.1 — Finaliser le module Terraform `modules/site` paramétrable avec variables `site_id`, `site_cidr`, `vlan_map`, `wan_ip`.
- [ ] 6.2.2 — Finaliser un playbook master `site.yml` qui applique toute la config d'un site avec `--limit site_X`.
- [ ] 6.2.3 — Créer les golden templates NetBox (via Jinja2 + API) pour un nouveau site : pré-création des VLANs/prefixes.
- [ ] 6.2.4 — Créer le template de dashboard Kibana paramétré par `site_id`.
- [ ] 6.2.5 — Créer un template de règles pfSense (XML partiel) applicable à un nouveau site.

### 6.3 Multi-site readiness `[infra_scalability + bonus]`

- [ ] 6.3.1 — Rédiger `docs/onboarding-new-site.md` : procédure step-by-step pour ajouter un Site 3.
- [ ] 6.3.2 — Créer `sites/s3.tfvars.example` et `inventories/s3.template/`.
- [ ] 6.3.3 — Démonstration dry-run : lancer `terraform plan -var-file=sites/s3.tfvars.example` → tout le plan doit être généré correctement.
- [ ] 6.3.4 — Documenter les conventions d'adressage et la capacité max (combien de sites supportés par le plan actuel).

---

## PHASE 7 — Documentation finale et DRP (Semaines 10-11)

### 7.1 Documentation consolidée `[repo_doc]`

- [ ] 7.1.1 — `README.md` final : quickstart, liens vers toute la doc.
- [ ] 7.1.2 — `ARCHITECTURE.md` : vue d'ensemble, composants, flux, choix techniques.
- [ ] 7.1.3 — `docs/tech-choices.md` : justifications finales avec versions retenues.
- [ ] 7.1.4 — `docs/access-matrix.md` : matrice RBAC finalisée.
- [ ] 7.1.5 — `docs/ip-plan.md` : plan d'adressage complet avec allocations.
- [ ] 7.1.6 — `docs/onboarding-new-site.md` : procédure scalabilité.
- [ ] 7.1.7 — `runbooks/*.md` : tous les runbooks listés (VPN, DNS, NetBox, bastion, killswitch, DR, secrets).
- [ ] 7.1.8 — `docs/screenshots/` : captures d'écran de chaque service fonctionnel (pfSense, NetBox, Kibana dashboards, Proxmox VMs, alertes reçues).

### 7.2 Diagramme final `[diagram_delivery, diagram_quality]`

- [ ] 7.2.1 — Mettre à jour le diagramme d'architecture avec l'état final (IPs réelles, règles effectives, flux réels).
- [ ] 7.2.2 — Exporter en PNG haute résolution + PDF.
- [ ] 7.2.3 — Inclure dans le README et les slides.

### 7.3 Test complet DRP

- [ ] 7.3.1 — Planifier une session de test DR sur 2h.
- [ ] 7.3.2 — Détruire volontairement un composant (ex: VM NetBox) et chronométrer la reconstruction from scratch avec les runbooks.
- [ ] 7.3.3 — Ajuster les runbooks selon les frictions rencontrées.
- [ ] 7.3.4 — Enregistrer une vidéo courte de la reconstruction (bonus pour la keynote).

---

## PHASE 8 — Keynote (Semaine 11-12)

### 8.1 Slides keynote `[proj_presentation]`

- [ ] 8.1.1 — Plan des slides :
  1. Intro + équipe + scope.
  2. Problème client et contraintes.
  3. Architecture cible (diagramme final).
  4. Stack technique + justifications.
  5. Démonstration capacités : connectivité, sécurité, observabilité, scalabilité.
  6. Choix notables (kill switch, SSH CA, SOPS, etc.).
  7. Challenges rencontrés et résolution.
  8. DR et reproductibilité.
  9. Métriques projet (tickets, commits, couverture).
  10. Roadmap / améliorations futures.
  11. Q&A.
- [ ] 8.1.2 — Version markdown versionnée + export PDF.
- [ ] 8.1.3 — Screenshots soignés et annotés intégrés.

### 8.2 Démonstration live

- [ ] 8.2.1 — Scripter la démo (10-15 min) avec timing précis :
  - 1' — Tour du repo (structure, CI, PR merge récente).
  - 2' — NetBox : ajouter une IP, voir le webhook déclencher un job.
  - 2' — Connexion bastion avec MFA → bond vers une VM interne.
  - 2' — Kibana : parcourir 2 dashboards, montrer une alerte récente.
  - 2' — Kill switch : activer en live, montrer la perte de connectivité, désactiver.
  - 2' — Onboarding Site 3 : `terraform plan` dry-run.
  - 2' — Bilan.
- [ ] 8.2.2 — Préparer un plan B en cas de panne (vidéos pré-enregistrées de chaque démo).
- [ ] 8.2.3 — Répéter 3 fois minimum en conditions réelles.

### 8.3 Livrables keynote

- [ ] 8.3.1 — Zip final avec : repo complet tag `v1.0.0`, slides PDF, diagramme final, DRP.
- [ ] 8.3.2 — Lien de démo (URLs, credentials temporaires via password manager chiffré).
- [ ] 8.3.3 — Transmission aux instructeurs.

### 8.4 Keynote day

- [ ] 8.4.1 — Arriver 30 min avant, tester matériel.
- [ ] 8.4.2 — Présenter avec confiance, respecter le timing.
- [ ] 8.4.3 — Gérer le Q&A avec honnêteté (dire « on n'a pas implémenté X pour Y raison » plutôt que bluffer).
- [ ] 8.4.4 — Célébrer.

---

## Checklist finale de validation des critères

| Critère | Validé par |
|---|---|
| `infra_delivery` | Phase 2-3 complète |
| `infra_spec` | Phases 2-4 complètes |
| `infra_scalability` | Phase 6.3 |
| `infra_choices` | `docs/tech-choices.md` |
| `diagram_delivery` | Follow-up 1 + Keynote |
| `diagram_quality` | Phase 1.2 + Phase 7.2 |
| `iac_delivery` | Phases 3.1, 3.2, 6 |
| `iac_quality` | Pipeline CI + modularité Terraform/Ansible |
| `network_spec1` | Phase 3.5 + tests |
| `network_spec2` | Phase 3.4 + démo |
| `network_vpn` | Phase 2.3 |
| `network_firewall` | Phases 2.5, 5.2 |
| `network_dns` | Phase 2.4 |
| `network_ip_mngmt` | Phase 3.3 |
| `sec_access` | Phase 5.2 |
| `sec_bastion` | Phase 3.4 |
| `sec_credentials` | Phase 5.1 |
| `incident_killswitch` | Phase 5.3 |
| `incident_recovery` | Phases 5.4, 7.3 |
| `log_centralisation` | Phase 4.2 |
| `log_observability` | Phases 4.1, 4.4, 4.5 |
| `log_analysis` | Phase 4.3 |
| `log_visuals` | Phase 4.3 |
| `repo_practices` | Phase 0.3 |
| `repo_doc` | Phase 7.1 |
| `repo_content` | Continu |
| `proj_subdivision` | Phase 1.3 + updates |
| `proj_planning` | Phase 0.4 + updates |
| `proj_presentation` | Phases 1.4, 3.6, 5.5, 8 |
| **Bonus CI/CD** | Phase 6.1 |
| **Bonus Golden paths** | Phase 6.2 |
| **Bonus Multi-site** | Phase 6.3 |
| **Bonus Advanced monitoring** | Phases 4.3, 4.4, 4.5 |

---

## Règles d'or à garder en tête

1. **Documenter au fur et à mesure.** Chaque étape qui s'achève → commit doc + screenshot si visuel.
2. **Commits petits et fréquents.** Un commit = une intention. Messages descriptifs en conventional commits.
3. **Idempotence toujours.** Tout ce qui est IaC doit pouvoir être rejoué sans casse.
4. **Secrets jamais en clair.** Même dans les branches privées. Toujours SOPS.
5. **Tester ce qu'on présente.** Toute démo doit avoir été répétée au moins deux fois en conditions réelles.
6. **Traçabilité.** Chaque ticket fermé → référence au commit + mention du critère validé.
7. **Pas de dette cachée.** Un blocker non résolu → ticket ouvert + mention dans la review.
