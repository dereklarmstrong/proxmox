# Proxmox Utility Toolkit

Bash scripts for managing Proxmox VE 8.x on Debian 12. VMs, containers, backups, networking, and storage — all with consistent error handling, input validation, and dry-run safety.

## Prerequisites

- Proxmox VE 8.x on Debian 12 (bookworm)
- Run scripts as **root** on a Proxmox node
- SSH public key ready for cloud-init setups

## Quick Start

```bash
# Clone and configure
git clone https://github.com/dereklarmstrong/proxmox.git
cd proxmox
cp config.example.sh config.sh    # Edit with your settings

# Create a cloud-init template
./scripts/vm/create_template.sh --image https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img \
  --name ubuntu-2404-template --vmid 9000

# Clone a VM with static IP
./scripts/vm/clone_cloud_init.sh --template 9000 --name dev-box --vmid 110 \
  --ip 10.0.1.50/24 --gateway 10.0.1.1 --sshkey ~/.ssh/id_ed25519.pub --start

# List everything
./scripts/vm/list_vms.sh
./scripts/containers/list_containers.sh
```

## Scripts at a Glance

### VM Management (`scripts/vm/`)

| Script | Description |
|--------|-------------|
| `list_vms.sh` | List all VMs and containers with status, CPU, memory |
| `clone_cloud_init.sh` | Clone a cloud-init template with static IP and SSH key |
| `create_template.sh` | Create a cloud-init enabled VM template from disk image |
| `create_cloud_init_template.sh` | Create a cloud-init template with custom network and user data |
| `clone_vm.sh` | Clone a VM (full or linked clone) |
| `snapshot_vm.sh` | Create snapshots of VMs |
| `snapshot.sh` | Batch snapshot operations across multiple VMs |
| `destroy_vm.sh` | Destroy VMs (with confirmation by default) |
| `check_template.sh` | Validate a VM is a proper cloud-init template |
| `info.sh` | Display detailed VM information |
| `find_ip.sh` | Find VM IP address via Proxmox API |
| `console.sh` | Open a VNC/SPICE console to a VM |
| `compute_image_sha256.sh` | Compute SHA256 hash of a disk image |

### Container Management (`scripts/containers/`)

| Script | Description |
|--------|-------------|
| `create_lxc.sh` | Create LXC containers from templates with network config |
| `create_container.sh` | Create LXC containers (alias for create_lxc.sh) |
| `destroy_lxc.sh` | Destroy containers (with confirmation by default) |
| `destroy_container.sh` | Destroy containers (alias for destroy_lxc.sh) |
| `list_containers.sh` | List containers with status, CPU, memory |
| `list_templates.sh` | List available LXC templates |

### Backup (`scripts/backup/`)

| Script | Description |
|--------|-------------|
| `backup_status.sh` | Check backup status with filtering and JSON output |
| `gfs_retention.sh` | Manage GFS backup retention (daily/weekly/monthly/yearly) |
| `backup_vm.sh` | Back up a single VM or container with configurable options |
| `backup_all.sh` | Back up all VMs and containers (with exclusion list support) |
| `prune_backups.sh` | Prune old backups beyond retention policy |
| `report.sh` | Generate backup status report |
| `backup_single.sh` | Back up a single VM (alias for backup_vm.sh) |

### Networking (`scripts/network/`)

| Script | Description |
|--------|-------------|
| `network_report.sh` | Generate network configuration report |
| `vlan_setup.sh` | Set up VLAN network bridges |
| `show.sh` | Display current network configuration |

### Storage (`scripts/storage/`)

| Script | Description |
|--------|-------------|
| `cleanup_orphaned.sh` | Find and remove orphaned disk images |
| `cleanup.sh` | Storage cleanup operations |
| `disk_usage.sh` | Report storage pool usage with capacity warnings |

### API (`scripts/api/`)

| Script | Description |
|--------|-------------|
| `api_wrapper.sh` | Full-featured API wrapper with ticket auth (username/password) and token auth, CLI args |
| `api_request.sh` | Minimal API caller — requires env vars (`PVE_API_URL`, `PVE_TOKEN_ID`, `PVE_TOKEN_SECRET`) |
| `create_api_token.sh` | Create Proxmox API tokens with least-privilege scoping |

### Kubernetes (`scripts/k8s/`)

| Script | Description |
|--------|-------------|
| `deploy_ol_k8s_cluster.sh` | Deploy a Kubernetes cluster on Oracle Linux nodes via SSH |

