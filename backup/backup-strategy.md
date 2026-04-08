# Backup & Disaster Recovery Strategy

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## Overview

This guide covers comprehensive backup strategies for Proxmox environments, from basic local backups to enterprise-grade solutions.

**Related Documentation**: See [`BACKUP/README.md`](BACKUP/README.md) for the complete backup documentation index.

---

## What You'll Learn

This guide covers enterprise-grade backup strategies for Proxmox:

- **3-2-1 Backup Rule**: Industry-standard backup strategy (3 copies, 2 media types, 1 offsite)
- **GFS Retention Strategy**: Grandfather-Father-Son retention policies
- **Incremental vs Differential Backups**: Understanding backup types and trade-offs
- **Disaster Recovery Testing**: Validating backup integrity and restore procedures
- **Backup Encryption**: Securing backup data at rest
- **Proxmox Backup Server**: Enterprise-grade backup solution

## When You Need This

- Multi-VM/CT environments with critical data
- Compliance requirements (data retention policies)
- Environments with ransomware risk
- When you need point-in-time recovery
- Multi-site deployments requiring offsite backups

## Simpler Alternative

For most homelab users:
- Weekly full backups to local storage
- Monthly backups to external drive or cloud
- Test restores quarterly
- Use Proxmox's built-in vzdump for simplicity

---

## The 3-2-1 Backup Rule

The 3-2-1 rule is the industry standard for data protection:
- **3** copies of your data (original + 2 backups)
- **2** different media types (e.g., disk + tape, or disk + cloud)
- **1** copy offsite (for disaster recovery)

### Implementation

```bash
# Example 3-2-1 implementation for Proxmox
# Copy 1: Local Proxmox storage (original)
# Copy 2: Local backup storage (vzdump)
# Copy 3: Remote PBS or cloud storage

# Local backup script
cat > /root/local_backup.sh << 'EOF'
#!/bin/bash
# Local backup with vzdump
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)
vzdump --mode snapshot --storage local-backup --compress zstd
echo "Local backup completed: $BACKUP_TIME"
EOF
chmod +x /root/local_backup.sh

# Remote sync script (rsync to offsite)
cat > /root/offsite_backup.sh << 'EOF'
#!/bin/bash
# Sync backups to offsite location
# ⚠️ PITFALL: Monitor for sync failures
REMOTE_HOST="backup.example.com"
REMOTE_PATH="/backups/proxmox"
RSYNC_USER="backup"

# Create timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Sync backup directory
rsync -avz --delete /var/lib/vz/dump/ ${RSYNC_USER}@${REMOTE_HOST}:${REMOTE_PATH}/proxmox_${TIMESTAMP}/

# Clean up old offsite backups (keep 30 days)
ssh ${RSYNC_USER}@${REMOTE_HOST} "find ${REMOTE_PATH} -type d -mtime +30 -exec rm -rf {} +"
EOF
chmod +x /root/offsite_backup.sh
```

---

## GFS (Grandfather-Father-Son) Retention Strategy

GFS provides hierarchical backup retention:
- **Son (Daily)**: Keep 7 daily backups
- **Father (Weekly)**: Keep 4 weekly backups
- **Grandfather (Monthly)**: Keep 12 monthly backups
- **Yearly**: Keep 2 yearly backups

### Proxmox Backup Server Configuration

