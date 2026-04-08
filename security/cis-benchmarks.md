# CIS Benchmark Compliance Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers CIS (Center for Internet Security) benchmark implementation for Proxmox environments:

- **CIS Benchmark Overview**: Understanding security baselines
- **Proxmox Hardening**: CIS-compliant Proxmox configuration
- **OS Hardening**: Debian/Ubuntu CIS compliance
- **Compliance Automation**: Automated compliance checking
- **Audit Preparation**: Preparing for security audits

## When You Need This

- Compliance requirements (SOC2, HIPAA, PCI-DSS)
- Security certification preparation
- Enterprise security deployments
- Multi-tenant environments
- Regular security audits

## Simpler Alternative

For most homelab users:
- Follow basic security hardening guides
- Keep systems updated
- Use strong passwords and SSH keys
- Enable firewall and monitoring

---

## CIS Benchmark Overview

CIS Benchmarks are consensus-based security configuration guidelines.

### CIS Benchmark Levels

| Level | Description | Use Case |
|------|------|------|
| Level 1 | Basic security | Default for most environments |
| Level 2 | Enhanced security | High-security environments |

### Relevant CIS Benchmarks

| Benchmark | Description |
|------|------|
| CIS Debian 12 | Operating system hardening |
| CIS Ubuntu 22.04 | Operating system hardening |
| CIS Proxmox VE | Hypervisor hardening |
| CIS Docker | Container security |

---

## Proxmox CIS Hardening

### SSH Hardening (CIS 3.1)

```bash
# Configure SSH for CIS compliance
cat > /etc/ssh/sshd_config.d/cis-hardening.conf << 'EOF'
# CIS Benchmark SSH Settings
PermitRootLogin prohibit-password
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
PermitUserEnvironment no
Compression delayed
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
GSSAPIAuthentication no
EOF

# Restart SSH service
systemctl restart sshd

# Verify configuration
sshd -T | grep -E "permitrootlogin|passwordauthentication|usepam"
```

### File System Security (CIS 3.2)

```bash
# Configure file system mount options
cat >> /etc/fstab << 'EOF'
# CIS-compliant mount options
/dev/mapper/pve-root / ext4 defaults,noatime 0 1
/dev/mapper/pve-data /var/lib/vz ext4 defaults,noatime 0 2
EOF

# Remount with new options
mount -o remount,noatime /
mount -o remount,noatime /var/lib/vz

# Set restrictive umask
cat >> /etc/profile << 'EOF'
# CIS-compliant umask
umask 027
EOF

# Verify mount options
mount | grep -E "ext4.*noatime"
```

### Service Hardening (CIS 3.3)

```bash
# Disable unnecessary services
systemctl disable --now postfix
systemctl disable --now cups
systemctl disable --now avahi-daemon

# Enable only required services
systemctl enable --now sshd
systemctl enable --now pvedaemon
systemctl enable --now pveproxy
systemctl enable --now pvestatd

# Check running services
systemctl list-units --type=service --state=running
```

### Network Security (CIS 3.4)

```bash
# Enable SYN flood protection
cat > /etc/sysctl.d/99-syn-flood.conf << 'EOF'
# CIS-compliant network settings
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-syn-flood.conf

# Enable IP forwarding only if needed
# echo "net.ipv4.ip_forward = 0" >> /etc/sysctl.d/99-syn-flood.conf
```

---

## Debian/Ubuntu CIS Hardening

### Account Security (CIS 1.1)

```bash
# Set password expiration policy
cat > /etc/login.defs << 'EOF'
# Password aging settings
PASS_MAX_DAYS 90
PASS_MIN_DAYS 7
PASS_WARN_AGE 14
EOF

# Set default password expiration
chage -M 90 -m 7 -W 14 root

# Configure PAM password policy
cat > /etc/pam.d/common-password << 'EOF'
password    requisite     pam_pwquality.so retry=3 minlen=12 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1
password    sufficient    pam_unix.so sha512 shadow nullok try_first_pass use_authtok
EOF

# Lock inactive accounts after 30 days
cat > /etc/default/useradd << 'EOF'
# Default user settings
INACTIVE=30
EOF
```

### File Permissions (CIS 1.2)

