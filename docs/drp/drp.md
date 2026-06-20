# Plan de Reprise d'Activité (DRP) — CIA

**Propriétaire** : GR46 · **Version** : 1.0 · **Dernière revue** : 2026-04-18

Ce document décrit les scénarios de sinistre retenus, les procédures de
reprise associées, les RTO/RPO visés et les responsabilités.

## 1. Portée

| Élément protégé                       | Criticité | RTO    | RPO    |
|---------------------------------------|-----------|--------|--------|
| Tunnel VPN site-à-site                | S1        | 15 min | 0      |
| Firewall pfSense (A ou B)             | S1        | 30 min | 0      |
| NetBox (IPAM)                         | S2        | 2 h    | 24 h   |
| Stack Elastic (logs)                  | S2        | 4 h    | 15 min |
| Bastion SSH Site B                    | S1        | 30 min | 0      |
| Vault (secrets)                       | S1        | 1 h    | 1 h    |

## 2. Équipe & rôles

- **DRP coordinator** : lead tech GR46 (on-call rotatif).
- **Security lead** : valide l'ouverture de tout killswitch.
- **Infra lead** : restaure Proxmox/VM.
- **Communication** : annonce sur #ops Slack + email stakeholders.

## 3. Scénarios

### Scénario #1 — Perte d'une VM (Proxmox intact)

**Probabilité** : élevée · **Exemple** : disque corrompu `services-s1`.

1. Vérifier Proxmox healthy :

   ```bash
   ssh root@proxmox-s1 "qm list; pvesm status"
   ```

2. Détruire la VM corrompue :

   ```bash
   cd terraform/siteA && terraform destroy -target=module.services_s1
   ```

3. Recréer :

   ```bash
   terraform apply -target=module.services_s1
   ```

4. Reconfigurer avec Ansible :

   ```bash
   cd ../../ansible
   ansible-playbook -i inventories/siteA.ini playbooks/siteA.yml --limit services-s1
   ```

5. Restaurer NetBox DB si besoin (runbook `netbox.md` §5).

**RTO visé** : 30 min après détection.

### Scénario #2 — Perte totale d'un site (A ou B)

**Probabilité** : faible · **Exemple** : incendie DC.

1. Si Site A perdu : Site B continue d'autonome (LAN, bastion, services B).
   Les logs s'accumulent localement sur `services-s2`.
2. Commander/provisionner nouveau cluster Proxmox Site A.
3. `./scripts/bootstrap-new-site.sh siteA` (voir `docs/onboarding-new-site.md`).
4. Rétablir DNS public vers la nouvelle IP WAN Site A.
5. Renouveler certs OpenVPN (CN reste `cia-vpn-server-siteA`).
6. Relancer tunnel (runbook `vpn.md` §4.1).

**RTO visé** : 4 h (si matériel disponible).

### Scénario #3 — Compromis détecté (killswitch)

**Probabilité** : moyenne · **Exemple** : brute-force SSH ou anomalie log.

1. Déclencher killswitch sur le site concerné (runbook `killswitch.md`).
2. Geler les snapshots Proxmox en cours :

   ```bash
   ssh root@proxmox-s1 "for id in 100 101 102; do qm snapshot $id forensic-$(date +%F-%H%M); done"
   ```

3. Rotation IMMÉDIATE des secrets exposés :
   - clefs SSH admin (génération via §DRP secrets)
   - tokens Vault opérateurs
   - cert OpenVPN (régénère via `vault/scripts/generate-certs.sh`)
4. Forensic : export logs bruts Elasticsearch fenêtre [-24h, now] :

   ```bash
   curl -u elastic:${ES_PW} "http://localhost:9200/cia-*/_search?size=10000&q=..." \
     > docs/forensic/snapshot-$(date +%F).ndjson
   ```

5. Rapport sous 48 h.

**RTO visé** : 1 h isolation ; 24 h reprise contrôlée.

### Scénario #4 — Corruption config pfSense

