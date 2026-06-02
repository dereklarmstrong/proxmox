# Troubleshooting Guide

## Common Issues

### Script Errors

#### "command not found"

```bash
# Ensure you're on Proxmox node
which qm
which pct
which pvesm

# Install missing tools
apt update && apt install -y proxmox-small-fs
```

#### Permission Denied

All scripts must run as root:

```bash
sudo ./scripts/vm/list_vms.sh
```

#### Connection Refused

Check Proxmox connectivity:

```bash
# Test API
curl -k -u root@pam https://192.168.1.3:8006/api2/json/version

# Check if Proxmox services are running
systemctl status pveproxy
systemctl status pvedaemon
```

### VM Issues

#### VM Won't Start

```bash
# Check VM config
qm config 100

# Check for locked state
qm unlock 100

# Check storage availability
pvesm status

# Check logs
tail -f /var/log/syslog | grep qemu
```

#### VM Network Issues

```bash
# Check bridge
brctl show vmbr0

# Check VM network config
qm config 100 | grep net

# Test from host
ping -c 3 <vm_ip>
```

#### VM Disk Full

```bash
# Check disk usage inside VM
ssh vm "df -h"

# Resize disk from host
qm resize 100 scsi0 +10G

# Check disk info
qemu-img info /var/lib/vz/images/100/vm-100-disk-0.raw
```

### Container Issues

#### Container Won't Start

```bash
# Check container config
pct config 200

# Check template exists
pct list-templates

# Check storage
pvesm status
```

#### Container Network Issues

```bash
# Check container network config
pct config 200 | grep net

# Check host routing
ip route

# Test DNS resolution
nslookup example.com
```

### Backup Issues

#### Backup Fails

```bash
# Check backup storage
pvesm status --content backup

# Check available space
df -h /var/lib/vz/dump

# Check backup logs
grep "vzdump" /var/log/syslog
```

#### Restore Fails

```bash
# Verify backup file exists
ls -la /var/lib/vz/dump/vzdump-qemu-100-2024_01_01-12_00_00.vma.zst

# Check backup integrity
vma zst test /var/lib/vz/dump/vzdump-qemu-100-2024_01_01-12_00_00.vma.zst
```

### Storage Issues

#### Storage Not Available

```bash
# Check storage configuration
cat /etc/pve/storage.cfg

# Verify storage path
ls -la /var/lib/vz

# Check filesystem
df -h
```

#### Disk Space Full

```bash
# Find large files
find /var/lib/vz -type f -size +1G -exec ls -lh {} \;

# Clean old backups
./scripts/backup/gfs_retention.sh --force

# Clean orphaned disks
./scripts/storage/cleanup_orphaned.sh --force
```

### Snapshot Issues

#### Snapshot Too Large

```bash
# List snapshots
qm snapshots 100

# Remove old snapshots
qm snapshots 100 | awk 'NR>1 {print $1}' | head -1 | xargs -I {} qm snapshot 100 {} --delete

# Check snapshot size
qm config 100 | grep snap
```

#### Snapshot Freeze

```bash
# Check if filesystem is frozen
qm config 100 | grep freeze

# Unfreeze
qm freeze 100 --unfreeze
```

## Debug Mode

### Enable Verbose Logging

```bash
# Run with bash debug mode
bash -x ./scripts/vm/list_vms.sh
```

### Check Proxmox Logs

```bash
# System logs
tail -f /var/log/syslog

# Proxmox logs
tail -f /var/log/pveproxy/access.log

# QEMU logs
tail -f /var/log/qemu/*.log
```

### API Debug

```bash
# Enable API logging
systemctl restart pveproxy

# Check API logs
tail -f /var/log/pveproxy/error.log
```

## Getting Help

1. Check script `--help` for usage
2. Review `lib/common.sh` for utility functions
3. Search Proxmox forums: https://forum.proxmox.com
4. Check Proxmox documentation: https://pve.proxmox.com/pve-docs/
