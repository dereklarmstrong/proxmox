# Zero Trust Architecture Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers Zero Trust Architecture implementation for Proxmox environments:

- **Zero Trust Principles**: Core concepts and philosophy
- **Network Segmentation**: Micro-segmentation strategies
- **Identity and Access Management**: Strong authentication
- **Continuous Verification**: Ongoing security validation
- **Least Privilege Access**: Minimal permission models

## When You Need This

- Multi-tenant environments
- High-security requirements
- Compliance with strict regulations
- Protection against lateral movement
- Advanced threat mitigation

## Simpler Alternative

For most homelab users:
- Basic network segmentation
- Strong passwords and 2FA
- Regular security updates
- Firewall rules

---

## Zero Trust Principles

### Core Principles

| Principle | Description | Implementation |
|------|------|------|
| Never Trust | Verify every request | All traffic authenticated |
| Always Verify | Continuous validation | MFA, device checks |
| Least Privilege | Minimal access needed | Role-based permissions |
| Micro-Segmentation | Isolate workloads | VLANs, firewalls |
| Assume Breach | Plan for compromise | Monitoring, detection |

### Zero Trust vs Traditional Security

```
┌─────────────────────────────────────────────────────────────────┐
│                    Traditional Security                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Perimeter Firewall                     │   │
│  │  ┌───────────────────────────────────────────────────┐  │   │
│  │  │              Internal Network (Trusted)           │  │   │
│  │  │  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐             │  │   │
│  │  │  │ VM  │  │ VM  │  │ VM  │  │ VM  │             │  │   │
│  │  │  │ 1   │  │ 2   │  │ 3   │  │ 4   │             │  │   │
│  │  │  └─────┘  └─────┘  └─────┘  └─────┘             │  │   │
│  │  └───────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  "Trust but verify" - Once inside, trust the network           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Zero Trust Security                          │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Identity & Access Management               │   │
│  │  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐          │   │
│  │  │ VM  │  │ VM  │  │ VM  │  │ VM  │  │ VM  │          │   │
│  │  │ 1   │  │ 2   │  │ 3   │  │ 4   │  │ 5   │          │   │
│  │  └──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘          │   │
│  │     │        │        │        │        │              │   │
│  │  ┌──▼────────▼────────▼────────▼────────▼──┐          │   │
│  │  │         Micro-Segmentation              │          │   │
│  │  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │          │   │
│  │  │  │Fire │ │Fire │ │Fire │ │Fire │       │          │   │
│  │  │  │wall │ │wall │ │wall │ │wall │       │          │   │
│  │  │  └─────┘ └─────┘ └─────┘ └─────┘       │          │   │
│  │  └─────────────────────────────────────────┘          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  "Never trust, always verify" - Every request authenticated    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Network Segmentation

### Micro-Segmentation Design

```bash
# Create VLAN-aware bridge
cat > /etc/network/interfaces.d/vmbr0 << 'EOF'
auto vmbr0
iface vmbr0 inet manual
    vlan_aware yes
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-maxwait 0
EOF

# Restart networking
systemctl restart networking

# Verify VLAN-aware bridge
brctl show vmbr0
```

### VLAN Configuration for Zero Trust

```bash
# Create VLAN configuration
cat > /root/zero-trust-vlans.conf << 'EOF'
# Zero Trust VLAN Configuration
# Management VLAN
VLAN_MGMT=10
VLAN_MGMT_SUBNET=192.168.10.0/24
VLAN_MGMT_GATEWAY=192.168.10.1

# VM VLAN
VLAN_VM=20
VLAN_VM_SUBNET=192.168.20.0/24
VLAN_VM_GATEWAY=192.168.20.1

# Container VLAN
VLAN_CONTAINER=30
VLAN_CONTAINER_SUBNET=192.168.30.0/24
VLAN_CONTAINER_GATEWAY=192.168.30.1

