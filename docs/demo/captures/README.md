# Captures FW2

Captures d'écran et exports utilisés comme preuves dans
[`fw2-demo-walkthrough.md`](../fw2-demo-walkthrough.md).

## Inventaire attendu

| Fichier | Section walkthrough | Source |
|---|---|---|
| `01-topology-infra.png` | 1.1 | `docs/architecture/infra.drawio` |
| `02-topology-vpn.png` | 1.2 | `docs/architecture/vpn.drawio` |
| `03-firewall-rules.png` | 1.3 | `docs/architecture/firewall-rules.drawio` |
| `04-access-matrix.png` | 1.4 | `docs/access-matrix.md` (preview MD) |
| `05-proxmox-vms-running.png` | 2.1 | Proxmox UI |
| `06-proxmox-bridges.png` | 2.2 | Proxmox UI → System → Network |
| `07-terraform-plan-noop.png` | 2.3 | Terminal `terraform plan` |
| `08-module-proxmox-vm.png` | 3.1 | VS Code split (main.tf + variables.tf) |
| `09-role-bastion-mfa.png` | 3.2 | VS Code (3 onglets bastion) |
| `10-playbook-killswitch.png` | 3.3 | VS Code (`killswitch.yml`) |
| `11-secrets-encrypted.png` | 3.4 | Terminal `type secrets\siteB.enc.yml` |
| `12-ci-actions-green.png` | 4.1 | GitHub Actions tab |
| (cap 13 retirée — preuve absorbée dans cap 12 via workflow `quality.yml`) | 4.2 | — |
| `14-security-scan-workflow.png` | 4.3 | VS Code (`security-scan.yml`) |
| `15-onboarding-new-site.png` | 5.1 | VS Code preview MD |
| `16-runbook-killswitch.png` | 5.2 | VS Code preview MD |
| `17-drp-scenarios.png` | 5.3 | VS Code preview MD |
| `18-school-proxmox-A-allocation.png` | 5b.1 | Proxmox UI école Site A |
| `19-school-proxmox-B-allocation.png` | 5b.2 | Proxmox UI école Site B |
| `20-gantt-fw2.png` | 5d.2 | `docs/gantt/CIA_Gantt_GR46-2.pptx` |
| `21-blockers-report.png` | 5d.3 | `docs/STATUS.md` section Blocages |
| `22-followup3-tickets.png` | 5d.2 | `docs/backlog/followup3.md` (preview MD) |

## Convention

- Format : PNG, zoom 100% à 200% selon contenu, fond clair
- Nommage : `NN-mots-en-kebab-case.png`, NN = ordre d'apparition
- Pas de PII / secrets visibles (passwords masqués, tokens floutés)
- Captures en français quand le texte capturé est en français (UI VS Code,
  Proxmox UI), en anglais quand l'outil est en anglais (Terraform,
  GitHub Actions)
