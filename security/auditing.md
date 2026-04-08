# Security Auditing Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers security auditing tools and techniques for Proxmox environments:

- **Lynis Auditing**: System security assessment
- **Auditd Configuration**: System call auditing
- **Log Analysis**: Security event monitoring
- **Vulnerability Scanning**: Identifying security gaps
- **Compliance Checking**: Meeting security standards

## When You Need This

- Regular security assessments
- Compliance requirements (SOC2, HIPAA, PCI-DSS)
- Before and after security hardening
- Incident investigation
- Security certification preparation

## Simpler Alternative

For most homelab users:
- Run Lynis monthly
- Check system logs weekly
- Review security updates regularly
- Test critical services periodically

---

## Lynis Security Auditing

Lynis performs comprehensive system security audits.

### Installation

```bash
# Install Lynis
apt update
apt install -y lynis

# Update definitions
lynis update info

# Run system audit
lynis audit system

# Run with verbose output
lynis audit system --verbose

# Generate HTML report
lynis audit system --html-report /root/lynis-report.html
```

### Interpreting Lynis Results

```bash
# Check audit results
cat /var/log/lynis.log

# View specific findings
lynis audit system --show-scores

# Common findings to address:
# - SSH configuration issues
# - Missing security updates
# - Weak password policies
# - Unnecessary services running
```

### Scheduled Auditing

```bash
# Create audit script
cat > /root/security_audit.sh << 'EOF'
#!/bin/bash
# Security Audit Script
# ⚠️ PITFALL: Audits can be resource-intensive

REPORT_DIR="/var/log/security-audits"
DATE=$(date +%Y%m%d)

mkdir -p $REPORT_DIR

# Run Lynis audit
lynis audit system --quiet >> $REPORT_DIR/audit_$DATE.log 2>&1

# Generate summary
echo "=== Security Audit Summary ===" > $REPORT_DIR/summary_$DATE.txt
echo "Date: $(date)" >> $REPORT_DIR/summary_$DATE.txt
echo "" >> $REPORT_DIR/summary_$DATE.txt

# Count critical issues
CRITICAL=$(grep -c "CRITICAL" $REPORT_DIR/audit_$DATE.log 2>/dev/null || echo "0")
WARNING=$(grep -c "WARNING" $REPORT_DIR/audit_$DATE.log 2>/dev/null || echo "0")

echo "Critical Issues: $CRITICAL" >> $REPORT_DIR/summary_$DATE.txt
echo "Warnings: $WARNING" >> $REPORT_DIR/summary_$DATE.txt

# Send alert if critical issues found
if [ "$CRITICAL" -gt 0 ]; then
    echo "ALERT: $CRITICAL critical security issues found" | mail -s "Security Audit Alert" admin@example.com
fi
EOF
chmod +x /root/security_audit.sh

# Schedule monthly audit
echo "0 6 1 * * /root/security_audit.sh" | crontab -
```

> **⚠️ PITFALL**: Don't run audits during peak hours - they can impact performance.

---

## Auditd System Auditing

Auditd provides kernel-level system call auditing.

### Installation and Configuration

```bash
# Install auditd
apt install -y auditd audispd-plugins

# Start and enable service
systemctl enable auditd
systemctl start auditd

# Check auditd status
systemctl status auditd

# View audit logs
ausearch -m SYSCALL -ts today
```

### Common Audit Rules

```bash
# Create audit rules file
cat > /etc/audit/rules.d/security.rules << 'EOF'
# Monitor file access
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege

# Monitor failed login attempts
-a always,exit -F arch=b64 -S execve -k execution

# Monitor network changes
-w /etc/network/ -p wa -k network
-w /etc/iptables/ -p wa -k firewall

# Monitor privilege escalation
-a always,exit -F arch=b64 -S setuid -S setgid -k priv_change
EOF

# Reload audit rules
augenrules --load

# View active rules
auditctl -l
```

### Audit Log Analysis

```bash
# Search for specific events
ausearch -k identity -ts today
ausearch -k privilege -ts today

# Generate audit report
aureport -au -i > /var/log/audit/user-report.txt
aureport -f > /var/log/audit/file-report.txt
aureport -i > /var/log/audit/interval-report.txt

# Monitor in real-time
auditctl -w /etc/shadow -p wa -k shadow
tail -f /var/log/audit/audit.log
```

---

## Log Analysis

Centralized log analysis for security monitoring.

### Log Collection

```bash
# Install log tools
apt install -y logwatch rsyslog

# Configure logwatch for daily reports
cat > /etc/logwatch/conf/logwatch.conf << 'EOF'
Detail = Low
MailTo = admin@example.com
Range = yesterday
Output = mail
EOF

# Run logwatch
logwatch --detail High --service All
```

### Security Log Monitoring

```bash
# Monitor authentication logs
tail -f /var/log/auth.log

# Search for failed logins
grep "Failed password" /var/log/auth.log | tail -20

# Check for sudo usage
grep "sudo" /var/log/auth.log | tail -20

# Monitor SSH connections
grep "sshd" /var/log/auth.log | grep "Accepted" | tail -20
```

