# CIA — GR46 — Follow-up 3 (Beta) — Migration dev → école & configuration complète

**Date cible** : juin 2026
**Groupe** : GR46 · **École** : Epitech · **Projet** : T-NSA-810-REP25 — Deployment & Securing of a Hybrid Infrastructure with Proxmox

---

## 1. Objectif du Follow-up 3

Le Follow-up 2 a validé toute la chaîne **en environnement de développement** :
un Proxmox VE 8.4 imbriqué (nested VMware), trois VMs Site B *running*, secrets
SOPS+age opérationnels, CI verte, et un `terraform plan` idempotent.

Le Follow-up 3 a un objectif unique et mesurable :

> **Faire basculer l'infrastructure validée en dev vers l'environnement réel
> fourni par l'école (2 hôtes Proxmox, 6 VMs pré-allouées) et terminer la
> configuration complète des deux sites.**

Concrètement, à la fin du FW3 :

- les deux sites tournent sur le matériel Proxmox de l'école (plus de nested) ;
- les 6 VMs pré-allouées sont **réconciliées** dans le state Terraform (`import`),
  puis pilotées de façon déclarative ;
- les playbooks Ansible sont **réellement appliqués** (plus seulement
  `--syntax-check`) : pfSense, OpenVPN, NetBox, stack Elastic, bastion, DNS ;
- le **tunnel OpenVPN site-à-site** est monté et visible dans Kibana ;
- le tout reste piloté par Git (aucune action manuelle hors du dépôt).

---

## 2. Pourquoi le dev d'abord ? — la méthode GitOps

Ce n'est pas un détour : c'est la méthode. L'infrastructure est traitée comme
du logiciel. Git est la **source de vérité unique**, et toute promotion se fait
par paramètres, pas par réécriture.

**Principe.** Le même code (modules Terraform, rôles Ansible, pipelines
Logstash) décrit les deux environnements. Ce qui change entre dev et prod n'est
pas le code mais la **configuration injectée** : un fichier `*.tfvars`, un
inventaire `*.ini`, un bundle de secrets chiffré. On valide à bas risque sur le
dev, puis on rejoue exactement la même logique sur la prod en ne changeant que
ces entrées.

**Pourquoi c'est le bon choix ici.**

- **Réduction du risque.** Les 6 VMs de l'école sont une ressource partagée et
  limitée. On ne « teste » pas dessus : on y déploie un code déjà éprouvé. Le
  nested VMware a servi de bac à sable jetable où l'on a pu casser, recommencer,
  étendre le module `proxmox-vm` pour pfSense (FreeBSD) sans aucune conséquence.
- **Reproductibilité.** Un `terraform apply` et un `ansible-playbook` doivent
  produire le même résultat partout. Le passage dev → prod *prouve* cette
  promesse plutôt que de la postuler.
- **Traçabilité.** Chaque écart entre l'état désiré (Git) et l'état réel
  (Proxmox) est visible dans un `terraform plan`. La migration n'est pas un
  « big bang » : c'est une convergence contrôlée, lisible diff par diff.

**Conséquence pratique pour le FW3.** La migration n'est pas une réécriture.
C'est : (a) pointer les providers vers les endpoints de l'école, (b) importer
l'existant dans le state, (c) laisser Terraform et Ansible converger vers l'état
déclaré, (d) ajouter ce qui manque encore (tunnel, observabilité).

---

## 3. État de départ FW3

| Environnement | Rôle | État FW2 |
|---|---|---|
| Nested VMware (PVE 8.4, `192.168.208.50`) | Dev / bac à sable | 3 VMs running, validé, idempotent |
| Hôte Proxmox école #1 (PVE 9.1.x) | Prod — Site A cible | 6 VMs pré-allouées, à réconcilier |
| Hôte Proxmox école #2 (PVE 9.1.x) | Prod — Site B cible | inclus dans les 6 VMs, à réconcilier |

> **À renseigner dès l'accès** (voir `ansible/inventories/prod.ini.example` et
> `terraform/siteA/terraform.tfvars.example`) : endpoints API des deux nœuds,
> noms de nœuds, VMIDs des 6 VMs, IPs de management, datastore, ID des templates.

