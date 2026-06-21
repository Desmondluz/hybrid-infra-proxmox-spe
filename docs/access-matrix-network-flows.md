# Matrice de flux réseau — CIA (détaillée, justifiée)

**Propriétaire** : GR46 · **Version** : 1.0 · **Dernière revue** : 2026-06-20
**Périmètre** : runtime école (Site A + B) + extension cloud Site C Azure

Ce document complète [`access-matrix.md`](access-matrix.md) (vue zone à zone)
en exposant **chaque flux réseau autorisé** ligne par ligne, avec sa
**justification métier** et son **application du principe de moindre
privilège**. Il sert de référence pour défendre les règles pfSense au jury et
aux auditeurs sécurité.

Les flux non listés explicitement comme ✔ ALLOW sont **implicitement ✘ DENY**
par la politique « default deny » de pfSense.

---

## 1. Inventaire des composants (adressage réel école + cloud)

| Composant         | Site | Zone     | IP runtime          | Rôle fonctionnel                              |
|-------------------|------|----------|---------------------|-----------------------------------------------|
| pfSense WAN A     | A    | A-W      | `5.196.50.70`       | Firewall + OpenVPN server + NAT entrant       |
| pfSense LAN A     | A    | A-L      | `10.1.0.1/24`       | Passerelle Site A                             |
| services-s1       | A    | A-L      | `10.1.0.101`        | NetBox + webapp interne (Ansible queued)      |
| observability-s1  | A    | A-L      | `10.1.0.100`        | Elastic stack ES+Kibana+Logstash (queued)     |
| pfSense WAN B     | B    | B-W      | `5.196.50.60`       | Firewall + OpenVPN client (vers A ou C)       |
| pfSense LAN B     | B    | B-L      | `10.2.0.1/24`       | Passerelle Site B                             |
| services-s2       | B    | B-L      | `10.2.0.101`        | Services + bastion-lite (runtime FW3)         |
| bastion-s2        | B    | B-L      | `10.2.0.10` (cible) | Bastion dédié MFA (install queued)            |
| Site C pip        | C    | C-W      | dynamique (Azure)   | OpenVPN server + bastion + NetBox + Elastic   |
| Site C VM         | C    | C-L      | `10.3.1.0/24`       | VM Ubuntu 22.04 Standard_B2as_v2 (queued)     |
| Tunnel VPN A↔B    | —    | VPN      | `172.16.0.0/30`     | Point-to-point chiffré AES-256-GCM            |
| Tunnel VPN B↔C    | —    | VPN-C    | `172.16.1.0/30`     | Point-to-point Site B (client) ↔ C (server)   |
| Poste pilotage    | —    | EXT      | IP publique dyn.    | WSL Ubuntu, Ansible, Terraform                |

---

## 2. Conventions

- **Direction** : `→` initié par la source, retour stateful implicite.
- **Justification** : raison métier + principe de moindre privilège appliqué.
- **Ref Ansible** : pointe vers la règle déclarative dans
  `ansible/roles/pfsense/defaults/main.yml` (section `pfsense_rules`).
- **Risque résiduel** : ce qu'un attaquant pourrait faire si la règle est
  exploitée, mitigation associée.

---

## 3. Matrice détaillée — flux autorisés

### 3.1 Entrée Internet → infrastructure (publique)

