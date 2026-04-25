# Runbook — Elastic Stack (Elasticsearch + Kibana + Logstash)

**Propriétaire** : GR46 · **Dernière revue** : 2026-04-18 · **Criticité** : S2

Stack centralisée sur `observability-s1` (10.10.0.30). Un seul nœud, ILM
`cia-30d` (rétention 30 jours), pas de cluster haute dispo dans ce MVP.

## 1. Accès

| Service       | URL                                   | Auth                     |
|---------------|---------------------------------------|--------------------------|
| Elasticsearch | `http://10.10.0.30:9200`              | user `elastic` + pw Vault|
| Kibana        | `https://kibana.s1.lan` (Caddy TLS)   | SSO (Kibana natif)       |
| Logstash API  | `http://10.10.0.30:9600`              | (localhost only)         |

Mot de passe `elastic` : `kv/cia/elastic/admin`.

## 2. Checks quotidiens

```bash
# Cluster health
curl -u elastic:${ES_PW} http://10.10.0.30:9200/_cluster/health?pretty
# Attendu : status green, unassigned_shards 0

# Indices CIA
curl -u elastic:${ES_PW} "http://10.10.0.30:9200/_cat/indices/cia-*?v&h=index,docs.count,store.size"

# Logstash
curl http://127.0.0.1:9600/_node/stats | jq '.pipelines.main.events'
```

Attendu : events.in ≈ events.out (écart < 10 %), events.out > 0 dans les 5
dernières minutes pour pfsense, ssh et openvpn.

## 3. ILM — politique cia-30d

Créée par `roles/elasticsearch/tasks/main.yml`. Phases :
- `hot`  : pas d'action
- `delete` : après 30 jours, suppression

Vérifier :

```bash
curl -u elastic:${ES_PW} http://10.10.0.30:9200/_ilm/policy/cia-30d | jq
```

Modifier la rétention : changer `elastic_retention_days` dans
`group_vars/all.yml` puis rejouer la tâche `elasticsearch`.

## 4. Plein disque / "red" cluster

1. Mesurer :
   ```bash
   df -h /var/lib/elasticsearch
   curl -u elastic:${ES_PW} http://localhost:9200/_cat/allocation?v
   ```
2. Forcer ILM à nettoyer :
   ```bash
   curl -u elastic:${ES_PW} -X POST http://localhost:9200/_ilm/explain
   curl -u elastic:${ES_PW} -X POST "http://localhost:9200/cia-*/_ilm/move/hot" -d '{...}'
   ```
3. Libérer manuellement (en dernier recours) :
   ```bash
   curl -u elastic:${ES_PW} -X DELETE "http://localhost:9200/cia-*-<YYYY.MM.DD>"
   ```
4. Si status `red` persistent : stop logstash côté ingestion (évite perte),
   diagnostic avec `_cat/shards?v`, recover les shards OFFLINE manuellement.

## 5. Pipeline Logstash — reload

```bash
sudo systemctl reload logstash   # recharge conf.d/*.conf sans redémarrer
tail -f /var/log/logstash/logstash-plain.log | grep -i error
```

## 6. Sauvegarde des dashboards Kibana

```bash
curl -u elastic:${ES_PW} -X POST \
  "https://kibana.s1.lan/api/saved_objects/_export" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{"type":["dashboard","visualization","search","index-pattern"]}' \
  > docs/dashboards/snapshot-$(date +%F).ndjson
git add docs/dashboards/
```

## 7. Filebeat — expédition arrêtée côté source

```bash
ssh admin@<host>
sudo systemctl status filebeat
sudo tail -f /var/log/filebeat/filebeat
sudo filebeat test output     # teste la connectivité Logstash
```

## 8. Rotation du mot de passe `elastic`

Via Elastic API :

```bash
curl -u elastic:${CURRENT_PW} -X POST \
  "http://localhost:9200/_security/user/elastic/_password" \
  -H 'Content-Type: application/json' \
  -d '{"password":"<NEW_PW>"}'
vault kv put kv/cia/elastic/admin password=<NEW_PW>
ansible-playbook -i ansible/inventories/siteA.ini ansible/playbooks/elastic.yml --tags password
```

## 9. Logs

- `/var/log/elasticsearch/cia-elastic.log`
- `/var/log/kibana/kibana.log`
- `/var/log/logstash/logstash-plain.log`

## 10. Escalade

L2 (obs) si cluster `red` > 30 min. L3 (infra) si disque plein physique.