# Database VLAN
VLAN_DATABASE=40
VLAN_DATABASE_SUBNET=192.168.40.0/24
VLAN_DATABASE_GATEWAY=192.168.40.1

# DMZ VLAN
VLAN_DMZ=50
VLAN_DMZ_SUBNET=192.168.50.0/24
VLAN_DMZ_GATEWAY=192.168.50.1
EOF

# Source VLAN configuration
source /root/zero-trust-vlans.conf

# Create VMs with VLAN tagging
qm create 100 --name webserver --memory 2048 --cores 2 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-100-disk-0,size=20G \
  --net0 vlan=${VLAN_VM},bridge=vmbr0,firewall=1

qm create 200 --name database --memory 4096 --cores 4 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-200-disk-0,size=50G \
  --net0 vlan=${VLAN_DATABASE},bridge=vmbr0,firewall=1

qm create 300 --name container-host --memory 2048 --cores 2 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-300-disk-0,size=20G \
  --net0 vlan=${VLAN_CONTAINER},bridge=vmbr0,firewall=1
```

### Firewall Rules for Zero Trust

```bash
# Create Zero Trust firewall rules
# Rule 1: Allow management access only from management VLAN
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --source 192.168.10.0/24 \
  --dest-port 22,8006 \
  --proto tcp \
  --name "Allow-Mgmt-Access"

# Rule 2: Allow web servers to access database only on specific port
pvesh create /firewall/rules \
  --ruleid 200 \
  --action accept \
  --source 192.168.20.0/24 \
  --dest 192.168.40.0/24 \
  --dest-port 3306 \
  --proto tcp \
  --name "Allow-Web-to-DB"

# Rule 3: Block all inter-VLAN traffic by default
pvesh create /firewall/rules \
  --ruleid 999 \
  --action drop \
  --name "Default-Drop-All"

# Rule 4: Allow DNS from all VLANs
pvesh create /firewall/rules \
  --ruleid 101 \
  --action accept \
  --dest-port 53 \
  --proto udp,tcp \
  --name "Allow-DNS"

# Rule 5: Allow NTP from all VLANs
pvesh create /firewall/rules \
  --ruleid 102 \
  --action accept \
  --dest-port 123 \
  --proto udp \
  --name "Allow-NTP"
```

---

## Identity and Access Management

### Strong Authentication Setup

```bash
# Enable 2FA for Proxmox web interface
apt install -y libpam-google-authenticator

# Configure PAM for 2FA
cat >> /etc/pam.d/pve << 'EOF'
auth required pam_google_authenticator.so
EOF

# Configure SSH for 2FA
cat >> /etc/ssh/sshd_config << 'EOF'
ChallengeResponseAuthentication yes
AuthenticationMethods publickey,keyboard-interactive
EOF

# Restart services
systemctl restart sshd
systemctl restart pvedaemon

# Generate 2FA for users
google-authenticator -q -t -d -f
```

### Role-Based Access Control (RBAC)

```bash
# Create custom roles for least privilege
# Role 1: Read-only auditor
pvesh create /access/roles \
  --roleid Auditor \
  --privs "PVEAuditor"

# Role 2: VM operator (can start/stop VMs only)
pvesh create /access/roles \
  --roleid VMOperator \
  --privs "PVEVMUser,PVEVMMonitor"

# Role 3: Backup operator
pvesh create /access/roles \
  --roleid BackupOperator \
  --privs "PVEAuditor,Datastore.Audit,Pool.Allocate"

# Assign roles to users
pvesh create /access/acl \
  --userid operator@pve \
  --path / \
  --roleid VMOperator

pvesh create /access/acl \
  --userid auditor@pve \
  --path / \
  --roleid Auditor
```

### API Token Management

```bash
# Create API tokens with least privilege
# Token for VM operations only
pvesh create /access/token \
  --userid vm-operator@pve \
  --description "VM Operations Token" \
  --privsep 0 \
  --permissions "PVEVMUser,PVEVMMonitor"

