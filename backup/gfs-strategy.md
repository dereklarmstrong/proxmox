# GFS Backup Strategy Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What Enterprise Skills You'll Learn

- **GFS Retention Strategy**: Grandfather-Father-Son backup retention
- **Backup Lifecycle Management**: Data retention policies
- **Storage Planning**: Capacity management for long-term retention
- **Compliance Requirements**: Regulatory data retention
- **Cost Optimization**: Balancing retention vs storage costs

## When You Actually Need This in Production

- Compliance requirements (data retention laws)
- Audit requirements (specific recovery points)
- Long-term data archiving
- Regulatory compliance (HIPAA, PCI-DSS, GDPR)
- Disaster recovery with specific RPO/RTO

## Simpler Alternative for Daily Services

For most homelab users:
- Simple daily rotation (7-day retention)
- Weekly full backup
- Monthly archive to external drive
- Manual retention management

---

## GFS Retention Strategy Overview

### What: Grandfather-Father-Son Retention

GFS is a backup retention strategy that maintains backups at different time intervals:

- **Son (Daily)**: Recent daily backups for quick recovery
- **Father (Weekly)**: Weekly backups for mid-term recovery
- **Grandfather (Monthly)**: Monthly backups for long-term recovery

### GFS Example Schedule

| Level | Frequency | Retention | Example |
|-------|-----------|-----------|---------|
| Son | Daily | 7 days | Last 7 daily backups |
| Father | Weekly | 4 weeks | Last 4 weekly backups |
| Grandfather | Monthly | 12 months | Last 12 monthly backups |
| Yearly | Yearly | 2 years | Last 2 yearly backups |

---

## Implementing GFS with Proxmox Backup Server

### What: Configure GFS retention on PBS

```bash
# Create backup job with GFS retention
pvesh create /cluster/backupjob \
  --id gfs-daily \
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

# Verify backup job
pvesh get /cluster/backupjob
```

**What You'll Learn**: PBS GFS configuration, retention policies

**When You Need This**: Compliance, audit requirements

**Simpler Alternative**: Simple daily rotation

**Potential Pitfalls**: Storage capacity planning

---

## Implementing GFS with vzdump

### What: Manual GFS implementation with vzdump

```bash
# Create GFS backup script
cat > /root/gfs_backup.sh << 'EOF'
#!/bin/bash
# GFS Backup Script with Retention Policy

BACKUP_DIR="/var/lib/vz/dump"
RETENTION_DAYS=30

# Get current date
DATE=$(date +%Y%m%d)
DAY_OF_WEEK=$(date +%u)
DAY_OF_MONTH=$(date +%d)

# Daily backup (Son) - Every day
daily_backup() {
    echo "Running daily backup..."
    vzdump --mode snapshot --storage local-backup --compress zstd
    
    # Keep last 7 days
    find $BACKUP_DIR -name "*.vma.zst" -mtime +7 -delete
    echo "Daily backup completed: $DATE"
}

# Weekly backup (Father) - Sunday
weekly_backup() {
    if [ $DAY_OF_WEEK -eq 7 ]; then
        echo "Running weekly backup..."
        vzdump --mode stop --storage local-backup --compress zstd
        
        # Move to weekly folder
        mkdir -p $BACKUP_DIR/weekly
        mv $BACKUP_DIR/*.vma.zst $BACKUP_DIR/weekly/
        
        # Keep last 4 weeks (28 days)
        find $BACKUP_DIR/weekly -name "*.vma.zst" -mtime +28 -delete
        echo "Weekly backup completed: $DATE"
    fi
}

# Monthly backup (Grandfather) - 1st of month
monthly_backup() {
    if [ $DAY_OF_MONTH -eq 01 ]; then
        echo "Running monthly backup..."
        vzdump --mode stop --storage local-backup --compress zstd
        
        # Move to monthly folder
        mkdir -p $BACKUP_DIR/monthly
        mv $BACKUP_DIR/*.vma.zst $BACKUP_DIR/monthly/
        
        # Keep last 12 months
        find $BACKUP_DIR/monthly -name "*.vma.zst" -mtime +365 -delete
        echo "Monthly backup completed: $DATE"
    fi
}

# Yearly backup - January 1st
yearly_backup() {
    if [ $(date +%m%d) -eq 0101 ]; then
        echo "Running yearly backup..."
        vzdump --mode stop --storage local-backup --compress zstd
        
        # Move to yearly folder
        mkdir -p $BACKUP_DIR/yearly
        mv $BACKUP_DIR/*.vma.zst $BACKUP_DIR/yearly/
        
        # Keep last 2 years
        find $BACKUP_DIR/yearly -name "*.vma.zst" -mtime +730 -delete
        echo "Yearly backup completed: $DATE"
    fi
}

# Run all backup functions
daily_backup
weekly_backup
monthly_backup
yearly_backup

echo "GFS backup completed: $(date)"
EOF
chmod +x /root/gfs_backup.sh

# Add to crontab
cat > /root/gfs_crontab << 'EOF'
# GFS Backup Schedule
0 2 * * * /root/gfs_backup.sh >> /var/log/gfs_backup.log 2>&1
EOF
crontab /root/gfs_crontab
```

