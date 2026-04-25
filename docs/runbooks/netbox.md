# Runbook — NetBox (IPAM source de vérité)

**Propriétaire** : GR46 · **Dernière revue** : 2026-04-18 · **Criticité** : S2

NetBox 3.x tourne en docker-compose sur `services-s1` (10.10.0.20), derrière
Caddy TLS (`netbox.s1.lan`).

## 1. Accès

- UI : https://netbox.s1.lan
- API : https://netbox.s1.lan/api/
- Credentials : `admin` (Vault `kv/cia/netbox/admin`) + token API
  (`kv/cia/netbox/admin-token`).

## 2. Démarrage / arrêt

```bash
ssh admin@services-s1
cd /opt/netbox
sudo docker compose ps
sudo docker compose logs -f --tail=100 netbox
sudo docker compose restart netbox     # redémarrage sans perte données
```

## 3. Seed & resync

Le script `ansible/roles/netbox/files/seed_netbox.py` lit
`networking/addressing.yml` et crée/maj sites, prefixes, IP addresses.
Idempotent.

```bash
NETBOX_URL=https://netbox.s1.lan \
NETBOX_TOKEN=$(vault kv get -field=token kv/cia/netbox/admin-token) \
python3 ansible/roles/netbox/files/seed_netbox.py networking/addressing.yml
```

Relancer après toute modification du plan d'adressage.

## 4. Sauvegarde PostgreSQL

Auto (cron) + sur demande :

```bash
ssh admin@services-s1 sudo docker compose -f /opt/netbox/docker-compose.yml \
    exec -T postgres pg_dump -U netbox netbox \
    | gzip > /var/backups/netbox-$(date +%F).sql.gz
```

Les backups > 7 jours sont purgés.

## 5. Restauration

```bash
gunzip < /var/backups/netbox-<date>.sql.gz \
  | ssh admin@services-s1 sudo docker compose -f /opt/netbox/docker-compose.yml \
        exec -T postgres psql -U netbox netbox
sudo docker compose restart netbox
```

## 6. Upgrade NetBox

1. Lire le CHANGELOG upstream (breaking changes en 4.x).
2. Backup :
   ```bash
   git commit -am "ops: netbox backup pre-upgrade $(date +%F)"
   # + pg_dump §4
   ```
3. Bumper le tag image dans `/opt/netbox/docker-compose.yml`.
4. `docker compose pull && docker compose up -d`.
5. Migrer :
   ```bash
   sudo docker compose exec netbox /opt/netbox/venv/bin/python \
        /opt/netbox/netbox/manage.py migrate
   ```
6. Vérifier UI + seed_netbox.py idempotent.

## 7. API lecture/écriture — exemples

```bash
TOKEN=$(vault kv get -field=token kv/cia/netbox/admin-token)
curl -sH "Authorization: Token ${TOKEN}" https://netbox.s1.lan/api/dcim/sites/ | jq
curl -sH "Authorization: Token ${TOKEN}" \
     https://netbox.s1.lan/api/ipam/prefixes/ | jq '.results[] | {prefix, status, site}'
```

## 8. Troubleshooting

| Symptôme                   | Action                                                 |
|----------------------------|--------------------------------------------------------|
| UI 502                     | `docker compose logs caddy` → cert TLS ?               |
| Migrations pending         | `manage.py migrate` puis `collectstatic`               |
| Redis OOM                  | Augmenter RAM VM ; check `docker stats`                |
| `postgres disk full`       | Purger backups anciens, vacuum full                    |

## 9. Logs

- `docker compose logs netbox` (stdout → filebeat → `cia-netbox-*`)
- Audit NetBox : `/opt/netbox/netbox/media/reports/`
- Caddy : `/var/log/caddy/netbox.log`