# Token for backup operations only
pvesh create /access/token \
  --userid backup-operator@pve \
  --description "Backup Operations Token" \
  --privsep 0 \
  --permissions "PVEAuditor,Datastore.Audit"

# List all tokens
pvesh get /access/tokens

# Revoke token
pvesh delete /access/token --tokenid <token-id>
```

---

## Continuous Verification

### Health Check Script

```bash
# Create continuous verification script
cat > /root/zero-trust-verify.sh << 'EOF'
#!/bin/bash
# Zero Trust Continuous Verification
# ⚠️ PITFALL: Run frequently for real-time security

LOG_FILE="/var/log/zero-trust-verify.log"
ALERT_EMAIL="admin@example.com"
DATE=$(date +%Y%m%d-%H%M%S)

echo "[$(date)] Verification started" >> $LOG_FILE

# Check 1: Verify firewall is enabled
echo "1. Checking firewall status..."
if pve-firewall status 2>/dev/null | grep -q "enabled"; then
    echo "   ✓ Firewall enabled" >> $LOG_FILE
else
    echo "   ✗ Firewall disabled - ALERT!" >> $LOG_FILE
    echo "Firewall disabled" | mail -s "Zero Trust Alert" $ALERT_EMAIL
fi

# Check 2: Verify no unauthorized users
echo "2. Checking for unauthorized users..."
UNUSUAL_USERS=$(grep -E "/bin/bash|/bin/sh" /etc/passwd | grep -v "nobody\|sync\|shutdown\|halt" | wc -l)
if [ "$UNUSUAL_USERS" -lt 3 ]; then
    echo "   ✓ No unauthorized users" >> $LOG_FILE
else
    echo "   ✗ Possible unauthorized users - ALERT!" >> $LOG_FILE
    grep -E "/bin/bash|/bin/sh" /etc/passwd | grep -v "nobody\|sync\|shutdown\|halt" >> $LOG_FILE
fi

# Check 3: Verify SSH configuration
echo "3. Checking SSH configuration..."
if grep -q "PermitRootLogin prohibit-password" /etc/ssh/sshd_config; then
    echo "   ✓ SSH root login restricted" >> $LOG_FILE
else
    echo "   ✗ SSH root login not restricted" >> $LOG_FILE
fi

if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
    echo "   ✓ SSH password auth disabled" >> $LOG_FILE
else
    echo "   ✗ SSH password auth enabled" >> $LOG_FILE
fi

# Check 4: Verify VLAN segmentation
echo "4. Checking VLAN segmentation..."
VLAN_COUNT=$(cat /sys/class/net/vmbr0/bridge/vids 2>/dev/null | tr -cd ',' | wc -c)
if [ "$VLAN_COUNT" -gt 2 ]; then
    echo "   ✓ VLAN segmentation active" >> $LOG_FILE
else
    echo "   ⚠ Limited VLAN segmentation" >> $LOG_FILE
fi

# Check 5: Verify firewall rules
echo "5. Checking firewall rules..."
RULE_COUNT=$(pvesh get /firewall/rules 2>/dev/null | grep -c "ruleid")
if [ "$RULE_COUNT" -gt 5 ]; then
    echo "   ✓ Firewall rules configured" >> $LOG_FILE
else
    echo "   ⚠ Limited firewall rules" >> $LOG_FILE
fi

echo "[$(date)] Verification completed" >> $LOG_FILE
EOF
chmod +x /root/zero-trust-verify.sh

# Run every 5 minutes
echo "*/5 * * * * /root/zero-trust-verify.sh" | crontab -
```

### Anomaly Detection

```bash
# Create anomaly detection script
cat > /root/anomaly-detect.sh << 'EOF'
#!/bin/bash
# Zero Trust Anomaly Detection