**Probabilité** : moyenne · **Exemple** : mauvaise règle appliquée, pfctl KO.

Voir runbook `pfsense.md` §6 (restauration depuis git).

**RTO visé** : 10 min.

### Scénario #5 — Perte Vault (unseal keys OU données)

**Probabilité** : faible · **Exemple** : VM Vault corrompue, unseal keys
perdues.

Deux branches :

- **Unseal keys retrouvées** : restore backup snapshot Proxmox +
  `vault operator unseal` (3/5 keys).
- **Unseal keys perdues** : rebuild vault from scratch (voir
  `runbooks/secrets.md §8`).
  1. `./vault/scripts/init-vault.sh` (nouveau vault).
  2. Réinjecter secrets depuis sources canoniques :
     - SOPS : `sops -d ansible/group_vars/all/secrets.sops.yml`
     - Certs publics (pas sensibles) → `configs/openvpn/pki/ca.crt`
     - Mots de passe → rotation forcée de tous les comptes.
  3. Re-run `ansible-playbook site.yml` pour pousser nouveaux tokens.

**RTO visé** : 4 h.

---

## 3 bis. Scénarios détaillés (PRA niveau pro)

Les quatre scénarios suivants reprennent les sinistres les plus critiques du
sujet CIA avec une procédure complète : déclencheur, détection, isolation,
reprise, RTO/RPO chiffrés, responsabilités, communication de crise, test de
validation post-reprise et grille de *lessons learned*. À jouer en
exercice DRP semestriel (cf. section 4).

### SCEN-A — Perte totale du site distant (Site B école inaccessible)

**Description** : le cluster Proxmox école Site B (`ns3183326.ip-146-59-253.eu`)
devient injoignable. pfSense Site B, services-s2 (services + bastion-lite),
et bastion-s2 ne répondent plus. Les logs depuis Site B cessent de remonter
vers Logstash.

| Probabilité | Impact | Criticité globale |
|---|---|---|
| Faible (école dispose de redondance) | Élevé (50 % infra runtime perdue) | **S1** |

**Déclencheurs et détection (objectif < 60 s)** :

- Heartbeat Filebeat `services-s2` perdu sur Kibana (alert rule
  `cia-siteB-heartbeat`).
- `ping 5.196.50.60` failed depuis WSL et depuis un serveur tiers de
  contrôle (élimine cause réseau local).
- `ssh admin@5.196.50.60` time out (port 22 inaccessible).
- Notification Slack `#cia-alerts` (webhook Kibana actions).

**Procédure d'isolation immédiate (0–5 min)** :

1. Confirmer le sinistre via ping multi-source (laptop + tiers externe).
2. Vérifier le statut côté école (mail/portail) : maintenance planifiée ou
   panne non annoncée ?
3. Annoncer sur Slack `#cia-ops` : *"Site B unreachable depuis HH:MM,
   investigation en cours"*.
4. Activer le **killswitch Site A** (`playbooks/killswitch.yml -e site=siteA
   -e killswitch_state=active`) si compromission lateralisée soupçonnée.

**Procédure de reprise (15 min → 4 h)** :

1. **Diagnostic distance (5 min)** :

   ```bash
   ssh admin@5.196.50.60        # confirmation timeout pfSense WAN
   ssh par_25@services-s2       # confirmation timeout LAN via jump
   curl -k -v --max-time 10 https://ns3183326.ip-146-59-253.eu:8006
   ```

2. **Contact admin école (10 min, en parallèle du diag)** :
   - Mail à Valentin (`gr46-cia-incidents@epitech.eu`) avec timestamp précis,
     captures d'écran et ID de ressources concernées.
   - Demander statut maintenance vs panne (information clé pour décider
     bascule).

3. **Bascule des services critiques (1–2 h)** :
   - Si Site B définitivement perdu : provisionner nouveau cluster école OU
     bascule services vers **Site C Azure** (extension cloud bonus,
     `terraform/siteC-azure/`).
   - Restaurer config pfSense depuis Git (`configs/pfsense/siteB-config.xml`)
     sur la nouvelle pfSense.
   - Re-applier Ansible : `ansible-playbook -i prod.ini playbooks/siteB.yml`
     sur les nouvelles VMs.

