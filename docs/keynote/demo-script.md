# Démo keynote — Script chronométré

**Propriétaire** : GR46 (Joseph-Desmon Yonzou)
**Durée totale démos live** : 8 min (intégrées dans le créneau 20 min keynote)
**Format** : 4 démos courtes, scénarios de fallback documentés
**Dernière mise à jour** : 2026-06-21

> **Objectif** : démontrer que l'infrastructure CIA tourne en runtime réel,
> pas juste du code statique. Chaque démo a un fallback (vidéo backup,
> screenshot statique) au cas où le réseau école KO le jour J.

---

## 0. Pré-keynote — 30 min avant la soutenance (smoke check)

Liste de vérifications à dérouler avant d'entrer dans la salle :

```bash
# 1. WSL + Docker stack
wsl
docker ps --filter name=cia --format "table {{.Names}}\t{{.Status}}"
# Attendu: es-cia, kibana-cia, logstash-cia tous "Up"

# 2. Tunnel SSH inverse actif
ps aux | grep "ssh -R 5044" | grep -v grep
# Si absent : ssh -R 5044:127.0.0.1:5044 services-s2 -N -f

# 3. Filebeat services-s2 vivant
ssh services-s2 'sudo systemctl is-active filebeat'
# Attendu: active

# 4. ES indexe en live
curl -s "http://localhost:9200/cia-services-s2-*/_count" | python3 -c "import sys,json; print(json.load(sys.stdin))"
# Attendu: count > 15000 (croissant à chaque check)

# 5. Kibana accessible
curl -s -o /dev/null -w "Kibana HTTP %{http_code} - %{time_total}s\n" http://localhost:5601/api/status
# Attendu: HTTP 200

# 6. 4 dashboards visibles
# Ouvrir http://localhost:5601 → Analytics → Dashboards
# Attendu: CIA — Observability, SSH Security, OpenVPN, Network

# 7. 6 alert rules Enabled
# Stack Management → Rules
# Attendu: 6 rules toutes en Enabled + Last response = Succeeded
```

**Si un check échoue** → bascule sur la **vidéo backup** correspondante
(stockée sur clé USB + Google Drive).

---

## Démo 1 — Pipeline observabilité LIVE (3 min)

**Slide synchronisée** : 10 (Pipeline runtime) + 11 (Dashboards + Alerts)

**Objectif** : montrer que les logs réels de services-s2 transitent par un
tunnel SSH chiffré → Logstash → Elasticsearch → Kibana **en direct**.

### Script (3 min)

**[0:00]** Ouvrir Kibana → **Analytics → Dashboard → CIA — Observability — services-s2**

> *"Ce que vous voyez ici est en temps réel. Cette VM tourne sur le cluster
> école Site B, et ses logs auth, syslog, audit remontent dans cette stack
> Elastic via un tunnel SSH chiffré. Premier indicateur :
> [pointer Total events] 15 222 événements indexés en 24 heures. Deuxième
> indicateur : [pointer Timeline] vous voyez la courbe qui continue à
> monter, c'est live."*

**[1:00]** Cliquer **Refresh** (bouton en haut à droite)

> *"Je rafraîchis. Le compteur a augmenté de quelques événements pendant
> que je parlais. C'est exactement le pattern qu'on aurait avec Filebeat
> sur n'importe quelle VM en production : agents légers, collecte
> centralisée, indexation, restitution."*

**[1:30]** Switch vers **CIA — Network Activity** (pfSense + DNS)

> *"Même pattern pour les autres sources : ici les flux pfSense — blocked
> vs passed — et la résolution DNS interne. Sur le cluster école, on a
> 80 flux bloqués / 30 autorisés, et 60 requêtes DNS dont 10 NXDOMAIN.
> Ces dashboards sont prêts à recevoir les vraies données pfSense dès
> que Filebeat module 'pfsense' est branché — le code KQL est identique."*

**[2:30]** Switch vers **Analytics → Discover** → KQL `host.hostname: "services-s2"`

