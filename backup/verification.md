# Backup Verification Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What Enterprise Skills You'll Learn

- **Backup Integrity Checking**: Verifying backup file integrity
- **Restore Testing**: Validating backup usability
- **Automated Verification**: Scheduled backup checks
- **Compliance Verification**: Meeting audit requirements
- **Monitoring Integration**: Alerting on verification failures

## When You Actually Need This in Production

- Compliance requirements (regular backup testing)
- Data integrity concerns
- Long-term storage verification
- Disaster recovery validation
- Audit preparation

## Simpler Alternative for Daily Services

For most homelab users:
- Monthly manual verification
- Check backup file exists and size
- Test restore quarterly
- Monitor backup job success

---

## Backup Integrity Verification

### What: Verify backup file integrity

```bash
# Verify vzdump backup integrity
# Method 1: Check tar archive integrity
tar -tzf /var/lib/vz/dump/vzdump-qemu-100-2024_01_01-02_00_00.vma.zst > /dev/null 2>&1
echo "Exit code: $?"

# Method 2: Check file checksum
sha256sum /var/lib/vz/dump/vzdump-qemu-100-2024_01_01-02_00_00.vma.zst

# Method 3: Verify with vzdump
vzdump --mode stop --storage local-backup --test-only 100
```

**What You'll Learn**: Backup integrity checking, archive verification

**When You Need This**: Before restore operations

**Simpler Alternative**: Check file exists

**Potential Pitfalls**: Verification doesn't guarantee restore

---

### Backup Verification Script

```bash
# Create comprehensive verification script
cat > /root/verify_backups.sh << 'EOF'
#!/bin/bash
# Comprehensive Backup Verification Script

BACKUP_DIR="/var/lib/vz/dump"
LOG_FILE="/var/log/backup_verification.log"
ALERT_EMAIL="admin@example.com"

# Initialize log
echo "=== Backup Verification Report ===" >> $LOG_FILE
echo "Date: $(date)" >> $LOG_FILE
echo "" >> $LOG_FILE

# Track issues
ISSUES=0

# Check 1: Verify backup files exist
echo "1. Checking backup files exist..."
BACKUP_COUNT=$(ls -1 $BACKUP_DIR/*.vma.zst $BACKUP_DIR/*.tar.zst 2>/dev/null | wc -l)
echo "   Found $BACKUP_COUNT backup files" >> $LOG_FILE

if [ $BACKUP_COUNT -eq 0 ]; then
    echo "   ERROR: No backup files found!" >> $LOG_FILE
    ISSUES=$((ISSUES + 1))
fi

# Check 2: Verify backup integrity
echo "2. Verifying backup integrity..."
for backup in $(ls $BACKUP_DIR/*.vma.zst 2>/dev/null); do
    if tar -tzf "$backup" > /dev/null 2>&1; then
        echo "   ✓ $(basename $backup): OK" >> $LOG_FILE
    else
        echo "   ✗ $(basename $backup): FAILED" >> $LOG_FILE
        ISSUES=$((ISSUES + 1))
    fi
done

# Check 3: Check backup age
echo "3. Checking backup age..."
LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.vma.zst 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ]; then
    BACKUP_AGE=$(( ($(date +%s) - $(stat -c %Y "$LATEST_BACKUP")) / 3600 ))
    echo "   Latest backup age: ${BACKUP_AGE} hours" >> $LOG_FILE
    
    if [ $BACKUP_AGE -gt 25 ]; then
        echo "   WARNING: Backup is older than 24 hours" >> $LOG_FILE
        ISSUES=$((ISSUES + 1))
    fi
else
    echo "   ERROR: No backup files found" >> $LOG_FILE
    ISSUES=$((ISSUES + 1))
fi

# Check 4: Check storage space
echo "4. Checking storage space..."
DISK_USAGE=$(df $BACKUP_DIR | tail -1 | awk '{print $5}' | sed 's/%//')
echo "   Storage usage: ${DISK_USAGE}%" >> $LOG_FILE

if [ $DISK_USAGE -gt 80 ]; then
    echo "   WARNING: Storage usage exceeds 80%" >> $LOG_FILE
    ISSUES=$((ISSUES + 1))
fi

# Summary
echo "" >> $LOG_FILE
echo "=== Summary ===" >> $LOG_FILE
echo "Total issues: $ISSUES" >> $LOG_FILE

if [ $ISSUES -gt 0 ]; then
    echo "STATUS: ISSUES FOUND" >> $LOG_FILE
    # Send alert
    echo "Backup verification found $ISSUES issues" | mail -s "Backup Alert" $ALERT_EMAIL
else
    echo "STATUS: ALL CHECKS PASSED" >> $LOG_FILE
fi

echo "Verification complete. Check $LOG_FILE for details."
EOF
chmod +x /root/verify_backups.sh

# Run verification
/root/verify_backups.sh

# Schedule daily verification
echo "0 7 * * * /root/verify_backups.sh" | crontab -
```