Ce qui est **déjà prêt et ne change pas** : les modules Terraform, les 11 rôles
Ansible, les pipelines Logstash, les configs pfSense/OpenVPN/DNS, les 7 runbooks,
le DRP.

Ce qui **change** : trois fichiers d'entrée par site (tfvars, inventaire,
secrets) + le passage de `--syntax-check`/`--check` à l'`apply` réel.

---

## 4. Plan de migration — phases et commandes

> Convention : toutes les commandes sont lancées depuis la racine du dépôt.
> Les valeurs entre `<…>` sont à remplacer par les valeurs réelles de l'école.
> Chaque phase se termine par une **preuve** (capture / sortie) à archiver dans
> `docs/demo/captures/`.

### Phase 0 — Reconnaissance & accès (J0)

Objectif : récupérer les paramètres réels et valider l'accès API.

```bash
# Sur chaque hôte Proxmox école (via la console web ou SSH) :
pveversion                 # confirmer 9.1.x
qm list                    # relever VMID, nom, statut des 6 VMs
pvesh get /nodes           # nom exact des nœuds
cat /etc/network/interfaces  # bridges existants (vmbrX)
```

Créer le user/token API dédié (droits `VM.Allocate`, `VM.Config.*`,
`Datastore.AllocateSpace`, `SDN.*`) — **à faire soi-même côté Proxmox**, ne
jamais committer le token en clair :

```bash
# Sur le Proxmox école, en root :
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role PVEVMAdmin
pveum user token add terraform@pve ci --privsep 0
```

> Preuve : `00-school-qm-list.png`, `00-school-pveversion.png`.

### Phase 1 — Secrets prod (J0)

Créer le bundle de secrets prod, chiffré dès la première seconde (jamais de
secret en clair sur le disque commité).

```bash
# Repartir du gabarit fourni :
cp secrets/school-prod.enc.yml.example /tmp/school-prod.plain.yml
# éditer /tmp/school-prod.plain.yml : token Proxmox, mots de passe, tokens NetBox/ES
sops --encrypt --age $(cat ~/.config/sops/age/keys.txt | grep public | cut -d' ' -f4) \
  /tmp/school-prod.plain.yml > secrets/school-prod.enc.yml
shred -u /tmp/school-prod.plain.yml     # détruire la version claire
sops -d secrets/school-prod.enc.yml | head   # vérifier le déchiffrement
```

> Preuve : `01-sops-decrypt-ok.png` (sortie déchiffrée, secrets masqués).

### Phase 2 — Pointer Terraform vers l'école & importer l'existant (J1)

C'est le cœur de la migration. On ne recrée rien : on **réconcilie**.

```bash
cd terraform/siteA
cp terraform.tfvars.example terraform.tfvars
# éditer terraform.tfvars : pve_endpoint, pve_node, VMIDs, datastore, templates

terraform init
terraform plan      # montre qu'il VEUT créer des VMs déjà existantes → normal avant import

# Importer chaque VM pré-allouée dans le state (à répéter pour les 6) :
terraform import 'module.vm["pfsense-s1"].proxmox_virtual_environment_vm.this' <NODE>/<VMID>
terraform import 'module.vm["services-s1"].proxmox_virtual_environment_vm.this' <NODE>/<VMID>
terraform import 'module.vm["observability-s1"].proxmox_virtual_environment_vm.this' <NODE>/<VMID>

terraform plan      # objectif : converger vers "No changes" ou diffs maîtrisés
```

Répéter pour `terraform/siteB`. Tout écart restant au `plan` est analysé : soit
on aligne le code sur le réel (drift voulu côté école), soit on laisse Terraform
corriger (drift non voulu).

> Preuve : `02-tf-import-state.png`, `03-tf-plan-converged.png`.

### Phase 3 — Réseau / bridges / SDN (J1)

Provisionner les bridges des deux sites via le module `network`, en important le
bridge de management existant pour ne pas couper l'accès (leçon du dev, blocage
B1).

```bash
cd terraform/siteA
# importer le bridge management AVANT d'appliquer, comme en dev :
terraform import 'module.network.proxmox_virtual_environment_network_linux_bridge.mgmt' <NODE>/vmbr0
terraform apply        # crée les bridges LAN/ADMIN/SERVICES manquants
```