> *"Et si je veux investiguer en mode forensique, Discover me sort les
> événements bruts avec les tags Ansible que j'ai définis dans
> l'inventaire : `host_role = bastion,linux,services,services_b,siteB`.
> Mes tags d'infrastructure persistent jusqu'à la couche observabilité,
> ça facilite la corrélation."*

### Fallback (si Kibana KO)

→ Vidéo `docs/demo/videos/demo-kibana.mp4` (3 min, OBS Studio, enregistrée mardi)
→ Screenshots `docs/demo/captures/kibana-*.png` (4 dashboards complets)

---

## Démo 2 — Alerting LIVE déclenché en direct (2 min) ⭐

**Slide synchronisée** : 12 (ALERTING LIVE prouvé)

**Objectif** : déclencher en direct la rule `ALERT-SSH-FAIL-BURST` par
injection de logs et montrer le log payload dans Kibana en < 90 secondes.
**C'est la démo la plus impressionnante du keynote.**

### Pré-requis live (à lancer 5 min avant le créneau démo)

Si tu veux montrer aussi le déclenchement organique :

```bash
# Garde un terminal ouvert avec ce tail-f
docker logs -f kibana-cia 2>&1 | grep -iE "alert|server-log"
```

### Script (2 min)

**[0:00]** Ouvrir un terminal WSL bien visible (police 18+)

> *"Je vais maintenant déclencher une vraie alerte de production en direct.
> Sur services-s2, j'injecte 12 fausses tentatives de connexion SSH
> avec mots de passe ratés."*

**[0:10]** Lancer la commande :

```bash
ssh services-s2 'for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  IP="203.0.113.$((10+i))"
  USR=$(printf "demo_jury_%02d" $i)
  logger -t "sshd[demoLIVE]" -p auth.info \
    "Failed password for invalid user $USR from $IP port $((55000+i)) ssh2"
done; echo "12 events injectés à $(date +%H:%M:%S)"'
```

**[0:30]** Switch vers Kibana → **Stack Management → Rules → ALERT-SSH-FAIL-BURST**

> *"La rule check toutes les 60 secondes. Elle déclenche si plus de 5
> Failed passwords en 5 minutes. On en a 12. Dans moins d'une minute,
> elle va passer en status Active."*

**[1:00]** Attendre 30-60 sec, refresh la page (bouton Refresh top-right)

> *"Voilà — l'onglet Alerts montre maintenant une alerte 'query matched'
> en status Active. Et regardez le compteur d'exécutions : 'X executions
> in the last 24 hours' a augmenté. La rule a fait son job."*

**[1:30]** Switch terminal → afficher les logs Kibana :

```bash
docker logs --tail 50 kibana-cia 2>&1 | grep "ALERT-SSH-FAIL-BURST" | tail -3
```

> *"Et voici le payload custom logué par le connector CIA Server Log.
> En prod, on remplace 'Server log' par 'Slack' ou 'PagerDuty' — c'est
> une seule ligne de config à changer. Le payload contient le timestamp,
> le compteur, et l'investigation hint. C'est notre Layer 4 de défense
> en profondeur en action."*

### Fallback (si réseau KO)

→ Screenshots `docs/demo/captures/kibana-rule-ssh-burst-active.png` +
`kibana-server-log-alerts-fired.png` (déjà capturées au cours de la session précédente)
→ Texte `docs/demo/captures/kibana-alerts-fired.txt` (preuve grep brute)

---

## Démo 3 — NetBox auto-sync via Ansible (1 min 30)

**Slide synchronisée** : (mention dans slide 4 Stack technique + slide 13 CI/CD)

**Objectif** : démontrer que la source de vérité `addressing.yml` se
synchronise automatiquement vers NetBox via Ansible, avec validation CI.

### Script (1 min 30)

**[0:00]** Terminal WSL — montrer le CI workflow :

```bash
# Voir le dernier run netbox-validate (vert)
gh run list --workflow=netbox-validate.yml --limit 3 2>/dev/null || \
    echo "(ouvrir https://github.com/Desmondluz/hybrid-infra-proxmox-spe/actions)"
```