| # | Source              | Destination          | Port/Proto    | Motif                                            | Justification moindre privilège                                                                  | Ref Ansible           |
|---|---------------------|----------------------|---------------|--------------------------------------------------|--------------------------------------------------------------------------------------------------|-----------------------|
| 1 | Internet (any)      | `5.196.50.60:22`     | TCP           | SSH management pfSense Site B                    | Authentification par clé ed25519 uniquement (PasswordAuth off), fail2ban 3/24h, admin renommé    | `server-side` rule SSH |
| 2 | Internet (any)      | `5.196.50.60:443`    | TCP           | OpenVPN client out vers Site A (sortant via WAN) | Stateful return uniquement, pas de listener inbound côté Site B. TCP 443 = OpenVPN-over-HTTPS pattern (cf. runbooks/vpn.md §1bis) | `client-side` allow VPN out |
| 3 | Internet (any)      | `5.196.50.70:443`    | TCP           | OpenVPN server Site A (accepte clients)          | TLS-crypt activé, CA dédiée projet CIA, tls-auth 0/1, cipher AES-256-GCM. TCP 443 traverse firewall école (cf. runbooks/vpn.md §1bis) | `server-side` allow VPN in |
| 4 | Internet (any)      | `5.196.50.70:22`     | TCP           | SSH management pfSense Site A (à débloquer)      | Idem #1. **Actuellement bloqué en amont par opérateur école, demande admin en cours.**           | `server-side` rule SSH |
| 5 | Internet (any)      | `<pip-siteC>:22`     | TCP           | SSH bastion Site C Azure                         | Clé RSA 4096 (admin_ssh_key Azure), MFA TOTP, NSG restreint, fail2ban                            | `roles/bastion` MFA   |
| 6 | Internet (any)      | `<pip-siteC>:443`    | TCP           | OpenVPN server Site C (accepte client Site B)    | TLS-crypt, NSG Azure NSG allow-openvpn (priorité 110). TCP 443 cohérent avec pattern global       | NSG `azurerm_nsg`     |
| 7 | Internet (any)      | `<pip-siteC>:443`    | TCP           | HTTPS NetBox UI (Caddy reverse proxy)            | TLS interne (Caddy `tls internal`), authentification NetBox SSO, audit access log                | NSG allow-https       |
| 8 | Internet (any)      | `<pip-siteC>:5601`   | TCP           | HTTPS Kibana UI (démo observabilité jury)        | Authentification basique (à renforcer post-keynote), TLS reverse proxy                           | NSG allow-kibana      |

### 3.2 Pilotage (poste développeur) → infrastructure

| #  | Source              | Destination          | Port/Proto | Motif                                       | Justification moindre privilège                                                       | Ref Ansible            |
|----|---------------------|----------------------|------------|---------------------------------------------|---------------------------------------------------------------------------------------|------------------------|
| 9  | EXT (WSL desmon)    | `5.196.50.60:22`     | TCP        | Ansible ProxyJump vers Site B LAN           | Clé `cia_gr46`, audit log auditd `execve`, sudo NOPASSWD limité au groupe `sudo`       | inventory `prod.ini`   |
| 10 | EXT (WSL desmon)    | `<pip-siteC>:22`     | TCP        | Ansible ProxyJump vers Site C VNet (futur)  | Clé `cia_gr46_azure` (RSA 4096 Azure-compat), audit syslog forward                     | inventory `prod.ini`   |
| 11 | EXT (WSL desmon)    | GitHub `git@github.com:443` | TCP | Push / pull repo Ansible+Terraform          | SSH key ed25519 dédiée, MFA GitHub                                                    | n/a (workflow git)     |

### 3.3 Bastion-jump → LAN interne (post-bastion auth)

| #  | Source              | Destination          | Port/Proto | Motif                                       | Justification moindre privilège                                                       | Ref Ansible            |
|----|---------------------|----------------------|------------|---------------------------------------------|---------------------------------------------------------------------------------------|------------------------|
| 12 | pfSense B (admin)   | `10.2.0.101:22`      | TCP        | SSH ProxyJump vers services-s2              | ControlMaster SSH côté pilote, sudo NOPASSWD `desmon`, auditd capture des exec        | `bastion` group        |
| 13 | bastion-s2 (cible)  | `10.2.0.0/24:22`     | TCP        | Jump host vers toutes VMs LAN Site B        | Bastion isolé du reste, AllowUsers limité, port 2222 (DNAT), MFA TOTP requis          | `roles/bastion`        |
| 14 | services-s1 (jump)  | `10.1.0.0/24:22`     | TCP        | (Futur) jump host LAN Site A                | Idem, queued après déblocage SSH externe Site A                                       | `roles/bastion`        |
| 15 | Site C VM           | `10.3.1.0/24:*`      | TCP/UDP    | Trafic interne VNet Site C                  | NSG limite à intra-VNet par défaut                                                    | NSG default            |

### 3.4 LAN → SERVICES (intra-site, applicatif)