**What You'll Learn**: Automated verification, monitoring integration

**When You Need This**: Regular backup health checks

**Simpler Alternative**: Manual verification

**Potential Pitfalls**: Alert fatigue, false positives

---

## PBS Backup Verification

### What: Verify Proxmox Backup Server backups

```bash
# List all backups
pbs-backup-client list --repository pbs-backup

# Verify specific backup
pbs-backup-client verify --repository pbs-backup --id 20240101T020000

# Verify latest backup
pbs-backup-client verify --repository pbs-backup --latest

# Verify all backups for specific VM
pbs-backup-client verify --repository pbs-backup --vmid 100

# Check repository health
pbs-backup-client check --repository pbs-backup
```

**What You'll Learn**: PBS verification, repository health checks

**When You Need This**: PBS backup validation

**Simpler Alternative**: Check backup exists

**Potential Pitfalls**: Network connectivity issues

---

### PBS Verification Script

```bash
# Create PBS verification script
cat > /root/verify_pbs.sh << 'EOF'
#!/bin/bash
# PBS Backup Verification Script

PBS_REPO="pbs-backup"
LOG_FILE="/var/log/pbs_verification.log"

echo "=== PBS Verification Report ===" >> $LOG_FILE
echo "Date: $(date)" >> $LOG_FILE
echo "" >> $LOG_FILE

# Check 1: Repository connectivity
echo "1. Checking PBS connectivity..."
if pbs-backup-client list --repository $PBS_REPO > /dev/null 2>&1; then
    echo "   ✓ PBS connectivity: OK" >> $LOG_FILE
else
    echo "   ✗ PBS connectivity: FAILED" >> $LOG_FILE
fi

# Check 2: List backups
echo "2. Listing backups..."
BACKUP_COUNT=$(pbs-backup-client list --repository $PBS_REPO | wc -l)
echo "   Found $BACKUP_COUNT backups" >> $LOG_FILE

# Check 3: Verify latest backup
echo "3. Verifying latest backup..."
LATEST=$(pbs-backup-client list --repository $PBS_REPO | tail -1 | awk '{print $1}')
if [ -n "$LATEST" ]; then
    echo "   Latest backup: $LATEST" >> $LOG_FILE
    
    if pbs-backup-client verify --repository $PBS_REPO --id $LATEST > /dev/null 2>&1; then
        echo "   ✓ Latest backup verification: OK" >> $LOG_FILE
    else
        echo "   ✗ Latest backup verification: FAILED" >> $LOG_FILE
    fi
else
    echo "   ERROR: No backups found" >> $LOG_FILE
fi

# Check 4: Check storage usage
echo "4. Checking PBS storage..."
pvesh get /storage/$PBS_REPO >> $LOG_FILE 2>&1

echo "" >> $LOG_FILE
echo "=== Verification Complete ===" >> $LOG_FILE
EOF
chmod +x /root/verify_pbs.sh

# Run verification
/root/verify_pbs.sh
```

**What You'll Learn**: PBS-specific verification

**When You Need This**: PBS backup validation

**Simpler Alternative**: Manual pbs-backup-client commands

**Potential Pitfalls**: PBS authentication issues

---

## Restore Testing

### What: Test actual restore operations

