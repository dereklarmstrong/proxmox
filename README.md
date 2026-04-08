# 🚀 Proxmox Utility Toolkit

> **Your homelab sidekick for VMs, containers, backups, and automation magic.**

---

## 🎯 What's This All About?

Welcome! This is your go-to collection of scripts and docs for taming Proxmox VE 8.x on Debian 12. Whether you're spinning up VMs, managing containers, setting up backups, or diving into Kubernetes clusters—there's something here to make your life easier.

**⚠️ Quick reality check:** This is a **learning playground**. Production homelabs thrive on simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = more failure points. Keep your production stuff simple, folks!

---

## 🏃 Quick Start (Let's Go!)

```bash
# 1. Clone and set up
git clone https://github.com/dereklarmstrong/proxmox.git
cd proxmox
cp config.example.sh config.sh         # Edit this with your settings
./scripts/test.sh                      # Optional: run the test suite

# 2. Enable the Proxmox community repo
bash scripts/setup/pve_community_repo.sh

# 3. Create a cloud-init template (pick your flavor)
# Ubuntu 24.04 (you'll need the SHA):
bash scripts/vm/create_cloud_init_template.sh -i 9000 --sha256 <ubuntu_sha>

# Oracle Linux 9 (checksum included):
bash scripts/vm/create_cloud_init_template.sh -i 9100 --os ol9

# 4. Clone a VM with your homelab IP
bash scripts/vm/clone_vm.sh -s 9000 -d 150 -n web01 -i 192.168.1.60/24 -g 192.168.1.1

# 5. (Optional) Deploy a Kubernetes cluster
bash scripts/k8s/deploy_ol_k8s_cluster.sh --config config.k8s.sh
```

---

## 📋 Prerequisites

- ✅ Proxmox VE 8.x on Debian 12 (bookworm)
- ✅ Run scripts as **root** on a Proxmox node
- ✅ SSH public key ready for cloud-init and container setups

---

## 🎨 What's Inside?

### 🗂️ Documentation

| Category | Docs |
|----------|------|
| **Getting Started** | [`README.md`](README.md) • [`docs/cheatsheet.md`](docs/cheatsheet.md) • [`docs/storage_strategy.md`](docs/storage_strategy.md) |
| **Backup & Recovery** | [`backup/readme.md`](backup/readme.md) • [`backup/backup-strategy.md`](backup/backup-strategy.md) • [`backup/gfs-strategy.md`](backup/gfs-strategy.md) • [`backup/pbs-setup.md`](backup/pbs-setup.md) • [`backup/restore-procedures.md`](backup/restore-procedures.md) • [`backup/verification.md`](backup/verification.md) |
| **GPU Passthrough** | [`gpu-passthrough/readme.md`](gpu-passthrough/readme.md) • [`gpu-passthrough/nvidia-cuda.md`](gpu-passthrough/nvidia-cuda.md) • [`gpu-passthrough/amd-rocm.md`](gpu-passthrough/amd-rocm.md) • [`gpu-passthrough/gaming.md`](gpu-passthrough/gaming.md) • [`gpu-passthrough/troubleshooting.md`](gpu-passthrough/troubleshooting.md) |
| **Networking** | [`networking/readme.md`](networking/readme.md) • [`networking/vlan-setup.md`](networking/vlan-setup.md) • [`networking/firewall-rules.md`](networking/firewall-rules.md) • [`networking/sdn-guide.md`](networking/sdn-guide.md) |
| **Automation** | [`automation/readme.md`](automation/readme.md) • [`automation/learning-path.md`](automation/learning-path.md) • [`automation/ansible/readme.md`](automation/ansible/readme.md) • [`automation/terraform/readme.md`](automation/terraform/readme.md) |
| **Security** | [`security.md`](security.md) • [`security/readme.md`](security/readme.md) • [`security/auditing.md`](security/auditing.md) • [`security/cis-benchmarks.md`](security/cis-benchmarks.md) • [`security/incident-response.md`](security/incident-response.md) • [`security/zero-trust.md`](security/zero-trust.md) |
| **Services** | [`services/vm-patterns.md`](services/vm-patterns.md) • [`services/container-patterns.md`](services/container-patterns.md) • [`services/service-deployments.md`](services/service-deployments.md) |

