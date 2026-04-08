# Incident Response Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers incident response procedures for Proxmox environments:

- **Incident Response Planning**: Building IR capabilities
- **Detection and Analysis**: Identifying security events
- **Containment Strategies**: Limiting incident impact
- **Eradication and Recovery**: Restoring systems
- **Post-Incident Analysis**: Learning from incidents

## When You Need This

- Security breach detection
- Malware or ransomware incidents
- Unauthorized access attempts
- Data breach response
- System compromise investigation

## Simpler Alternative

For most homelab users:
- Keep regular backups
- Monitor for unusual activity
- Have a recovery plan
- Test restore procedures

---

## Incident Response Framework

### NIST Incident Response Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                    NIST IR Lifecycle                            │
├─────────────┬─────────────┬─────────────┬───────────────────────┤
│  Preparation│ Detection   │ Containment │ Eradication & Recovery│
│             │ & Analysis  │             │                       │
└─────────────┴─────────────┴─────────────┴───────────────────────┘
                              │
                              ▼
                    Post-Incident Activity
```

### Incident Severity Levels

| Level | Description | Response Time |
|------|------|------|
| Critical | Active breach, data exfiltration | Immediate |
| High | Confirmed unauthorized access | 1 hour |
| Medium | Suspicious activity | 4 hours |
| Low | Minor security event | 24 hours |

---

## Incident Response Planning

### Create Incident Response Plan

```bash
# Create IR plan directory
mkdir -p /root/incident-response
cd /root/incident-response

# Create incident response playbook
cat > playbook.md << 'EOF'
# Incident Response Playbook

## Emergency Contacts
- System Administrator: [contact]
- Security Team: [contact]
- Management: [contact]

## Incident Classification
- Critical: Active breach, data loss
- High: Unauthorized access confirmed
- Medium: Suspicious activity
- Low: Minor security event

## Response Procedures
See individual procedure documents for each incident type.
EOF

# Create contact list
cat > contacts.md << 'EOF'
# Incident Response Contacts

## Internal
- Primary Admin: [name] - [phone] - [email]
- Secondary Admin: [name] - [phone] - [email]
- Management: [name] - [phone] - [email]

## External
- ISP: [contact]
- Hosting Provider: [contact]
- Law Enforcement: [contact]
- Legal Counsel: [contact]
EOF

# Create evidence collection checklist
cat > evidence-checklist.md << 'EOF'
# Evidence Collection Checklist

## System Evidence
- [ ] System logs (/var/log/)
- [ ] Authentication logs (/var/log/auth.log)
- [ ] Process list (ps aux)
- [ ] Network connections (netstat -tulpn)
- [ ] Running services (systemctl list-units)
- [ ] Scheduled tasks (crontab -l)
- [ ] User accounts (cat /etc/passwd)
- [ ] Recent file changes (find / -mtime -7)

## Network Evidence
- [ ] Firewall logs
- [ ] Network traffic captures
- [ ] DNS queries
- [ ] Proxy logs

## VM/Container Evidence
- [ ] VM configuration files
- [ ] Container logs
- [ ] Snapshot data
- [ ] Backup integrity

## Chain of Custody
Document all evidence handling:
- Date/Time collected
- Collected by
- Storage location
- Access log
EOF
```

---

## Detection and Analysis

### Log Monitoring Setup

```bash
# Create log monitoring script
cat > /root/incident-monitor.sh << 'EOF'
#!/bin/bash
# Incident Detection Monitor
# ⚠️ PITFALL: Monitor for false positives

LOG_DIR="/var/log/incident-monitor"
ALERT_LOG="$LOG_DIR/alerts.log"
DATE=$(date +%Y%m%d)

mkdir -p $LOG_DIR

# Check for failed login attempts
FAILED_LOGINS=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
if [ "$FAILED_LOGINS" -gt 10 ]; then
    echo "[$(date)] ALERT: High failed login attempts: $FAILED_LOGINS" >> $ALERT_LOG
    echo "High failed logins detected" | mail -s "Security Alert" admin@example.com
fi

# Check for new root user
NEW_ROOT=$(grep "root:" /etc/passwd | grep -v "nologin\|false" | wc -l)
if [ "$NEW_ROOT" -gt 1 ]; then
    echo "[$(date)] ALERT: Multiple root accounts detected" >> $ALERT_LOG
    echo "Multiple root accounts found" | mail -s "Security Alert" admin@example.com