4. **Restauration NetBox + Elastic (2–4 h)** :
   - Restore NetBox depuis dernier `pg_dump` offsite (`/var/backups/netbox/`).
   - Reindexer Elasticsearch depuis snapshots S3 conservés.

**RTO cible** : 4 h (si infrastructure de remplacement disponible).
**RPO cible** : 24 h NetBox · 15 min Elasticsearch logs.

**Responsabilités** :

- **Infra Lead** : provisionnement nouveau cluster Site B / bascule Site C.
- **Security Lead** : décision activation killswitch Site A.
- **DRP Coordinator** : communication + suivi exécution checklist.

**Communication de crise** :

| T (relatif) | Action                                                  |
|------------|---------------------------------------------------------|
| T+0        | Slack `#cia-ops` + mail stakeholders                    |
| T+30 min   | Update Slack + relance admin école si pas de réponse    |
| T+1 h      | Rapport écrit `docs/drp/incidents/AAAA-MM-JJ-siteB.md`  |
| T+24 h     | Post-mortem détaillé + lessons learned                  |

**Test de validation post-reprise** :

```bash
ansible -i prod.ini siteB -m ping              # ✓ pong sur toutes les VMs
ssh services-s2 'sudo systemctl status filebeat'  # ✓ active (running)
cd terraform/siteB && terraform plan           # ✓ "No changes"
ansible-playbook -i prod.ini playbooks/site.yml --check --limit siteB
# ✓ PLAY RECAP : changed=0
```

**Lessons learned (à compléter post-exercice)** :

- Root cause identifiée : ☐ panne école · ☐ action admin · ☐ matérielle.
- Délai de détection réel vs cible 60 s : ___.
- Alerte Kibana déclenchée : ☐ oui · ☐ non, ajuster.
- Procédure exécutable sans hésitation : ☐ oui · ☐ non, mettre à jour.

---

### SCEN-B — Panne du tunnel VPN site-à-site

**Description** : le tunnel OpenVPN entre pfSense Site A (server) et pfSense
Site B (client) tombe. Les VMs de Site A ne peuvent plus joindre Site B et
réciproquement. Aucun nouveau log ne traverse le tunnel chiffré.

| Probabilité | Impact | Criticité globale |
|---|---|---|
| Moyenne | Élevé (rupture comm inter-sites) | **S1** |

**Causes typiques** :

- Expiration de la CA OpenVPN (validité 10 ans mais erreur de date système).
- Cert serveur/client révoqué par erreur.
- pfSense crash ou config corrompue post-update.
- Coupure WAN d'un des deux sites.
- Saturation UDP/1194 (DDoS, mauvais routage).

**Déclencheurs et détection (objectif < 30 s)** :

- Status OpenVPN sur pfSense passe en `down` (visible web GUI Status).
- `ansible -i prod.ini siteA -m ping` échoue depuis Site B et vice-versa.
- Logstash : aucun event tagué `vpn=tunnel-up` depuis 30 s (alert rule
  `cia-vpn-down`).
- Heartbeat Filebeat services-s2 → observability-s1 perdu.

**Procédure d'isolation immédiate (0–5 min)** :

1. Confirmer que le sinistre est bien le tunnel (et pas une perte de site
   complète — SCEN-A) :

   ```bash
   ssh admin@5.196.50.70   # Site A pfSense joignable individuellement ?
   ssh admin@5.196.50.60   # Site B pfSense joignable individuellement ?
   ```

   Si les deux pfSense répondent en SSH mais que le tunnel est down, on est
   bien sur SCEN-B.

2. Snapshot Proxmox des pfSense (forensic) :

   ```bash
   ssh root@<proxmox-A> "qm snapshot <vmid-pfsense-A> vpn-down-$(date +%F-%H%M)"
   ssh root@<proxmox-B> "qm snapshot <vmid-pfsense-B> vpn-down-$(date +%F-%H%M)"
   ```

