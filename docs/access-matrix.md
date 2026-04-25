# Matrice d'accès — CIA

**Propriétaire** : GR46 · **Dernière revue** : 2026-04-18

Cette matrice formalise les flux autorisés entre zones. Elle est la
traduction lisible des règles pfSense (voir `configs/pfsense/*.xml`) et
fait foi en cas d'écart.

Notation : `✔ ALLOW · ✘ DENY · ⚠ conditional`.

## 1. Zones

| Code | Zone                                     | Réseau              |
|------|------------------------------------------|---------------------|
| A-L  | Site A · LAN (clients, services internes)| 10.10.0.0/24        |
| A-M  | Site A · ADMIN (management)              | 10.10.10.0/24       |
| A-W  | Site A · WAN                             | public              |
| B-L  | Site B · LAN                             | 192.168.0.0/24      |
| B-S  | Site B · SERVICES                        | 192.168.10.0/24     |
| B-W  | Site B · WAN                             | public              |
| VPN  | Tunnel site-à-site                       | 172.16.0.0/30       |
| INT  | Internet public                          | 0.0.0.0/0           |

## 2. Matrice LAN ↔ zones

```
FROM \ TO   A-L   A-M   A-W   B-L   B-S   INT
A-L          ✔     ✘    ✔80/443 ✔     ✘    ✔80/443
A-M          ✔     ✔     ✔     ✔     ✔     ✔
A-W          ⚠1    ✘     —     ✘     ✘     —
B-L          ✔     ✘     ✔80/443 ✔     ✘    ✔80/443
B-S          ✔     ✔     ✔     ✘     ✔     ✔80/443
INT          ⚠2    ✘     —     ⚠3    ✘     —
```

**Conditions :**

- ⚠1 (A-W → A-L) : uniquement trafic retour (stateful) des connexions
  sortantes initiées depuis A-L.
- ⚠2 (INT → A-L) : **refusé sauf** trafic UDP/1194 OpenVPN vers pfsense-s1
  et retour stateful.
- ⚠3 (INT → B-L) : **refusé sauf** NAT WAN:2222 → `192.168.10.10:22`
  (bastion SSH).

## 3. Matrice SERVICES ↔ RÔLES

| Service           | Zone source autorisée                 | Port        |
|-------------------|---------------------------------------|-------------|
| NetBox UI         | A-L, A-M, B-L via VPN, B-S via VPN    | TCP 443     |
| NetBox API        | A-M, B-S via VPN                      | TCP 443     |
| Kibana            | A-L, A-M, B-S via VPN                 | TCP 443     |
| Elasticsearch API | logstash localhost + filebeat clients | TCP 9200    |
| Logstash beats    | toutes VM Linux CIA                   | TCP 5044    |
| Logstash syslog   | pfSense A + pfSense B via VPN         | UDP 5514    |
| Bastion SSH       | INT → NAT 2222                        | TCP 2222    |
| SSH interne       | A-M, B-S (via bastion)                | TCP 22      |
| DNS résolveur     | A-L, A-M, B-L, B-S                    | UDP 53      |

## 4. Matrice RÔLES / UTILISATEURS

| Utilisateur       | Ressources                             | Authentification          |
|-------------------|----------------------------------------|---------------------------|
| `admin` (GR46)    | Proxmox, pfSense, Vault root           | SSH key + TOTP            |
| `ops`             | Ansible runs, Vault policies `pfsense` | SSH key + TOTP bastion    |
| `netbox-ro`       | NetBox UI lecture                      | SSO local                 |
| `terraform-ci`    | Provider Proxmox + Vault policy proxmox| Token CI scoped           |
| Service `filebeat`| Logstash:5044                          | Mutual TLS (v2)           |

## 5. Killswitch

Quand `KILLSWITCH_ACTIVE` non vide sur un pfSense, la règle floating
prioritaire bloque tout trafic sortant WAN. Effet : matrice §2 colonnes
`A-W`, `B-W`, `INT` forcées à `✘` pour le site concerné.

## 6. Écarts détectés

Tout écart entre cette matrice et les règles pfSense effectives doit être
rapporté dans GitHub Issues (template `task.md`). La CI compare via
`pfctl -sr` vs règles attendues (workflow v2).

## 7. Historique

| Date        | Change                                    |
|-------------|-------------------------------------------|
| 2026-04-18  | Version initiale post follow-up #1        |
