# Storage Strategy Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What Enterprise Skills You'll Learn

- **Storage Types**: ZFS, LVM-Thin, Directory comparison
- **Storage Decision Matrix**: Choosing the right storage for each use case
- **Performance Optimization**: Tuning storage for specific workloads
- **Data Protection**: RAID, snapshots, and replication
- **Capacity Planning**: Storage growth and management

## When You Actually Need This in Production

- Multi-VM/CT environments
- Performance-critical applications
- Data integrity requirements
- Scalability needs
- Compliance requirements

## Simpler Alternative for Daily Services

For most homelab users:
- Use local-lvm for all VMs
- Directory storage for ISOs
- Simple backup to external drive
- Default settings for performance

---

## Storage Type Comparison

### ZFS (Zettabyte File System)

| Feature | Description |
|------|-----|
| **Type** | Copy-on-write filesystem with built-in RAID |
| **Best For** | VM storage, critical data, data integrity |
| **Pros** | Snapshots, compression, deduplication, data integrity |
| **Cons** | Higher RAM requirements, less flexible |
| **RAM** | 1GB per 1TB storage recommended |

```bash
# Create ZFS storage
pvesm add zfs rpool/VM -content images,rootdir

# Create ZFS dataset with compression
zfs create -o compression=lz4 rpool/VM/vm-100-disk-0

# Create snapshot
zfs snapshot rpool/VM/vm-100-disk-0@backup

# List snapshots
zfs list -t snapshot

# Rollback to snapshot
zfs rollback rpool/VM/vm-100-disk-0@backup
```

**What You'll Learn**: ZFS filesystem, snapshots, data integrity

**When You Need This**: VM storage, critical data

**Simpler Alternative**: LVM-Thin for simpler setups

**Potential Pitfalls**: RAM requirements, recovery complexity

---

### LVM-Thin (Logical Volume Manager - Thin Provisioning)

| Feature | Description |
|------|-----|
| **Type** | Logical volume manager with thin provisioning |
| **Best For** | High I/O, smaller setups, flexibility |
| **Pros** | Thin provisioning, snapshots, flexible sizing |
| **Cons** | No built-in RAID, single point of failure |
| **RAM** | Minimal requirements |

```bash
# Create LVM-Thin storage
pvesm add lvmthin vg-pve -content images,rootdir

# Create thin volume
lvcreate -V 20G -n vm-100-disk-0 vg-pve

# Create snapshot
lvcreate -s -n vm-100-disk-0-snap -L 1G vg-pve/vm-100-disk-0

# List volumes
lvs

# Extend volume
lvextend -L +10G vg-pve/vm-100-disk-0
```

**What You'll Learn**: LVM management, thin provisioning

**When You Need This**: High I/O workloads, flexible storage

**Simpler Alternative**: Directory storage for simple needs

**Potential Pitfalls**: No data redundancy, snapshot limits

---

### Directory (Plain Directory Storage)

| Feature | Description |
|------|-----|
| **Type** | Simple directory-based storage |
| **Best For** | ISO storage, non-critical data, templates |
| **Pros** | Simple, flexible, no overhead |
| **Cons** | No snapshots, no compression, no integrity checks |
| **RAM** | Minimal requirements |

```bash
# Create directory storage
pvesm add dir local-isos -path /mnt/pve/local-isos -content iso

# Upload ISO
qm importdisk 100 /mnt/pve/local-isos/ubuntu-24.04.iso local-lvm

# List directory contents
ls -la /mnt/pve/local-isos/

# Create directory for templates
mkdir -p /mnt/pve/local/templates
```

**What You'll Learn**: Directory storage, file management

**When You Need This**: ISO storage, templates, non-critical data

**Simpler Alternative**: Use existing directory storage

**Potential Pitfalls**: No data protection, manual management

---

## Storage Decision Matrix

### What: Choose the right storage for each use case

