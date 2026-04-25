# Runbook — VPN site-à-site

**Propriétaire** : GR46 · **Dernière revue** : 2026-04-18 · **Criticité** : S1

Ce runbook couvre le tunnel OpenVPN reliant Site A (serveur) et Site B
(client). Il est la source de vérité opérationnelle ; les procédures
restaurent un tunnel en moins de 15 minutes.

## 1. Topologie

```
Site A pfsense-s1 ── WAN ── Internet ── WAN ── pfsense-s2 Site B
   172.16.0.1 (server)                         172.16.0.2 (client)
   LAN 10.10.0.0/24                            LAN 192.168.0.0/24
   ADMIN 10.10.10.0/24                         SERVICES 192.168.10.0/24
```

- Transport : UDP/1194
- Chiffrement : AES-256-GCM, auth SHA256, TLS 1.2+, tls-crypt
- PKI : Vault `pki_cia_vpn/`, CA valide 10 ans, certs 1 an
- Config fichiers : `configs/openvpn/server.conf`, `configs/openvpn/client.conf`

## 2. Vérifications quotidiennes (2 min)

```bash
# Depuis Site A
pfctl -ss | grep 1194        # session UDP active
ping -c 3 172.16.0.2         # IP tunnel côté B
ssh admin@10.10.0.30 "curl -s http://logstash:9600/_node/stats | jq .process.cpu"

# Depuis Site B
ssh -p 2222 admin@bastion.s2.lan ping -c 3 172.16.0.1
```

Critères OK :
- `status.log` côté server : `Peer Connection Initiated with [AF_INET]...`
- `ping 172.16.0.x` < 30 ms, 0 % loss
- Kibana index `cia-openvpn-*` reçoit des événements dans les 5 dernières min

## 3. Symptômes et diagnostic

| Symptôme                                 | Cause probable                      | Aller à |
|------------------------------------------|-------------------------------------|---------|
| `ping 172.16.0.2` KO depuis A            | Tunnel down                         | §4.1    |
| Tunnel up mais `ping 192.168.0.10` KO    | Route ou règle VPN manquante        | §4.2    |
| Reneg toutes les 2 min dans `openvpn.log`| Horloge désynchronisée              | §4.3    |
| `TLS Error: cannot locate HMAC`          | tls-crypt key divergente            | §4.4    |
| Cert expiré                              | PKI non tournée                     | §4.5    |

## 4. Procédures

### 4.1 Relancer le tunnel

```bash
# Côté server (Site A)
ssh admin@pfsense-s1
pfSsh.php playback svc restart openvpn server 1
tail -f /var/log/openvpn.log

# Côté client (Site B)
ssh -p 2222 admin@bastion.s2.lan
ssh admin@pfsense-s2 pfSsh.php playback svc restart openvpn client 1
```

Temps cible : 2 min.

### 4.2 Route manquante

Vérifier `push "route 10.10.0.0 255.255.255.0"` dans `configs/openvpn/server.conf`.
Appliquer via Ansible :

```bash
cd ansible
ansible-playbook -i inventories/siteA.ini playbooks/vpn.yml --tags routes
```

### 4.3 Horloge

```bash
for host in pfsense-s1 pfsense-s2; do
  ssh admin@$host chronyc tracking | grep -E "System time|Leap"
done
```

Drift > 1 s : relancer `chronyd` ou reconfigurer `pool.ntp.org`.

### 4.4 tls-crypt divergente

Clef statique partagée ; la régénérer casse le tunnel.
Pour la rotation planifiée :

```bash
export VAULT_TOKEN=$(cat ~/.cia-vault/openvpn.token)
./vault/scripts/generate-certs.sh   # régénère + push dans Vault
ansible-playbook -i ansible/inventories/siteA.ini ansible/playbooks/vpn.yml --tags tls-crypt
ansible-playbook -i ansible/inventories/siteB.ini ansible/playbooks/vpn.yml --tags tls-crypt
```

### 4.5 Renouvellement certs

Automatisable (cron trimestriel) :

```bash
./vault/scripts/generate-certs.sh
ansible-playbook -i ansible/inventories/siteA.ini ansible/playbooks/vpn.yml --tags pki
ansible-playbook -i ansible/inventories/siteB.ini ansible/playbooks/vpn.yml --tags pki
```

## 5. Rollback

Configuration précédente toujours sauvegardée dans le git, côté pfSense via
export XML auto (`configs/pfsense/site{A,B}-config.xml`). Restauration :

```bash
scp configs/pfsense/siteA-config.xml admin@pfsense-s1:/tmp/
ssh admin@pfsense-s1 pfSsh.php playback config restore /tmp/siteA-config.xml
```

## 6. Escalade

- L1 (on-call GR46) : tentative §4 complète.
- L2 (tech-lead réseau) : si `openvpn.log` mentionne `TLS handshake failed`.
- L3 (infra) : défaillance matérielle Proxmox.

## 7. Preuves & logs

- Live : `journalctl -u openvpn@server -f`
- Historique : Kibana index `cia-openvpn-*`
- Config auditable : `configs/openvpn/server.conf`, `configs/openvpn/client.conf`
