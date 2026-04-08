# Proxmox CLI Cheatsheet

## VM (qm)

### Basic Commands
- List VMs: `qm list`
- Create VM: `qm create <id> --name <name> --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0`
- Start/Stop: `qm start <id>` / `qm stop <id>`
- Shutdown/Reboot: `qm shutdown <id>` / `qm reboot <id>`
- Console: `qm terminal <id>`
- Clone template: `qm clone <template_id> <new_id> --name <name> --full`
- Destroy VM: `qm destroy <id>`

### Cloud-init
- Configure: `qm set <id> --ciuser ubuntu --sshkey ~/.ssh/id_rsa.pub --ipconfig0 ip=192.168.1.50/24,gw=192.168.1.1`
- Set password: `qm set <id> --cipassword <password>`
- Set nameserver: `qm set <id> --nameserver 8.8.8.8`

### Snapshots
- Create: `qm snapshot <id> <snapname>`
- Rollback: `qm rollback <id> <snapname>`
- Delete: `qm delsnapshot <id> <snapname>`
- List: `qm snapshot <id>`

### Migration
- Migrate: `qm migrate <id> <target-node> --online 1`

### Configuration
- View config: `qm config <id>`
- Set CPU: `qm set <id> --cores 4 --cpu host`
- Set memory: `qm set <id> --memory 4096`
- Set disk: `qm set <id> --scsi0 <storage>:vm-<id>-disk-0,size=50G`
- Set network: `qm set <id> --net0 virtio,bridge=vmbr0,firewall=1`

---

## Containers (pct)

### Basic Commands
- List CTs: `pct list`
- Create: `pct create <id> <template> --hostname <name> --net0 name=eth0,bridge=vmbr0,ip=dhcp`
- Start/Stop: `pct start <id>` / `pct stop <id>`
- Console: `pct enter <id>`
- Resize disk: `pct resize <id> rootfs +10G`
- Destroy CT: `pct destroy <id>`

### Configuration
- View config: `pct config <id>`
- Set CPU: `pct set <id> --cpuunits 1024`
- Set memory: `pct set <id> --memory 1024 --swap 512`
- Set network: `pct set <id> --net0 name=eth0,bridge=vmbr0,ip=192.168.1.50/24,gw=192.168.1.1`

### Export/Import
- Export: `pct export <id> <backup-file>`
- Import: `pct import <id> <backup-file>`

---

## Templates

### List Templates
- List available: `pveam available`
- List local: `pveam local list`

### Download Templates
- Download Debian: `pveam download local debian-12-standard_12.0-1_amd64.tar.zst`
- Download Ubuntu: `pveam download local ubuntu-24.04-standard_24.04-1_amd64.tar.zst`

### Convert VM to Template
- Convert: `qm template <vmid>`
- Verify: `qm config <vmid> | grep template`

---

## Backups

### Manual Backup
- Backup VM/CT: `vzdump <id> --storage local --mode snapshot --compress zstd`
- Backup all: `vzdump --all --storage local --mode snapshot --compress zstd`

### Restore VM
- Restore: `qmrestore /var/lib/vz/dump/vzdump-qemu-<id>.vma.zst <new_id> --storage local-lvm`

### Restore CT
- Restore: `vzrestore /var/lib/vz/dump/vzdump-lxc-<id>.tar.zst <new_id>`

### Prune Old Backups
- Manual prune: `find /var/lib/vz/dump -name "vzdump-*" -mtime +30 -delete`
- Use script: `bash scripts/backup/prune_backups.sh -r 30`

### Backup Report
- Generate report: `bash scripts/backup/report.sh [-d <days>] [-s <storage>]`

---

## Storage

### List Storages
- Status: `pvesm status`
- Content: `pvesm content <storage>`

### Add Storage
- Add NFS: `pvesm add nfs <id> <server>:<path> --export <path> --path /mnt/pve/<id> --content images,iso,backup`
- Add directory: `pvesm add dir <id> --path /mnt/<id>`
- Add ZFS: `pvesm add zfs <id> --pool rpool/<id>`

### Disk Usage
- View usage: `bash scripts/storage/disk_usage.sh [-s <storage>]`
- Cleanup: `bash scripts/storage/cleanup.sh [-n] [-y]`

---

## Network

### Bridge Configuration
- View bridges: `ip link show type bridge`
- Config file: `/etc/network/interfaces`

### VLAN Setup
- VLAN interface: `auto vmbr0.10`
- VLAN config: `iface vmbr0.10 inet manual`

### Firewall Rules
- Add rule: `pvesh create /firewall/rules --action accept --dest-port 80 --proto tcp`
- List rules: `pvesh get /firewall/rules`
- Delete rule: `pvesh delete /firewall/rules --ruleid <id>`

### Network View
- View all: `bash scripts/network/show.sh`
- VLAN info: `bash scripts/network/show.sh -v`
- IP assignments: `bash scripts/network/show.sh -i`

---

## API

### API Token
- Create token: `bash scripts/api/create_api_token.sh -u <user> -t <token_name>`
- Environment: `PVE_API_URL`, `PVE_TOKEN_ID`, `PVE_TOKEN_SECRET`

