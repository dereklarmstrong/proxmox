# Security Hardening Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers enterprise security practices for Proxmox:

- **CIS Benchmark Compliance**: Understanding security baselines and hardening standards
- **Zero Trust Architecture**: Principles of never trusting, always verifying
- **Incident Response Preparation**: Building systems ready for security events
- **Security Auditing and Monitoring**: Tools and techniques for continuous security assessment
- **SSH Hardening**: Securing remote access
- **TLS Certificate Management**: Proper certificate generation and configuration
- **Firewall Configuration**: Network-level security controls

## When You Need This

- Multi-tenant environments where isolation is critical
- Compliance requirements (SOC2, HIPAA, PCI-DSS)
- Systems exposed to untrusted networks
- Environments handling sensitive data
- When security audits are required

## Simpler Alternative

For most homelab users:
- Keep SSH on default port 22 (unless you're a target)
- Use password authentication during initial setup
- Enable the Proxmox firewall but start with default rules
- Use self-signed certificates for internal services
- Run security audits occasionally, not continuously

---

## SSH Hardening

Hardening SSH prevents unauthorized access to your system.

```bash
# Harden SSH configuration
# ⚠️ PITFALL: Always keep an active session when making changes
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
systemctl restart sshd
```

---

## 2FA for Web Interface

Two-factor authentication adds an extra layer of security to the Proxmox web interface.

```bash
# Install Google Authenticator PAM module
apt install libpam-google-authenticator

# Enable PAM Google Authenticator
pam-auth-update --enable pam_google_authenticator

# Configure PAM
nano /etc/pam.d/common-auth
# Add: auth required pam_google_authenticator.so

# Configure SSH for 2FA
nano /etc/pam.d/sshd
# Add: auth required pam_google_authenticator.so

# Configure SSHD
nano /etc/ssh/sshd_config
# Add: ChallengeResponseAuthentication yes
# Add: AuthenticationMethods publickey,keyboard-interactive

systemctl restart sshd
```

> **⚠️ Critical**: Backup your authenticator keys before enabling 2FA.

---

## Proxmox Firewall Configuration

Enable and configure the Proxmox firewall for network security.

```bash
# Enable firewall at node level
pve-firewall enable

# Enable firewall at cluster level
pvesh create /firewall/options --enabled 1

# Create firewall rules
pvesh create /firewall/rules --ruleid 100 --action accept --type guest --name "Allow-VM-Access"
pvesh create /firewall/rules --ruleid 101 --action drop --type guest

# View firewall status
pve-firewall status
```

> **⚠️ PITFALL**: Test rules in logging mode first to avoid blocking legitimate traffic.

---

## TLS Certificate Hardening

Generate strong TLS certificates for the Proxmox web interface.

```bash
# Generate self-signed cert with strong settings (RSA 4096-bit)
openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
  -keyout /etc/pve/pve-ssl.key \
  -out /etc/pve/pve-ssl.crt \
  -subj "/CN=your-proxmox"

# Generate ECDSA certificate (more modern, smaller)
openssl ecparam -genkey -name prime256v1 -out /etc/pve/pve-ssl.key
openssl req -new -x509 -days 365 -key /etc/pve/pve-ssl.key \
  -out /etc/pve/pve-ssl.crt \
  -subj "/CN=your-proxmox"

# Update cipher suites (strong ciphers only)
echo "SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384" > /etc/default/pveproxy

systemctl restart pveproxy
```

> **⚠️ PITFALL**: Set up monitoring for certificate expiration.

---

## Secret Management

Proper secret management prevents credential leaks and unauthorized access.

### Never Commit Secrets to Version Control

- Use `config.example.sh` as a template; never commit `config.sh` or `config.k8s.sh`
- Store API tokens, passwords, and keys in environment variables or a secrets manager
- The `.gitignore` file blocks common secret file patterns

### Pre-Commit Secret Scanning

A pre-commit hook (`.husky/pre-commit`) is included to detect secrets before they are committed. It scans for:

- Private keys (RSA, EC, DSA, OPENSSH)
- Cloud provider keys (AWS, GCP, Azure)
- GitHub/GitLab tokens
- Proxmox API tokens
- Bearer tokens

To install: `cp .husky/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`

Bypass for false positives: `git commit --no-verify`

### Environment Variables for API Access

Always use environment variables for Proxmox API access:

```bash
# Set in your shell profile or load from a non-committed config file
export PVE_API_URL="https://pve.example.com:8006/api2/json"
export PVE_TOKEN_ID="root@pve!mytoken"
export PVE_TOKEN_SECRET="<token-value>"
```

### Recommended Secrets Managers

| Tool | Use Case |
|------|----------|
| HashiCorp Vault | Production-grade secret storage |
 | Doppler | Developer-friendly secrets management |
 | 1Password CLI | Team-sharing secrets securely |
 | ansible-vault | Encrypted Ansible variables |

### Rotating Compromised Credentials

If a secret is accidentally exposed:

1. Immediately revoke the token/credential
2. Rotate all credentials that may have been exposed
3. Review git history: `git log -p --all -S "secret_value"`
4. Consider using [git-filter-repo](https://github.com/newren/git-filter-repo) to remove the secret from history
5. For GitHub repos, use `git push -f` after rewriting history (coordinate with all collaborators)

---

## Security Auditing with Lynis

Lynis performs system security audits and identifies vulnerabilities.

```bash
# Install Lynis
apt install lynis

# Run system audit
lynis audit system

# Run with verbose output
lynis audit system --verbose

# Generate report
lynis audit system --audit-file report.txt

# Common Lynis commands
lynis update info              # Update definitions
lynis audit file               # Audit file permissions
lynis audit package --list     # List installed packages
```

---

## CIS Benchmark Compliance

Apply CIS (Center for Internet Security) benchmarks for hardening.

```bash
# Install CIS benchmark tools
apt install cis-audit

# Run specific checks
cis-audit ssh
cis-audit sudo
cis-audit file-permissions

# Generate compliance report
cis-audit --report > cis-compliance-report.txt
```

> **⚠️ PITFALL**: Over-hardening can break functionality - test in non-production first.

---

## Zero Trust Architecture Patterns

Zero trust principles:
1. Never trust, always verify
2. Least privilege access
3. Micro-segmentation
4. Continuous verification

### Implementation

```bash
# Network segmentation with VLANs
# Create VLAN-aware bridge
auto vmbr0
iface vmbr0 inet manual
    vlan_aware yes
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0

# Assign services to isolated VLANs
net0: vlan=10,bridge=vmbr0,firewall=1    # Management
net0: vlan=20,bridge=vmbr0,firewall=1    # VMs
net0: vlan=30,bridge=vmbr0,firewall=1    # Containers
net0: vlan=40,bridge=vmbr0,firewall=1    # Guest network

# Firewall rules for zero trust
pvesh create /firewall/rules --ruleid 200 --action accept --source 192.168.1.0/24 --dest-port 22
pvesh create /firewall/rules --ruleid 201 --action drop --type guest
```

---

## Incident Response Preparation

Prepare your system for security incidents.

```bash
# Enable comprehensive logging
rsyslog -n  # Run without daemonization for testing
systemctl enable rsyslog

# Configure log rotation
nano /etc/logrotate.conf
# Ensure logs are rotated and retained

# Create incident response checklist
cat > /root/incident-response.md << 'EOF'
# Incident Response Checklist

## Detection
- [ ] Identify the incident type
- [ ] Determine scope and impact
- [ ] Preserve evidence

## Containment
- [ ] Isolate affected systems
- [ ] Block malicious IPs
- [ ] Disable compromised accounts

## Eradication
- [ ] Remove malware
- [ ] Patch vulnerabilities
- [ ] Reset credentials

## Recovery
- [ ] Restore from clean backup
- [ ] Verify system integrity
- [ ] Monitor for recurrence

## Lessons Learned
- [ ] Document what happened
- [ ] Update procedures
- [ ] Improve detection
EOF

# Create backup verification script
cat > /root/verify-backup-integrity.sh << 'EOF'
#!/bin/bash
# Verify backup integrity before use
BACKUP_FILE="$1"
if [ -f "$BACKUP_FILE" ]; then
    echo "Verifying $BACKUP_FILE..."
    tar -tzf "$BACKUP_FILE" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Backup integrity: OK"
    else
        echo "Backup integrity: FAILED"
        exit 1
    fi
else
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi
EOF
chmod +x /root/verify-backup-integrity.sh
```

---

## Security Tools Summary

| Tool | Purpose | When to Use |
|------|-------|---------|
| Lynis | System security auditing | Regular security assessments |
| fail2ban | Intrusion prevention | Systems exposed to internet |
| rkhunter | Rootkit detection | Periodic security checks |
| chkrootkit | Rootkit detection | Periodic security checks |
| auditd | System auditing | Compliance requirements |
| wazuh | SIEM/SOAR | Advanced monitoring needs |

---

## Summary

### Learning Path Progression

1. **Beginner**: SSH hardening, basic firewall rules
2. **Intermediate**: 2FA, TLS certificates, regular audits
3. **Advanced**: Zero trust architecture, incident response
4. **Enterprise**: CIS compliance, automated security monitoring

### Real-World Job Skill Mapping

- **Security Engineer**: All sections apply directly
- **DevOps Engineer**: SSH hardening, firewall, TLS
- **SRE**: Incident response, auditing, monitoring
- **Cloud Engineer**: Zero trust, network segmentation

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
