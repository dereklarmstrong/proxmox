# Backup Restore Procedures

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What Enterprise Skills You'll Learn

- **VM/Container Restore**: Restoring from vzdump backups
- **PBS Restore**: Restoring from Proxmox Backup Server
- **Disaster Recovery**: Full system recovery procedures
- **Point-in-Time Recovery**: Restoring to specific backup points
- **Partial Restore**: Restoring individual files or directories

## When You Actually Need This in Production

- Data corruption incidents
- Accidental deletion
- Malware/ransomware attacks
- Hardware failures
- Compliance requirements

## Simpler Alternative for Daily Services

For most homelab users:
- Test restores quarterly
- Keep recent backups accessible
- Document restore procedures
- Practice disaster recovery

---

## VM Restore from vzdump

### What: Restore VM from local backup

```bash
# List available backups
ls -lt /var/lib/vz/dump/*.vma.zst

# Restore VM from backup
# Syntax: qmrestore <backup_file> <new_vmid> --storage <storage>

# Example: Restore VM 100 to new VM 200
qmrestore /var/lib/vz/dump/vzdump-qemu-100-2024_01_01-02_00_00.vma.zst 200 \
  --storage local-lvm

# Restore with different storage
qmrestore /var/lib/vz/dump/vzdump-qemu-100-2024_01_01-02_00_00.vma.zst 200 \
  --storage local-zfs

# Verify restore
qm list
qm config 200
```

**What You'll Learn**: VM restore from vzdump, storage migration

**When You Need This**: VM recovery, hardware replacement

**Simpler Alternative**: Manual reconfiguration

**Potential Pitfalls**: Storage compatibility, disk size

---

### VM Restore Script

```bash
# Create restore script
cat > /root/restore_vm.sh << 'EOF'
#!/bin/bash
# VM Restore Script

BACKUP_FILE="$1"
TARGET_VMID="$2"
TARGET_STORAGE="${3:-local-lvm}"

if [ -z "$BACKUP_FILE" ] || [ -z "$TARGET_VMID" ]; then
    echo "Usage: $0 <backup_file> <target_vmid> [target_storage]"
    echo ""
    echo "Available backups:"
    ls -lt /var/lib/vz/dump/*.vma.zst | head -5
    exit 1
fi

echo "=== VM Restore Procedure ==="
echo "Backup: $BACKUP_FILE"
echo "Target VMID: $TARGET_VMID"
echo "Target Storage: $TARGET_STORAGE"
echo ""

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Check if VMID is available
if qm list | grep -q "^$TARGET_VMID "; then
    echo "WARNING: VMID $TARGET_VMID is already in use"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Stop VM if running
if qm status $TARGET_VMID | grep -q "running"; then
    echo "Stopping existing VM..."
    qm stop $TARGET_VMID
fi

# Restore VM
echo "Restoring VM..."
qmrestore "$BACKUP_FILE" "$TARGET_VMID" --storage "$TARGET_STORAGE"

if [ $? -eq 0 ]; then
    echo "✓ VM restored successfully"
    echo ""
    echo "VM Configuration:"
    qm config $TARGET_VMID
    echo ""
    echo "Start VM with: qm start $TARGET_VMID"
else
    echo "✗ Restore failed"
    exit 1
fi
EOF
chmod +x /root/restore_vm.sh

# Use the script
./restore_vm.sh /var/lib/vz/dump/vzdump-qemu-100-2024_01_01-02_00_00.vma.zst 200
```

**What You'll Learn**: Automated restore procedures, error handling

**When You Need This**: Frequent restore operations

**Simpler Alternative**: Manual qmrestore command

**Potential Pitfalls**: VMID conflicts, storage issues

---

## Container Restore from vzdump

### What: Restore LXC container from backup

```bash
# List available container backups
ls -lt /var/lib/vz/dump/*.tar.zst

# Restore container from backup
# Syntax: vzrestore <backup_file> <new_ctid>

# Example: Restore container 100 to new container 200
vzrestore /var/lib/vz/dump/vzdump-lxc-100-2024_01_01-02_00_00.tar.zst 200

# Verify restore
pct list
pct config 200
```

**What You'll Learn**: Container restore, vzrestore usage

**When You Need This**: Container recovery

**Simpler Alternative**: Recreate container from template

**Potential Pitfalls**: Template version mismatch

---

### Container Restore Script