> Preuve : `04-bridges-applied.png`.

### Phase 4 — Configuration Ansible réelle (J2-J3)

Passer de la validation à l'exécution. On déroule dans l'ordre de dépendance.

```bash
cd ansible

# 1. Base commune sur toutes les VMs Linux (users, sshd durci, auditd, fail2ban)
ansible-playbook -i inventories/prod.ini playbooks/site.yml --check    # dry-run d'abord
ansible-playbook -i inventories/prod.ini playbooks/site.yml            # apply réel

# 2. pfSense (règles firewall + interfaces) sur les deux sites
ansible-playbook -i inventories/prod.ini playbooks/siteA.yml --tags pfsense
ansible-playbook -i inventories/prod.ini playbooks/siteB.yml --tags pfsense

# 3. NetBox (IPAM) + seed du plan d'adressage
ansible-playbook -i inventories/prod.ini playbooks/siteA.yml --tags netbox

# 4. Stack Elastic (ES + Kibana + Logstash + Filebeat)
ansible-playbook -i inventories/prod.ini playbooks/elastic.yml

# 5. Bastion SSH (MFA TOTP + audit)
ansible-playbook -i inventories/prod.ini playbooks/bastion.yml
```

> Preuve : `05-ansible-site-recap.png` (récap `ok/changed/failed=0`),
> `06-netbox-ui.png`, `07-kibana-up.png`, `08-bastion-mfa.png`.

### Phase 5 — Tunnel OpenVPN site-à-site (J3)

Une fois les deux pfSense configurés, monter le tunnel et vérifier le
re-handshake côté Kibana.

```bash
cd ansible
ansible-playbook -i inventories/prod.ini playbooks/vpn.yml
# vérifier la connectivité inter-sites à travers le tunnel :
ansible -i inventories/prod.ini services-s1 -m ping     # via 172.16.0.0/30
```

> Preuve : `09-vpn-tunnel-up.png` (status OpenVPN pfSense + ping inter-site).

### Phase 6 — Vérification de bout en bout (J4)

```bash
# idempotence : un second apply ne change rien
cd terraform/siteA && terraform plan        # "No changes"
cd ../../ansible && ansible-playbook -i inventories/prod.ini playbooks/site.yml --check  # changed=0

# killswitch (démo sécurité)
ansible-playbook -i inventories/prod.ini playbooks/killswitch.yml -e killswitch_state=active -e site=siteB
# curl depuis le LAN → bloqué, puis revert
ansible-playbook -i inventories/prod.ini playbooks/killswitch.yml -e killswitch_state=inactive -e site=siteB
```

> Preuve : `10-tf-plan-nochanges-prod.png`, `11-killswitch-demo.png`.

### Phase 7 — Documentation & clôture (J4-J5)

- Mettre à jour `docs/STATUS.md` : runtime 55% → ~95%, tout passe en ✅ Live.
- Rédiger `docs/demo/fw3-demo-walkthrough.md` (même format que FW2 :
  capture + explication pour étudiant débutant).
- Cocher cette checklist, tagger `fw3-2026-06` (déclenche `release.yml`).

---

## 5. Critères d'évaluation couverts par le FW3

| Attendu | Preuve FW3 |
|---|---|
| Infra réellement déployée (pas seulement décrite) | Phases 2-5, captures runtime école |
| Configuration complète des deux sites | Phase 4, récaps Ansible |
| Tunnel site-à-site fonctionnel | Phase 5, status OpenVPN + ping inter-site |
| Centralisation des logs opérationnelle | Phase 4.4, Kibana avec logs réels |
| IPAM source de vérité | Phase 4.3, NetBox seedé depuis `addressing.yml` |
| Idempotence / reproductibilité | Phase 6, `plan`=No changes, `--check`=changed=0 |
| Sécurité démontrée live | Phase 4.5 + 6, bastion MFA, killswitch |

---

## 5b. Décision de design FW3 — services-s2 fait double duty (services + bastion)

