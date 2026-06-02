# Getting Started with Proxmox Utility Toolkit

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://git.orcafam.com/dereklarmstrong/proxmox.git
cd proxmox
```

### 2. Configure

```bash
cp config.example.sh config.sh
```

Edit `config.sh` with your environment settings:

```bash
# Proxmox connection
PROXMOX_HOST="192.168.1.3"
PROXMOX_USER="root@pam"

# API token auth (recommended)
# Create with: pveum user token add root@pam automation --privsep 0
PROXMOX_API_TOKEN_ID="root@pam!automation"
PROXMOX_API_TOKEN_SECRET="your-token-secret-here"

# Defaults
DEFAULT_STORAGE="local-lvm"
DEFAULT_BRIDGE="vmbr0"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519.pub"

# Backup
BACKUP_STORAGE="backup-lvm"
BACKUP_RETENTION_DAYS=7
```

### 3. Verify Connection

```bash
# Test API connectivity
./scripts/api/api_wrapper.sh GET /version
```

## First VM

### Create a Cloud-Init Template

```bash
./scripts/vm/create_template.sh \
  --image https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img \
  --name ubuntu-2404-template \
  --vmid 9000 \
  --sshkey ~/.ssh/id_ed25519.pub
```

### Clone a VM

```bash
./scripts/vm/clone_cloud_init.sh \
  --template 9000 \
  --name dev-box \
  --vmid 110 \
  --ip 10.0.1.50/24 \
  --gateway 10.0.1.1 \
  --sshkey ~/.ssh/id_ed25519.pub \
  --start
```

### Connect

```bash
ssh ubuntu@10.0.1.50
```

## First Container

```bash
./scripts/containers/create_lxc.sh \
  --ctid 200 \
  --template local:vztmpl/debian-12-standard.tar.zst \
  --hostname web01 \
  --ip 10.0.1.60/24 \
  --gateway 10.0.1.1 \
  --start
```

## Common Workflows

### List Everything

```bash
./scripts/vm/list_vms.sh
./scripts/containers/list_containers.sh
```

### Check Backups

```bash
./scripts/backup/backup_status.sh
./scripts/backup/backup_status.sh --days 30 --failed-only
```

### Network Report

```bash
./scripts/network/network_report.sh
```

### Cleanup Storage

```bash
./scripts/storage/cleanup_orphaned.sh --dry-run
./scripts/storage/cleanup_orphaned.sh --force
```

## Next Steps

- Read individual script `--help` for full option lists
- Review `docs/backup_strategy.md` for backup best practices
- Review `docs/network_guide.md` for advanced networking