LOG_FILE="/var/log/anomaly-detection.log"
DATE=$(date +%Y%m%d)

# Monitor for unusual network patterns
echo "[$(date)] Network Anomaly Check" >> $LOG_FILE

# Check for unusual outbound connections
UNUSUAL_OUTBOUND=$(netstat -tulpn 2>/dev/null | grep ESTABLISHED | grep -v "192.168" | wc -l)
if [ "$UNUSUAL_OUTBOUND" -gt 5 ]; then
    echo "ALERT: Unusual outbound connections: $UNUSUAL_OUTBOUND" >> $LOG_FILE
fi

# Check for unusual inbound connections
UNUSUAL_INBOUND=$(netstat -tulpn 2>/dev/null | grep LISTEN | wc -l)
if [ "$UNUSUAL_INBOUND" -gt 10 ]; then
    echo "ALERT: Too many listening ports: $UNUSUAL_INBOUND" >> $LOG_FILE
fi

# Check for unusual process activity
UNUSUAL_PROCS=$(ps aux | grep -E "nc|netcat|ncat|socat" | grep -v grep | wc -l)
if [ "$UNUSUAL_PROCS" -gt 0 ]; then
    echo "ALERT: Suspicious network tools running: $UNUSUAL_PROCS" >> $LOG_FILE
fi

# Check for unusual file access
UNUSUAL_FILES=$(find /etc -type f -mtime -1 2>/dev/null | wc -l)
if [ "$UNUSUAL_FILES" -gt 10 ]; then
    echo "ALERT: Many config files modified: $UNUSUAL_FILES" >> $LOG_FILE
fi

echo "[$(date)] Anomaly check completed" >> $LOG_FILE
EOF
chmod +x /root/anomaly-detect.sh

# Run every 15 minutes
echo "*/15 * * * * /root/anomaly-detect.sh" | crontab -
```

---

## Least Privilege Implementation

### Service Account Configuration

```bash
# Create dedicated service accounts
# Web server service account
useradd -r -s /usr/sbin/nologin -d /var/www webserver

# Database service account
useradd -r -s /usr/sbin/nologin -d /var/lib/mysql mysql

# Backup service account
useradd -r -s /usr/sbin/nologin -d /var/backup backup

# Set appropriate permissions
chown -R webserver:webserver /var/www
chown -R mysql:mysql /var/lib/mysql
chown -R backup:backup /var/backup

# Configure sudo for specific commands only
cat > /etc/sudoers.d/backup-user << 'EOF'
# Backup user - can only run backup commands
backup ALL=(ALL) NOPASSWD: /usr/bin/vzdump, /usr/bin/pvesh
EOF

chmod 440 /etc/sudoers.d/backup-user
```

### Container Security

```bash
# Create unprivileged containers for least privilege
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 \
  -cores 2 \
  -memory 1024 \
  -swap 512 \
  -net0 name=eth0,bridge=vmbr0,firewall=1,vtag=30 \
  -unprivileged 1 \
  -rootfs local-lvm:100,size=10G

# Configure container limits
pct set 100 --cpulimit 100 --cpuunits 256

# Enable container firewall
pct set 100 --firewall 1

# Create container-specific firewall rules
pvesh create /firewall/rules \
  --ruleid 300 \
  --action accept \
  --type guest \
  --guest 100 \
  --dest-port 80,443 \
  --proto tcp \
  --name "Allow-Web-Container"

pvesh create /firewall/rules \
  --ruleid 999 \
  --action drop \
  --type guest \
  --guest 100 \
  --name "Drop-All-Container"
```

### VM Resource Isolation

```bash
# Create VM with resource limits
qm create 200 --name isolated-vm --memory 2048 --cores 2 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-200-disk-0,size=20G \
  --net0 vlan=20,bridge=vmbr0,firewall=1

# Set CPU limit
qm set 200 --cpulimit 100

# Set CPU units
qm set 200 --cpuunits 256