```bash
# Create container restore script
cat > /root/restore_container.sh << 'EOF'
#!/bin/bash
# Container Restore Script

BACKUP_FILE="$1"
TARGET_CTID="$2"

if [ -z "$BACKUP_FILE" ] || [ -z "$TARGET_CTID" ]; then
    echo "Usage: $0 <backup_file> <target_ctid>"
    echo ""
    echo "Available backups:"
    ls -lt /var/lib/vz/dump/*.tar.zst | head -5
    exit 1
fi

echo "=== Container Restore Procedure ==="
echo "Backup: $BACKUP_FILE"
echo "Target CTID: $TARGET_CTID"
echo ""

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Stop container if running
if pct status $TARGET_CTID | grep -q "running"; then
    echo "Stopping existing container..."
    pct stop $TARGET_CTID
fi

# Restore container
echo "Restoring container..."
vzrestore "$BACKUP_FILE" "$TARGET_CTID"

if [ $? -eq 0 ]; then
    echo "✓ Container restored successfully"
    echo ""
    echo "Container Configuration:"
    pct config $TARGET_CTID
    echo ""
    echo "Start container with: pct start $TARGET_CTID"
else
    echo "✗ Restore failed"
    exit 1
fi
EOF
chmod +x /root/restore_container.sh

# Use the script
./restore_container.sh /var/lib/vz/dump/vzdump-lxc-100-2024_01_01-02_00_00.tar.zst 200
```

**What You'll Learn**: Container restore automation

**When You Need This**: Frequent container restores

**Simpler Alternative**: Manual vzrestore command

**Potential Pitfalls**: CTID conflicts

---

## Restore from Proxmox Backup Server

### What: Restore VM from PBS

```bash
# List available backups on PBS
pbs-backup-client list --repository pbs-backup

# List backups for specific VM
pbs-backup-client list --repository pbs-backup --vmid 100

# Restore VM from PBS
# Syntax: pvesh create /storage/<storage>/restore --vmid <vmid> --backup <backup_id>

# Example: Restore VM 100 from PBS
pvesh create /storage/pbs-backup/restore \
  --vmid 100 \
  --backup vzdump-qemu-100-2024_01_01-02_00_00

# Restore to different VMID
pvesh create /storage/pbs-backup/restore \
  --vmid 200 \
  --backup vzdump-qemu-100-2024_01_01-02_00_00

# Verify restore
qm list
```

**What You'll Learn**: PBS restore, remote backup recovery

**When You Need This**: PBS backups, offsite recovery

**Simpler Alternative**: Local vzdump restore

**Potential Pitfalls**: Network connectivity, authentication

---

### PBS Restore Script

```bash
# Create PBS restore script
cat > /root/restore_from_pbs.sh << 'EOF'
#!/bin/bash
# PBS Restore Script

PBS_REPO="pbs-backup"
VMID="$1"
TARGET_VMID="${2:-$VMID}"

if [ -z "$VMID" ]; then
    echo "Usage: $0 <vmid> [target_vmid]"
    echo ""
    echo "Available backups:"
    pbs-backup-client list --repository $PBS_REPO
    exit 1
fi

echo "=== PBS Restore Procedure ==="
echo "Repository: $PBS_REPO"
echo "Source VMID: $VMID"
echo "Target VMID: $TARGET_VMID"
echo ""

# List available backups for VM
echo "Available backups for VM $VMID:"
pbs-backup-client list --repository $PBS_REPO --vmid $VMID

# Get latest backup
LATEST=$(pbs-backup-client list --repository $PBS_REPO --vmid $VMID | tail -1 | awk '{print $1}')
echo ""
echo "Latest backup: $LATEST"

# Confirm restore
read -p "Restore to VMID $TARGET_VMID? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled"
    exit 0
fi

# Restore VM
echo "Restoring VM..."
pvesh create /storage/pbs-backup/restore \
  --vmid $TARGET_VMID \
  --backup $LATEST

if [ $? -eq 0 ]; then
    echo "✓ VM restored successfully from PBS"
    echo ""
    echo "Start VM with: qm start $TARGET_VMID"
else
    echo "✗ Restore failed"
    exit 1
fi
EOF
chmod +x /root/restore_from_pbs.sh

# Use the script
./restore_from_pbs.sh 100 200
```

**What You'll Learn**: PBS restore automation

**When You Need This**: PBS backup recovery

**Simpler Alternative**: Manual pvesh restore

**Potential Pitfalls**: PBS connectivity, backup availability

---

## Point-in-Time Recovery

### What: Restore to specific backup point

```bash
# List all backups with timestamps
pbs-backup-client list --repository pbs-backup --vmid 100

# Identify backup by date
# Format: YYYYMMDDTHHMMSS

# Restore to specific point
pvesh create /storage/pbs-backup/restore \
  --vmid 200 \
  --backup vzdump-qemu-100-20240115T020000

# For vzdump backups
# Find backup by date
ls -lt /var/lib/vz/dump/ | grep "2024_01_15"

# Restore specific backup
qmrestore /var/lib/vz/dump/vzdump-qemu-100-2024_01_15-02_00_00.vma.zst 200 \
  --storage local-lvm
```

**What You'll Learn**: Point-in-time recovery, backup selection

**When You Need This**: Recover from specific event

**Simpler Alternative**: Restore latest backup

**Potential Pitfalls**: Backup chain dependencies

---

## Partial Restore

### What: Extract individual files from backup

