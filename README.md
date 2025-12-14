## Proxmox Utility Toolkit

General-purpose Proxmox VE utility scripts for VMs, LXC containers, backups, and API automation. Targeted for Proxmox VE 8.x (no dark-theme hacks needed).

### Quick Start (homelab-friendly)
```bash
git clone https://github.com/dereklarmstrong/proxmox.git
cd proxmox
cp config.example.sh config.sh         # set bridge/storage, SSH key
./scripts/test.sh                      # optional: run tests (vendored bats)

# 1) Enable no-subscription repo on Proxmox
bash scripts/setup/pve_community_repo.sh

# 2) Build a base cloud-init template (choose one)
# Ubuntu 24.04 (provide SHA):
bash scripts/vm/create_cloud_init_template.sh -i 9000 --sha256 <ubuntu_sha>
# Oracle Linux 9 preset with checksum:
bash scripts/vm/create_cloud_init_template.sh -i 9100 --os ol9 --sha256 415274f04015112eeb972ed8a4e6941cb71df0318c4acba5a760931b7d7c0c69

# 3) Clone VMs with homelab IPs (192.168.1.50-99)
bash scripts/vm/clone_vm.sh -s 9000 -d 150 -n web01 -i 192.168.1.60/24 -g 192.168.1.1

# 4) (Optional) Deploy the k8s lab cluster on Oracle Linux nodes
# Runtime: CRI-O (kube-native, Podman-friendly). Build images with Podman, run via CRI-O.
# Edit config.k8s.sh or use the generated defaults, then:
bash scripts/k8s/deploy_ol_k8s_cluster.sh --config config.k8s.sh
```

### Prerequisites
- Proxmox VE 8.x on Debian 12 (bookworm)
- Run scripts as root on a Proxmox node
- SSH public key on the node for cloud-init and container setups

### Scripts Overview
- Setup: [scripts/setup/pve_community_repo.sh](scripts/setup/pve_community_repo.sh) — enable no-subscription repo, disable enterprise list.
- VM templates & cloning:
	- [scripts/vm/create_cloud_init_template.sh](scripts/vm/create_cloud_init_template.sh) — create a cloud-init template (Ubuntu/Oracle Linux presets with checksum verification).
	- [scripts/vm/clone_vm.sh](scripts/vm/clone_vm.sh) — full clone with optional static IP and SSH key.
	- [scripts/vm/destroy_vm.sh](scripts/vm/destroy_vm.sh) — destroy one or more VMs.
- Containers:
	- [scripts/containers/create_container.sh](scripts/containers/create_container.sh) — create LXC from template with optional static IP.
	- [scripts/containers/destroy_container.sh](scripts/containers/destroy_container.sh) — destroy containers.
	- [scripts/containers/list_templates.sh](scripts/containers/list_templates.sh) — list available LXC templates.
- Backups:
	- [scripts/backup/backup_vm.sh](scripts/backup/backup_vm.sh) — vzdump wrapper for a single VM/CT.
	- [scripts/backup/backup_all.sh](scripts/backup/backup_all.sh) — back up all VMs/CTs.
	- [scripts/backup/prune_backups.sh](scripts/backup/prune_backups.sh) — prune old vzdump files by age.
- API helpers:
	- [scripts/api/create_api_token.sh](scripts/api/create_api_token.sh) — create an API token with a role.
	- [scripts/api/api_request.sh](scripts/api/api_request.sh) — minimal curl wrapper using API tokens.

### Configuration
Copy the template and tweak values to your environment:
```bash
cp config.example.sh config.sh
```
Key settings: `DEFAULT_STORAGE`, `DEFAULT_BRIDGE`, `SSH_KEY_PATH`, `TEMPLATE_ID_START`, `BACKUP_STORAGE`, `BACKUP_RETENTION_DAYS`.

### Usage Examples
- Community repo: `bash scripts/setup/pve_community_repo.sh`
- Ubuntu template: `bash scripts/vm/create_cloud_init_template.sh -i 9000 --sha256 <ubuntu_sha>`
- Oracle Linux template: `bash scripts/vm/create_cloud_init_template.sh -i 9100 --os ol9 --sha256 415274f04015112eeb972ed8a4e6941cb71df0318c4acba5a760931b7d7c0c69`
- Clone VM (homelab IP range): `bash scripts/vm/clone_vm.sh -s 9000 -d 150 -n web01 -i 192.168.1.60/24 -g 192.168.1.1`
- LXC container: `bash scripts/containers/create_container.sh -i 200 -n util01 -t local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst`
- Backups: `bash scripts/backup/backup_all.sh`
- Prune backups: `bash scripts/backup/prune_backups.sh -r 30`
- K8s on OL (defaults from config.k8s.sh): `bash scripts/k8s/deploy_ol_k8s_cluster.sh --yes`

### Documentation
- Expanded CLI cheatsheet: [docs/cheatsheet.md](docs/cheatsheet.md)
- Proxmox API viewer: https://pve.proxmox.com/pve-docs/api-viewer/index.html
