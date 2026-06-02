# Backup Strategy

## The 3-2-1 Rule

- **3** copies of your data
- **2** different storage mediums
- **1** copy offsite

## Backup Types

### Full Backup

Complete copy of the VM/container. Used as the base for incremental backups.

```bash
# Proxmox native backup (creates .vma.zst)
pvesm backup 100 --storage backup-lvm --mode full
```

### Incremental Backup

Only changed blocks since last backup. Faster and uses less space.

```bash
pvesm backup 100 --storage backup-lvm --mode incremental
```

### Snapshot

Point-in-time state capture. Not a backup — must be synced to storage.

```bash
./scripts/vm/snapshot_vm.sh --vmid 100 --name pre-upgrade
```

## Backup Schedule

| Frequency | Retention | Purpose |
|-----------|-----------|---------|
| Daily | 7 days | Recent recovery |
| Weekly | 4 weeks | Week-level recovery |
| Monthly | 6 months | Month-level recovery |
| Yearly | 1 year | Compliance, long-term |

## Best Practices

### What to Backup

- All production VMs and containers
- Configuration files (`/etc/`, `/root/`)
- Database dumps
- Application data volumes

### What Not to Backup

- Temporary files
- Cache directories
- Swap files
- Already-redundant data (ZFS mirrors, RAID)

### Storage Considerations

- Keep backup storage separate from production storage
- Use dedicated backup server (Proxmox Backup Server) for large environments
- Monitor backup storage usage regularly
- Test restores quarterly

## Backup Verification

```bash
# Check backup status
./scripts/backup/backup_status.sh

# Verify backup integrity
pvesm backup 100 --storage backup-lvm --mode verify
```

## Restore Procedures

See `docs/restore_procedures.md` for detailed restore instructions.