```
┌─────────────────────────────────────────────────────────────────────┐
│                    STORAGE DECISION MATRIX                           │
├─────────────────────────────────────────────────────────────────────┤
│ Use Case              │ ZFS    │ LVM-Thin │ Directory │ Recommendation │
├───────────────────────┼────────┼──────────┼───────────┼────────────────┤
│ VM Storage (Critical) │   ✓    │    -     │     -     │ ZFS for data   │
│                       │        │          │           │ integrity      │
├───────────────────────┼────────┼──────────┼───────────┼────────────────┤
│ VM Storage (General)  │   -    │    ✓     │     -     │ LVM-Thin for   │
│                       │        │          │           │ flexibility    │
├───────────────────────┼────────┼──────────┼───────────┼────────────────┤
│ ISO Storage           │   -    │    -     │     ✓     │ Directory for  │
│                       │        │          │           │ simplicity     │
├───────────────────────┼────────┼──────────┼───────────┼────────────────┤
│ Template Storage      │   -    │    -     │     ✓     │ Directory for  │
│                       │        │          │           │ flexibility    │
├───────────────────────┼────────┼──────────┼───────────┼────────────────┤
│ Backup Storage        │   ✓    │    ✓     │     -     │ ZFS/LVM for    │
│                       │        │          │           │ backup integrity│
├───────────────────────┼────────┼──────────┼───────────┼────────────────┤
│ Container Storage     │   -    │    ✓     │     -     │ LVM-Thin for   │
│                       │        │          │           │ containers     │
├───────────────────────┼────────┼──────────┼───────────┼────────────────┤
│ High I/O Workloads    │   -    │    ✓     │     -     │ LVM-Thin for   │
│                       │        │          │           │ performance    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Storage Configuration Examples

### Example 1: Single Node with ZFS

```bash
# Check available ZFS pools
zpool list

# Create ZFS storage for VMs
pvesm add zfs rpool/VM \
  -content images,rootdir,backup \
  -zfs_options compression=lz4,dedup=off

# Create ZFS storage for backups
pvesm add zfs rpool/BACKUP \
  -content backup \
  -zfs_options compression=on

# Verify storage
pvesm status

# Monitor ZFS health
zpool status
zfs list
```

**What You'll Learn**: ZFS storage configuration, pool management

**When You Need This**: Single node with ZFS hardware

**Simpler Alternative**: LVM-Thin for simpler setups

**Potential Pitfalls**: RAM requirements, pool recovery

---

### Example 2: Single Node with LVM-Thin

```bash
# Check available volume groups
vgs

# Create LVM-Thin storage
pvesm add lvmthin vg-pve \
  -content images,rootdir,backup

# Create thin pool with specific size
lvcreate -L 100G -T vg-pve/thinpool

# Create thin volume
lvcreate -V 20G -n vm-100-disk-0 vg-pve/thinpool

# Monitor thin pool usage
lvs -o +seg_monitor vg-pve

# Extend thin pool
lvextend -L +50G vg-pve/thinpool
```

**What You'll Learn**: LVM-Thin configuration, thin pool management

**When You Need This**: Single node with LVM hardware

**Simpler Alternative**: Directory storage for simple needs

**Potential Pitfalls**: Thin pool exhaustion, snapshot limits

---

### Example 3: Multi-Storage Setup

```bash
# Create multiple storage types
# Local SSD for VMs
pvesm add lvmthin vg-ssd \
  -content images,rootdir \
  -thinpool ssd_pool

# Local HDD for backups
pvesm add dir local-backup \
  -path /mnt/pve/local-backup \
  -content backup

# NFS for shared storage
pvesm add nfs nfs-storage \
  -server 192.168.1.200 \
  -export /exports/proxmox \
  -content images,rootdir,backup

# Verify all storages
pvesm status

# Check storage usage
df -h
```

**What You'll Learn**: Multi-storage configuration, NFS integration

**When You Need This**: Mixed workload environments

**Simpler Alternative**: Single storage type

**Potential Pitfalls**: NFS latency, storage management

---

## Performance Optimization

### What: Optimize storage for specific workloads

```bash
# ZFS Performance Tuning
# Enable compression (reduces I/O)
zfs set compression=lz4 rpool/VM

# Tune cache settings
zfs set primarycache=metadata rpool/VM
zfs set secondarycache=all rpool/VM

# LVM-Thin Performance Tuning
# Set optimal discard settings
echo 'thin_pool_discard=1' >> /etc/lvm/lvm.conf

# Directory Storage Optimization
# Use faster filesystem
mkfs.xfs -f /dev/sdb1
mount /dev/sdb1 /mnt/pve/fast-storage

# VM Storage Optimization
# Use virtio-scsi for better performance
qm set 100 --scsihw virtio-scsi-pci

# Enable I/O threading
qm set 100 --iothread 1

# Use SSD for VM disk
qm set 100 --scsi0 ssd:vm-100-disk-0,size=20G
```

**What You'll Learn**: Storage performance tuning, optimization

**When You Need This**: Performance-critical workloads

**Simpler Alternative**: Default settings

**Potential Pitfalls**: Over-optimization, compatibility issues

---

## Capacity Planning

### What: Plan for storage growth

```bash
# Calculate storage needs
# Formula: (VM Size × VM Count) + (Backup Size × Retention) + Overhead