fi

# Check for unusual processes
UNUSUAL_PROCS=$(ps aux | grep -E "cryptominer|xmrig|minerd" | grep -v grep | wc -l)
if [ "$UNUSUAL_PROCS" -gt 0 ]; then
    echo "[$(date)] ALERT: Possible cryptominer detected" >> $ALERT_LOG
    echo "Unusual processes detected" | mail -s "Security Alert" admin@example.com
fi

# Check for large file changes
LARGE_CHANGES=$(find /var/log -type f -size +100M -mtime -1 2>/dev/null | wc -l)
if [ "$LARGE_CHANGES" -gt 0 ]; then
    echo "[$(date)] ALERT: Large log files created" >> $ALERT_LOG
fi

# Check for new scheduled tasks
NEW_CRON=$(find /etc/cron* -mtime -1 2>/dev/null | wc -l)
if [ "$NEW_CRON" -gt 0 ]; then
    echo "[$(date)] ALERT: New cron jobs created" >> $ALERT_LOG
fi

echo "[$(date)] Check completed" >> $LOG_DIR/monitor_$DATE.log
EOF
chmod +x /root/incident-monitor.sh

# Run every 5 minutes
echo "*/5 * * * * /root/incident-monitor.sh" | crontab -
```

### Network Anomaly Detection

```bash
# Create network monitoring script
cat > /root/network-monitor.sh << 'EOF'
#!/bin/bash
# Network Anomaly Detection

LOG_DIR="/var/log/network-monitor"
DATE=$(date +%Y%m%d)

mkdir -p $LOG_DIR

# Monitor unusual outbound connections
echo "=== Outbound Connections ===" > $LOG_DIR/outbound_$DATE.log
netstat -tulpn 2>/dev/null | grep ESTABLISHED >> $LOG_DIR/outbound_$DATE.log

# Check for unusual ports
echo "=== Unusual Port Activity ===" >> $LOG_DIR/outbound_$DATE.log
netstat -tulpn 2>/dev/null | grep -E ":(4444|5555|6666|31337)" >> $LOG_DIR/outbound_$DATE.log || echo "No unusual ports" >> $LOG_DIR/outbound_$DATE.log

# Monitor bandwidth usage
echo "=== Bandwidth Usage ===" >> $LOG_DIR/outbound_$DATE.log
iftop -n -t -i eth0 -b -F "port 4444 or port 31337" 2>/dev/null | head -20 >> $LOG_DIR/outbound_$DATE.log || echo "iftop not available" >> $LOG_DIR/outbound_$DATE.log

# Check for DNS tunneling
echo "=== DNS Queries ===" >> $LOG_DIR/outbound_$DATE.log
grep "dnsmasq" /var/log/syslog 2>/dev/null | tail -100 >> $LOG_DIR/outbound_$DATE.log
EOF
chmod +x /root/network-monitor.sh
```

---

## Containment Strategies

### Immediate Containment

```bash
# Create containment script
cat > /root/contain_incident.sh << 'EOF'
#!/bin/bash
# Incident Containment Script
# ⚠️ CRITICAL: Use with caution - this can disrupt services

INCIDENT_ID="INC-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="/var/log/incident-response/${INCIDENT_ID}.log"
DATE=$(date)

mkdir -p /var/log/incident-response

echo "=== Incident Containment ===" > $LOG_FILE
echo "Incident ID: $INCIDENT_ID" >> $LOG_FILE
echo "Date: $DATE" >> $LOG_FILE
echo "" >> $LOG_FILE

# Step 1: Document current state
echo "=== Current State ===" >> $LOG_FILE
echo "System: $(hostname)" >> $LOG_FILE
echo "Uptime: $(uptime)" >> $LOG_FILE
echo "Network: $(ip addr show)" >> $LOG_FILE
echo "Processes: $(ps aux | wc -l)" >> $LOG_FILE
echo "" >> $LOG_FILE

# Step 2: Isolate affected system
echo "=== Containment Actions ===" >> $LOG_FILE

# Option 1: Disable network interface
echo "1. Disabling network interface..." >> $LOG_FILE
ip link set eth0 down 2>&1 | tee -a $LOG_FILE