> *"L'IPAM, c'est NetBox. Mais NetBox n'est PAS la source de vérité — c'est
> `networking/addressing.yml` qui l'est. Ce fichier YAML est versionné dans
> Git. Toute modification déclenche automatiquement un workflow GitHub
> Actions qui valide la syntaxe, vérifie les CIDR, détecte les overlaps,
> puis tente un seed dry-run contre un mock NetBox."*

**[0:30]** Montrer le fichier source :

```bash
head -30 networking/addressing.yml
echo "---"
echo "Validation locale :"
python3 scripts/netbox/validate-addressing.py
```

> *"Le validateur dit : 2 sites, 6 networks, 8 hosts. OK. Maintenant
> imaginons que j'ajoute un host."*

**[1:00]** Montrer la commande Ansible :

```bash
echo "Pour synchroniser vers le vrai NetBox :"
echo "  ansible-playbook -i ansible/inventories/siteA.ini \\"
echo "    ansible/playbooks/siteA.yml --tags netbox-sync"
echo ""
echo "Le tag 'netbox-sync' ne ré-installe pas Docker/NetBox,"
echo "il fait juste tourner le seed idempotent en 5 secondes."
```

> *"Cinq secondes. Get-or-create sur chaque site, prefix, IP. Aucune
> duplication. Et tout est tracé dans le runbook netbox-sync.md avec
> diagramme ASCII, procédures, troubleshooting. C'est ce qu'on appelle
> Infrastructure-as-Code mature."*

### Fallback (si runtime NetBox KO)

→ Montrer le runbook complet `docs/runbooks/netbox-sync.md`
→ Montrer le workflow GitHub Actions vert (capture `12-ci-actions-green.png`)

---

## Démo 4 — Kill Switch en action (1 min 30)

**Slide synchronisée** : 9 (Killswitch)

**Objectif** : démontrer l'isolation egress en 1 commande Ansible, avec
revert immédiat.

### Pré-requis

> ⚠️ **Site A école inaccessible** : la démo se fait conceptuellement via
> les configs versionnées + capture `fw3-pfsense-siteB-floating-killswitch.png`.
> Si pfsense-s2 (Site B) est joignable et que tu as un terminal pfSense
> ouvert : démo live possible. Sinon, raconter via les screenshots.

### Script (1 min 30)

**[0:00]** Ouvrir terminal WSL avec ce side-by-side :

```bash
# Côté terminal : le playbook
cat ansible/playbooks/killswitch.yml | head -40

# Côté navigateur : la rule pfSense
# Ouvrir https://pfsense-s2.lan (si accessible) sur l'onglet Firewall > Rules > Floating
```

> *"Le Kill Switch, c'est notre arme atomique. Une seule commande Ansible
> active une floating rule pfSense qui bloque tout trafic egress sur WAN.
> Usage type : isolation post-incident pour investigation forensique,
> exercice DRP, ou test de conformité."*

**[0:45]** Montrer la commande complète (sans la lancer si Site A KO) :

```bash
echo "Activation :"
echo "  ansible-playbook ansible/playbooks/killswitch.yml \\"
echo "    -e killswitch_state=active \\"
echo "    -e site=siteB"
echo ""
echo "Revert :"
echo "  ansible-playbook ansible/playbooks/killswitch.yml \\"
echo "    -e killswitch_state=inactive \\"
echo "    -e site=siteB"
```

**[1:15]** Montrer la rule via screenshot ou pfSense UI :

→ `docs/demo/captures/fw3-pfsense-siteB-floating-killswitch.png`

> *"Cette règle est en alias `KILLSWITCH_ACTIVE`. Le playbook switch
> l'alias, pfctl reload, et l'effet est immédiat : curl 200 OK avant,
> timeout après. Revert en 5 secondes. Tracé Git via `ansible-playbook`
> command, audit trail conservé."*

### Fallback (toujours OK)

