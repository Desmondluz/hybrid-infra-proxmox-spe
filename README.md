# 🏗️ Hybrid Proxmox Infrastructure  
### Secure, Automated & Scalable Multi‑Site Architecture

![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4)
![Ansible](https://img.shields.io/badge/Automation-Ansible-EE0000)
![Proxmox](https://img.shields.io/badge/Platform-Proxmox-000000)
![OpenVPN](https://img.shields.io/badge/VPN-OpenVPN-F47B20)
![pfSense](https://img.shields.io/badge/Firewall-pfSense-212121)
![Elasticsearch](https://img.shields.io/badge/Observability-Elasticsearch-005571)
## Status CI/CD

![Terraform CI](https://github.com/Desmondluz/Projects/hybrid-infra-proxmox-spe/actions/workflows/terraform.yml/badge.svg)
![Ansible CI](https://github.com/Desmondluz/Projects/hybrid-infra-proxmox-spe/actions/workflows/ansible.yml/badge.svg)
![Quality Checks](https://github.com/Desmondluz/Projects/hybrid-infra-proxmox-spe/actions/workflows/quality.yml/badge.svg)


---

## 🌍 Overview

This project implements a **hybrid infrastructure** composed of **two Proxmox sites** (on‑premise and remote), securely interconnected through a **site‑to‑site VPN**, and designed to be **scalable** for future site onboarding

The solution strictly follows the client requirements defined in the project specification :

- Secure inter‑site connectivity  
- Strong network segmentation  
- Automated provisioning (IaC)  
- Centralized observability  
- Automated IP management  
- Bastion‑based remote access  
- DNS forwarding between sites  
- Internal‑only website  
- Disaster recovery documentation  

---

# 🧱 Architecture

The infrastructure is built around **two Proxmox sites**:

- 🏢 **Site A (On‑Premise)** — Core services  
- 🌐 **Site B (Remote)** — Lightweight remote environment  

### 🔒 Network Segmentation

Each site is divided into:

- **Admin network** (Proxmox, pfSense, management)  
- **Services network** (NetBox, Elastic, internal website)  
- **LAN network** (user workloads)  

This segmentation enforces least privilege, as required by the project .

---

## 🔗 Site‑to‑Site VPN

- OpenVPN tunnel  
- Encrypted routed subnets  
- Firewall‑controlled flows  
- **Emergency kill switch** on both pfSense firewalls  
- DNS forwarding between sites (mandatory requirement)  

---

## 🧍 Bastion Host

- Located in **Site B**  
- Only entry point for external SSH access  
- Logged and monitored  
- Required for remote site access   

---

## 🧩 Centralized Services (Site A)

| Service | Description |
|--------|-------------|
| **NetBox** | IPAM / Source of Truth, automatically updated |
| **Elasticsearch** | Centralized logs & observability |
| **Internal Website** | Accessible only from LAN/Services networks |

These services must be clearly located in the architecture diagram .

---

## 📊 Architecture Diagrams

All diagrams are available in:

```
docs/architecture/
```

They include:

- Global infrastructure diagram  
- VPN topology  
- Firewall rules  
- DNS forwarding flow  

---

# 🚀 Core Features

- 🏗️ Hybrid infrastructure (2 Proxmox sites)  
- 🔐 OpenVPN site‑to‑site VPN  
- 🔥 pfSense firewalls with kill switch  
- 🧍 Bastion host for secure external access  
- 🌐 DNS forwarding between sites  
- 🗂️ NetBox IPAM with automated updates  
- 📊 Elasticsearch for centralized logging  
- 🕸️ Internal website (private access only)  
- 🔁 Full IaC reproducibility (Terraform + Ansible)  
- 📈 Multi‑site ready architecture  

---

# ⚙️ Technology Stack

| Layer              | Technology       |
|-------------------|-----------------|
| Virtualization    | Proxmox VE      |
| Infrastructure    | Terraform       |
| Configuration     | Ansible         |
| VPN               | OpenVPN         |
| Firewall          | pfSense         |
| Bastion           | Linux (SSH)     |
| IPAM              | NetBox          |
| Observability     | Elasticsearch   |
| Internal Website  | Nginx / Apache  |
| Secrets           | Vault           |

---

# 📁 Project Structure

```
hybrid-infra-proxmox-spe/
├── docs/
│   ├── architecture/
│   ├── runbooks/
│   ├── drp/
│   ├── backlog/
│   └── gantt/
├── terraform/
│   ├── siteA/
│   ├── siteB/
│   └── modules/
├── ansible/
│   ├── inventories/
│   ├── roles/
│   ├── playbooks/
│   └── group_vars/
├── vault/
├── configs/
├── networking/
└── README.md
```

This structure matches the expected deliverables .

---

# ⚡ Deployment

## 1. Clone the repository

```bash
git clone https://github.com/your-repo/hybrid-infra-proxmox-spe.git
cd hybrid-infra-proxmox-spe
```

## 2. Deploy infrastructure (Terraform)

Site A:

```bash
cd terraform/siteA
terraform init
terraform apply
```

Site B:

```bash
cd terraform/siteB
terraform init
terraform apply
```

## 3. Configure services (Ansible)

```bash
ansible-playbook -i inventories/siteA.ini ansible/playbooks/siteA.yml
ansible-playbook -i inventories/siteB.ini ansible/playbooks/siteB.yml
```

## 4. Deploy core services

```bash
ansible-playbook ansible/playbooks/vpn.yml
ansible-playbook ansible/playbooks/bastion.yml
ansible-playbook ansible/playbooks/elastic.yml
ansible-playbook ansible/playbooks/internal_website.yml
```

---

# 🔒 Security

Security is enforced at every layer:

- Least privilege  
- Default‑deny firewall rules  
- Segmentation (Admin / LAN / Services)  
- Bastion‑only external access  
- Encrypted VPN communications  
- Secure secrets storage (Vault)  
- Emergency kill switch  
- Logged administrative access  

---

# 🔄 Disaster Recovery

The project includes a complete DRP:

- Rebuild procedures (IaC + runbooks)  
- Backup & restore strategy  
- VPN recovery  
- Firewall rollback  
- Service restoration  

📄 Documentation:  
```
docs/drp/drp.md
```

---

# 📊 Project Management

- Backlog: `docs/backlog/`  
- Gantt chart: `docs/gantt/gantt.png`  
- Follow‑ups: scoping → build → beta → final delivery  

---

# ⚠️ Constraints

- **3 VMs maximum per Proxmox site** (mandatory)  
- **Actively maintained technologies only**  
- **Full documentation required**  
- **Infrastructure must be fully reproducible via IaC**  

---
