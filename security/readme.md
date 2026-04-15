# Security Documentation

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## Overview

This section covers security hardening, auditing, and compliance for Proxmox environments.

## Documentation Index

| Document | Description | Difficulty |
|----------|-------------|------------|
| [`security.md`](../security.md) | Security hardening guide | Intermediate |
| [`auditing.md`](auditing.md) | Security auditing and monitoring | Advanced |
| [`cis-benchmarks.md`](cis-benchmarks.md) | CIS benchmark compliance | Advanced |
| [`incident-response.md`](incident-response.md) | Incident response procedures | Advanced |
| [`zero-trust.md`](zero-trust.md) | Zero trust architecture | Expert |

### Quick Reference

- **Getting Started**: Start with [`security.md`](../security.md)
- **Auditing**: See [`auditing.md`](auditing.md)
- **Compliance**: Follow [`cis-benchmarks.md`](cis-benchmarks.md)
- **Incident Response**: See [`incident-response.md`](incident-response.md)

## Learning Path

### Beginner
1. SSH hardening in [`security.md`](../security.md)
2. Basic firewall rules
3. TLS certificate management

### Intermediate
1. 2FA for web interface
2. Security auditing with Lynis
3. Regular compliance checks

### Advanced
1. Zero trust architecture in [`zero-trust.md`](zero-trust.md)
2. CIS benchmark compliance in [`cis-benchmarks.md`](cis-benchmarks.md)
3. Incident response procedures in [`incident-response.md`](incident-response.md)

## Security Layers

```
┌─────────────────────────────────────────────────────────┐
│                    Application Layer                    │
│              (Service hardening, app security)          │
└─────────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────────┐
│                    Network Layer                        │
│         (Firewall, VLANs, network segmentation)         │
└─────────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────────┐
│                   Host Layer                            │
│    (SSH hardening, OS security, auditing, monitoring)   │
└─────────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────────┐
│                  Hypervisor Layer                       │
│        (Proxmox security, VM isolation, API security)   │
└─────────────────────────────────────────────────────────┘
```

## Security Checklist

### Essential (Beginner)
- [ ] SSH key authentication
- [ ] Firewall enabled
- [ ] Regular updates
- [ ] Strong passwords

### Recommended (Intermediate)
- [ ] 2FA for web interface
- [ ] TLS certificates
- [ ] Security auditing
- [ ] Backup encryption

### Advanced (Expert)
- [ ] Zero trust architecture
- [ ] CIS benchmark compliance
- [ ] Automated incident response
- [ ] Continuous monitoring

## Related Documentation

- **Networking**: See [`networking/`](../networking/) for network security
- **Backup**: See [`backup/`](../backup/) for backup security
- **Services**: See [`services/`](../services/) for service hardening

## Security Tools

| Tool | Purpose | Documentation |
|------|------|------|
| Lynis | System security auditing | [`auditing.md`](auditing.md) |
| fail2ban | Intrusion prevention | [`security.md`](../security.md) |
| rkhunter | Rootkit detection | [`security.md`](../security.md) |
| auditd | System auditing | [`auditing.md`](auditing.md) |
| Wazuh | SIEM/SOAR | [`security.md`](../security.md) |

## Compliance Frameworks

| Framework | Requirements | Documentation |
|------|------|------|
| CIS Benchmarks | Security baselines | [`cis-benchmarks.md`](cis-benchmarks.md) |
| SOC2 | Security controls | [`security.md`](../security.md) |
| HIPAA | Healthcare data | [`security.md`](../security.md) |
| PCI-DSS | Payment data | [`security.md`](../security.md) |

## Job Skill Mapping

| Role | Security Skills |
|------|------|
| Security Engineer | All sections apply directly |
| DevOps Engineer | SSH hardening, firewall, TLS |
| SRE | Incident response, auditing |
| Cloud Engineer | Zero trust, network segmentation |

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