→ Screenshot + lecture commenté du playbook `ansible/playbooks/killswitch.yml`

---

## Transitions entre démos

| De → vers | Phrase de transition |
|---|---|
| Obs runtime → Alerting LIVE | "Maintenant que je vous ai montré que les logs arrivent, je vous prouve que les alertes se déclenchent vraiment." |
| Alerting → NetBox sync | "Cette même rigueur runtime, on l'applique aussi à notre source de vérité IPAM." |
| NetBox → Killswitch | "Et quand quelque chose tourne mal — incident sécurité — voici comment on isole en une commande." |

---

## Anti-flop checklist

| Risque | Mitigation |
|---|---|
| Réseau école KO le jour J | 4G téléphone (partage de connexion) → la stack WSL Docker est locale, juste besoin d'Internet pour Kibana cosmétique |
| Kibana se déconnecte pendant démo | Recharger F5, les rules + dashboards persistent (state ES + Kibana volume) |
| Le pré-keynote check montre filebeat down | `sudo systemctl restart filebeat` côté services-s2 + relance tunnel SSH |
| Tunnel SSH inverse tombe | `ssh -R 5044:127.0.0.1:5044 services-s2 -N -f` (la commande imprimée sur sticker laptop) |
| Burst SSH ne déclenche pas la rule en démo | Avoir Discover ouvert sur message: "Failed password" → montrer le count qui monte = suffisant |
| Vidéo backup non disponible | Slides 12 + 13 ont les screenshots de la session précédente — `docs/demo/captures/kibana-rule-ssh-burst-active.png` |
| Le jury demande à voir Site A école | Honnêteté : "le port 22 et le 8006 sont filtrés par l'admin réseau Epitech. Documenté dans STATUS.md §Blockers. Code 100 % prêt à apply dès accès rétabli." |

---

## Inventaire des assets de démo (à vérifier veille)

```bash
ls docs/demo/captures/ | wc -l           # attendu: > 30 captures
ls docs/demo/videos/   | wc -l           # attendu: 1 (demo-kibana.mp4) si enregistré
ls infra/kibana/dashboards/*.ndjson      # attendu: 4 dashboards
ls infra/kibana/alerts/*.ndjson          # attendu: 1 ndjson (6 rules)
git log --oneline -10                    # voir derniers commits propres
```

---

## Récap : combien de temps en démo pure ?

| Démo | Durée | Slot |
|---|---|---|
| 1. Obs runtime | 3 min | 12:00 → 15:00 |
| 2. Alerting LIVE | 2 min | 15:00 → 17:00 |
| 3. NetBox auto-sync | 1 min 30 | 11:00 → 12:30 (peut bouger) |
| 4. Killswitch | 1 min 30 | (intégré dans slide 9 explication) |
| **Total démos** | **~ 8 min** | dans le créneau 20 min keynote |

Le reste : explications architecture, sécurité, bilan, Q&R (10 min).

---

## Speaker notes — phrases-clés à mémoriser

> "Tout-code, tout-version, tout-audit. Aucune action manuelle non reproductible."
>
> "Le code est complet, le runtime est partiel — et c'est documenté
> honnêtement dans `STATUS.md`. Les blockers sont externes : école et
> capacité Azure. La méthode, elle, est entièrement prouvée."
>
> "Vous voyez ici en temps réel les vrais logs d'une VM en production
> qui transitent par un tunnel SSH chiffré jusqu'à cette instance Kibana.
> 15 000 événements indexés depuis hier soir, 6 règles d'alerting actives,
> dont une qu'on vient de déclencher en direct devant vous."
>
> "GitOps marche : on a fait la migration d'un Proxmox imbriqué dev jetable
> vers le matériel école réel en ne changeant que 3 fichiers — `terraform.tfvars`,
> l'inventaire Ansible, et les secrets SOPS. C'est ça la promesse
> Infrastructure-as-Code."

---

*GR46 — CIA Epitech 2025-2026 — Script vivant, à actualiser après chaque répétition.*