**What You'll Learn**: Manual GFS implementation, backup scripting

**When You Need This**: Without PBS, simple environments

**Simpler Alternative**: Use PBS GFS features

**Potential Pitfalls**: Script maintenance, edge cases

---

## Storage Capacity Planning

### What: Calculate storage requirements for GFS

```bash
# Calculate storage needs
# Formula: (Daily Size × Daily Retention) + (Weekly Size × Weekly Retention) + ...

# Example calculation for 100GB VMs:
# Daily: 100GB × 7 = 700GB
# Weekly: 100GB × 4 = 400GB
# Monthly: 100GB × 12 = 1,200GB
# Yearly: 100GB × 2 = 200GB
# Total: 2,300GB (2.3TB) per VM

# Check current storage usage
df -h /var/lib/vz/dump

# Estimate backup size
vzdump 100 --mode snapshot --storage local-backup --dry-run

# Monitor storage growth
cat > /root/storage_monitor.sh << 'EOF'
#!/bin/bash
# Monitor backup storage usage

BACKUP_DIR="/var/lib/vz/dump"
THRESHOLD=80

# Get current usage
USAGE=$(df $BACKUP_DIR | tail -1 | awk '{print $5}' | sed 's/%//')

echo "Backup storage usage: ${USAGE}%"

if [ $USAGE -gt $THRESHOLD ]; then
    echo "WARNING: Storage usage exceeds ${THRESHOLD}%"
    # List oldest backups
    ls -lt $BACKUP_DIR | tail -5
fi
EOF
chmod +x /root/storage_monitor.sh
```

**What You'll Learn**: Storage capacity planning, growth monitoring

**When You Need This**: Long-term retention planning

**Simpler Alternative**: Monitor and clean manually

**Potential Pitfalls**: Underestimating growth

---

## GFS Retention Policies

### Policy 1: Basic GFS (Homelab)

```bash
# Basic GFS for homelab
# Son: 7 days
# Father: 4 weeks
# Grandfather: 3 months

pvesh create /cluster/backupjob \
  --id basic-gfs \
  --storage pbs-backup \
  --mode snapshot \
  --all 1 \
  --enabled 1 \
  --gfs-daily 7 \
  --gfs-weekly 4 \
  --gfs-monthly 3
```

**What You'll Learn**: Basic GFS implementation

**When You Need This**: Small homelab, basic compliance

**Simpler Alternative**: 7-day rotation only

**Potential Pitfalls**: Limited recovery points

---

### Policy 2: Standard GFS (Production)

```bash
# Standard GFS for production
# Son: 14 days
# Father: 8 weeks
# Grandfather: 12 months

pvesh create /cluster/backupjob \
  --id standard-gfs \
  --storage pbs-backup \
  --mode snapshot \
  --all 1 \
  --enabled 1 \
  --gfs-daily 14 \
  --gfs-weekly 8 \
  --gfs-monthly 12
```