3. Annoncer Slack `#cia-ops` : *"Tunnel VPN site-à-site down depuis HH:MM"*.

**Procédure de reprise (5–30 min)** :

1. **Vérifier les certs (5 min)** :

   ```bash
   ssh admin@5.196.50.70 "openssl x509 -in /var/etc/openvpn/server1/cert -dates -noout"
   ssh admin@5.196.50.60 "openssl x509 -in /var/etc/openvpn/client1/cert -dates -noout"
   ```

   Si l'un est expiré → étape 2 (rotation PKI). Sinon → étape 3.

2. **Rotation PKI OpenVPN (10 min)** :

   ```bash
   ./vault/scripts/generate-certs.sh --regen-server --regen-client
   ansible-playbook -i prod.ini playbooks/vpn.yml --tags certs
   ```

3. **Restart instance OpenVPN sur les deux pfSense (2 min)** :

   ```bash
   ansible -i prod.ini pfsense -m shell -a "/etc/rc.d/openvpn restart"
   ```

4. **Si tunnel toujours down → restore config XML depuis git (10 min)** :

   ```bash
   scp configs/pfsense/siteA-config.xml admin@5.196.50.70:/cf/conf/config.xml
   scp configs/pfsense/siteB-config.xml admin@5.196.50.60:/cf/conf/config.xml
   ansible -i prod.ini pfsense -m shell -a "pfSsh.php playback restorebackup"
   ```

5. **Vérifier connectivité inter-sites** :

   ```bash
   ansible -i prod.ini services-s1 -m ping  # joignable depuis services-s2 ?
   ssh services-s2 "ping -c 3 172.16.0.1"   # via VPN tunnel CIDR
   ```

**RTO cible** : 30 min (avec PKI valide en stock).
**RPO cible** : 0 (pas de perte de donnée, juste indispo réseau).

**Responsabilités** :

- **Infra Lead** : exécution procédure.
- **Security Lead** : signe la rotation PKI si déclenchée.
- **DRP Coordinator** : Slack et chronométrage.

**Communication de crise** :

| T (relatif) | Action                                            |
|------------|---------------------------------------------------|
| T+0        | Slack `#cia-ops` "tunnel down"                    |
| T+15 min   | Update : "rotation PKI en cours" ou "restore conf"|
| T+30 min   | Confirmer tunnel up + ping inter-site OK          |
| T+48 h     | Post-mortem si la rotation PKI n'était pas planifiée |

**Test de validation post-reprise** :

```bash
ansible -i prod.ini siteA -m ping             # ✓ via 172.16.0.x
ansible -i prod.ini siteB -m ping             # ✓ via 172.16.0.x
ssh services-s2 "ssh services-s1 hostname"    # cross-site SSH OK
curl -s -X GET "http://10.10.10.40:9200/_cat/indices?v" | grep vpn
# ✓ index vpn-* ingestant les nouveaux events
```

**Lessons learned** :

- Délai entre détection et tunnel rétabli : ___.
- Cause root : ☐ cert expiré · ☐ pfSense crash · ☐ WAN · ☐ DDoS.
- Procédure adaptée du runbook `vpn.md` § _ ___.
- Alerte Kibana `vpn-down` déclenchée < 30 s : ☐ oui · ☐ non.

---

### SCEN-C — Compromission du bastion SSH

**Description** : suspicion ou preuve qu'un attaquant a obtenu un accès non
autorisé au bastion SSH (bastion-s2 ou services-s2 dual-duty FW3) : clé
SSH leakée publiquement, bypass MFA via vol de seed TOTP, brute-force
réussi, ou exfiltration détectée dans les logs.

