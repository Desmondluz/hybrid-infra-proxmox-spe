# Runbook — Killswitch réseau

**Propriétaire** : GR46 · **Dernière revue** : 2026-04-18 · **Criticité** : S0

Le killswitch coupe instantanément toute sortie WAN d'un site. Il s'agit
d'une règle floating pfSense conditionnée à l'alias `KILLSWITCH_ACTIVE`.
Quand l'alias contient au moins une adresse, la règle `block out any on WAN`
prend effet immédiatement.

## 1. Activer (incident sécurité)

```bash
ansible-playbook ansible/playbooks/killswitch.yml \
    -e killswitch_state=active \
    -e site=siteA          # ou siteB, ou "both"
```

Ce playbook :

1. Met `KILLSWITCH_ACTIVE` à `0.0.0.0/0` via l'API pfSense.
2. Force `pfctl reload`.
3. Vérifie qu'un ping WAN échoue depuis le LAN (assertion).

Temps total : < 60 s.

## 2. Vérification manuelle

```bash
# Côté pfSense
ssh admin@pfsense-s1 pfctl -sr | grep -i KILLSWITCH
ssh admin@pfsense-s1 "pfctl -t KILLSWITCH_ACTIVE -T show"

# Depuis une VM LAN
ssh admin@services-s1 "curl -m 3 https://1.1.1.1 || echo BLOCKED"
```

## 3. Lever le killswitch

```bash
ansible-playbook ansible/playbooks/killswitch.yml \
    -e killswitch_state=inactive \
    -e site=siteA
```

Vérification : `pfctl -t KILLSWITCH_ACTIVE -T show` ne doit rien renvoyer.

## 4. Cas d'usage

| Scénario                                           | Portée                    |
|----------------------------------------------------|---------------------------|
| Détection d'exfiltration                           | Site concerné uniquement  |
| Compromis du bastion                               | Site B (+ révocations)    |
| Pic d'échecs SSH 100/min                           | Site B                    |
| Exercice DRP — scénario "coupure WAN"              | Site A ou B               |

## 5. Effet collatéral

- Le tunnel VPN Site-A/Site-B tombe (car UDP sortant bloqué) : PRÉVU.
- Les services internes LAN restent accessibles.
- NetBox accessible depuis LAN Site A, Kibana aussi.
- Les logs continuent d'être générés mais ne sont pas exportés
  hors-site → résilience logstash local.

## 6. Test semestriel

Inscrit dans `docs/drp/drp.md` scénario #3. Fenêtre de 15 min, annoncée au
canal #ops 48 h à l'avance. Preuve : capture `pfctl` avant/après + diff
Kibana.

## 7. Escalade

- L1 déclenche sur alerte PagerDuty.
- Si le playbook échoue (API pfSense KO), fallback manuel : GUI → Firewall
  → Aliases → éditer `KILLSWITCH_ACTIVE` → Apply.