```bash
# List files in backup
tar -tzf /var/lib/vz/dump/vzdump-qemu-100-2024_01_01-02_00_00.vma.zst | head -20

# Extract specific file
# Note: This requires extracting the disk image first

# Mount backup disk (requires loop device)
# 1. Extract disk from backup
tar -xzf /var/lib/vz/dump/vzdump-qemu-100-2024_01_01-02_00_00.vma.zst -C /tmp/

# 2. Mount the disk image
mkdir /mnt/backup-disk
mount -o loop /tmp/vm-100-disk-0.qcow2 /mnt/backup-disk

# 3. Access files
ls /mnt/backup-disk/home/admin/

# 4. Copy specific file
cp /mnt/backup-disk/home/admin/config.conf /tmp/

# 5. Unmount
umount /mnt/backup-disk
```

**What You'll Learn**: Partial file recovery, backup inspection

**When You Need This**: Recover single files, not full VM

**Simpler Alternative**: Full VM restore

**Potential Pitfalls**: Disk format compatibility, permissions

---

## Disaster Recovery Procedures

### Scenario 1: Single VM Failure

```bash
# 1. Identify failed VM
qm list | grep -E "stopped|error"

# 2. Stop VM if running
qm stop <failed_vm_id>

# 3. Find latest backup
ls -lt /var/lib/vz/dump/vzdump-qemu-<failed_vm_id>*.vma.zst | head -1

# 4. Restore to new VMID
qmrestore /var/lib/vz/dump/vzdump-qemu-<failed_vm_id>-*.vma.zst <new_vmid> \
  --storage local-lvm

# 5. Update network configuration
qm set <new_vmid> --net0 virtio,bridge=vmbr0,ip=<original_ip>/24,gw=<gateway>

# 6. Start restored VM
qm start <new_vmid>
```

### Scenario 2: Storage Failure

```bash
# 1. Assess damage
df -h
pvesm status

# 2. Replace/repair storage
# (Hardware replacement or storage rebuild)

# 3. Restore from offsite backup
# (Use PBS or external backup)

# 4. Restore VMs
qmrestore /path/to/backup.vma.zst <vmid> --storage <new_storage>

# 5. Verify all VMs restored
qm list
```

### Scenario 3: Complete Node Failure

```bash
# 1. Provision new node
# (Install Proxmox VE)

# 2. Join cluster
pvecm add <existing_node_ip>

# 3. Restore from PBS
pvesh create /storage/pbs-backup/restore \
  --vmid <vmid> \
  --backup <backup_id>

# 4. Restore all VMs
# (Use restore script for multiple VMs)

# 5. Verify cluster health
pvecm status
qm list
```

---

## Restore Testing

### What: Regular restore testing

```bash
# Create restore test script
cat > /root/test_restore.sh << 'EOF'
#!/bin/bash
# Restore Test Script

echo "=== Restore Test Procedure ==="
echo "Date: $(date)"
echo ""

# Test 1: List available backups
echo "1. Checking available backups..."
ls -lt /var/lib/vz/dump/*.vma.zst | head -3
echo ""

# Test 2: Verify backup integrity
echo "2. Verifying backup integrity..."
for backup in $(ls /var/lib/vz/dump/*.vma.zst | head -1); do
    if tar -tzf "$backup" > /dev/null 2>&1; then
        echo "✓ Backup integrity: OK - $backup"
    else
        echo "✗ Backup integrity: FAILED - $backup"
    fi
done
echo ""

# Test 3: Check PBS connectivity
echo "3. Checking PBS connectivity..."
if pvesh get /version > /dev/null 2>&1; then
    echo "✓ PBS connectivity: OK"
else
    echo "✗ PBS connectivity: FAILED"
fi
echo ""

# Test 4: Simulate restore (dry run)
echo "4. Simulating restore..."
echo "Restore would use: qmrestore <backup> <vmid> --storage local-lvm"
echo ""

echo "=== Test Complete ==="
echo "Next test: $(date -d '+30 days' '+%Y-%m-%d')"
EOF
chmod +x /root/test_restore.sh

# Run test
/root/test_restore.sh

# Schedule monthly test
echo "0 6 1 * * /root/test_restore.sh >> /var/log/restore_test.log 2>&1" | crontab -
```

**What You'll Learn**: Restore testing, disaster recovery validation

**When You Need This**: Compliance, confidence in backups

**Simpler Alternative**: Annual testing

**Potential Pitfalls**: Test doesn't guarantee production restore

---

## Learning Path Progression

1. **Beginner**: Basic VM/container restore from vzdump
2. **Intermediate**: PBS restore, point-in-time recovery
3. **Advanced**: Partial restore, disaster recovery scenarios
4. **Enterprise**: Automated restore testing, DR runbooks

---

## Real-World Job Skill Mapping

- **SRE**: Disaster recovery, restore procedures
- **DevOps Engineer**: Automated restore, testing
- **Security Engineer**: Ransomware recovery, data restoration
- **Cloud Engineer**: Multi-site recovery, PBS restore

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