| Probabilité | Impact | Criticité globale |
|---|---|---|
| Faible-moyenne | Critique (pivot vers tout l'infra) | **S0** |

**Déclencheurs et détection** :

- Pic d'échecs SSH dans Kibana (`ssh_failure > 50 / 5 min` → alert auto).
- Connexion réussie depuis une IP géolocalisée inhabituelle.
- Apparition de processus inattendus dans auditd (rule `user_cmd`).
- Modification non planifiée de `/etc/ssh/sshd_config` (auditd `ssh_config`).
- Alerte gitleaks signalant une clé privée commitée par erreur.

**Procédure d'isolation IMMÉDIATE (0–2 min — priorité absolue)** :

1. **Bloquer tout SSH externe entrant** :

   ```bash
   ssh admin@5.196.50.60 "easyrule block wan tcp any 5.196.50.60 22"
   ssh admin@5.196.50.70 "easyrule block wan tcp any 5.196.50.70 22"
   ```

2. **Killswitch Site B** (interdit tout outbound depuis services-s2) :

   ```bash
   ansible-playbook -i prod.ini playbooks/killswitch.yml \
     -e killswitch_state=active -e site=siteB
   ```

3. **Snapshot Proxmox du bastion immédiatement** (forensic intact) :

   ```bash
   ssh root@<proxmox-B> "qm snapshot <vmid-bastion> compromise-$(date +%F-%H%M)"
   ```

**Procédure de reprise CONTRÔLÉE (1–24 h)** :

1. **Forensic — extraction logs auditd + bash_history (30 min)** :

   ```bash
   ssh services-s2 "sudo journalctl --since '24 hours ago' --no-pager > /tmp/forensic.log"
   ssh services-s2 "sudo ausearch -k user_cmd --start recent > /tmp/auditd.log"
   scp services-s2:/tmp/*.log docs/forensic/$(date +%F)/
   ```

2. **Rotation IMMÉDIATE des secrets exposés (2 h)** :
   - Toutes clés SSH admin : génération nouvelles paires + déploiement
     via `ansible-playbook playbooks/site.yml --tags users`.
   - Tokens API pfSense : régénération via web GUI + update SOPS.
   - Tokens API Proxmox `GR46@pve!ci` : révocation + nouveau token via
     Proxmox UI.
   - PKI OpenVPN : rotation complète (CA + serveur + client).
   - Mots de passe admin pfSense (les deux sites) : nouveau strong password.
   - Seeds TOTP bastion : régénération via `setup-mfa` sur tous les users.

3. **Rebuild bastion-s2 / services-s2 from scratch (2 h)** :

   ```bash
   cd terraform/siteB && terraform destroy -target=module.bastion
   terraform apply -target=module.bastion
   ansible-playbook -i prod.ini playbooks/bastion.yml --limit bastion-s2
   ```

   La rebuild garantit l'absence de backdoor injectée.

4. **Re-validation MFA pour tous les admins (1 h)** :
   - Suppression `~/.google_authenticator` de tous les users sur bastion.
   - Re-enrollment TOTP via `setup-mfa` sur chaque admin physiquement présent.

5. **Notification stakeholders (≤ 24 h légal RGPD)** :
   - Si données personnelles exposées : déclaration CNIL sous 72 h.

**RTO cible** : 1 h isolation · 24 h reprise contrôlée.
**RPO cible** : 0 (sauf si données exfiltrées — voir forensic).

**Responsabilités** :

- **Security Lead** : pilote l'isolation et la rotation des secrets.
- **DRP Coordinator** : pilote la communication (interne et CNIL si besoin).
- **Infra Lead** : exécute le rebuild et la re-validation MFA.

**Communication de crise** :

| T (relatif) | Action                                                       |
|------------|--------------------------------------------------------------|
| T+0        | Slack `#cia-security` (canal privé restreint) + appel        |
| T+15 min   | Mail stakeholders avec statut "incident sécurité en cours"   |
| T+2 h      | Rapport préliminaire interne (forensic en cours)             |
| T+24 h     | Rapport complet + check-list mitigations appliquées          |
| T+72 h     | Si données perso exposées : déclaration CNIL                 |
| T+30 j     | Post-mortem public partagé (si non sensible)                 |

**Test de validation post-reprise** :

```bash
# Toutes les clés SSH compromises sont révoquées
ansible -i prod.ini all -m shell -a "grep -c COMPROMISED_KEY ~/.ssh/authorized_keys" \
  | grep -v "0$"   # ✓ doit retourner aucune ligne
# fail2ban a banni les IPs suspectes
ssh services-s2 "sudo fail2ban-client status sshd | grep Banned"
# auditd capture toujours les execve
ssh services-s2 "sudo auditctl -l | grep user_cmd"
# Bastion bootstrapable en MFA propre
ssh -i ~/.ssh/cia_gr46 desmon@bastion-s2 'echo "MFA challenge incoming"'
```

**Lessons learned** :

- Vecteur d'attaque identifié : ☐ clé leak · ☐ MFA bypass · ☐ brute-force ·
  ☐ supply-chain · ☐ autre : _______.
- Délai entre intrusion et détection : ___ heures.
- Données exposées : ☐ aucune · ☐ logs · ☐ secrets · ☐ PII.
- Procédure de rotation a déroulé sans heurts : ☐ oui · ☐ non, ajustement
  nécessaire dans : _______.

---

### SCEN-D — Activation killswitch en faux positif

**Description** : le killswitch a été déclenché (par alerte automatique mal
calibrée, action humaine accidentelle, ou exercice DRP mal communiqué) sans
qu'il y ait de vrai incident sécurité. La situation : pfSense Site A ou B
bloque tout outbound, les utilisateurs ne peuvent plus joindre Internet, les
logs cessent de remonter, NetBox ne synchronise plus.

| Probabilité | Impact | Criticité globale |
|---|---|---|
| Moyenne (premier exercice DRP) | Moyen (rupture service mais pas de fuite) | **S2** |

**Déclencheurs et détection** :

- Tickets utilisateurs : "Internet HS depuis HH:MM".
- Status pfSense montre la règle floating `KILLSWITCH` en `enabled` alors
  qu'elle devrait être `disabled`.
- Logs Logstash : arrêt brutal des events sortants côté site bloqué.
- Vérification : aucune intrusion détectée dans la fenêtre des 24 h
  précédentes (rule `ssh_failure < 5 / h` OK, pas d'audit anomalie).

**Procédure de validation (avant de désactiver — 5 min)** :

⚠️ **Ne PAS désactiver le killswitch en aveugle**. Vérifier d'abord qu'il
s'agit bien d'un faux positif.

1. **Confirmer absence de vrai incident** :
   - Kibana : aucune alerte de niveau S0/S1 dans la fenêtre
     [killswitch_time - 1 h, killswitch_time].
   - Auditd : aucun `user_cmd` suspect.
   - Aucun rapport de sécurité en cours.

2. **Identifier l'origine du déclenchement** :

   ```bash
   ssh admin@5.196.50.60 "cat /var/log/system.log | grep killswitch | tail -20"
   git log -p --since='2 hours ago' ansible/playbooks/killswitch.yml
   ```

   Sources possibles : alerte Kibana mal calibrée, commande Ansible lancée
   par erreur, ou test DRP non annoncé.

**Procédure de désactivation contrôlée (5–15 min)** :

1. **Annoncer Slack** `#cia-ops` : *"Killswitch faux positif confirmé,
   désactivation en cours"*.

2. **Désactivation via Ansible (procédure inverse)** :

   ```bash
   ansible-playbook -i prod.ini playbooks/killswitch.yml \
     -e killswitch_state=inactive -e site=<siteX>
   ```

3. **Vérification rétablissement complet** :

   ```bash
   ssh services-s2 "curl -s -o /dev/null -w '%{http_code}\n' https://www.google.com"
   # ✓ 200
   ansible -i prod.ini all -m ping
   # ✓ tous répondent pong
   ```

4. **Reprise du flux observabilité** :

   ```bash
   ssh services-s2 "sudo systemctl restart filebeat"
   curl -s http://10.10.10.40:9200/_cat/indices?v | grep filebeat
   # ✓ nouveau bloc d'events ingéré
   ```

**RTO cible** : 15 min (de la détection à la désactivation).
**RPO cible** : 5 min de logs perdus en moyenne (Filebeat met en cache puis
forward dès reconnexion).

**Responsabilités** :

- **DRP Coordinator** : valide qu'il s'agit bien d'un faux positif (ne pas
  désactiver sans cette validation explicite).
- **Infra Lead** : exécute la désactivation et vérifications.
- **Security Lead** : analyse a posteriori et calibre les alertes pour
  réduire le risque de récidive.

**Communication de crise** :

| T (relatif) | Action                                                  |
|------------|---------------------------------------------------------|
| T+0        | Slack `#cia-ops` : "killswitch déclenché, investigation"|
| T+5 min    | Slack : "faux positif confirmé, désactivation en cours" |
| T+15 min   | Slack : "rétablissement complet, post-mortem à suivre"  |
| T+24 h     | Post-mortem interne : ajuster seuils alerting           |

**Test de validation post-reprise** :

```bash
# Killswitch bien désactivé
ssh admin@5.196.50.60 "pfctl -sr | grep KILLSWITCH | grep disabled"
# Connectivité Internet sortante restaurée
ssh services-s2 "curl -I https://www.elastic.co 2>&1 | head -2"
# Logs reprennent le flux normal
docker compose -f ~/elastic-demo/docker-compose.yml logs --tail=20 logstash \
  | grep "events received"
# Idempotence : un second apply ne change rien
ansible-playbook -i prod.ini playbooks/site.yml --check
# PLAY RECAP : changed=0
```

**Lessons learned** :

- Origine du déclenchement : ☐ alerte Kibana mal calibrée · ☐ commande
  humaine accidentelle · ☐ test DRP non annoncé · ☐ autre : _______.
- Délai de détection du killswitch (utilisateur impacté → annonce ops) :
  ___ minutes (cible : < 5 min).
- Calibration alerte ajustée : ☐ oui (seuil passé de _ à _) · ☐ non.
- Documentation killswitch mise à jour avec ce cas : ☐ oui · ☐ non.

---

## 4. Tests & exercices

Semestriels, plan :

| # | Scénario                         | Date cible  | Portée   |
|---|----------------------------------|-------------|----------|
| 1 | Perte VM services-s1             | 2026-06-15  | Site A   |
| 2 | Killswitch Site B                | 2026-07-01  | Site B   |
| 3 | Restore pfSense config depuis git| 2026-09-15  | Site A   |
| 4 | Rotation cert OpenVPN            | 2026-11-01  | Les deux |

Chaque exercice génère un compte-rendu commité sous `docs/drp/reports/`.

## 5. Sauvegardes

| Artefact                       | Localisation                     | Rétention |
|--------------------------------|----------------------------------|-----------|
| NetBox pg_dump                 | `/var/backups/netbox/` + offsite | 30 j      |
| pfSense XML                    | git `configs/pfsense/`           | illimité  |
| Terraform state                | Backend distant chiffré          | illimité  |
| Secrets SOPS                   | git (chiffré)                    | illimité  |
| Vault raft snapshots           | `/var/backups/vault/` + offsite  | 30 j      |
| Elasticsearch snapshots        | S3 compat (à configurer v2)      | 30 j      |

## 6. Contacts

| Rôle              | Canal                          |
|-------------------|--------------------------------|
| DRP coordinator   | #ops + téléphone on-call       |
| Infra provider    | Proxmox support                |
| ISP               | N° commercial (cf. contrats)   |
| Stakeholders      | <stakeholders@cia.lan>           |

## 7. Journal de révision

| Date        | Auteur | Changement                                                |
|-------------|--------|-----------------------------------------------------------|
| 2026-04-18  | GR46   | Version initiale post follow-up #1                        |
| 2026-06-20  | GR46   | Section 3 bis — 4 scénarios détaillés (SCEN-A à D) pré-Final |