# Example calculation:
# 10 VMs × 50GB = 500GB
# Backups (7 daily + 4 weekly + 12 monthly) = 2TB
# Overhead (20%) = 540GB
# Total = 3.04TB

# Monitor storage usage
pvesm status
df -h

# Set up alerts
cat > /root/storage_monitor.sh << 'EOF'
#!/bin/bash
# Storage monitoring script

THRESHOLD=80

# Check each storage
for storage in $(pvesm status | grep -v "^#" | awk '{print $1}'); do
    USAGE=$(pvesm status $storage | grep -v "^#" | awk '{print $5}' | sed 's/%//')
    if [ $USAGE -gt $THRESHOLD ]; then
        echo "WARNING: Storage $storage is at ${USAGE}%" | mail -s "Storage Alert" admin@example.com
    fi
done
EOF
chmod +x /root/storage_monitor.sh

# Schedule monitoring
echo "0 6 * * * /root/storage_monitor.sh" | crontab -
```

**What You'll Learn**: Capacity planning, growth monitoring

**When You Need This**: Long-term storage planning

**Simpler Alternative**: Manual monitoring

**Potential Pitfalls**: Underestimating growth

---

## Data Protection

### What: Protect data with snapshots and replication

```bash
# ZFS Snapshots
# Create snapshot
zfs snapshot rpool/VM/vm-100-disk-0@daily

# List snapshots
zfs list -t snapshot -o name,used,avail,created

# Delete old snapshots
zfs list -t snapshot -H -o name | grep -v "latest" | xargs -I {} zfs destroy {}

# LVM-Thin Snapshots
# Create snapshot
lvcreate -s -n vm-100-disk-0-snap -L 5G vg-pve/vm-100-disk-0

# List snapshots
lvs -o +snap_count vg-pve

# Delete snapshot
lvremove vg-pve/vm-100-disk-0-snap

# Backup with Proxmox
vzdump 100 --mode snapshot --storage local-backup --compress zstd

# Replicate ZFS dataset (if available)
zfs send rpool/VM/vm-100-disk-0@daily | ssh backup-server zfs recv backup/rpool/VM/vm-100-disk-0
```

**What You'll Learn**: Snapshots, data replication, backup strategies

**When You Need This**: Data protection, disaster recovery

**Simpler Alternative**: Regular backups

**Potential Pitfalls**: Snapshot overhead, replication complexity

---

## Storage Best Practices

### What: Storage configuration best practices

```bash
# 1. Use appropriate storage for each use case
# VMs: ZFS or LVM-Thin
# ISOs: Directory
# Backups: ZFS or LVM-Thin

# 2. Enable compression for ZFS
zfs set compression=lz4 rpool/VM

# 3. Monitor storage usage
pvesm status

# 4. Set up alerts
# See storage monitoring script above

# 5. Document storage configuration
cat > /root/storage_documentation.md << 'EOF'
# Storage Documentation

## ZFS Storage (rpool/VM)
- Type: ZFS
- Size: 1TB
- Compression: lz4
- Used for: VM storage

## LVM-Thin Storage (vg-pve)
- Type: LVM-Thin
- Size: 500GB
- Thin Pool: ssd_pool
- Used for: High I/O VMs

## Directory Storage (local-isos)
- Type: Directory
- Path: /mnt/pve/local-isos
- Used for: ISO files
EOF

# 6. Regular maintenance
# Check ZFS health monthly
zpool status

# Check LVM health monthly
lvs -a

# Clean up old snapshots
find /var/lib/vz/dump -name "*.vma.zst" -mtime +30 -delete
```

**What You'll Learn**: Storage best practices, documentation

**When You Need This**: Production storage deployment

**Simpler Alternative**: Ad-hoc storage setup

**Potential Pitfalls**: Inconsistent configuration

---

## Learning Path Progression

1. **Beginner**: Basic storage types, simple configuration
2. **Intermediate**: Multi-storage setup, performance tuning
3. **Advanced**: ZFS optimization, replication
4. **Enterprise**: Multi-site storage, automated management

---

## Real-World Job Skill Mapping

- **Cloud Engineer**: Storage types, capacity planning
- **DevOps Engineer**: Storage automation, optimization
- **SRE**: Data protection, monitoring
- **Storage Engineer**: All sections apply directly

---

## Storage Comparison Summary

| Feature | ZFS | LVM-Thin | Directory |
|------|-----|----------|-----|
| Snapshots | Yes | Yes | No |
| Compression | Yes | No | No |
| RAID | Yes (mirror) | No | No |
| Performance | Good | Excellent | Good |
| RAM Usage | High | Low | Low |
| Complexity | Medium | Low | Low |
| Best For | Data integrity | Performance | Simplicity |

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