Pendant l'apply de FW3, l'installation Ubuntu de la VM dédiée `bastion-s2` a
buté deux fois sur un bug subiquity (erreurs internes au démarrage du clavier
ou de l'install OpenSSH). Plutôt que de bloquer l'avancée du Follow-up 3
sur cette friction, nous avons pris la décision documentée suivante :

**`services-s2` joue temporairement le rôle de "services + bastion"** pour la
durée du FW3. Cette décision est explicite et traçable :

- Le rôle Ansible `bastion` est appliqué sur `services-s2` avec deux toggles
  désactivés (`bastion_mfa_enabled=false`, `bastion_sshd_override=false`),
  ajoutés dans la version FW3 du rôle. Cela évite tout risque de lockout
  tout en posant 80 % des fonctionnalités bastion.
- Ce qui est appliqué : banner d'accès restreint, fail2ban *aggressive jail*
  (ban 24 h, `maxretry=3`), auditd bastion-rules (tracking execve des users,
  log tamper, ssh config), forward syslog chiffré vers Elastic, paquets MFA
  préinstallés (`libpam-google-authenticator`).
- Ce qui est reporté à la keynote finale : activation effective de la MFA TOTP
  (le rôle l'active dès `bastion_mfa_enabled=true`), séparation propre sur la
  VM `bastion-s2` dédiée (séparation des préoccupations), enrôlement TOTP
  des admins via le script `/usr/local/bin/setup-mfa`.

**Pourquoi c'est défendable** : la fonction bastion ne disparaît pas, elle est
co-hébergée avec services-s2 pour FW3, code et conf prêts à migrer sur une
VM dédiée par un simple `terraform import` + `ansible-playbook bastion.yml`
côté Final.

## 5c. Tentative NetBox sur services-s2 (FW3) — bloquée disque

Pendant FW3, nous avons tenté de déployer NetBox (IPAM) sur `services-s2`
via le rôle Ansible `netbox`. Le rôle s'est exécuté correctement jusqu'à
l'extraction des images Docker, où il a buté sur **`no space left on device`** :

- Disque actuel de `services-s2` : **10 Go**, 100 % utilisé après install
  Ubuntu base + paquets common/bastion + Docker CE (920 Mo) + clone
  `netbox-docker` + images partielles (~6 Go).
- Images requises pour la stack NetBox complète : ~5 Go supplémentaires
  (postgres, valkey, netbox v4.6).
- **Permissions école** : le user `GR46@pve` n'a pas les droits
  `Datastore.AllocateSpace` pour faire `qm resize 2046 scsi0 +20G` depuis
  l'interface web Proxmox ni depuis le shell. Le redimensionnement
  nécessite une action admin école.

**Améliorations apportées au rôle dans la branche FW3** :

- Installation de Docker depuis le **repo officiel** (Ubuntu 24.04 noble)
  au lieu de `docker.io` + `docker-compose-plugin` (qui n'existe pas dans
  les repos par défaut sur noble).
- Toggle `netbox_seed_enabled` (défaut `true`) pour permettre l'apply
  sans le seed automatique du plan d'adressage (utile quand WSL ne route
  pas vers la LAN école).

**Plan pour la keynote finale** : (1) demande admin école pour resize
disque services-s2 à 30 Go, OU déploiement de NetBox sur `services-s1`
(Site A, qui aura plus d'espace), (2) re-lancer `playbooks/netbox-services-s2.yml`
(rôle corrigé) en mode `--check` d'abord puis apply, (3) capture UI + sites
+ préfixes seedés depuis `networking/addressing.yml`.

## 5d. Bonus Site C — extension cloud hybride sur Microsoft Azure

Pour démontrer la capacité GitOps à étendre l'infrastructure hybride au cloud
public, un troisième site `siteC-azure` a été conçu et codé en Terraform :

- Module complet `terraform/siteC-azure/` (5 fichiers, ~250 lignes) avec
  provider `azurerm`, Resource Group + VNet (`10.3.0.0/16`) + Subnet public
  + NSG (firewall as code : SSH 22, OpenVPN 1194/UDP, HTTPS 443, Kibana
  5601) + Public IP statique + NIC + VM Linux Ubuntu 22.04 LTS.
- Cloud-init pré-installant Docker CE depuis le repo officiel.
- 12 checks `checkov` PASSED, 3 skips inline avec justification engineering
  (CKV_AZURE_10 SSH bastion design, CKV_AZURE_50 false-positive cloud-init,
  CKV_AZURE_119 public IP par design pour OpenVPN server).
- Architecture cible : Site C héberge NetBox + stack Elastic (Elasticsearch
  + Kibana + Logstash) + bastion SSH + OpenVPN server pour tunnel
  inter-sites Site B (client) → Site C (server).

**État runtime** : `terraform plan` validé (8 ressources, 0 erreur), `terraform
apply` partiellement déployé (RG + VNet + Subnet + NSG + Public IP + NIC
créés avec succès), provisioning final VM bloqué par les **quotas Azure for
Students** (SKU `Standard_B2s` et `Standard_B2as_v2` non disponibles dans les
5 régions autorisées par la politique étudiante : `germanywestcentral`,
`polandcentral`, `francecentral`, `spaincentral`, `italynorth`).

**Mitigation en production** : ouvrir un ticket Azure Support pour quota
increase B-series VMs sur la région cible. Délai habituel 24-72h, sans
coût additionnel sous Students subscription. Le code Terraform est sans
modification : un seul `terraform apply` suffit dès le quota libéré.

**Observabilité runtime pour la keynote finale** : stack Elastic +
Kibana déployée localement en Docker compose dans WSL pour démontrer la
chaîne complète Filebeat (services-s2) → Logstash → Elasticsearch → Kibana
via SSH reverse tunnel. C'est la même architecture, mais hébergée
provisoirement sur le poste de pilotage en attendant le déblocage du quota
Azure.

## 6. Bonus (si le temps le permet, après la migration)

Ces objectifs étaient le cœur de l'ancien plan FW3 ; ils deviennent du **bonus**
une fois la migration faite. À ne lancer qu'après la Phase 7.

| Bonus | Engagement |
|---|---|
| Exercice DRP réel | Jouer le scénario #1 (perte VM `services-s1`) en live, preuve vidéo |
| Alerting (monitoring avancé) | Règles Kibana → webhook Slack `#cia-alerts` |
| Multi-site horizontal | POC Site C en un `terraform apply` (sandbox) |
| Rotation PKI OpenVPN | `scripts/rotate-openvpn.sh` + cron trimestriel |
| Hardening supplémentaire | Profils AppArmor + USBGuard |
| Performance Elastic | Benchmark ingestion 10 k EPS |

---

## 7. Métriques visées FW3

| Métrique | Cible |
|---|---|
| Migration dev → école (terraform import + converge) | < 1 journée |
| `terraform plan` prod idempotent | "No changes" |
| `ansible-playbook site.yml --check` post-apply | `changed=0` |
| Tunnel OpenVPN up (re-handshake) | < 30 s après `vpn.yml` |
| Log → visible Kibana | < 10 s |
| Restauration config pfSense depuis Git | < 10 min |

---

## 8. Risques & parades

| Risque | Parade |
|---|---|
| VMs école dans un état imprévu (drift fort) | `terraform import` + `plan` avant tout apply ; aligner le code si besoin |
| Token API insuffisant (droits SDN/Datastore) | Vérifier les rôles PVE en Phase 0 avant de commencer |
| Couper le management en touchant `vmbr0` | Importer le bridge mgmt avant `apply` (leçon dev) |
| Templates absents sur les nœuds école | Cloner/importer les templates en Phase 0 (Ubuntu + pfSense) |
| Indispo créneau data-room | Tout est scriptable : rejouable en une session courte |

---

## 9. Dépendances externes

- Accès SSH + API aux deux hôtes Proxmox de l'école, avec un token dédié.
- Permissions `GR46@pve` / `terraform@pve` suffisantes (cf Phase 0).
- Valentin disponible pour la validation finale FW3.

---

## 10. Livrables après FW3 → Final

- `docs/demo/fw3-demo-walkthrough.md` (captures + explications).
- `docs/STATUS.md` à ~95% runtime.
- Keynote finale (`docs/backlog/keynote.md` → deck `pptx`).
- Vidéo démo (3 min) : migration + tunnel + killswitch.
- `CRITERES.md` à jour avec preuves runtime.

---

*GR46 — CIA Epitech 2025-2026 — Plan vivant, mis à jour à chaque phase FW3.*