```bash
# Configure GFS retention with Proxmox Backup Server
pvesh create /cluster/backup \
  --id datacenter-backup \
  --schedule "0 2 * * *" \
  --storage pbs-backup \
  --mode snapshot \
  --all 1 \
  --enabled 1 \
  --prune-backups 1 \
  --gfs-daily 7 \
  --gfs-weekly 4 \
  --gfs-monthly 12 \
  --gfs-yearly 2

# Manual GFS implementation with vzdump
cat > /root/gfs_backup.sh << 'EOF'
#!/bin/bash
# GFS Backup Script with Retention
# ⚠️ PITFALL: Complex retention can lead to storage exhaustion

# Daily backup (Son)
daily_backup() {
    vzdump --mode snapshot --storage local-backup --compress zstd
    # Keep last 7 days
    find /var/lib/vz/dump -name "*.vma.zst" -mtime +7 -delete
}

# Weekly backup (Father) - Sunday
weekly_backup() {
    if [ $(date +%u) -eq 7 ]; then
        vzdump --mode stop --storage local-backup --compress zstd
        mv /var/lib/vz/dump/*.vma.zst /var/lib/vz/dump/weekly/
        # Keep last 4 weeks
        find /var/lib/vz/dump/weekly -name "*.vma.zst" -mtime +28 -delete
    fi
}

# Monthly backup (Grandfather) - 1st of month
monthly_backup() {
    if [ $(date +%d) -eq 01 ]; then
        vzdump --mode stop --storage local-backup --compress zstd
        mv /var/lib/vz/dump/*.vma.zst /var/lib/vz/dump/monthly/
        # Keep last 12 months
        find /var/lib/vz/dump/monthly -name "*.vma.zst" -mtime +365 -delete
    fi
}

# Yearly backup - January 1st
yearly_backup() {
    if [ $(date +%m%d) -eq 0101 ]; then
        vzdump --mode stop --storage local-backup --compress zstd
        mv /var/lib/vz/dump/*.vma.zst /var/lib/vz/dump/yearly/
        # Keep last 2 years
        find /var/lib/vz/dump/yearly -name "*.vma.zst" -mtime +730 -delete
    fi
}

# Run all
daily_backup
weekly_backup
monthly_backup
yearly_backup

echo "GFS backup completed: $(date)"
EOF
chmod +x /root/gfs_backup.sh

# Add to crontab
# 0 2 * * * /root/gfs_backup.sh
```

---

## Proxmox Backup Server (PBS) Setup

PBS is an enterprise-grade backup solution designed specifically for Proxmox environments.

### Installation

```bash
# Install PBS on separate server (Debian 12)
# Download and install PBS ISO
# Or use: apt install proxmox-backup-server

# Create backup repository on PBS
pvesh create /storage/pbs-backup \
  --type directory \
  --path /backup \
  --content backup,images

# Configure backup store
pvesh create /storage/pbs \
  --store pbs-backup \
  --type directory \
  --path /backup \
  --content backup,images

# Create backup user on PBS
pvesh create /access/acl \
  --userid backup-user \
  --path / \
  --role PVEAuditor

# Generate API token for backup
pvesh create /access/token \
  --userid backup-user \
  --description "Backup automation" \
  --privsep 0

# Configure Proxmox to use PBS
# On Proxmox node:
cat > /etc/pve/pbs.cfg << 'EOF'
pbs-server pbs.example.com
pbs-user backup-user@pbs
pbs-password your-password
EOF

# Test connection
pbs-storage pbs.example.com
```

---

## Backup Encryption

Encrypting backups protects sensitive data at rest.

```bash
# Create encrypted backup password file
cat > /etc/pve/pve-backup.json << 'EOF'
{
  "password": "your-encryption-password"
}
chmod 600 /etc/pve/pve-backup.json

# Backup with encryption
vzdump 100 \
  --mode stop \
  --storage pbs-backup \
  --compress zstd \
  --password-file /etc/pve/pve-backup.json

# Backup with inline encryption (PBS 3.0+)
vzdump 100 \
  --mode snapshot \
  --storage pbs-backup \
  --compress zstd \
  --encryption-key "your-encryption-key"

# Verify encrypted backup
pbs-backup-client verify \
  --repository your-repo \
  --id $BACKUP_ID \
  --password-file /etc/pve/pve-backup.json
```

> **⚠️ Critical**: Lost encryption keys = lost data. Store keys securely.

---

## Backup Verification

Always verify backups are restorable before you need them.

```bash
# Backup verification script
cat > /root/verify_backups.sh << 'EOF'
#!/bin/bash
# Verify backup integrity
# ⚠️ PITFALL: Verification doesn't guarantee successful restore

PBS_REPO="your-repo"
BACKUP_DIR="/var/lib/vz/dump"

echo "== Backup Verification Report =="
echo "Date: $(date)"
echo ""

# Check latest backup exists
LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.vma.zst 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "ERROR: No backups found!"
    exit 1
fi

echo "Latest backup: $LATEST_BACKUP"

# Verify backup integrity
echo "Verifying backup integrity..."
if tar -tzf "$LATEST_BACKUP" > /dev/null 2>&1; then
    echo "✓ Backup integrity: OK"
else
    echo "✗ Backup integrity: FAILED"
    exit 1
fi

# Check backup size
BACKUP_SIZE=$(du -h "$LATEST_BACKUP" | cut -f1)
echo "Backup size: $BACKUP_SIZE"

# Check backup age
BACKUP_AGE=$(( ($(date +%s) - $(stat -c %Y "$LATEST_BACKUP")) / 3600 ))
echo "Backup age: ${BACKUP_AGE} hours"

# Alert if backup is older than 24 hours
if [ $BACKUP_AGE -gt 24 ]; then
    echo "⚠ WARNING: Backup is older than 24 hours"
fi

echo ""
echo "== PBS Repository Verification =="
# Verify PBS repository
pbs-backup-client verify --repository $PBS_REPO --latest

echo ""
echo "== Verification Complete =="
EOF
chmod +x /root/verify_backups.sh

# Run verification daily
# 0 6 * * * /root/verify_backups.sh >> /var/log/backup_verification.log 2>&1
```