| #  | Source              | Destination          | Port/Proto | Motif                                       | Justification moindre privilège                                                       | Ref Ansible            |
|----|---------------------|----------------------|------------|---------------------------------------------|---------------------------------------------------------------------------------------|------------------------|
| 16 | LAN Site B `10.2.0.0/24` | `<services-s2>:443` | TCP | Accès NetBox UI (futur)                     | Authentification SSO NetBox, RBAC lecture par défaut, écriture limitée admin          | `roles/netbox`         |
| 17 | LAN Site A `10.1.0.0/24` | `10.1.0.40:9200`    | TCP | Ingest Elasticsearch depuis Filebeat        | Mutual TLS prévu v2, actuellement HTTP intra-LAN seulement (pas exposé WAN)           | `roles/filebeat`       |
| 18 | LAN Site A `10.1.0.0/24` | `10.1.0.40:5044`    | TCP | Beats → Logstash                            | Idem, intra-LAN seulement, persistence queue Filebeat si Logstash down                 | `roles/filebeat`       |
| 19 | LAN Site A `10.1.0.0/24` | `10.1.0.40:5601`    | TCP | Kibana UI                                   | Authentification basique, futur Entra ID via Site C                                   | `roles/kibana`         |
| 20 | LAN Site B `10.2.0.0/24` | `10.2.0.1:53`       | UDP | DNS récursif via pfSense unbound            | unbound configuré en récursif, pas de transfert zone vers Internet                    | `roles/dns-forwarder`  |

### 3.5 Inter-sites via tunnel VPN chiffré

| #  | Source              | Destination          | Port/Proto    | Motif                                       | Justification moindre privilège                                                       | Ref Ansible            |
|----|---------------------|----------------------|---------------|---------------------------------------------|---------------------------------------------------------------------------------------|------------------------|
| 21 | services-s2 (`10.2.0.101`) | `10.1.0.40:5044` | TCP via VPN | Forward logs Filebeat vers Logstash Site A  | Tunnel AES-256-GCM, jamais en clair sur Internet, IP source restreinte               | `vpn.yml` + filebeat   |
| 22 | services-s1 (`10.1.0.101`) | `10.2.0.101:443` | TCP via VPN | Accès NetBox côté Site B                    | Authentification + chiffrement bout en bout                                          | `vpn.yml`              |
| 23 | pfSense A (`172.16.0.1`) | pfSense B (`172.16.0.2`) | TCP 443 + ICMP | Maintenance tunnel + monitoring          | tls-crypt clé partagée, rotation trimestrielle planifiée. TCP 443 (cf. runbooks/vpn.md §1bis)        | `roles/openvpn`        |
| 24 | services-s2 (`10.2.0.101`) | `<siteC-vm>:5044` | TCP via VPN-C | Forward logs vers Elastic Site C (futur)  | Idem #21, mais bascule cloud comme alternative observability-s1                       | `roles/openvpn` client |

### 3.6 Sortie Internet contrôlée (NAT WAN)

| #  | Source              | Destination          | Port/Proto    | Motif                                       | Justification moindre privilège                                                       | Ref Ansible            |
|----|---------------------|----------------------|---------------|---------------------------------------------|---------------------------------------------------------------------------------------|------------------------|
| 25 | LAN Site B `10.2.0.0/24` | Internet `0.0.0.0/0:443` | TCP | HTTPS sortant (mises à jour, GitHub, APT) | Stateful, NAT masquerade pfSense, killswitch override possible                        | `client-side` rules    |
| 26 | LAN Site B `10.2.0.0/24` | Internet `0.0.0.0/0:80`  | TCP | HTTP sortant (mirror APT)                  | Idem, à durcir vers HTTPS-only v2                                                     | `client-side` rules    |
| 27 | LAN Site B `10.2.0.0/24` | Internet `0.0.0.0/0:53`  | UDP | DNS sortant si unbound forward désactivé   | Idem                                                                                  | `client-side` rules    |
| 28 | Site C VM           | Internet `0.0.0.0/0:*`  | TCP/UDP | Updates Ubuntu + Docker pull + Azure metadata | NSG Azure egress par défaut, restrictions par tags possibles v2                       | NSG default            |

---

## 4. Flux EXPLICITEMENT INTERDITS (renforce moindre privilège)