**What You'll Learn**: Standard GFS implementation

**When You Need This**: Production environments, compliance

**Simpler Alternative**: Basic GFS

**Potential Pitfalls**: Higher storage requirements

---

### Policy 3: Extended GFS (Enterprise)

```bash
# Extended GFS for enterprise
# Son: 30 days
# Father: 12 weeks
# Grandfather: 24 months
# Yearly: 7 years

pvesh create /cluster/backupjob \
  --id extended-gfs \
  --storage pbs-backup \
  --mode snapshot \
  --all 1 \
  --enabled 1 \
  --gfs-daily 30 \
  --gfs-weekly 12 \
  --gfs-monthly 24 \
  --gfs-yearly 7
```

**What You'll Learn**: Extended GFS implementation

**When You Need This**: Enterprise compliance, long-term archiving

**Simpler Alternative**: Standard GFS

**Potential Pitfalls**: Very high storage requirements

---

## GFS with Incremental Backups

### What: Optimize GFS with incremental backups

```bash
# Create incremental backup job
pvesh create /cluster/backupjob \
  --id incremental-gfs \
  --storage pbs-backup \
  --mode snapshot \
  --vmids 100,101,102 \
  --enabled 1 \
  --incremental 1 \
  --gfs-daily 7 \
  --gfs-weekly 4 \
  --gfs-monthly 12

# Verify incremental backups
pbs-backup-client list --repository pbs-backup --vmid 100
```

**What You'll Learn**: Incremental backup optimization

**When You Need This**: Large VM sets, limited storage

**Simpler Alternative**: Full backups only

**Potential Pitfalls**: Backup chain dependencies

---

## GFS Verification

### What: Verify GFS backup integrity

```bash
# Create GFS verification script
cat > /root/verify_gfs.sh << 'EOF'
#!/bin/bash
# Verify GFS backup retention

PBS_REPO="pbs-backup"

echo "=== GFS Backup Verification ==="
echo "Date: $(date)"
echo ""

# Check daily backups
echo "Daily Backups (should be 7):"
pbs-backup-client list --repository $PBS_REPO --daily | wc -l

# Check weekly backups
echo "Weekly Backups (should be 4):"
pbs-backup-client list --repository $PBS_REPO --weekly | wc -l

# Check monthly backups
echo "Monthly Backups (should be 12):"
pbs-backup-client list --repository $PBS_REPO --monthly | wc -l

# Check latest backup
echo ""
echo "Latest Backup:"
pbs-backup-client list --repository $PBS_REPO | head -1

echo ""
echo "=== Verification Complete ==="
EOF
chmod +x /root/verify_gfs.sh

# Run verification
/root/verify_gfs.sh
```

**What You'll Learn**: GFS verification, retention validation

**When You Need This**: Compliance, audit preparation

**Simpler Alternative**: Manual backup count

**Potential Pitfalls**: Verification doesn't guarantee restore

---

## Learning Path Progression

1. **Beginner**: Basic daily rotation, simple retention
2. **Intermediate**: GFS with PBS, manual implementation
3. **Advanced**: Incremental GFS, storage optimization
4. **Enterprise**: Extended GFS, compliance automation

---

## Real-World Job Skill Mapping

- **SRE**: Backup strategies, retention policies
- **DevOps Engineer**: GFS automation, compliance
- **Security Engineer**: Data retention, compliance
- **Cloud Engineer**: Backup lifecycle management

---

## GFS Storage Requirements

| Policy | Daily | Weekly | Monthly | Yearly | Total (per 100GB VM) |
|--------|-------|--------|---------|--------|------|
| Basic | 7 days | 4 weeks | 3 months | - | 1.1TB |
| Standard | 14 days | 8 weeks | 12 months | - | 2.2TB |
| Extended | 30 days | 12 weeks | 24 months | 7 years | 5.4TB |

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