### Log Rotation

```bash
# Configure log rotation
cat > /etc/logrotate.d/auth << 'EOF'
/var/log/auth.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
EOF

# Test log rotation
logrotate -d /etc/logrotate.conf
```

---

## Vulnerability Scanning

Identify security vulnerabilities in your system.

### OpenVAS Scanner

```bash
# Install OpenVAS (requires separate installation)
# Follow OpenVAS installation guide for your distribution

# Run vulnerability scan
gvmd --host=127.0.0.1 --port=9390 --username=admin --password=password

# View scan results
gvmd --host=127.0.0.1 --port=9390 --username=admin --password=password \
    --get_vts --format=xml
```

### Nikto Web Scanner

```bash
# Install Nikto
apt install -y nikto

# Scan web server
nikto -h http://your-server.com

# Scan with specific options
nikto -h http://your-server.com -Format xml -o scan-results.xml
```

### Nmap Security Scan

```bash
# Install Nmap
apt install -y nmap

# Basic scan
nmap -sV your-server.com

# Vulnerability scan
nmap --script=vuln your-server.com

# Security-focused scan
nmap -sV -sC --script=ssh-enum-algos,ssh-hostkey your-server.com
```

---

## Compliance Checking

Verify compliance with security standards.

### CIS Benchmark Checklist

```bash
# Install CIS benchmark tools
apt install -y cis-audit

# Run CIS checks
cis-audit ssh
cis-audit sudo
cis-audit file-permissions

# Generate compliance report
cis-audit --report > cis-compliance-report.txt
```

### Custom Compliance Script

```bash
# Create compliance check script
cat > /root/compliance_check.sh << 'EOF'
#!/bin/bash
# Compliance Check Script

echo "=== Security Compliance Check ==="
echo "Date: $(date)"
echo ""

# Check 1: SSH configuration
echo "1. SSH Configuration:"
if grep -q "PermitRootLogin prohibit-password" /etc/ssh/sshd_config; then
    echo "   ✓ Root login restricted"
else
    echo "   ✗ Root login not properly restricted"
fi

if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
    echo "   ✓ Password authentication disabled"
else
    echo "   ✗ Password authentication enabled"
fi

# Check 2: Firewall status
echo ""
echo "2. Firewall Status:"
if pve-firewall status | grep -q "enabled"; then
    echo "   ✓ Proxmox firewall enabled"
else
    echo "   ✗ Proxmox firewall disabled"
fi

# Check 3: Security updates
echo ""
echo "3. Security Updates:"
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c "upgradable")
if [ "$UPDATES" -eq 0 ]; then
    echo "   ✓ System is up to date"
else
    echo "   ⚠ $UPDATES updates available"
fi

# Check 4: Failed login attempts
echo ""
echo "4. Failed Login Attempts:"
FAILED=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
if [ "$FAILED" -lt 10 ]; then
    echo "   ✓ Low failed login attempts: $FAILED"
else
    echo "   ⚠ High failed login attempts: $FAILED"
fi

echo ""
echo "=== Compliance Check Complete ==="
EOF
chmod +x /root/compliance_check.sh

# Run compliance check
/root/compliance_check.sh
```

---

## Security Monitoring Dashboard

Create a security monitoring dashboard.

```bash
# Create monitoring script
cat > /root/security_dashboard.sh << 'EOF'
#!/bin/bash
# Security Dashboard

echo "========================================"
echo "     SECURITY DASHBOARD"
echo "     $(date)"
echo "========================================"
echo ""

# System Info
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime)"
echo "Kernel: $(uname -r)"
echo ""

# Security Status
echo "=== Security Status ==="
echo "Firewall: $(pve-firewall status 2>/dev/null | grep -o 'enabled\|disabled' || echo 'unknown')"
echo "SSH Port: $(grep -E '^Port' /etc/ssh/sshd_config | awk '{print $2}')"
echo "Failed Logins (24h): $(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")"
echo ""

# Disk Usage
echo "=== Disk Usage ==="
df -h / | tail -1 | awk '{print "Root Partition: "$5" used"}'
echo ""

# Running Services
echo "=== Critical Services ==="
systemctl is-active pvedaemon
systemctl is-active pveproxy
systemctl is-active pvestatd
echo ""

echo "========================================"
EOF
chmod +x /root/security_dashboard.sh

# Add to crontab for hourly checks
echo "0 * * * * /root/security_dashboard.sh >> /var/log/security_dashboard.log 2>&1" | crontab -
```

---

## Learning Path Progression

1. **Beginner**: Run Lynis audits, check logs
2. **Intermediate**: Configure auditd, set up log analysis
3. **Advanced**: Vulnerability scanning, compliance checking
4. **Enterprise**: Automated security monitoring, SIEM integration

## Real-World Job Skill Mapping

- **Security Engineer**: All sections apply directly
- **SRE**: Log analysis, monitoring
- **DevOps Engineer**: Compliance checking, automation
- **Compliance Officer**: Audit reporting, documentation

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
