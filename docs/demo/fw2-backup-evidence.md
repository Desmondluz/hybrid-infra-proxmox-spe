# FW2 — Backup evidence pour la démo

**Rôle** : preuve "hors-ligne" si la démo live échoue (filtrage école,
panne Proxmox, latence VPN, batterie).
**Référence** : à utiliser conjointement avec
[`fw2-storyboard.md`](fw2-storyboard.md).

Toutes les captures sont enregistrées sous `docs/demo/captures/` (à
peupler avant le jour J — voir checklist §6).

---

## 1. Topologie + idempotence Terraform

### 1.1 Diagramme

- `docs/architecture/infra.drawio` → exporter en PNG 4K
  (`captures/infra.png`) avant la démo. Présenter en plein écran sans le
  client drawio.

### 1.2 Sortie `terraform plan`

- `captures/terraform-plan-noop.png` — capture pleine page de la sortie
  *"No changes. Your infrastructure matches the configuration."*
- Inclure le `data.sops_file.secrets: Read complete after 0s` pour prouver
  que le déchiffrement age fonctionne.
- Commit de référence : à mettre à jour après le tag `fw2-2026-04`.

---

## 2. Création d'un user bastion via Ansible

### 2.1 Diff git de l'ajout

- `captures/group_vars-add-jury-user.png` — capture du diff dans VS Code,
  hunks colorés.

### 2.2 Sortie ansible-playbook

- `captures/ansible-bastion-add-user.png` — sortie `ok=4 changed=2`,
  pleine page, lecture facile.

### 2.3 Login TOTP bastion

- `captures/bastion-totp-login.mp4` — vidéo de 25 s :
  1. `ssh -p 2222 jury_demo@192.168.0.10`
  2. password
  3. Google Authenticator code
  4. banner d'audit
  5. `exit`
- Sous-titres burned-in (les jurys peuvent ne pas entendre le narrateur).

---

## 3. Killswitch

- `captures/killswitch-on-off.mp4` — vidéo de 50 s qui couvre les 4 étapes
  §3.1 → §3.4 du storyboard. Time-codes :
  - 00:00 → état avant (`curl HTTP/2 200`)
  - 00:10 → activation (`changed=2`)
  - 00:25 → test bloqué (`Connection timed out`)
  - 00:40 → désactivation + retour 200
- `captures/pfsense-firewall-log-killswitch.png` — onglet pfSense System
  Logs filtré sur la rule `floating-block-all`.

---

## 4. Kibana — captures de pré-prod

> **Mention orale obligatoire** : *"La stack Elastic tourne sur le Site A
> qui n'est pas connecté en FW2. Les captures qui suivent viennent de
> l'environnement de pré-prod monté sur la même image — la production
> physique est le sujet du Follow-up 3."*

### 4.1 Dashboard SSH

- `captures/kibana-ssh-overview.png` — vue Discover + visualizations,
  filtre `event.dataset:ssh.auth`, dernières 24h.
- Marquer en rouge la ligne `jury_demo` créée pendant la démo.

### 4.2 Dashboard pfSense

- `captures/kibana-pfsense-overview.png` — top sources bloquées, top
  destinations, courbe drops/min avec le pic killswitch.

### 4.3 Dashboard OpenVPN

- `captures/kibana-openvpn-overview.png` — heartbeat tunnel, re-keys, top
  clients par volume.

### 4.4 Pipeline Logstash (preuve de versioning)

- Capture rapide de `ansible/roles/logstash/templates/pipelines/pfsense.conf.j2`
  pour montrer que les pipelines sont en code, pas dans l'UI Kibana.

---

## 5. Onboarding Site C

### 5.1 Preview du runbook

- `captures/onboarding-new-site-preview.png` — preview Markdown rendu
  dans VS Code, table des matières visible.

### 5.2 Diff terraform/siteB → siteC

- `captures/onboarding-diff-siteB-siteC.png` — `git diff --stat` simulé
  entre `terraform/siteB/` et un répertoire `terraform/siteC/` créé en
  test (à dropper après la démo).
- Montre que les changements sont localisés à 4 fichiers : `variables.tf`,
  `terraform.tfvars`, `siteC.ini`, `group_vars/siteC.yml`.

---

## 6. Checklist préparation backup (à faire avant T-1 jour)

- [ ] Exporter `infra.drawio` en PNG 4K
- [ ] Re-jouer la séquence ansible bastion en local et capturer la sortie
- [ ] Enregistrer `bastion-totp-login.mp4` (OBS Studio, 25 s)
- [ ] Enregistrer `killswitch-on-off.mp4` (OBS Studio, 50 s)
- [ ] Exporter les 3 dashboards Kibana en PNG (zoom 100 %)
- [ ] Capturer `pfsense-firewall-log-killswitch.png`
- [ ] Capturer `terraform-plan-noop.png` après le dernier apply
- [ ] Capturer `group_vars-add-jury-user.png` (diff VS Code)
- [ ] Capturer `ansible-bastion-add-user.png`
- [ ] Capturer `onboarding-new-site-preview.png`
- [ ] Capturer `onboarding-diff-siteB-siteC.png` puis supprimer le
      répertoire `terraform/siteC/` de test
- [ ] Vérifier que `docs/demo/captures/` est dans `.gitignore` **non**
      (les captures servent au jury et doivent être versionnées) — à part
      les MP4 > 5 MB qui passent par Git LFS

---

## 7. Bascule en démo

Si une section live échoue, le présentateur :

1. Annonce en une phrase calme : *"Je bascule sur la capture pré-prod."*
2. Ouvre l'onglet correspondant (toutes les captures sont ouvertes en
   onglet caché dès le début de la démo).
3. Lit la capture en suivant le même phrasing que le storyboard.
4. Continue sur la section suivante sans débuger en live.

**Règle d'or** : pas plus de 60 secondes de tentative de débug live. Si la
section ne repasse pas, on bascule, on note l'incident pour FW3.

---

*GR46 — CIA Epitech 2025-2026 — Backup démo FW2.*