```bash
# Set restrictive permissions on sensitive files
chmod 600 /etc/shadow
chmod 644 /etc/passwd
chmod 600 /etc/gshadow
chmod 644 /etc/group

# Set sticky bit on /tmp
chmod 1777 /tmp

# Verify permissions
ls -la /etc/shadow /etc/passwd /etc/gshadow /etc/group
```

### Kernel Parameters (CIS 1.3)

```bash
# Configure kernel parameters for CIS compliance
cat > /etc/sysctl.d/99-cis-kernel.conf << 'EOF'
# Kernel hardening
kernel.kptr_restrict = 2
kernel.unprivileged_bpf_disabled = 1
kernel.unprivileged_userns_clone = 0
fs.suid_dumpable = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
EOF

# Apply settings
sysctl -p /etc/sysctl.d/99-cis-kernel.conf
```

---

## Compliance Automation

### Automated Compliance Script

```bash
# Create compliance automation script
cat > /root/cis_compliance_check.sh << 'EOF'
#!/bin/bash
# CIS Compliance Check Script
# ⚠️ PITFALL: This is a simplified check - use official tools for production

REPORT_FILE="/var/log/cis-compliance-$(date +%Y%m%d).log"
PASS=0
FAIL=0
WARN=0

echo "=== CIS Compliance Check ===" > $REPORT_FILE
echo "Date: $(date)" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check 1: SSH Root Login
echo "1. SSH Root Login Configuration" >> $REPORT_FILE
if grep -q "PermitRootLogin prohibit-password" /etc/ssh/sshd_config; then
    echo "   ✓ PASS: Root login restricted" >> $REPORT_FILE
    ((PASS++))
else
    echo "   ✗ FAIL: Root login not properly restricted" >> $REPORT_FILE
    ((FAIL++))
fi

# Check 2: SSH Password Authentication
echo "2. SSH Password Authentication" >> $REPORT_FILE
if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
    echo "   ✓ PASS: Password authentication disabled" >> $REPORT_FILE
    ((PASS++))
else
    echo "   ✗ FAIL: Password authentication enabled" >> $REPORT_FILE
    ((FAIL++))
fi

# Check 3: Firewall Status
echo "3. Proxmox Firewall Status" >> $REPORT_FILE
if pve-firewall status 2>/dev/null | grep -q "enabled"; then
    echo "   ✓ PASS: Firewall enabled" >> $REPORT_FILE
    ((PASS++))
else
    echo "   ⚠ WARN: Firewall not enabled" >> $REPORT_FILE
    ((WARN++))
fi

# Check 4: Unnecessary Services
echo "4. Unnecessary Services" >> $REPORT_FILE
UNNECESSARY=$(systemctl list-units --type=service --state=running | grep -E "postfix|cups|avahi" | wc -l)
if [ "$UNNECESSARY" -eq 0 ]; then
    echo "   ✓ PASS: Unnecessary services disabled" >> $REPORT_FILE
    ((PASS++))
else
    echo "   ⚠ WARN: $UNNECESSARY unnecessary services running" >> $REPORT_FILE
    ((WARN++))
fi

# Check 5: Password Policy
echo "5. Password Policy" >> $REPORT_FILE
if grep -q "PASS_MAX_DAYS 90" /etc/login.defs; then
    echo "   ✓ PASS: Password expiration configured" >> $REPORT_FILE
    ((PASS++))
else
    echo "   ✗ FAIL: Password expiration not configured" >> $REPORT_FILE
    ((FAIL++))
fi

# Summary
echo "" >> $REPORT_FILE
echo "=== Summary ===" >> $REPORT_FILE
echo "Passed: $PASS" >> $REPORT_FILE
echo "Failed: $FAIL" >> $REPORT_FILE
echo "Warnings: $WARN" >> $REPORT_FILE

# Send report
if [ "$FAIL" -gt 0 ]; then
    echo "CIS Compliance Check: $FAIL failures found" | mail -s "CIS Compliance Alert" admin@example.com
fi

echo "Report saved to: $REPORT_FILE"
EOF
chmod +x /root/cis_compliance_check.sh

# Schedule weekly compliance checks
echo "0 6 * * 0 /root/cis_compliance_check.sh" | crontab -
```

---

## CIS Benchmark Tools

### Lynis with CIS Checks

```bash
# Install Lynis
apt install -y lynis

# Run with CIS-specific checks
lynis audit system --tests CIS

# View CIS-related findings
lynis audit system --verbose 2>&1 | grep -i "cis\|benchmark"
```

