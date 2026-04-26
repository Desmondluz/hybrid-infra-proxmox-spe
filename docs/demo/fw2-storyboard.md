# FW2 — Storyboard de la démo (15 min + 2 min Q&R)

**Cible** : jury Epitech CIA 2025-2026 (Silya, Valentin)
**Durée** : 15 min de démo, 2 min de Q&R
**Présentateur** : Desmond (GR46)
**Pré-requis salle** : VGA/HDMI, accès réseau école pour connexion VPN au lab,
fallback hotspot 4G en cas de filtrage.
**Dernière revue** : 2026-04-26

---

## Avant la démo (T-15 min)

Checklist d'amorçage à dérouler dans cet ordre, en silence, dans une fenêtre
PowerShell dédiée. Si l'une de ces étapes échoue, basculer sur le doc
[`fw2-backup-evidence.md`](fw2-backup-evidence.md) — ne pas tenter de débuger
en live.

```powershell
# 1. Lab proxmox up
ping -n 2 192.168.208.50
# 2. Tunnel VMware NAT vers le réseau du lab
Test-NetConnection 192.168.208.50 -Port 8006
# 3. Toutes les VMs Site B running
ssh root@192.168.208.50 "qm list"
# attendu : VMID 100/101/102 status=running
# 4. age key chargée
$env:SOPS_AGE_KEY_FILE
# attendu : C:\Users\DELL\AppData\Roaming\sops\age\keys.txt
# 5. terraform/siteB plan idempotent
cd C:\Users\DELL\Desktop\T-NSA-810-REP25\hybrid-infra-proxmox-spe\terraform\siteB
terraform plan "-out=siteB.tfplan"
# attendu : "No changes. Your infrastructure matches the configuration."
```

Onglets navigateur à pré-ouvrir :

1. Proxmox UI : `https://192.168.208.50:8006` (déjà loggé `terraform@pve`)
2. Repo GitHub `T-NSA-810-REP25/hybrid-infra-proxmox-spe` — onglet **Actions**
   sur le dernier run vert
3. Diagramme `docs/architecture/infra.drawio` rendu en PNG plein écran
4. Kibana `https://observability-s1:5601` (Site A — fenêtre démo simulée
   sur captures, voir backup §4)

---

## Section 1 — Topologie + idempotence Terraform (2 min)

**Message clé** : "Tout ce qui est sur l'écran a été décrit en code et est
réversible en une commande."

### 1.1 Diagramme (45 s)

Onglet 3. Pointer dans l'ordre :

- vmbr0 (WAN) ↔ vmbr146 (LAN GR46) sur Site B
- VLAN 20/21/22 sur vmbr146 (DMZ / SERVICES / ADMIN)
- pfSense-s2 = passerelle 192.168.0.1
- bastion-s2 (192.168.0.10, port 2222), services-s2 (192.168.10.20)
- Tunnel OpenVPN site-à-site vers Site A (10.10.0.0/24)

### 1.2 Idempotence Terraform (75 s)

Fenêtre PowerShell. Volume sonore : on lit la commande à voix haute.

```powershell
cd C:\Users\DELL\Desktop\T-NSA-810-REP25\hybrid-infra-proxmox-spe\terraform\siteB
terraform plan
```

**Sortie attendue** (lue à voix haute) :

```text
data.sops_file.secrets: Reading...
data.sops_file.secrets: Read complete after 0s
module.network.proxmox_virtual_environment_network_linux_bridge.this["vmbr0"]: Refreshing state...
module.vm_pfsense.proxmox_virtual_environment_vm.this: Refreshing state... [id=101]
module.vm_bastion.proxmox_virtual_environment_vm.this: Refreshing state... [id=102]
module.vm_services.proxmox_virtual_environment_vm.this: Refreshing state... [id=100]

No changes. Your infrastructure matches the configuration.
```

**Phrase de transition** : *"Le state Terraform colle au runtime — pas de
drift. C'est la même commande qui peut détruire l'infra entière en
30 secondes (`terraform destroy`), ce qui prouve que rien n'a été cliqué à
la main."*

---

## Section 2 — Création d'un user bastion via Ansible (3 min)

**Message clé** : "L'ajout d'un opérateur passe par une PR — pas par un
shell sur le bastion."

### 2.1 Édition de l'inventaire (45 s)

Ouvrir `ansible/group_vars/all.yml` dans VS Code (split à droite).

Montrer le bloc `bastion_users:` puis ajouter en live :

```yaml
bastion_users:
  - name: desmond
    ssh_pubkey: "ssh-ed25519 AAAA... desmond@gr46"
    totp_required: true
  - name: jury_demo                  # <-- nouvelle entrée
    ssh_pubkey: "ssh-ed25519 AAAA... jury@epitech"
    totp_required: true
```

