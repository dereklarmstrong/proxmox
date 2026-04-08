# Proxmox Backup Server Setup Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers Proxmox Backup Server (PBS) setup and configuration:

- **PBS Installation**: Enterprise backup server setup
- **Repository Management**: Backup storage configuration
- **Client Configuration**: Connecting Proxmox to PBS
- **Backup Optimization**: Compression, deduplication, encryption
- **Disaster Recovery**: Restoring from PBS backups

## When You Need This

- Multi-node cluster management
- Large-scale backup requirements
- Compliance requirements
- Offsite backup needs
- Enterprise-grade backup solutions

## Simpler Alternative

For most homelab users:
- Use local vzdump backups
- Simple retention policies
- Manual backup verification
- External drive for offsite copies

---

## PBS Installation

### Option 1: Install PBS on Dedicated Server

```bash
# Download PBS ISO
# https://www.proxmox.com/en/proxmox-backup-server/downloads

# Install PBS
# 1. Boot from PBS ISO
# 2. Follow installation wizard
# 3. Configure network settings
# 4. Set admin password

# Access PBS web interface
# https://pbs-server-ip:8006

# Login with root and password set during installation
```

### Option 2: Install PBS in VM

```bash
# Create PBS VM
qm create 500 --name pbs-server --memory 8192 --cores 4 \
  --scsi0 local-lvm:vm-500-disk-0,size=100G \
  --net0 virtio,bridge=vmbr0

# Attach PBS ISO
qm set 500 --ide2 local:iso/pbs-3.x.iso,media=cdrom

# Start VM and install
qm start 500
qm terminal 500

# Follow installation wizard
# Set network, admin password, storage
```

> **⚠️ PITFALL**: Performance limitations in VM, hardware requirements.

---

## Repository Configuration

Create backup repositories on PBS.

```bash
# Login to PBS web interface
# Navigate to Datastore -> Repositories -> Add

# Repository 1: Local backups
# Name: local-backup
# Path: /backup/local
# Content: Backup, Images

# Repository 2: Offsite backups
# Name: offsite-backup
# Path: /backup/offsite
# Content: Backup

# Create repository via API
pvesh create /storage/offsite-backup \
  --type directory \
  --path /backup/offsite \
  --content backup,images

# Set repository permissions
pvesh create /access/acl \
  --userid backup-user@pbs \
  --path /storage/offsite-backup \
  --role PVEAuditor
```

> **⚠️ PITFALL**: Storage capacity planning is critical.

---

## Client Configuration

Connect Proxmox to PBS.

```bash
# Create PBS user on Proxmox
pvesh create /access/users \
  --userid pbs-backup@pbs \
  --password your-password

# Create API token for PBS
pvesh create /access/token \
  --userid pbs-backup@pbs \
  --description "PBS Backup" \
  --privsep 0

# Configure PBS on Proxmox node
cat > /etc/pve/pbs.cfg << 'EOF'
pbs-server pbs.example.com:8007
pbs-user pbs-backup@pbs
pbs-password your-password
EOF

# Test connection
pbs-storage pbs.example.com

# Create PBS storage in Proxmox
pvesh create /storage/pbs-backup \
  --type directory \
  --path /backup \
  --content backup,images \
  --server pbs.example.com:8007 \
  --username pbs-backup@pbs \
  --password your-password
```

> **⚠️ PITFALL**: Network connectivity and authentication issues.

---

## Backup Configuration

Configure backup jobs.

```bash
# Create backup job via API
pvesh create /cluster/backupjob \
  --id daily-backup \
  --schedule "0 2 * * *" \
  --storage pbs-backup \
  --mode snapshot \
  --all 1 \
  --enabled 1 \
  --prune-backups 1 \
  --window 2

# Configure GFS retention
pvesh create /cluster/backupjob \
  --id weekly-backup \
  --schedule "0 3 * * 0" \
  --storage pbs-backup \
  --mode snapshot \
  --all 1 \
  --enabled 1 \
  --prune-backups 1 \
  --gfs-weekly 4 \
  --gfs-monthly 12

# Create VM-specific backup
pvesh create /cluster/backupjob \
  --id vm100-backup \
  --schedule "0 1 * * *" \
  --storage pbs-backup \
  --mode snapshot \
  --vmids 100 \
  --enabled 1
```

