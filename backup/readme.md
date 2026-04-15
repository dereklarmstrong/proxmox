# Backup & Disaster Recovery Documentation

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## Overview

This section covers comprehensive backup and disaster recovery strategies for Proxmox environments, from basic local backups to enterprise-grade solutions with Proxmox Backup Server.

## Documentation Index

### Core Backup Strategies

| Document | Description | Difficulty |
|-----|-----|-----|
| [`backup-strategy.md`](../backup-strategy.md) | 3-2-1 backup rule, GFS retention, encryption, monitoring | Intermediate |
| [`gfs-strategy.md`](gfs-strategy.md) | Grandfather-Father-Son retention policy implementation | Advanced |
| [`pbs-setup.md`](pbs-setup.md) | Proxmox Backup Server installation and configuration | Advanced |
| [`restore-procedures.md`](restore-procedures.md) | VM and container restore procedures | All levels |
| [`verification.md`](verification.md) | Backup integrity checking and testing | Intermediate |

### Quick Reference

- **Getting Started**: Start with [`backup-strategy.md`](../backup-strategy.md)
- **Compliance Requirements**: See [`gfs-strategy.md`](gfs-strategy.md)
- **Enterprise Setup**: Follow [`pbs-setup.md`](pbs-setup.md)
- **Disaster Recovery**: Read [`restore-procedures.md`](restore-procedures.md)
- **Backup Health**: Use [`verification.md`](verification.md)

## Learning Path

### Beginner
1. Understand basic backup concepts in [`backup-strategy.md`](../backup-strategy.md)
2. Learn simple local backups with vzdump
3. Test restore procedures in [`restore-procedures.md`](restore-procedures.md)

### Intermediate
1. Implement GFS retention in [`gfs-strategy.md`](gfs-strategy.md)
2. Set up backup verification in [`verification.md`](verification.md)
3. Configure backup monitoring

### Advanced
1. Deploy Proxmox Backup Server in [`pbs-setup.md`](pbs-setup.md)
2. Implement encryption and offsite backups
3. Create automated disaster recovery procedures

## Related Documentation

- **Storage**: See [`docs/cheatsheet.md`](../docs/cheatsheet.md) for storage configuration tips
- **Automation**: See [`automation/`](../automation/) for backup automation scripts
- **Security**: See [`security.md`](../security.md) for backup encryption

## Common Use Cases

| Use Case | Recommended Documents |
|-----|-----|
| Simple homelab backup | [`backup-strategy.md`](../backup-strategy.md) |
| Compliance requirements | [`gfs-strategy.md`](gfs-strategy.md) |
| Multi-site deployment | [`pbs-setup.md`](pbs-setup.md) |
| Ransomware recovery | [`restore-procedures.md`](restore-procedures.md) |
| Regular backup testing | [`verification.md`](verification.md) |

## Backup Scripts

The following scripts are available for backup automation:

### Individual VM/Container Backup
- [`scripts/backup/backup_vm.sh`](../scripts/backup/backup_vm.sh:1) — vzdump wrapper for a single VM/CT
  - Usage: `bash scripts/backup/backup_vm.sh -i <vmid|ctid> [options]`
  - Options: `-s <storage>` (target storage), `-m <mode>` (snapshot|stop|suspend), `-c <compress>` (zstd|lzo|gzip)

### All VMs/Containers Backup
- [`scripts/backup/backup_all.sh`](../scripts/backup/backup_all.sh:1) — back up all VMs and containers
  - Usage: `bash scripts/backup/backup_all.sh [options]`
  - Options: `-s <storage>`, `-m <mode>`, `-c <compress>`
  - See: [`backup-strategy.md`](../backup-strategy.md) for backup mode recommendations

### Backup Pruning
- [`scripts/backup/prune_backups.sh`](../scripts/backup/prune_backups.sh:1) — prune old vzdump backups by age
  - Usage: `bash scripts/backup/prune_backups.sh [-d <dir>] [-r <days>]`
  - Default retention: `$BACKUP_RETENTION_DAYS` from config
  - See: [`gfs-strategy.md`](gfs-strategy.md) for retention policy guidance

### Backup Reporting
- [`scripts/backup/report.sh`](../scripts/backup/report.sh:1) — generate backup status report for all VMs and containers
  - Usage: `bash scripts/backup/report.sh [-d <days>] [-s <storage>]`
  - Shows backup status, age, and identifies missing or old backups
  - See: [`verification.md`](verification.md) for backup verification best practices

## Backup Best Practices

### 3-2-1 Rule
- **3** copies of your data
- **2** different storage media
- **1** offsite copy
- See: [`backup-strategy.md`](../backup-strategy.md)

### GFS Retention
- **Grandfather-Father-Son** rotation for compliance
- Daily (Son), Weekly (Father), Monthly (Grandfather) backups
- See: [`gfs-strategy.md`](gfs-strategy.md)

### Backup Verification
- Regular integrity checks
- Test restores periodically
- See: [`verification.md`](verification.md)

## Integration with Other Documentation

| Documentation | Backup Integration |
|-----|-----|
| [`automation/readme.md`](../automation/readme.md) | Schedule backup scripts via cron |
| [`security/readme.md`](../security/readme.md) | Backup encryption and key management |
| [`networking/readme.md`](../networking/readme.md) | Backup network considerations |
| [`storage/readme.md`](../scripts/storage/readme.md) | Storage type selection for backups |

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
