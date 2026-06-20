# Runbook — Gestion du Terraform State

**Owner** : GR46 — Equipe infra
**Dernière mise à jour** : 2026-06-20
**Niveau** : pro · single-dev (FW3-Final) avec plan de migration équipe

---

## 1. Contexte

Terraform maintient un fichier `terraform.tfstate` qui décrit *l'état réel*
des ressources qu'il a provisionnées (Proxmox VMs, Azure VM, bridges, etc.).
Ce fichier est **critique** : sa perte ou corruption entraîne une perte de
contrôle de l'infrastructure (Terraform ne sait plus quoi importer ni
détruire). Il contient aussi des **valeurs sensibles** (tokens API, mots de
passe initiaux, IPs internes), ce qui interdit son versionnement dans Git.

## 2. Choix actuel — backend local (FW3 → keynote finale)

L'infrastructure GR46 utilise actuellement le **backend Terraform local par
défaut** :

- `terraform/siteA/terraform.tfstate` — state Site A (école, hôte
  `ns3050272.ip-51-255-76.eu`)
- `terraform/siteB/terraform.tfstate` — state Site B (école, hôte
  `ns3183326.ip-146-59-253.eu`)
- `terraform/siteC-azure/terraform.tfstate` — state Site C cloud Azure
- Backups `*.tfstate.backup` générés automatiquement à chaque apply

Tous ces fichiers sont **explicitement exclus de Git** par
`.gitignore` (lignes 1-15) :

```text
**/.terraform/*
*.tfstate
*.tfstate.*
```

## 3. Sécurité opérationnelle locale

Les states locaux sont stockés sur le poste de pilotage (laptop Desmon
sous Windows + WSL Ubuntu). Mesures appliquées :

- **Sauvegarde manuelle régulière** : copie `terraform.tfstate*` vers
  un cloud personnel chiffré après chaque apply significatif.
- **Permission stricte** : fichiers en `chmod 600` (lecture/écriture par
  le propriétaire uniquement).
- **Pas de commit accidentel** : `.gitignore` durci + hook pre-commit
  `gitleaks` qui détecterait un secret leaké si bypass.
- **Documentation des commandes critiques** dans le runbook : ne jamais
  `terraform destroy` sans avoir backup du state d'abord.

## 4. Plan de migration — backend distant (post-keynote finale)

Pour passer à un workflow multi-développeurs en production, migration
prévue vers un backend distant. Trois options évaluées dans
[`tech-choices.md` ADR-14](../tech-choices.md) :

| Backend | Avantages | Inconvénients | Choix |
|---|---|---|---|
| **Azure Storage** | Géré, S3-compat, intégré Entra ID, Students free tier 5 Go | Verrouillage par blob lease (limité) | ⭐ Retenu si Site C Azure runtime |
| **Terraform Cloud** | Verrouillage natif, UI, state versionning, plan/apply remote | Free tier limité à 5 users + remote runs facturés | Backup |
| **S3 + DynamoDB** | Standard de fait, verrouillage table DynamoDB | Dépend d'AWS, coût > 0 hors free tier | Reporté |

Configuration cible (à appliquer post-keynote) :

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-cia-gr46-tfstate"
    storage_account_name = "ciagr46tfstate"
    container_name       = "tfstate"
    key                  = "siteA.tfstate"
  }
}
```

Procédure de migration :

1. Provisionner le Storage Account Azure dédié au state (RG distinct,
   region france-central, accès clé `Microsoft Entra ID`).
2. Activer le versioning + soft delete (30 jours) sur le container.
3. Backup local `terraform.tfstate` avant migration.
4. Ajouter le bloc `backend` dans chaque stack (`siteA`, `siteB`,
   `siteC-azure`).
5. `terraform init -migrate-state` qui pousse le state local vers le
   backend distant et active le verrouillage.
6. Vérifier que `terraform plan` répond toujours "No changes".

## 5. Récupération en cas de perte de state

Si le `terraform.tfstate` local est perdu/corrompu :

1. **Restaurer depuis le backup local** (`.tfstate.backup` est généré
   à chaque apply, conservé à côté du state).
2. **Si aucun backup local** : importer les ressources existantes via
   `terraform import` (procédure documentée dans
   `docs/backlog/followup3.md` Phase 2, déjà testée avec les VMs école
   pré-allouées). Compter ~30 min pour 6-10 ressources.
3. **Si l'infrastructure cible est inaccessible** : déclencher le
   scénario PRA correspondant dans [`docs/drp/drp.md`](../drp/drp.md).

## 6. Vérification post-clean

Pour s'assurer qu'aucun state n'est plus tracké :

```bash
git ls-files | grep -E "tfstate|\.terraform/" && echo "FAIL" || echo "OK"
```

La commande doit retourner `OK` (rien tracké).

---

*GR46 — CIA Epitech 2025-2026 — Runbook vivant, mis à jour à chaque
changement majeur du backend.*