### API Request
- GET: `bash scripts/api/api_request.sh -X GET -p /nodes/<node>/status`
- POST: `bash scripts/api/api_request.sh -X POST -p /nodes/<node>/qemu -d 'param=value'`

---

## Status & Monitoring

### VM Status
- List with status: `qm list`
- Single VM: `qm status <id>`

### Container Status
- List with status: `pct list`
- Single CT: `pct status <id>`

### Dashboard
- Full dashboard: `bash scripts/status.sh`

### VM Info
- Detailed info: `bash scripts/vm/info.sh <vmid_or_name>`
- Find IP: `bash scripts/vm/find_ip.sh <vmid_or_name>`
- Console access: `bash scripts/vm/console.sh <vmid_or_name>`

### Template Validation
- Check template: `bash scripts/vm/check_template.sh -v <vmid>`
- Check all: `bash scripts/vm/check_template.sh -a`

### Snapshot Management
- Create: `bash scripts/vm/snapshot.sh create <vmid> <name>`
- List: `bash scripts/vm/snapshot.sh list <vmid>`
- Delete: `bash scripts/vm/snapshot.sh delete <vmid> <name>`
- Cleanup: `bash scripts/vm/snapshot.sh cleanup <vmid> <days>`

---

## VM/Container Management Scripts

### VM Creation
- Cloud-init template: `bash scripts/vm/create_cloud_init_template.sh -i <vmid> --os <ubuntu|ol8|ol9> --sha256 <hash>`
- Clone VM: `bash scripts/vm/clone_vm.sh -s <source> -d <dest> -n <name> [-i <ip/cidr>] [-g <gateway>]`
- Full clone: `bash scripts/create_vm_full_clone.sh -s <source> -d <dest> -n <name> [-i <ip>] [-g <gateway>]`
- Destroy VM: `bash scripts/vm/destroy_vm.sh -i <vmid(s)>`

### Container Creation
- Create CT: `bash scripts/containers/create_container.sh -i <ctid> -n <name> -t <template> [-u <ip/cidr>]`
- Destroy CT: `bash scripts/containers/destroy_container.sh -i <ctid(s)>`
- List templates: `bash scripts/containers/list_templates.sh`

### Backup Scripts
- Backup single: `bash scripts/backup/backup_vm.sh -i <vmid|ctid> [-s <storage>] [-m <mode>] [-c <compress>]`
- Backup all: `bash scripts/backup/backup_all.sh [-s <storage>] [-m <mode>] [-c <compress>]`
- Prune backups: `bash scripts/backup/prune_backups.sh [-d <dir>] [-r <days>]`
- Report: `bash scripts/backup/report.sh [-d <days>] [-s <storage>]`

### Setup Scripts
- Community repo: `bash scripts/setup/pve_community_repo.sh`
- Download keys: `bash scripts/download_github_keys.sh [username]`

### Kubernetes
- Deploy cluster: `bash scripts/k8s/deploy_ol_k8s_cluster.sh [--config <path>] [--yes] [--dry-run]`

### Base VM Deployment
- Deploy base set: `bash scripts/deploy_base_vm_set.sh`

---

## Testing

### Run Tests
- All tests: `bash scripts/test.sh`
- Specific test: `bash scripts/test.sh tests/vm_create_cloud_init_template.bats`

---

## Useful One-Liners

### Find VM by name
```bash
qm list | grep -i <name>
```

### Find container by name
```bash
pct list | grep -i <name>
```

### List all VMs with IP config
```bash
qm list | while read id name; do echo "$name: $(qm config $id | grep ipconfig)"; done
```

### List all containers with IP config
```bash
pct list | while read id name; do echo "$name: $(pct config $id | grep ipconfig)"; done
```

### Find unused storage
```bash
bash scripts/storage/cleanup.sh -n  # dry run
```

### Check backup status
```bash
bash scripts/backup/report.sh -d 7  # last 7 days
```

---

## Configuration Files

### Main Config
- Location: `config.sh` (copy from `config.example.sh`)
- Variables: `DEFAULT_STORAGE`, `DEFAULT_BRIDGE`, `SSH_KEY_PATH`, `TEMPLATE_ID_START`, `BACKUP_STORAGE`, `BACKUP_RETENTION_DAYS`

### K8s Config
- Location: `config.k8s.sh` (copy from `config.k8s.example.sh`)
- Variables: `K8S_SSH_USER`, `K8S_SSH_KEY`, `K8S_MASTERS`, `K8S_WORKERS`, `K8S_VERSION`

---

## Related Documentation

- **Main README**: [`README.md`](../README.md)
- **Backup Guide**: [`backup/readme.md`](../backup/readme.md)
- **Networking**: [`networking/readme.md`](../networking/readme.md)
- **Automation**: [`automation/readme.md`](../automation/readme.md)
- **Services**: [`services/service-deployments.md`](../services/service-deployments.md)

---

## Proxmox API Reference

- **API Viewer**: https://pve.proxmox.com/pve-docs/api-viewer/index.html
- **Documentation**: https://pve.proxmox.com/pve-docs/