# Option 2: Block with firewall
echo "2. Blocking with firewall..." >> $LOG_FILE
pvesh create /firewall/rules \
    --ruleid 9999 \
    --action drop \
    --type host \
    --source $(hostname -I | awk '{print $1}') \
    --name "Incident-Containment-$INCIDENT_ID" 2>&1 | tee -a $LOG_FILE

# Option 3: Stop affected services
echo "3. Stopping affected services..." >> $LOG_FILE
systemctl stop affected-service 2>&1 | tee -a $LOG_FILE

# Step 3: Preserve evidence
echo "=== Evidence Preservation ===" >> $LOG_FILE
echo "Creating system snapshot..." >> $LOG_FILE
qm snapshot $(qm list | grep -E "^[0-9]+" | head -1 | awk '{print $1}') incident-evidence-$INCIDENT_ID 2>&1 | tee -a $LOG_FILE

echo "" >> $LOG_FILE
echo "Containment complete. Incident ID: $INCIDENT_ID" >> $LOG_FILE
echo "Review $LOG_FILE for details" >> $LOG_FILE
EOF
chmod +x /root/contain_incident.sh
```

### Network Isolation

```bash
# Create network isolation script
cat > /root/isolate_network.sh << 'EOF'
#!/bin/bash
# Network Isolation Script

echo "=== Network Isolation ==="
echo "Date: $(date)"
echo ""

# Block all outbound traffic except essential
echo "1. Blocking outbound traffic..."
iptables -F
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -j DROP

# Block all inbound traffic
echo "2. Blocking inbound traffic..."
iptables -A INPUT -j DROP

# Allow loopback
echo "3. Allowing loopback..."
iptables -A INPUT -i lo -j ACCEPT

# Save rules
iptables-save > /root/iptables-backup-$(date +%Y%m%d).rules

echo "Network isolation complete"
echo "To restore: iptables-restore < /root/iptables-backup-$(date +%Y%m%d).rules"
EOF
chmod +x /root/isolate_network.sh
```

---

## Eradication and Recovery

### System Recovery

```bash
# Create recovery script
cat > /root/recover_system.sh << 'EOF'
#!/bin/bash
# System Recovery Script
# ⚠️ PITFALL: Verify backup integrity before restore

INCIDENT_ID="$1"
BACKUP_DIR="/var/lib/vz/dump"
LOG_FILE="/var/log/incident-response/${INCIDENT_ID}-recovery.log"

if [ -z "$INCIDENT_ID" ]; then
    echo "Usage: $0 <incident_id>"
    exit 1
fi

echo "=== System Recovery ===" > $LOG_FILE
echo "Incident ID: $INCIDENT_ID" >> $LOG_FILE
echo "Date: $(date)" >> $LOG_FILE
echo "" >> $LOG_FILE

# Step 1: Find latest clean backup
echo "1. Finding latest backup..." >> $LOG_FILE
LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.vma.zst 2>/dev/null | head -1)
echo "Latest backup: $LATEST_BACKUP" >> $LOG_FILE

# Step 2: Verify backup integrity
echo "2. Verifying backup integrity..." >> $LOG_FILE
if tar -tzf "$LATEST_BACKUP" > /dev/null 2>&1; then
    echo "Backup integrity: OK" >> $LOG_FILE
else
    echo "Backup integrity: FAILED" >> $LOG_FILE
    echo "Cannot proceed with corrupted backup" >> $LOG_FILE
    exit 1
fi

# Step 3: Stop affected VM
echo "3. Stopping affected VM..." >> $LOG_FILE
VMID=$(qm list | grep -E "^[0-9]+" | head -1 | awk '{print $1}')
qm stop $VMID 2>&1 | tee -a $LOG_FILE

# Step 4: Restore from backup
echo "4. Restoring from backup..." >> $LOG_FILE
qmrestore "$LATEST_BACKUP" $VMID --storage local-lvm 2>&1 | tee -a $LOG_FILE

# Step 5: Verify restore
echo "5. Verifying restore..." >> $LOG_FILE
if qm list | grep -q "^$VMID "; then
    echo "Restore successful" >> $LOG_FILE
else
    echo "Restore failed" >> $LOG_FILE
    exit 1
fi

# Step 6: Start VM
echo "6. Starting VM..." >> $LOG_FILE
qm start $VMID 2>&1 | tee -a $LOG_FILE