> **⚠️ PITFALL**: Schedule conflicts, storage capacity.

---

## Backup Optimization

Optimize backup performance.

```bash
# Enable compression
pvesh create /cluster/backupjob \
  --id optimized-backup \
  --storage pbs-backup \
  --compress zstd \
  --compress-level 6

# Enable deduplication
pvesh create /storage/pbs-backup \
  --deduplication 1

# Configure parallel backups
pvesh create /cluster/options \
  --maxbackupjob 4

# Set bandwidth limits
pvesh create /storage/pbs-backup \
  --bwlimit 10000
```

> **⚠️ PITFALL**: CPU overhead, network impact.

---

## Backup Encryption

Encrypt backups for security.

```bash
# Create encryption key
openssl rand -base64 32 > /root/pbs-encryption.key
chmod 600 /root/pbs-encryption.key

# Configure encrypted backup
pvesh create /cluster/backupjob \
  --id encrypted-backup \
  --storage pbs-backup \
  --mode snapshot \
  --all 1 \
  --enabled 1 \
  --password-file /root/pbs-encryption.key

# Store encryption key securely
# Use password manager or encrypted storage
echo "Store key at: /root/pbs-encryption.key" >> /root/backup-notes.txt

# Verify encrypted backup
pbs-backup-client verify \
  --repository pbs-backup \
  --id $BACKUP_ID \
  --password-file /root/pbs-encryption.key
```

> **⚠️ Critical**: Lost encryption key = lost data.

---

## Backup Verification

Verify backup integrity.

```bash
# Verify latest backup
pbs-backup-client verify \
  --repository pbs-backup \
  --latest

# Verify specific backup
pbs-backup-client verify \
  --repository pbs-backup \
  --id 20240101T020000

# Create verification script
cat > /root/verify_pbs_backups.sh << 'EOF'
#!/bin/bash
# Verify PBS backups
# ⚠️ PITFALL: Verification doesn't guarantee restore

PBS_SERVER="pbs.example.com"
PBS_USER="pbs-backup@pbs"
PBS_REPO="pbs-backup"

# Get latest backup
LATEST=$(pbs-backup-client list --repository $PBS_REPO | tail -1 | awk '{print $1}')

echo "Verifying latest backup: $LATEST"
pbs-backup-client verify --repository $PBS_REPO --id $LATEST

if [ $? -eq 0 ]; then
    echo "Backup verification: SUCCESS"
else
    echo "Backup verification: FAILED"
    exit 1
fi
EOF
chmod +x /root/verify_pbs_backups.sh

# Schedule verification
echo "0 6 * * 0 /root/verify_pbs_backups.sh" | crontab -
```

---

## Summary

### PBS vs Local Backups

| Feature | PBS | Local vzdump |
|-----|-----|------|
| Deduplication | Yes | No |
| Compression | Advanced | Basic |
| Offsite | Easy | Manual |
| Performance | Better | Good |
| Complexity | Higher | Lower |
| Cost | Additional hardware | None |

### Learning Path Progression

1. **Beginner**: Basic PBS installation, simple backups
2. **Intermediate**: Repository management, backup jobs
3. **Advanced**: Optimization, encryption, verification
4. **Enterprise**: Multi-site, automated recovery

### Real-World Job Skill Mapping

- **SRE**: Backup infrastructure, disaster recovery
- **DevOps Engineer**: PBS integration, automation
- **Security Engineer**: Backup encryption, compliance
- **Cloud Engineer**: Backup strategies, storage

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