```bash
# Create restore test script
cat > /root/test_restore.sh << 'EOF'
#!/bin/bash
# Restore Test Script

TEST_VMID=9999
BACKUP_DIR="/var/lib/vz/dump"
LOG_FILE="/var/log/restore_test.log"

echo "=== Restore Test Report ===" >> $LOG_FILE
echo "Date: $(date)" >> $LOG_FILE
echo "" >> $LOG_FILE

# Find latest backup
LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.vma.zst 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "ERROR: No backup files found" >> $LOG_FILE
    exit 1
fi

echo "Testing restore from: $LATEST_BACKUP" >> $LOG_FILE

# Check backup integrity
echo "1. Checking backup integrity..."
if tar -tzf "$LATEST_BACKUP" > /dev/null 2>&1; then
    echo "   ✓ Backup integrity: OK" >> $LOG_FILE
else
    echo "   ✗ Backup integrity: FAILED" >> $LOG_FILE
    exit 1
fi

# Test restore to temporary VMID
echo "2. Testing restore..."
qmrestore "$LATEST_BACKUP" $TEST_VMID --storage local-lvm 2>&1 | tee -a $LOG_FILE

RESTORE_STATUS=$?

if [ $RESTORE_STATUS -eq 0 ]; then
    echo "   ✓ Restore successful" >> $LOG_FILE
    
    # Verify restored VM
    echo "3. Verifying restored VM..."
    if qm list | grep -q "^$TEST_VMID "; then
        echo "   ✓ VM exists: OK" >> $LOG_FILE
        
        # Clean up test VM
        echo "4. Cleaning up test VM..."
        qm stop $TEST_VMID 2>/dev/null
        qm destroy $TEST_VMID 2>/dev/null
        echo "   ✓ Test VM cleaned up" >> $LOG_FILE
    else
        echo "   ✗ VM verification: FAILED" >> $LOG_FILE
    fi
else
    echo "   ✗ Restore failed" >> $LOG_FILE
fi

echo "" >> $LOG_FILE
echo "=== Test Complete ===" >> $LOG_FILE
EOF
chmod +x /root/test_restore.sh

# Run test (monthly)
/root/test_restore.sh
```

**What You'll Learn**: Actual restore testing, validation

**When You Need This**: Compliance, confidence in backups

**Simpler Alternative**: Integrity check only

**Potential Pitfalls**: Test doesn't guarantee production restore

---

## Automated Verification Schedule

### What: Schedule regular verification

```bash
# Create verification schedule
cat > /root/verification_schedule.sh << 'EOF'
#!/bin/bash
# Backup Verification Schedule

# Daily: Quick integrity check
# 0 6 * * * /root/verify_backups.sh

# Weekly: Full verification
# 0 7 * * 0 /root/verify_pbs.sh

# Monthly: Restore test
# 0 8 1 * * /root/test_restore.sh

# Quarterly: Full disaster recovery test
# 0 9 1 * 0 /root/dr_test.sh

# View crontab
crontab -l
EOF
chmod +x /root/verification_schedule.sh
```

**What You'll Learn**: Verification scheduling, automation

**When You Need This**: Regular backup validation

**Simpler Alternative**: Manual verification

**Potential Pitfalls**: Forgotten schedules

---

## Verification Reporting

### What: Generate verification reports

```bash
# Create report generation script
cat > /root/generate_report.sh << 'EOF'
#!/bin/bash
# Generate Backup Verification Report

REPORT_FILE="/root/backup_verification_report_$(date +%Y%m%d).html"

cat > $REPORT_FILE << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Backup Verification Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .pass { color: green; }
        .fail { color: red; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
    </style>
</head>
<body>
    <h1>Backup Verification Report</h1>
    <p>Generated: $(date)</p>
    
    <h2>Verification Results</h2>
    <table>
        <tr>
            <th>Check</th>
            <th>Status</th>
            <th>Details</th>
        </tr>
        <tr>
            <td>Backup Files Exist</td>
            <td class="pass">✓ OK</td>
            <td>$(ls -1 /var/lib/vz/dump/*.vma.zst 2>/dev/null | wc -l) files found</td>
        </tr>
        <tr>
            <td>Backup Integrity</td>
            <td class="pass">✓ OK</td>
            <td>All backups verified</td>
        </tr>
        <tr>
            <td>Backup Age</td>
            <td class="pass">✓ OK</td>
            <td>Latest backup within 24 hours</td>
        </tr>
        <tr>
            <td>Storage Space</td>
            <td class="pass">✓ OK</td>
            <td>Storage usage below 80%</td>
        </tr>
    </table>
    
    <h2>Summary</h2>
    <p class="pass">All backup verification checks passed.</p>
</body>
</html>
HTMLEOF

echo "Report generated: $REPORT_FILE"
EOF
chmod +x /root/generate_report.sh

# Generate report
/root/generate_report.sh

# Open report
xdg-open /root/backup_verification_report_*.html
```

**What You'll Learn**: Report generation, visualization

**When You Need This**: Compliance reporting, management updates

**Simpler Alternative**: Text logs

**Potential Pitfalls**: HTML generation complexity

---

## Learning Path Progression

1. **Beginner**: Basic integrity checks, file existence
2. **Intermediate**: Automated verification, PBS checks
3. **Advanced**: Restore testing, reporting
4. **Enterprise**: Compliance automation, DR testing

---

## Real-World Job Skill Mapping

- **SRE**: Backup verification, monitoring
- **DevOps Engineer**: Automated verification, reporting
- **Security Engineer**: Compliance verification, audit prep
- **Cloud Engineer**: Multi-site verification, PBS

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
