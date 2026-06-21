# Kibana — Saved Objects (dashboards, alerts, data views)

**Owner** : GR46
**Stack** : Elastic 8.11 (Elasticsearch + Kibana + Logstash, déployée via `docker compose` sur le poste de pilotage)
**Pipeline source** : Filebeat (services-s2) → tunnel SSH inverse `5044/tcp` → Logstash WSL → Elasticsearch `cia-{hostname}-{YYYY.MM.dd}` → Kibana

---

## 1. Contenu du dossier

```
infra/kibana/
├── README.md                                       (ce fichier)
├── dashboards/
│   └── cia-observability-services-s2.ndjson       (dashboard runtime FW3-Final)
├── alerts/                                         (rules Kibana exportées — à venir)
└── dataviews/                                      (data views standalone — auto-incluses dans dashboards)
```

Tous les fichiers sont au format **NDJSON** (Newline Delimited JSON), format natif d'export/import Kibana.

## 2. Procédure d'import (reproductibilité)

Pour réimporter sur une autre instance Kibana (par exemple en redéploiement complet) :

1. Connecte-toi à Kibana → Menu burger ☰ → **Stack Management**
2. Colonne gauche : section **Kibana** → **Saved Objects**
3. En haut à droite : **Import**
4. Sélectionne le fichier `.ndjson` désiré
5. Coche **Automatically overwrite conflicts** si tu veux écraser une version précédente
6. **Import**

Kibana affichera la liste des objets importés (data view, dashboard, tags, visualisations Lens embarquées).

## 3. Procédure d'export (versionnement)

Pour exporter un dashboard et le commit dans ce repo :

1. Stack Management → **Saved Objects**
2. Filtre par **Type = Dashboard** (ou autre type)
3. Coche le ou les objets à exporter
4. **Export** → coche **Include related objects** (essentiel : embarque les viz Lens + data view + tags)
5. Le navigateur télécharge un `.ndjson`
6. Renomme proprement (ex: `cia-<scope>-<sujet>.ndjson`) et place dans `infra/kibana/<type>/`
7. Commit + push

## 4. Inventaire des dashboards versionnés

| Fichier | Titre | Panneaux | Usage |
|---|---|---|---|
| `dashboards/cia-observability-services-s2.ndjson` | CIA — Observability — services-s2 | 5 (Total events, SSH events, Sudo events, Timeline, Bar par dataset) | Démo runtime FW3-Final, screenshot keynote |
| `dashboards/cia-ssh-security-monitor.ndjson` | CIA — SSH Security Monitor — services-s2 | 5 (Failed passwords 24h, Invalid users 24h, Accepted succès 24h, Timeline failures auth, Détails failures) | SOC focus security FW3-Final, keynote |

## 5. Data view utilisée

| Nom Kibana | Pattern ES | Time field |
|---|---|---|
| `CIA Logs` | `cia-*` | `@timestamp` |

Cette data view est embarquée dans chaque export de dashboard (option `Include related objects`).

## 6. Tags

| Tag | Couleur | Sémantique |
|---|---|---|
| `cia` | vert clair | Tous les saved objects du projet |
| `runtime` | vert pâle | Objets démontrant le runtime live (vs design uniquement) |
| `keynote` | (à créer) | Objets utilisés directement dans la présentation finale |

## 7. Alerts (rules)

Trois rules opérationnelles exportées sous `alerts/cia-security-alerts.ndjson`.
Le connector `CIA Server Log` (Server log Kibana, écrit dans les logs du serveur Kibana) est inclus dans l'export.

| Rule | Sévérité | Condition | Fenêtre | Check | Action |
|---|---|---|---|---|---|
| `ALERT-SSH-FAIL-BURST` | P2 | `count(message: "Failed password")` IS ABOVE 5 | 5 min | 1 min | Server log (level warning) |
| `ALERT-AUDIT-TAMPER` | P1 | `count(message: ("/etc/ssh/" OR "/etc/sudoers" OR "/etc/pam.d/" OR "log_tamper" OR "ssh_config"))` IS ABOVE 0 | 10 min | 1 min | Server log (level error) |
| `ALERT-FILEBEAT-HEARTBEAT-LOST` | P2 | `count(*)` IS BELOW 1 | 10 min | 2 min | Server log (level warning) |

Pré-requis Kibana pour activer Alerting :

```yaml
# docker-compose.yml (service kibana)
environment:
  - XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY=<32+ random chars>
  - XPACK_REPORTING_ENCRYPTIONKEY=<32+ random chars>
  - XPACK_SECURITY_ENCRYPTIONKEY=<32+ random chars>
```

Sans ces 3 clés, le framework Alerting refuse de démarrer (`Additional setup required`).
Pour la prod, externaliser dans un `.env` non versionné. Pour la démo locale, valeurs en clair acceptables.

TODO post-keynote : remplacer le Server log connector par un connector Slack ou Webhook
pour notifications externes réelles (Server log = trace uniquement dans `docker logs kibana-cia`).

## 8. Dépendances runtime

Pour que les dashboards affichent des données :

1. Stack Elastic up : `cd ~/elastic-demo && docker compose up -d`
2. Tunnel SSH inverse actif : `ssh -R 5044:127.0.0.1:5044 services-s2 -N -f`
3. Filebeat actif sur services-s2 : `sudo systemctl status filebeat`
4. Vérif : `curl -s "http://localhost:9200/_cat/indices?v" | grep cia`

Smoke check complet :

```bash
# Tunnel
ps aux | grep "ssh -R 5044" | grep -v grep
# Listener côté services-s2
ssh services-s2 'ss -tln | grep 5044'
# Filebeat connecté
ssh services-s2 'sudo journalctl -u filebeat -n 20 --no-pager | grep -i established'
# Compte ES qui monte
curl -s "http://localhost:9200/cia-services-s2-*/_count"
```

## 9. Historique

| Date | Action |
|---|---|
| 2026-06-20 | Création initiale : dashboard `CIA — Observability — services-s2` post-runtime |
| 2026-06-21 | Ajout dashboard `CIA — SSH Security Monitor` + 3 alert rules (SSH-FAIL-BURST, AUDIT-TAMPER, FILEBEAT-HEARTBEAT-LOST) + connector Server log + encryption keys Kibana |