### OpenSCAP Scanner

```bash
# Install OpenSCAP
apt install -y openscap-scanner scap-security-guide

# Download CIS profile
oscap info /usr/share/xml/scap/ssg/content/ssg-deb12ds.xml

# Run scan
oscap xccdf eval \
    --profile xccdf_org.ssgproject.content_profile_cis \
    --results-arf /var/log/scap-report.arf \
    --report /var/log/scap-report.html \
    /usr/share/xml/scap/ssg/content/ssg-deb12ds.xml
```

---

## Audit Preparation

### Pre-Audit Checklist

```bash
# Create audit preparation script
cat > /root/audit_prep.sh << 'EOF'
#!/bin/bash
# Pre-Audit Preparation Script

echo "=== Pre-Audit Preparation ==="
echo "Date: $(date)"
echo ""

# 1. Document all systems
echo "1. System Documentation"
hostname > /tmp/system-doc.txt
pveversion -v >> /tmp/system-doc.txt
pvesm status >> /tmp/system-doc.txt

# 2. Review security logs
echo "2. Security Log Review"
echo "Recent authentication failures:"
grep "Failed password" /var/log/auth.log | tail -10

echo "Recent sudo usage:"
grep "sudo" /var/log/auth.log | tail -10

# 3. Check for pending updates
echo "3. Pending Updates"
apt list --upgradable 2>/dev/null | grep "upgradable"

# 4. Verify backup status
echo "4. Backup Status"
ls -lt /var/lib/vz/dump/*.vma.zst 2>/dev/null | head -5

# 5. Document changes
echo "5. Recent Changes"
echo "Last 10 configuration changes:"
grep -l "modified" /etc/* 2>/dev/null | head -10

echo ""
echo "Documentation saved to: /tmp/system-doc.txt"
EOF
chmod +x /root/audit_prep.sh

# Run before audit
/root/audit_prep.sh
```

---

## Compliance Reporting

### Generate Compliance Report

```bash
# Create compliance report generator
cat > /root/generate_compliance_report.sh << 'EOF'
#!/bin/bash
# Generate CIS Compliance Report

REPORT_DIR="/var/log/compliance-reports"
DATE=$(date +%Y%m%d)
mkdir -p $REPORT_DIR

# Generate report
cat > $REPORT_DIR/cis_report_$DATE.md << 'HTMLEOF'
# CIS Compliance Report

## Report Information
- **Generated**: $(date)
- **System**: $(hostname)
- **Proxmox Version**: $(pveversion -v)

## Compliance Summary

| Category | Status | Details |
|------|------|------|
| SSH Hardening | $(grep -q "PermitRootLogin prohibit-password" /etc/ssh/sshd_config && echo "✓ Compliant" || echo "✗ Non-Compliant") | Root login restricted |
| Password Policy | $(grep -q "PASS_MAX_DAYS 90" /etc/login.defs && echo "✓ Compliant" || echo "✗ Non-Compliant") | 90-day expiration |
| Firewall | $(pve-firewall status 2>/dev/null | grep -q "enabled" && echo "✓ Compliant" || echo "✗ Non-Compliant") | Proxmox firewall |
| File Permissions | ✓ Compliant | /etc/shadow: 600 |
| Kernel Parameters | ✓ Compliant | SYN cookies enabled |

## Recommendations

1. Enable 2FA for web interface
2. Configure backup encryption
3. Set up automated security monitoring
4. Schedule regular compliance checks

## Next Audit Date

$(date -d "+30 days" '+%Y-%m-%d')
HTMLEOF

echo "Report generated: $REPORT_DIR/cis_report_$DATE.md"
EOF
chmod +x /root/generate_compliance_report.sh

# Generate report
/root/generate_compliance_report.sh
```

---

## Learning Path Progression

1. **Beginner**: Basic SSH hardening, file permissions
2. **Intermediate**: Service hardening, kernel parameters
3. **Advanced**: Automated compliance, audit preparation
4. **Enterprise**: Full CIS implementation, continuous compliance

## Real-World Job Skill Mapping

- **Security Engineer**: All sections apply directly
- **Compliance Officer**: CIS benchmarks, audit preparation
- **DevOps Engineer**: Compliance automation, reporting
- **SRE**: Security hardening, monitoring

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