---

## 🛠️ Scripts at a Glance

### ⚙️ Setup & Utilities
- [`scripts/setup/pve_community_repo.sh`](scripts/setup/pve_community_repo.sh:1) — Enable the no-subscription repo
- [`scripts/download_github_keys.sh`](scripts/download_github_keys.sh:1) — Pull GitHub SSH keys into authorized_keys

### 🖥️ VM Templates & Cloning
- [`scripts/vm/create_cloud_init_template.sh`](scripts/vm/create_cloud_init_template.sh:1) — Build cloud-init templates (Ubuntu/Oracle Linux)
- [`scripts/vm/clone_vm.sh`](scripts/vm/clone_vm.sh:1) — Full clone with static IP + SSH key
- [`scripts/vm/destroy_vm.sh`](scripts/vm/destroy_vm.sh:1) — Nuke one or more VMs
- [`scripts/vm/check_template.sh`](scripts/vm/check_template.sh:1) — Validate templates and cloud-init config
- [`scripts/vm/compute_image_sha256.sh`](scripts/vm/compute_image_sha256.sh:1) — Download and checksum an image
- [`scripts/vm/console.sh`](scripts/vm/console.sh:1) — Quick console access
- [`scripts/vm/find_ip.sh`](scripts/vm/find_ip.sh:1) — Find a VM/container's IP by name
- [`scripts/vm/info.sh`](scripts/vm/info.sh:1) — Detailed VM/container info
- [`scripts/vm/snapshot.sh`](scripts/vm/snapshot.sh:1) — Snapshot management

### 🐧 Container Management
- [`scripts/containers/create_container.sh`](scripts/containers/create_container.sh:1) — Create LXC from template
- [`scripts/containers/destroy_container.sh`](scripts/containers/destroy_container.sh:1) — Destroy containers
- [`scripts/containers/list_templates.sh`](scripts/containers/list_templates.sh:1) — List available LXC templates

### 💾 Backups
- [`scripts/backup/backup_vm.sh`](scripts/backup/backup_vm.sh:1) — Backup a single VM/CT
- [`scripts/backup/backup_all.sh`](scripts/backup/backup_all.sh:1) — Backup everything
- [`scripts/backup/prune_backups.sh`](scripts/backup/prune_backups.sh:1) — Clean up old backups
- [`scripts/backup/report.sh`](scripts/backup/report.sh:1) — Generate backup status report

### 🔌 API Helpers
- [`scripts/api/create_api_token.sh`](scripts/api/create_api_token.sh:1) — Create API tokens
- [`scripts/api/api_request.sh`](scripts/api/api_request.sh:1) — Minimal curl wrapper for API calls

### ☸️ Kubernetes
- [`scripts/k8s/deploy_ol_k8s_cluster.sh`](scripts/k8s/deploy_ol_k8s_cluster.sh:1) — Deploy Oracle Linux K8s cluster

### 🌐 Network & Storage
- [`scripts/network/show.sh`](scripts/network/show.sh:1) — Show network configs for all VMs/CTs
- [`scripts/storage/cleanup.sh`](scripts/storage/cleanup.sh:1) — Clean up unused storage
- [`scripts/storage/disk_usage.sh`](scripts/storage/disk_usage.sh:1) — Disk usage by VM/container

### 📊 Status & Monitoring
- [`scripts/status.sh`](scripts/status.sh:1) — Dashboard-style status overview

### 🚀 Automation & Deployment
- [`scripts/deploy_base_vm_set.sh`](scripts/deploy_base_vm_set.sh:1) — Deploy base VMs for K8s
- [`scripts/create_vm_full_clone.sh`](scripts/create_vm_full_clone.sh:1) — Full clone with network + SSH setup

