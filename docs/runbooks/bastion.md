# Runbook — Bastion SSH (Site B)

**Propriétaire** : GR46 · **Dernière revue** : 2026-04-18 · **Criticité** : S1

Couvre le bastion `bastion-s2` — point d'entrée SSH unique pour le Site B,
exposé en `WAN:2222 → 192.168.10.10:22` via pfSense, MFA Google Authenticator.

## 1. Accès

```bash
ssh -p 2222 admin@<IP_PUBLIQUE_SITE_B>
```

- Authentification : clef SSH + TOTP (Google Authenticator).
- Users admin : `admin_users` dans `ansible/group_vars/all.yml`.
- Pas de password SSH (PAM exige clef ET TOTP).

## 2. Enrôlement d'un nouvel admin

1. Éditer `ansible/group_vars/all.yml` → ajouter login + clef publique.
2. Lancer :

   ```bash
   ansible-playbook -i ansible/inventories/siteB.ini ansible/playbooks/bastion.yml --tags users
   ```

3. Sur le bastion, l'utilisateur exécute le setup MFA :

   ```bash
   ssh -p 2222 <user>@bastion.s2.lan
   ~/setup-mfa.sh
   ```

   Le script (`roles/bastion/templates/setup-mfa.sh.j2`) génère un QR code,
   enregistre `~/.google_authenticator` (chmod 400), ne stocke JAMAIS la
   seed ailleurs.
4. Vérifier :

   ```bash
   ssh -p 2222 <user>@bastion.s2.lan 'true'  # doit demander clef + TOTP
   ```

## 3. Checks quotidiens

```bash
ssh -p 2222 admin@bastion.s2.lan <<'EOF'
    systemctl status sshd fail2ban
    fail2ban-client status sshd
    last -n 20
    cat /var/log/auth.log | grep "Accepted publickey" | tail -n 5
EOF
```

Attendu : fail2ban `Banned IP list` < 20 (monitoré via Kibana).

## 4. Incident : pic d'échecs SSH

1. Vérifier logs :

   ```bash
   journalctl -u sshd -n 200 | grep -iE "invalid|failed"
   ```

2. Déclencher killswitch si brute force > 100/min :

   ```bash
   ansible-playbook ansible/playbooks/killswitch.yml -e killswitch_state=active -e site=siteB
   ```

3. Suivi :
   - Kibana : dashboard "SSH failures — 1h"
   - Grep `ssh_failure` tag dans `cia-system-*`
4. Lever killswitch après mitigation :

   ```bash
   ansible-playbook ansible/playbooks/killswitch.yml -e killswitch_state=inactive -e site=siteB
   ```

## 5. Révocation d'un utilisateur

```bash
# 1. Désactiver dans Ansible
vi ansible/group_vars/all.yml   # supprimer login de admin_users
ansible-playbook -i ansible/inventories/siteB.ini ansible/playbooks/bastion.yml --tags users

# 2. Vérifier absence
ssh -p 2222 admin@bastion.s2.lan "getent passwd <login> || echo REMOVED"

# 3. Invalider sessions actives
ssh -p 2222 admin@bastion.s2.lan "pkill -KILL -u <login> || true"
```

## 6. Sauvegarde / restauration

- `.google_authenticator` reste local (pas sauvegardé — un user qui perd son
  device régénère via §2 étape 3).
- `sshd_config` : Ansible, idempotent.

## 7. Logs

- `auth.log` : authentifications SSH (succès + échecs)
- `fail2ban.log` : bannissements
- Syslog forward : rsyslog `*.* @@10.10.0.30:5514` (Logstash)
- Kibana dashboards :
  - `cia-ssh-*` (succès/échecs/IP sources)
  - `cia-bastion-*` (audit logins)

## 8. Escalade

Si `auth.log` montre auth réussie depuis IP inconnue → incident security :
révoquer toutes clefs admin, régénérer, communiquer.
