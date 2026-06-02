# Storage Management

## Storage Types

### LVM-Thin

Best for performance. Supports snapshots and thin provisioning.

```
Storage: local-lvm
Type: LVM-Thin
Pool: pve
```

### Directory (ext4/xfs)

Simple, reliable. Good for backups.

```
Storage: local
Type: Directory
Path: /var/lib/vz
```

### ZFS

Best for data integrity. Supports snapshots, compression, and deduplication.

```
Storage: zfs-pool
Type: ZFS Pool
Pool: rpool/data
```

### NFS

Network storage. Good for shared storage in cluster.

```
Storage: nfs-backup
Type: NFS
Path: /mnt/pve/nfs-backup
```

## Disk Formats

### qcow2

QEMU copy-on-write format. Supports snapshots, compression, and encryption.

```bash
# Convert to qcow2
qemu-img convert -f raw -O qcow2 disk.raw disk.qcow2

# Check image info
qemu-img info disk.qcow2
```

### raw

Raw disk image. Maximum performance, no overhead.

```bash
# Create raw disk
qemu-img create -f raw disk.raw 20G
```

### vmdk

VMware disk format. Useful for cross-platform compatibility.

## Storage Commands

### Check Storage Status

```bash
pvesm status
pvesm status --content images
pvesm status --content backup
```

### Disk Usage by VM

```bash
# List all disk usage
pvesm status --content images

# Check specific VM disk
qm config 100 | grep -E "^(scsi|virtio|sata)"
```

### Cleanup Orphaned Disks

```bash
# Preview orphaned files
./scripts/storage/cleanup_orphaned.sh --dry-run

# Delete orphaned files
./scripts/storage/cleanup_orphaned.sh --force
```

## Storage Best Practices

### Performance

- Use LVM-Thin or ZFS for VM disks
- Enable discard/trim: `qm set 100 --scsi0 discards=set`
- Use SSD/NVMe for production workloads
- Avoid network storage for database VMs

### Capacity Planning

- Keep storage usage below 80%
- Monitor disk growth trends
- Set up alerts at 70% and 90%
- Plan for 6-month growth

### Snapshots

- Snapshots are not backups
- Remove snapshots after verification
- Avoid long-lived snapshots (performance impact)
- Use for pre-upgrade safety only

## Storage Migration

### Move VM Disk Between Storages

```bash
# Stop VM
qm stop 100

# Move disk
qm move-disk 100 scsi0 backup-lvm

# Start VM
qm start 100
```

### Resize Disk

```bash
# Resize LVM-Thin disk
qm resize 100 scsi0 +20G

# Resize ZFS disk
qm resize 100 scsi0 50G
```
