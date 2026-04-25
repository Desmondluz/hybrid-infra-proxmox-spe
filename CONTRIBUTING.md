# Contributing — Hybrid Infrastructure Proxmox SPE

Merci de lire ce guide avant toute contribution. L'objectif est de maintenir un repo propre, reproductible et auditable.

## Prérequis locaux

| Outil | Version minimale | Usage |
|---|---|---|
| Git | 2.40+ | versioning |
| Terraform | 1.7+ | IaC |
| Ansible | 2.15+ | configuration |
| Python | 3.11+ | SDK NetBox, scripts |
| SOPS + age | 3.8+ / 1.1+ | secrets |
| pre-commit | 3.5+ | hooks |
| tflint / ansible-lint / yamllint | récent | linting |

Installation rapide :

```bash
pip install --user ansible ansible-lint yamllint pre-commit
brew install terraform tflint sops age     # macOS
# ou équivalent apt/winget/choco

pre-commit install
pre-commit install --hook-type commit-msg
```

## Stratégie de branches

- `main` : branche protégée, état reproductible de la production. Aucun push direct.
- `develop` : branche d'intégration. Les PR y sont mergées en premier.
- `feature/<scope>-<description-courte>` : nouvelles fonctionnalités.
- `fix/<scope>-<description>` : correctifs.
- `docs/<sujet>` : documentation uniquement.
- `ci/<scope>` : CI/CD uniquement.

Exemple : `feature/ansible-role-netbox`, `fix/terraform-siteA-vm-disk-size`.

## Convention de commits

Format **Conventional Commits** :

```
<type>(<scope>): <description en impératif 50 car max>

<corps optionnel, 72 car par ligne, explique le pourquoi>

<footer optionnel : Refs #ticket, BREAKING CHANGE: ...>
```

Types acceptés :

| Type | Quand l'utiliser |
|---|---|
| `feat` | Nouvelle fonctionnalité (code ou config) |
| `fix` | Correctif |
| `docs` | Documentation uniquement |
| `ci` | Pipeline / workflows |
| `refactor` | Changement sans impact fonctionnel |
| `test` | Ajout / modification de tests |
| `chore` | Maintenance (deps, gitignore, ...) |
| `perf` | Optimisation |
| `security` | Correctif ou amélioration sécurité |

Exemples :

```
feat(terraform): add proxmox-vm module with cloud-init support
fix(ansible-pfsense): handle missing interface on first run
docs(runbook): document kill switch activation procedure
ci(terraform): add tflint to validation pipeline
```

## Process de contribution

1. Créer un ticket (GitHub Issue) référencant le critère d'évaluation concerné si applicable.
2. Créer la branche depuis `develop`.
3. Coder. Commits petits et fréquents.
4. Rejouer `pre-commit run --all-files` avant push.
5. Ouvrir une PR vers `develop` avec la description remplie (template auto).
6. Attendre la CI verte + 1 reviewer.
7. Merger en squash pour garder un historique lisible.

## Règles non négociables

- **Aucun secret en clair.** Tous les secrets passent par SOPS (fichiers `*.enc.yml`) ou Vault.
- **IaC pour tout ce qui peut l'être.** Pas de configuration manuelle non documentée.
- **Idempotence Ansible.** Toute task doit pouvoir être rejouée sans casse.
- **Documentation au fil de l'eau.** Une brique déployée = un runbook mis à jour.
- **Pas de `main` cassée.** CI green avant merge, toujours.

## Structure du repo

Voir `README.md` pour l'arborescence détaillée.

## Questions, aide

Canal Discord du projet ou ouvrir une Issue label `question`.