Sauvegarder. La pré-commit hook (`gitleaks`, `yamllint`) tourne sous les yeux
du jury et ressort vert.

### 2.2 Apply ciblé (75 s)

```powershell
cd C:\Users\DELL\Desktop\T-NSA-810-REP25\hybrid-infra-proxmox-spe
ansible-playbook -i ansible/inventories/siteB.ini `
                 ansible/playbooks/bastion.yml `
                 --tags users `
                 --check
```

Run en `--check` pour la démo (pas d'écriture réelle). Output attendu :

```text
PLAY [Bastion durci] ******************************************************
TASK [bastion : Ensure bastion users present] *****************************
changed: [bastion-s2] => (item={'name': 'jury_demo', ...})
TASK [bastion : Configure TOTP for bastion users] *************************
changed: [bastion-s2] => (item={'name': 'jury_demo', ...})

PLAY RECAP ****************************************************************
bastion-s2 : ok=4  changed=2  unreachable=0  failed=0
```

### 2.3 Login TOTP (60 s)

Sur la backup VM (capture animée si la latence VPN > 2 s, voir
[`fw2-backup-evidence.md` §2.3](fw2-backup-evidence.md#23-login-totp-bastion)) :

```powershell
ssh -p 2222 jury_demo@192.168.0.10
# Password: <pw>
# Verification code: <Google Authenticator>
# Bienvenue sur bastion-s2 (Site B) — toute commande est auditée.
```

Pointer le banner d'audit + l'entrée correspondante dans
`/var/log/auth.log` (tail prêt dans onglet 4 de tmux).

**Phrase de transition** : *"L'ajout d'un user transite par git, lint, CI,
puis Ansible. Aucun secret n'a été tapé dans une CLI."*

---

## Section 3 — Killswitch (2 min)

**Message clé** : "En cas de compromission supposée, on isole le Site B en
moins de 30 secondes, et on prouve l'isolation."

### 3.1 État avant (20 s)

Depuis services-s2 :

```bash
ssh services-s2 "curl -m 3 -I https://www.epitech.eu"
# attendu : HTTP/2 200
```

### 3.2 Activation (40 s)

```powershell
ansible-playbook -i ansible/inventories/siteB.ini `
                 ansible/playbooks/killswitch.yml `
                 -e "killswitch_state=on"
```

Output attendu (extrait) :

```text
TASK [killswitch : Push floating block-all rule] **************************
changed: [pfsense-s2]
TASK [killswitch : Reload pfctl] ******************************************
changed: [pfsense-s2]
PLAY RECAP : pfsense-s2 : ok=3  changed=2
```

### 3.3 Test bloqué (30 s)

```bash
ssh services-s2 "curl -m 3 -I https://www.epitech.eu"
# attendu : curl: (28) Connection timed out
ssh services-s2 "curl -m 3 -I https://192.168.0.10"
# attendu : curl: (28) Connection timed out  (LAN coupé aussi)
```

### 3.4 Désactivation (30 s)

```powershell
ansible-playbook -i ansible/inventories/siteB.ini `
                 ansible/playbooks/killswitch.yml `
                 -e "killswitch_state=off"
