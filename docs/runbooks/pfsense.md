# Runbook — pfSense

**Propriétaire** : GR46 · **Dernière revue** : 2026-04-18 · **Criticité** : S1

Couvre les deux appliances pfSense (Site A / Site B) : tenue d'état,
troubleshooting des règles, sauvegarde, restauration.

## 1. Accès

| Site | Hôte       | URL admin                 | SSH                         |
|------|------------|---------------------------|-----------------------------|
| A    | pfsense-s1 | https://10.10.10.1        | `ssh admin@10.10.10.1`      |
| B    | pfsense-s2 | https://192.168.10.1      | via bastion Site B          |

Compte admin : Vault `kv/cia/pfsense/siteX/admin`. Jamais en local.

## 2. Vérifications quotidiennes

```bash
# État des services
ssh admin@pfsense-s1 'pfSsh.php playback svc status openvpn; pfSsh.php playback svc status unbound'

# Tables de filtrage
ssh admin@pfsense-s1 pfctl -sr | head
ssh admin@pfsense-s1 pfctl -ss | wc -l   # nombre d'états actifs
```

Attendu : openvpn + unbound `running`, états < 8 000.

## 3. Alias structurants

| Alias              | Type     | Contenu                              | Usage                          |
|--------------------|----------|--------------------------------------|--------------------------------|
| `KILLSWITCH_ACTIVE`| host     | vide par défaut                      | voir runbook `killswitch.md`   |
| `ADMIN_NETS`       | network  | `10.10.10.0/24 192.168.10.0/24`      | ACL management                 |
| `ELASTIC_HOSTS`    | host     | `10.10.0.30`                         | Log sink autorisé              |

Modifier via API :

```bash
curl -sS -u "admin:${PFSENSE_PASS}" -k \
     -H "Content-Type: application/json" \
     -X PUT "https://10.10.10.1/api/v1/firewall/alias" \
     -d '{"name":"ADMIN_NETS","type":"network","address":"10.10.10.0/24 192.168.10.0/24"}'
ssh admin@pfsense-s1 pfSsh.php playback filter reload
```

## 4. Règles — principes

1. Bloquer par défaut sur toutes les interfaces (policy = `block`).
2. Chaque passage explicite commenté (champ `descr`).
3. Segmentation : `LAN` n'atteint JAMAIS `ADMIN`.
4. OpenVPN pseudo-interface : règles dédiées par subnet.

Matrice complète : [docs/access-matrix.md](../access-matrix.md).

## 5. Sauvegarde de config

Auto : le rôle Ansible `pfsense` exporte XML après chaque run → commit
`configs/pfsense/site{A,B}-config.xml`. Manuel :

```bash
ansible-playbook -i ansible/inventories/siteA.ini ansible/playbooks/siteA.yml --tags backup
git diff configs/pfsense/
git add configs/pfsense/siteA-config.xml
git commit -m "ops: pfSense siteA backup $(date +%F)"
```

## 6. Restauration

1. Identifier le commit sain : `git log -p configs/pfsense/siteA-config.xml`.
2. Extraire le XML :
   ```bash
   git show <commit>:configs/pfsense/siteA-config.xml > /tmp/restore.xml
   ```
3. Uploader via GUI → Diagnostics → Backup & Restore, ou API :
   ```bash
   curl -sS -u admin:${PFSENSE_PASS} -k \
        -F "file=@/tmp/restore.xml" \
        https://10.10.10.1/api/v1/diagnostics/config_history/restore
   ```
4. Attendre reboot pfSense (≈ 60 s).

Temps cible : 10 min.

## 7. Troubleshooting courants

| Symptôme                                   | Diagnostic                                      |
|--------------------------------------------|-------------------------------------------------|
| `pfctl: syntax error`                      | règle API mal formée → `tail -n50 /tmp/rules.debug` |
| Trafic bloqué légitime                     | Live log filtrage : `clog -f /var/log/filter.log` |
| DNS LAN KO                                 | `pfSsh.php playback svc restart unbound`        |
| Règle non prise en compte                  | `pfSsh.php playback filter reload`              |

## 8. Logs

- Local : `/var/log/filter.log`, `/var/log/openvpn.log`, `/var/log/resolver.log`
- Centralisation : Kibana index `cia-pfsense-*` (filterlog), `cia-openvpn-*`

## 9. Escalade

L1 → L2 (network) si pfctl refuse le rechargement ; L3 si WAN down.