### 🧪 Testing
- [`scripts/test.sh`](scripts/test.sh:1) — Run the test suite (vendored bats)

---

## ⚙️ Configuration

Just copy the template and tweak it:

```bash
cp config.example.sh config.sh
```

Key settings to adjust: `DEFAULT_STORAGE`, `DEFAULT_BRIDGE`, `SSH_KEY_PATH`, `TEMPLATE_ID_START`, `BACKUP_STORAGE`, `BACKUP_RETENTION_DAYS`.

---

## 🎓 Learning Paths

### 🌱 Beginner
1. Start with basic VM/container creation
2. Learn simple backup procedures
3. Understand basic networking

### 🌿 Intermediate
1. Implement VLANs and firewall rules
2. Set up automated backups with retention
3. Learn Ansible for configuration management

### 🌳 Advanced
1. Deploy Proxmox Backup Server
2. Configure GPU passthrough for AI/gaming
3. Implement Terraform infrastructure as code

### 🌲 Expert
1. Zero trust architecture implementation
2. CIS benchmark compliance
3. Automated incident response

---

## 📚 Handy Links

- 🔗 [Proxmox API Viewer](https://pve.proxmox.com/pve-docs/api-viewer/index.html)
- 📖 [Proxmox Documentation](https://pve.proxmox.com/pve-docs/)
- 💾 [Proxmox Backup Server](https://www.proxmox.com/en/proxmox-backup-server)
- ☁️ [Cloud-init Documentation](https://cloud-init.io/)

---

## 📁 Repository Structure

```
proxmox/
├── README.md                    # You are here 👀
├── SECURITY.md                  # Security hardening guide
├── docs/
│   ├── cheatsheet.md            # CLI command reference
│   └── storage_strategy.md      # Storage type comparison
├── backup/
│   ├── readme.md                # Backup docs index
│   ├── backup-strategy.md       # 3-2-1 backup, GFS retention
│   ├── gfs-strategy.md          # GFS retention policy
│   ├── pbs-setup.md             # Proxmox Backup Server
│   ├── restore-procedures.md    # Restore procedures
│   └── verification.md          # Backup verification
├── gpu-passthrough/
│   ├── readme.md                # GPU passthrough index
│   ├── nvidia-cuda.md           # CUDA for AI/ML
│   ├── amd-rocm.md              # ROCm for AMD GPUs
│   ├── gaming.md                # Gaming VM setup
│   └── troubleshooting.md       # Troubleshooting guide
├── networking/
│   ├── readme.md                # Networking index
│   ├── vlan-setup.md            # VLAN configuration
│   ├── firewall-rules.md        # Firewall rules
│   └── sdn-guide.md             # SDN configuration
├── automation/
│   ├── readme.md                # Automation index
│   ├── learning-path.md         # Learning path
│   ├── ansible/
│   │   ├── readme.md            # Ansible guide
│   │   └── playbooks/
│   └── terraform/
│       ├── readme.md            # Terraform guide
│       └── main.tf
├── security/
│   ├── readme.md                # Security index
│   ├── auditing.md              # Security auditing
│   ├── cis-benchmarks.md        # CIS compliance
│   ├── incident-response.md     # Incident response
│   └── zero-trust.md            # Zero trust architecture
├── services/
│   ├── vm-patterns.md           # VM deployment patterns
│   ├── container-patterns.md    # Container patterns
│   └── service-deployments.md   # Service deployments
├── scripts/                     # Utility scripts galore
│   ├── setup/
│   ├── vm/
│   ├── containers/
│   ├── backup/
│   ├── api/
│   ├── k8s/
│   ├── network/
│   ├── storage/
│   └── status.sh
└── tests/                       # Test suite
```

---

> **💡 Remember:** This is for **learning**. Keep your production homelabs simple. Use these techniques to build skills, not because you need them for daily services. Complexity = more failure points.