```

Refaire le `curl` initial → 200. Pointer la fenêtre d'audit pfSense (UI →
Status → System Logs → Firewall) pour montrer la trace.

**Phrase de transition** : *"30 secondes pour fermer, 30 secondes pour
rouvrir, et tout est tracé."*

---

## Section 4 — Dashboards Kibana (3 min)

**Message clé** : "Pour chaque action de la démo, on a une trace dans
Kibana — c'est la preuve par le log."

> **Note jury** : la stack Elastic tourne sur Site A (non démontré live en
> FW2 — fenêtre démo physique en FW3). Cette section est jouée sur des
> captures vidéo annotées de l'environnement de pré-prod, voir
> [`fw2-backup-evidence.md` §4](fw2-backup-evidence.md#4-kibana--captures-de-pré-prod).

### 4.1 Dashboard SSH (60 s)

Ouvrir `Overview / SSH Auth Events`. Mettre en évidence :

- Entrée `jury_demo` créée à T-2 min (preuve corrélation avec §2)
- Failures fail2ban (champs `process.name=fail2ban`, niveau `WARN`)
- Carte des IP source

### 4.2 Dashboard pfSense (60 s)

Ouvrir `Overview / pfSense Firewall`. Pointer :

- Pic de drops à T-1 min = activation killswitch (§3)
- Trafic OpenVPN inter-sites (`source.port=1194`)
- Top destinations bloquées

### 4.3 Dashboard OpenVPN (60 s)

Ouvrir `Overview / VPN Tunnel`. Pointer :

- Heartbeat tunnel (RTT < 50 ms hub → spoke)
- Re-key TLS toutes les 60 min
- Volume IN/OUT par session client

**Phrase de transition** : *"Le runtime est observable de bout en bout, et
les pipelines sont versionnés dans le repo."*

---

## Section 5 — Onboarding Site C (3 min)

**Message clé** : "Ajouter un troisième site n'est pas une refonte — c'est
un script de 5 commandes."

### 5.1 Walkthrough du golden path (90 s)

Ouvrir `docs/onboarding-new-site.md` dans VS Code, mode preview Markdown.

Faire défiler doucement les 6 sections :

1. Hypothèses (CIDR, ASN privé, taille équipe)
2. Provisioning Proxmox (clone du template Site B)
3. Stack Terraform (`cp -r terraform/siteB terraform/siteC`)
4. Inventaire Ansible (`siteC.ini` + `group_vars/siteC.yml`)
5. Routage VPN (mesh ou hub-and-spoke selon volume)
6. Vérifications

### 5.2 Diff démontrable (90 s)

Montrer en split éditeur :

```text
terraform/siteB/variables.tf     ← terraform/siteC/variables.tf
ansible/inventories/siteB.ini    ← ansible/inventories/siteC.ini
ansible/group_vars/siteB.yml     ← ansible/group_vars/siteC.yml
```

Les diff portent uniquement sur :

- `site_id`, `site_name`
- préfixes (192.168.30.0/24)
- IP pfSense (10.10.0.3 sur le tunnel)

**Phrase de conclusion** : *"On a livré FW2 sur du code reproductible, des
secrets chiffrés, une CI verte sur 4 workflows, et un runbook par
fonction critique. La suite (FW3) c'est : déploiement physique Site A,
DRP exercice live et keynote final."*

---

## Section Q&R (2 min)

Réponses préparées pour les questions probables :

| Question                                         | Réponse courte                                                                                                                                    |
|--------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| Pourquoi pas Vault dès FW2 ?                     | SOPS+age suffit pour les secrets statiques (passwords, certs). Vault est planifié FW3 pour le dynamique (tokens API, PKI OpenVPN à rotation 24h). |
| Pourquoi pas full-mesh OpenVPN ?                 | Hub-and-spoke avec Site A en hub : 1 endpoint à durcir, audit centralisé. Migration full-mesh prévue si N≥4 sites (cf. ADR `tech-choices.md` §11).  |
| Que se passe-t-il si la clé age fuite ?          | Procédure §7 du runbook `secrets.md` : nouvelle paire, `sops updatekeys` sur tous les fichiers, retrait clef publique de `.sops.yaml`, commit.     |
| ILM 30 jours = pourquoi pas 90 ?                 | Single-node Elastic, ~120 GB de logs/mois sur la stack actuelle. Discussion avec Silya/Valentin (cf. `followup2.md` §3.3).                          |
| Qui peut unsealer Vault si Desmond indispo ?     | 3-of-5 quorum : 2 admins GR46 + 1 sponsor + 1 archive offline + 1 hors bande (cf. runbook `secrets.md` §3).                                       |
| Que fait la CI en plus du lint ?                 | gitleaks + trufflehog + checkov + tfsec + tflint + ansible-lint + yamllint + markdownlint. Voir badges README.                                     |

Si question hors scope : *"Bonne question — je note pour FW3."*

---

## Plan B si une section échoue

| Section échouée | Bascule                                                                          |
|-----------------|----------------------------------------------------------------------------------|
| §1 idempotence  | Capture d'écran du dernier `terraform plan` réussi (commit `6f3e2c1`)            |
| §2 ansible      | Capture vidéo MP4 de l'apply réel (`docs/demo/captures/bastion-user-add.mp4`)    |
| §3 killswitch   | Capture vidéo MP4 (`docs/demo/captures/killswitch-on-off.mp4`)                   |
| §4 Kibana       | Captures PNG du panneau (`docs/demo/captures/kibana-*.png`) — par défaut         |
| §5 onboarding   | Lecture du `docs/onboarding-new-site.md` rendu en preview Markdown               |

Toutes les captures sont versionnées sous `docs/demo/captures/` et
référencées dans [`fw2-backup-evidence.md`](fw2-backup-evidence.md).

---

## Checklist post-démo

À cocher dans les 30 min qui suivent :

- [ ] Noter les retours Silya/Valentin dans `docs/backlog/followup3.md`
- [ ] Faire `git tag -a fw2-2026-04 -m "FW2 démo"` (déjà fait par Phase 8)
- [ ] Pousser un message de remerciement #ops
- [ ] Rotation immédiate du mot de passe `terraform@pve` (compte de démo)
- [ ] Re-générer la clé age si la session a été enregistrée (par précaution)

---

*GR46 — CIA Epitech 2025-2026 — Storyboard FW2.*