---

## Restore Procedures

Documented procedures are essential for disaster recovery.

```bash
# Restore VM from backup
cat > /root/restore_vm.sh << 'EOF'
#!/bin/bash
# Restore VM from vzdump backup
# ⚠️ PITFALL: Untested restores fail when needed

BACKUP_FILE="$1"
TARGET_VMID="$2"
TARGET_STORAGE="${3:-local-lvm}"

if [ -z "$BACKUP_FILE" ] || [ -z "$TARGET_VMID" ]; then
    echo "Usage: $0 <backup_file> <target_vmid> [target_storage]"
    exit 1
fi

echo "== VM Restore Procedure =="
echo "Backup: $BACKUP_FILE"
echo "Target VMID: $TARGET_VMID"
echo "Target Storage: $TARGET_STORAGE"
echo ""

# Stop VM if running
qm status $TARGET_VMID | grep -q "running" && qm stop $TARGET_VMID

# Restore VM
qmrestore "$BACKUP_FILE" "$TARGET_VMID" --storage "$TARGET_STORAGE"

# Verify restore
echo "Verifying restore..."
qm list | grep "$TARGET_VMID"

if [ $? -eq 0 ]; then
    echo "✓ VM restored successfully"
    echo "Start VM with: qm start $TARGET_VMID"
else
    echo "✗ Restore failed"
    exit 1
fi
EOF
chmod +x /root/restore_vm.sh

# Restore LXC container
cat > /root/restore_container.sh << 'EOF'
#!/bin/bash
# Restore LXC container from backup

BACKUP_FILE="$1"
TARGET_CTID="$2"

if [ -z "$BACKUP_FILE" ] || [ -z "$TARGET_CTID" ]; then
    echo "Usage: $0 <backup_file> <target_ctid>"
    exit 1
fi

echo "== Container Restore Procedure =="
echo "Backup: $BACKUP_FILE"
echo "Target CTID: $TARGET_CTID"
echo ""

# Stop container if running
pct status $TARGET_CTID | grep -q "running" && pct stop $TARGET_CTID

# Restore container
vzrestore "$BACKUP_FILE" "$TARGET_CTID"

# Verify restore
echo "Verifying restore..."
pct list | grep "$TARGET_CTID"

if [ $? -eq 0 ]; then
    echo "✓ Container restored successfully"
    echo "Start container with: pct start $TARGET_CTID"
else
    echo "✗ Restore failed"
    exit 1
fi
EOF
chmod +x /root/restore_container.sh

# Disaster Recovery Runbook
cat > /root/DR_RUNBOOK.md << 'EOF'
# Disaster Recovery Runbook

## Pre-Disaster Preparation
- [ ] Verify backups are current
- [ ] Test restore procedures monthly
- [ ] Document recovery procedures
- [ ] Keep recovery media accessible

## Disaster Scenarios

### Scenario 1: Single VM Failure
1. Identify failed VM
2. Stop VM if running
3. Restore from latest backup
4. Verify VM functionality
5. Update documentation

### Scenario 2: Storage Failure
1. Assess damage
2. Replace/repair storage
3. Restore from offsite backup
4. Verify data integrity
5. Update monitoring

### Scenario 3: Complete Node Failure
1. Provision new node
2. Install Proxmox
3. Restore from PBS or offsite
4. Rejoin cluster
5. Verify cluster health

### Scenario 4: Ransomware Attack
1. Isolate affected systems
2. Identify infection vector
3. Wipe affected systems
4. Restore from clean backup
5. Patch vulnerabilities
6. Monitor for recurrence

## Post-Incident
- [ ] Document what happened
- [ ] Update procedures
- [ ] Improve detection
- [ ] Test new controls
- [ ] Review backup strategy
EOF
```

