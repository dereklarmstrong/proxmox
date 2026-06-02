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
| `snapshot_vm.sh` | Create snapshots of VMs |
| `destroy_vm.sh` | Destroy VMs (with confirmation by default) |

### Container Management (`scripts/containers/`)

| Script | Description |
|--------|-------------|
| `create_lxc.sh` | Create LXC containers from templates with network config |
| `destroy_lxc.sh` | Destroy containers (with confirmation by default) |
| `list_containers.sh` | List containers with status, CPU, memory |

### Backup (`scripts/backup/`)

| Script | Description |
|--------|-------------|
| `backup_status.sh` | Check backup status with filtering and JSON output |
| `gfs_retention.sh` | Manage GFS backup retention (daily/weekly/monthly/yearly) |
| `backup_vm.sh` | Back up a single VM or container with configurable options |
| `backup_all.sh` | Back up all VMs and containers (with exclusion list support) |

### Networking (`scripts/network/`)

| Script | Description |
|--------|-------------|
| `network_report.sh` | Generate network configuration report |
| `vlan_setup.sh` | Set up VLAN network bridges |

### Storage (`scripts/storage/`)

| Script | Description |
|--------|-------------|
| `cleanup_orphaned.sh` | Find and remove orphaned disk images |
| `disk_usage.sh` | Report storage pool usage with capacity warnings |

### API (`scripts/api/`)

| Script | Description |
|--------|-------------|
| `api_wrapper.sh` | Full-featured Proxmox API wrapper with ticket and token auth |
| `api_request.sh` | Minimal API caller using env vars for token auth |
| `create_api_token.sh` | Create Proxmox API tokens with least-privilege scoping |

### Kubernetes (`scripts/k8s/`)

| Script | Description |
|--------|-------------|
| `deploy_ol_k8s_cluster.sh` | Deploy a Kubernetes cluster on Oracle Linux nodes via SSH |

## Configuration

Copy the example config and edit:

```bash
cp config.example.sh config.sh
```

Key settings: `DEFAULT_STORAGE`, `DEFAULT_BRIDGE`, `SSH_KEY_PATH`, `PROXMOX_HOST`, `PROXMOX_USER`.

> **Note:** Authentication uses API tokens or ticket-based auth — never store passwords in config files.

## Script Standards

All scripts follow these conventions:

- Source `lib/common.sh` for logging, validation, and utilities
- Use `set -euo pipefail` for strict error handling
- Include `--help` / `-h` usage documentation
- Validate all inputs before execution
- Default to `--dry-run` for destructive operations
- Pass `shellcheck` without warnings

## Repository Structure

```
proxmox/
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── config.example.sh
├── lib/
│   └── common.sh              # Shared library (logging, validation, API helpers)
├── scripts/
│   ├── vm/
│   ├── containers/
│   ├── backup/
│   ├── network/
│   ├── storage/
│   ├── api/
│   └── k8s/
└── docs/
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
| [`gpu-passthrough/readme.md`](gpu-passthrough/readme.md) | GPU passthrough fundamentals, IOMMU, VFIO |
| [`security.md`](security.md) | SSH hardening, firewall, 2FA, TLS, CIS benchmarks |

## Links

- [Blog: The Proxmox Utility Toolkit](https://derekarmstrong.dev/blog/proxmox-utility-toolkit/)
- [Proxmox API Viewer](https://pve.proxmox.com/pve-docs/api-viewer/index.html)
- [Proxmox Documentation](https://pve.proxmox.com/pve-docs/)
- [Cloud-init Documentation](https://cloud-init.io/)

## License

MIT — See [LICENSE](LICENSE) for details.