| #  | Source              | Destination          | Port/Proto    | Pourquoi interdire                                                                                       |
|----|---------------------|----------------------|---------------|----------------------------------------------------------------------------------------------------------|
| X1 | Internet (any)      | `10.1.0.0/24:*`      | tout          | Pas d'accès direct LAN A depuis Internet — passage obligatoire par tunnel VPN ou bastion                 |
| X2 | Internet (any)      | `10.2.0.0/24:*`      | tout          | Idem pour LAN B                                                                                          |
| X3 | LAN A → LAN B       | tout (hors VPN)      | tout          | Inter-LAN sans passer par le tunnel chiffré = fuite potentielle de logs en clair                          |
| X4 | Filebeat clients    | `10.1.0.40:9200`     | TCP (HTTP)    | Pas d'accès direct ES depuis VMs hors LAN — passe par Logstash:5044 pour transformation                  |
| X5 | LAN A `10.1.0.0/24` | Internet `*:23, 21, 3389` | TCP    | Telnet, FTP, RDP — protocoles obsolètes ou non chiffrés, blocage explicite                                |
| X6 | LAN B `10.2.0.0/24` | `10.2.0.1:80, 22`    | TCP           | Pas d'accès admin pfSense depuis LAN (forcer passage par bastion ou WAN admin)                           |
| X7 | Site C VNet         | LAN A/B directement (hors VPN) | tout | Tout cross-site doit passer par tunnel chiffré, jamais via Internet direct                                |
| X8 | services-s2 → Internet `*:53` | UDP | tout | DNS résolu uniquement via pfSense unbound (10.2.0.1), pas de bypass DNS                                  |

---

## 5. Override Killswitch (sécurité d'isolation)

Quand le killswitch est activé sur un site (cf. `playbooks/killswitch.yml`),
**tous les flux ✔ ALLOW de la matrice sont FORCÉS à ✘ DENY pour la direction
outbound WAN** sur ce site. Effet immédiat :

- Lignes #25, #26, #27, #28 → bloquées (plus de sortie Internet).
- Ligne #2 (OpenVPN client out Site B) → bloquée si le killswitch est sur
  Site B (rupture du tunnel volontaire).
- Lignes intra-LAN (#16-#20) → préservées (pas de coupure de service local).

C'est exactement ce que le sujet CIA appelle un **mécanisme d'isolation
rapide** : bouclier descendu, l'infra continue à tourner en interne, mais
plus rien ne sort.

---

## 6. Synchronisation avec le code Ansible

Chaque ligne de cette matrice se traduit en règle déclarative dans
[`ansible/roles/pfsense/defaults/main.yml`](../ansible/roles/pfsense/defaults/main.yml)
au format :

```yaml
- type: pass
  interface: <wan|lan|openvpn>
  ipprotocol: inet
  protocol: <tcp|udp|any>
  source: "<CIDR ou any>"
  destination: "<IP cible>"
  destination_port: "<port>"
  descr: "GR46-FW3 : <motif>"
```

et est ensuite appliquée via `ansible-playbook playbooks/siteA.yml --tags
pfsense` (resp. `siteB.yml`) qui pousse les règles via l'API REST pfSense.

**Garantie d'alignement** : un job CI v2 comparera le `pfctl -sr` exporté
en direct depuis chaque pfSense aux règles attendues, et lèvera une issue
GitHub auto-assignée si écart détecté.

---

## 7. Procédure d'ajout / modification d'un flux

Toute modification de cette matrice suit ce workflow :

1. **PR GitHub** sur la branche `feat/flow-<nom>` modifiant à la fois
   `docs/access-matrix-network-flows.md` + `roles/pfsense/defaults/main.yml`.
2. **Revue obligatoire par le Security Lead** GR46 (validation moindre
   privilège, conformité PRA, impact killswitch).
3. **CI verte** (markdownlint, ansible-lint, terraform_validate).
4. **Apply contrôlé** via `ansible-playbook playbooks/siteA.yml --tags
   pfsense --check --diff` d'abord, puis vraie passe en fenêtre de
   maintenance.
5. **Test post-apply** : ping/curl ciblé pour valider le nouveau flux + ping
   ciblé pour valider que les flux interdits le sont toujours.
6. **Mise à jour matrice + revue** dans `docs/access-matrix.md` (vue zone).

---

## 8. Historique

| Date        | Auteur | Changement                                                                       |
|-------------|--------|----------------------------------------------------------------------------------|
| 2026-06-20  | GR46   | Création — matrice flux détaillée justifiée, adressage réel école + Site C Azure |