# Disable memory ballooning
qm set 200 --balloon 0

# Enable VM firewall
qm set 200 --firewall 1

# Configure VM-specific firewall rules
pvesh create /firewall/rules \
  --ruleid 400 \
  --action accept \
  --type guest \
  --guest 200 \
  --dest-port 22 \
  --proto tcp \
  --source 192.168.10.0/24 \
  --name "Allow-SSH-Management"

pvesh create /firewall/rules \
  --ruleid 999 \
  --action drop \
  --type guest \
  --guest 200 \
  --name "Drop-All-VM"
```

---

## Zero Trust Monitoring

### Centralized Logging

```bash
# Configure centralized logging
cat > /etc/rsyslog.d/zero-trust.conf << 'EOF'
# Forward security logs to central server
module(load="imudp")
input(type="imudp" port="514")

# Forward auth logs
:msg, contains, "sshd" @@192.168.10.1:514
:msg, contains, "sudo" @@192.168.10.1:514
:msg, contains, "pam" @@192.168.10.1:514

# Forward system logs
*.* @@192.168.10.1:514
EOF

# Restart rsyslog
systemctl restart rsyslog
```

### Security Dashboard

```bash
# Create Zero Trust dashboard
cat > /root/zero-trust-dashboard.sh << 'EOF'
#!/bin/bash
# Zero Trust Security Dashboard

echo "========================================"
echo "   ZERO TRUST SECURITY DASHBOARD"
echo "   $(date)"
echo "========================================"
echo ""

# Network Segmentation
echo "=== Network Segmentation =="
echo "VLANs configured: $(cat /sys/class/net/vmbr0/bridge/vids 2>/dev/null | tr -cd ',' | wc -c)"
echo "Firewall enabled: $(pve-firewall status 2>/dev/null | grep -o 'enabled\|disabled' || echo 'unknown')"
echo ""

# Access Control
echo "=== Access Control =="
echo "Active users: $(grep -c '@pve' /etc/pve/users 2>/dev/null || echo '0')"
echo "API tokens: $(pvesh get /access/tokens 2>/dev/null | grep -c 'tokenid' || echo '0')"
echo "Custom roles: $(pvesh get /access/roles 2>/dev/null | grep -c 'roleid' || echo '0')"
echo ""

# Security Events
echo "=== Security Events (24h) =="
echo "Failed logins: $(grep -c 'Failed password' /var/log/auth.log 2>/dev/null || echo '0')"
echo "Successful logins: $(grep -c 'Accepted' /var/log/auth.log 2>/dev/null || echo '0')"
echo "Sudo usage: $(grep -c 'sudo' /var/log/auth.log 2>/dev/null || echo '0')"
echo ""

# Firewall Rules
echo "=== Firewall Rules =="
echo "Total rules: $(pvesh get /firewall/rules 2>/dev/null | grep -c 'ruleid' || echo '0')"
echo "Accept rules: $(pvesh get /firewall/rules 2>/dev/null | grep -c 'action: accept' || echo '0')"
echo "Drop rules: $(pvesh get /firewall/rules 2>/dev/null | grep -c 'action: drop' || echo '0')"
echo ""

echo "========================================"
EOF
chmod +x /root/zero-trust-dashboard.sh

# Run dashboard
/root/zero-trust-dashboard.sh
```

---

## Learning Path Progression

1. **Beginner**: Basic network segmentation, strong authentication
2. **Intermediate**: RBAC, API token management, continuous verification
3. **Advanced**: Micro-segmentation, anomaly detection, centralized logging
4. **Enterprise**: Full Zero Trust implementation, automated response

## Real-World Job Skill Mapping

- **Security Engineer**: All sections apply directly
- **DevOps Engineer**: RBAC, API management, automation
- **SRE**: Monitoring, anomaly detection, incident response
- **Cloud Engineer**: Network segmentation, identity management

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
