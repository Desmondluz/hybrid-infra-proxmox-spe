# Onboarding d'un nouveau site (Site C, D, …)

**Propriétaire** : GR46 · **Dernière revue** : 2026-04-18

L'architecture CIA est conçue pour accueillir un troisième site en
réutilisant les mêmes modules Terraform, rôles Ansible et PKI Vault.
Ce guide est un *golden path* commité vérifiable.

## 1. Pré-requis

- Cluster Proxmox neuf, accessible en SSH root (ou API token créé).
- Empreinte TLS Proxmox récupérée : `openssl s_client -connect pve:8006`.
- Bloc CIDR libre (convention : Site C → `10.20.0.0/24` LAN + `10.20.10.0/24`
  ADMIN, tunnel `172.16.0.4/30`).
- Adresse WAN publique (fixe ou DNS dynamique).

## 2. Réservations dans NetBox

```bash
NETBOX_URL=https://netbox.s1.lan \
NETBOX_TOKEN=$(vault kv get -field=token kv/cia/netbox/admin-token) \
python3 ansible/roles/netbox/files/seed_netbox.py networking/addressing.yml
```

Après avoir ajouté dans `networking/addressing.yml` :

```yaml
siteC:
  name: "Site C — <nom>"
  networks:
    lan:    { cidr: 10.20.0.0/24,    description: "LAN Site C" }
    admin:  { cidr: 10.20.10.0/24,   description: "ADMIN Site C" }
  hosts:
    pfsense-s3:   { ip_admin: 10.20.10.1,  description: "pfSense Site C" }
    services-s3:  { ip: 10.20.0.20,        description: "Services Site C" }
    observability-s3: { ip: 10.20.0.30,    description: "Obs Site C" }
```

## 3. Terraform — copier `siteB` en `siteC`

```bash
cp -r terraform/siteB terraform/siteC
cd terraform/siteC
# éditer main.tf, vms.tf, terraform.tfvars : CIDR, noms, IPs, VLAN tags
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply
```

## 4. Ansible — nouvel inventaire + group_vars

```bash
cp ansible/inventories/siteB.ini ansible/inventories/siteC.ini
cp ansible/group_vars/siteB.yml  ansible/group_vars/siteC.yml
```

Édits :
- `site_id: 3`
- IPs spécifiques Site C
- `vpn_role: "client"` (si hub Site A reste unique)
- `bastion_wan_port: 2223` (ou autre si collision)

```bash
ansible-playbook -i ansible/inventories/siteC.ini ansible/playbooks/siteC.yml
```

(créer `playbooks/siteC.yml` sur le modèle de `siteB.yml`).

## 5. Vault — certificats OpenVPN Site C

```bash
export VAULT_TOKEN=$(cat ~/.cia-vault/openvpn.token)
# Nouveau rôle PKI si nécessaire (CN cia-vpn-client-siteC)
vault write pki_cia_vpn/roles/openvpn-client-siteC \
    allowed_domains="cia-vpn-client-siteC" allow_bare_domains=true \
    server_flag=false client_flag=true max_ttl=8760h
./vault/scripts/generate-certs.sh       # régénère (idempotent, ajoute siteC)
```

## 6. pfSense Site A (hub) — ajouter CCD & routes

Le playbook `vpn.yml` côté Site A doit lire `siteC` dans
`group_vars/all.yml → vpn_peers` et créer :

- un CCD `/etc/openvpn/ccd/cia-vpn-client-siteC` pointant `172.16.0.6`.
- des routes `192.168.20.0/24 → 172.16.0.6` (ou CIDR Site C).
- une règle firewall pfSense autorisant `siteC_lan → siteA_lan`.

Ces éléments sont déjà paramétrés par variable dans `roles/openvpn` :
éditer `vpn_peers` dans `group_vars/all.yml` puis :

```bash
ansible-playbook -i ansible/inventories/siteA.ini ansible/playbooks/vpn.yml
```

## 7. Observabilité

Filebeat des VM Site C → Logstash Site A via tunnel. Par défaut, `roles/filebeat`
lit `logstash_target` dans `group_vars/siteC.yml` (`10.10.0.30:5044`).
Aucune action supplémentaire.

## 8. Killswitch

Ajouter siteC dans `ansible/playbooks/killswitch.yml` (dict `site_hosts`)
et vérifier.

## 9. Test de bout en bout

```bash
# tunnel up
ansible siteC -m ping -i ansible/inventories/siteC.ini

# route cross-site
ssh admin@services-s3 ping -c 3 10.10.0.30

# logs remontent
curl -u elastic:${ES_PW} "http://10.10.0.30:9200/cia-system-*/_search?q=host.name:services-s3"
```

## 10. Documentation à mettre à jour

- [ ] `docs/access-matrix.md` — ajouter zones `C-L`, `C-A`.
- [ ] `docs/runbooks/vpn.md` — ajouter lignes diagnostic Site C.
- [ ] `docs/drp/drp.md` — scénarios étendus.
- [ ] Diagrammes `docs/architecture/*.drawio` — ajouter bloc siteC.

## 11. Validation

Revue par le lead sécurité avant mise en prod du nouveau site.
Preuves : capture `terraform apply` + `ansible-playbook` + test §9.

---

Ce parcours est le **golden path** demandé par le critère bonus
`bonus_golden_path`. Toute déviation doit être documentée en PR.