echo "" >> $LOG_FILE
echo "Recovery complete. Incident ID: $INCIDENT_ID" >> $LOG_FILE
EOF
chmod +x /root/recover_system.sh
```

### Patching and Hardening

```bash
# Create post-recovery hardening script
cat > /root/harden_after_incident.sh << 'EOF'
#!/bin/bash
# Post-Incident Hardening Script

echo "=== Post-Incident Hardening ==="
echo "Date: $(date)"
echo ""

# 1. Update all packages
echo "1. Updating system packages..."
apt update && apt upgrade -y

# 2. Review and rotate credentials
echo "2. Rotating credentials..."
# Generate new SSH key
ssh-keygen -t ed25519 -f /root/.ssh/incident-key -N ""

# 3. Review firewall rules
echo "3. Reviewing firewall rules..."
pvesh get /firewall/rules

# 4. Enable additional security measures
echo "4. Enabling additional security..."
pve-firewall enable

# 5. Review user accounts
echo "5. Reviewing user accounts..."
cat /etc/passwd | grep -v nologin | grep -v false

# 6. Check for backdoors
echo "6. Checking for backdoors..."
find / -name "*.sh" -mtime -7 2>/dev/null
find / -name "*.py" -mtime -7 2>/dev/null

echo ""
echo "Hardening complete"
EOF
chmod +x /root/harden_after_incident.sh
```

---

## Post-Incident Analysis

### Incident Report Template

```bash
# Create incident report template
cat > /root/incident-report-template.md << 'EOF'
# Incident Report

## Incident Information
- **Incident ID**: [INC-YYYYMMDD-XXXX]
- **Date/Time Detected**: [YYYY-MM-DD HH:MM]
- **Date/Time Resolved**: [YYYY-MM-DD HH:MM]
- **Severity**: [Critical/High/Medium/Low]
- **Status**: [Open/Closed]

## Executive Summary
[Brief description of the incident and its impact]

## Timeline
| Time | Event |
|------|-------|
| [HH:MM] | Incident detected |
| [HH:MM] | Initial response initiated |
| [HH:MM] | Containment actions taken |
| [HH:MM] | System recovered |
| [HH:MM] | Incident closed |

## Root Cause Analysis
[Detailed analysis of how the incident occurred]

## Impact Assessment
- **Systems Affected**: [List]
- **Data Affected**: [Description]
- **Downtime**: [Duration]
- **Financial Impact**: [If applicable]

## Actions Taken
1. [Action 1]
2. [Action 2]
3. [Action 3]

## Lessons Learned
- [Lesson 1]
- [Lesson 2]
- [Lesson 3]

## Recommendations
1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

## Appendix
- [Logs, evidence, additional documentation]
EOF
```

### Post-Incident Review

```bash
# Create review script
cat > /root/post_incident_review.sh << 'EOF'
#!/bin/bash
# Post-Incident Review Script

INCIDENT_ID="$1"
REPORT_FILE="/root/incident-reports/${INCIDENT_ID}-review.md"

mkdir -p /root/incident-reports

if [ -z "$INCIDENT_ID" ]; then
    echo "Usage: $0 <incident_id>"
    exit 1
fi

# Generate review
cat > $REPORT_FILE << HTMLEOF
# Post-Incident Review: $INCIDENT_ID

## Review Date: $(date)

## What Went Well
- [ ] Incident was detected promptly
- [ ] Response team was effective
- [ ] Communication was clear
- [ ] Recovery was successful

## What Could Be Improved
- [ ] Detection time
- [ ] Response procedures
- [ ] Documentation
- [ ] Tools and automation

## Action Items
| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| Update monitoring | | | Open |
| Improve procedures | | | Open |
| Add automation | | | Open |

## Metrics
- Detection Time: [Time]
- Containment Time: [Time]
- Recovery Time: [Time]
- Total Downtime: [Time]
HTMLEOF

echo "Review report generated: $REPORT_FILE"
EOF
chmod +x /root/post_incident_review.sh
```

---

## Learning Path Progression

1. **Beginner**: Basic incident detection, simple containment
2. **Intermediate**: Log analysis, evidence collection
3. **Advanced**: Full incident response, recovery procedures
4. **Enterprise**: Automated IR, compliance reporting

## Real-World Job Skill Mapping

- **SRE**: Incident response, recovery procedures
- **Security Engineer**: All sections apply directly
- **DevOps Engineer**: Automation, monitoring
- **IT Manager**: Incident management, reporting

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