### Setup (`scripts/setup/`)

| Script | Description |
|--------|-------------|
| `pve_community_repo.sh` | Add the Proxmox Community Repository |

### Utilities (top-level `scripts/`)

| Script | Description |
|--------|-------------|
| `create_vm_full_clone.sh` | Create a full clone of a VM |
| `deploy_base_vm_set.sh` | Deploy a set of base VMs |
| `download_github_keys.sh` | Download and verify GitHub SSH/GPG keys |
| `status.sh` | Show overall Proxmox cluster status |
| `test.sh` | Test harness for the toolkit |

## Configuration

Copy the example config and edit:

```bash
cp config.example.sh config.sh
```

Key settings: `DEFAULT_STORAGE`, `DEFAULT_BRIDGE`, `SSH_KEY_PATH`, `PROXMOX_HOST`, `PROXMOX_USER`.

> **Note:** Authentication uses API tokens or ticket-based auth — never store passwords in config files.

## Script Standards

Core scripts follow these conventions:

- Source `lib/common.sh` for logging, validation, and utilities
- Use `set -euo pipefail` for strict error handling
- Include `--help` / `-h` usage documentation
- Validate all inputs before execution
- Default to `--dry-run` for destructive operations
- Pass `shellcheck` without warnings

> **Note:** Some utility scripts (e.g., `download_github_keys.sh`, `test.sh`, `status.sh`) are standalone and do not source `common.sh`.

## Repository Structure

```
proxmox/
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── PROJECT_RULES.md
├── config.example.sh
├── config.k8s.example.sh
├── .gitignore
├── lib/
│   └── common.sh              # Shared library (logging, validation, API helpers)
├── scripts/
│   ├── vm/                    # VM management (list, clone, template, snapshot, destroy)
│   ├── containers/            # LXC container management
│   ├── backup/                # Backup operations and GFS retention
│   ├── network/               # Network configuration and reporting
│   ├── storage/               # Storage management and cleanup
│   ├── api/                   # Proxmox API utilities
│   ├── k8s/                   # Kubernetes cluster deployment
│   └── setup/                 # Proxmox setup scripts
├── docs/                      # User documentation
├── gpu-passthrough/           # GPU passthrough guides (IOMMU, VFIO, NVIDIA, AMD)
├── networking/                # Networking guides (firewall, SDN, VLANs)
├── security/                  # Security guides (CIS benchmarks, auditing, IR)
├── automation/                # Ansible, Terraform, cloud-init automation
├── learning-paths/            # Learning paths (beginner, intermediate, advanced)
├── services/                  # Service deployment patterns
└── tests/                     # BATS test suite
```

## Documentation

| Doc | Topic |
|-----|-------|
| [`getting_started.md`](docs/getting_started.md) | Setup and first-run guide |
| [`backup_strategy.md`](docs/backup_strategy.md) | 3-2-1 backup strategy, GFS retention, PBS setup |
| [`network_guide.md`](docs/network_guide.md) | VLANs, bridges, firewall rules, SDN |
| [`storage_guide.md`](docs/storage_guide.md) | Storage pools, formats, optimization |
| [`troubleshooting.md`](docs/troubleshooting.md) | Common issues and fixes |
| [`api_reference.md`](docs/api_reference.md) | API call reference |
| [`gpu_passthrough.md`](docs/gpu_passthrough.md) | NVIDIA CUDA and AMD ROCm GPU passthrough |
| [`security_hardening.md`](docs/security_hardening.md) | SSH, firewall, 2FA, audit logging, CIS benchmarks |
| [`cheatsheet.md`](docs/cheatsheet.md) | Quick reference cheatsheet |
| [`gpu-passthrough/readme.md`](gpu-passthrough/readme.md) | GPU passthrough fundamentals, IOMMU, VFIO |
| [`security.md`](security.md) | SSH hardening, firewall, 2FA, TLS, CIS benchmarks |

## Links

- [Blog: The Proxmox Utility Toolkit](https://derekarmstrong.dev/blog/proxmox-utility-toolkit/)
- [Proxmox API Viewer](https://pve.proxmox.com/pve-docs/api-viewer/index.html)
- [Proxmox Documentation](https://pve.proxmox.com/pve-docs/)
- [Cloud-init Documentation](https://cloud-init.io/)

## License

MIT — See [LICENSE](LICENSE) for details.