---

## Backup Scheduling

```bash
# Crontab for automated backups
cat > /root/backup_crontab << 'EOF'
# Proxmox Backup Schedule
# Daily incremental at 2 AM
0 2 * * * /root/local_backup.sh >> /var/log/backup.log 2>&1

# Weekly full backup on Sunday at 3 AM
0 3 * * 0 /root/gfs_backup.sh >> /var/log/backup.log 2>&1

# Monthly verification on 1st at 6 AM
0 6 1 * * /root/verify_backups.sh >> /var/log/backup_verification.log 2>&1

# Offsite sync daily at 4 AM
0 4 * * * /root/offsite_backup.sh >> /var/log/offsite_backup.log 2>&1
EOF

# Install crontab
crontab /root/backup_crontab

# View crontab
crontab -l

# Check backup job status
systemctl status proxmox-backup.timer 2>/dev/null || echo "Using cron for backups"
```

---

## Backup Monitoring

```bash
# Backup monitoring script
cat > /root/monitor_backups.sh << 'EOF'
#!/bin/bash
# Monitor backup health
# ⚠️ PITFALL: Alert fatigue - tune thresholds

LOG_FILE="/var/log/backup_monitor.log"
ALERT_EMAIL="admin@example.com"

# Check for failed backups in last 24 hours
FAILED_BACKUPS=$(grep -l "ERROR\|FAILED" /var/log/backup.log 2>/dev/null | wc -l)

if [ $FAILED_BACKUPS -gt 0 ]; then
    echo "$(date): WARNING - $FAILED_BACKUPS failed backups detected" >> $LOG_FILE
    # Send alert (configure mail or webhook)
    echo "Failed backups detected" | mail -s "Backup Alert" $ALERT_EMAIL
fi

# Check backup age
LATEST_BACKUP=$(ls -t /var/lib/vz/dump/*.vma.zst 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ]; then
    BACKUP_AGE=$(( ($(date +%s) - $(stat -c %Y "$LATEST_BACKUP")) / 3600 ))
    if [ $BACKUP_AGE -gt 25 ]; then
        echo "$(date): WARNING - Latest backup is ${BACKUP_AGE} hours old" >> $LOG_FILE
    fi
fi

# Check storage space
DISK_USAGE=$(df /var/lib/vz | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "$(date): WARNING - Backup storage at ${DISK_USAGE}%" >> $LOG_FILE
fi

echo "$(date): Backup monitoring check completed" >> $LOG_FILE
EOF
chmod +x /root/monitor_backups.sh

# Add to crontab
# */30 * * * * /root/monitor_backups.sh
```

---

## Summary

### Backup Strategy Comparison

| Strategy | Complexity | Recovery Time | Storage Cost | Best For |
|------|-----|---|-----|------|
| Local vzdump | Low | Fast | Medium | Homelab, small setups |
| GFS Retention | Medium | Fast | High | Compliance, specific recovery points |
| PBS + Offsite | High | Medium | High | Production, multi-site |
| Cloud Backup | Medium | Slow | Variable | Offsite, disaster recovery |

### Learning Path Progression

1. **Beginner**: Local vzdump backups, weekly rotation
2. **Intermediate**: GFS retention, backup verification
3. **Advanced**: PBS integration, encryption, offsite sync
4. **Enterprise**: Multi-site, automated DR testing

### Real-World Job Skill Mapping

- **SRE**: All sections apply directly
- **DevOps Engineer**: PBS, automation, monitoring
- **Security Engineer**: Encryption, compliance
- **Cloud Engineer**: Offsite backups, disaster recovery

---

## Related Documentation

- **Restore Procedures**: See [`BACKUP/RESTORE_PROCEDURES.md`](BACKUP/RESTORE_PROCEDURES.md)
- **GFS Strategy**: See [`BACKUP/GFS_STRATEGY.md`](BACKUP/GFS_STRATEGY.md)
- **PBS Setup**: See [`BACKUP/PBS_SETUP.md`](BACKUP/PBS_SETUP.md)
- **Backup Verification**: See [`BACKUP/VERIFICATION.md`](BACKUP/VERIFICATION.md)
- **Storage Strategy**: See [`docs/storage_strategy.md`](docs/storage_strategy.md)

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
