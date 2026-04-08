# Security Documentation

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## Overview

This section covers security hardening, auditing, and compliance for Proxmox environments.

## Documentation Index

| Document | Description | Difficulty |
|----------|-------------|------------|
| [`SECURITY.md`](../SECURITY.md) | Security hardening guide | Intermediate |
| [`AUDITING.md`](AUDITING.md) | Security auditing and monitoring | Advanced |
| [`CIS_BENCHMARKS.md`](CIS_BENCHMARKS.md) | CIS benchmark compliance | Advanced |
| [`INCIDENT_RESPONSE.md`](INCIDENT_RESPONSE.md) | Incident response procedures | Advanced |
| [`ZERO_TRUST.md`](ZERO_TRUST.md) | Zero trust architecture | Expert |

### Quick Reference

- **Getting Started**: Start with [`SECURITY.md`](../SECURITY.md)
- **Auditing**: See [`AUDITING.md`](AUDITING.md)
- **Compliance**: Follow [`CIS_BENCHMARKS.md`](CIS_BENCHMARKS.md)
- **Incident Response**: See [`INCIDENT_RESPONSE.md`](INCIDENT_RESPONSE.md)

## Learning Path

### Beginner
1. SSH hardening in [`SECURITY.md`](../SECURITY.md)
2. Basic firewall rules
3. TLS certificate management

### Intermediate
1. 2FA for web interface
2. Security auditing with Lynis
3. Regular compliance checks

### Advanced
1. Zero trust architecture in [`ZERO_TRUST.md`](ZERO_TRUST.md)
2. CIS benchmark compliance in [`CIS_BENCHMARKS.md`](CIS_BENCHMARKS.md)
3. Incident response procedures in [`INCIDENT_RESPONSE.md`](INCIDENT_RESPONSE.md)

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

- **Networking**: See [`NETWORKING/`](../NETWORKING/) for network security
- **Backup**: See [`BACKUP/`](../BACKUP/) for backup security
- **Services**: See [`SERVICES/`](../SERVICES/) for service hardening

## Security Tools

| Tool | Purpose | Documentation |
|------|------|------|
| Lynis | System security auditing | [`AUDITING.md`](AUDITING.md) |
| fail2ban | Intrusion prevention | [`SECURITY.md`](../SECURITY.md) |
| rkhunter | Rootkit detection | [`SECURITY.md`](../SECURITY.md) |
| auditd | System auditing | [`AUDITING.md`](AUDITING.md) |
| Wazuh | SIEM/SOAR | [`SECURITY.md`](../SECURITY.md) |

## Compliance Frameworks

| Framework | Requirements | Documentation |
|------|------|------|
| CIS Benchmarks | Security baselines | [`CIS_BENCHMARKS.md`](CIS_BENCHMARKS.md) |
| SOC2 | Security controls | [`SECURITY.md`](../SECURITY.md) |
| HIPAA | Healthcare data | [`SECURITY.md`](../SECURITY.md) |
| PCI-DSS | Payment data | [`SECURITY.md`](../SECURITY.md) |

## Job Skill Mapping

| Role | Security Skills |
|------|------|
| Security Engineer | All sections apply directly |
| DevOps Engineer | SSH hardening, firewall, TLS |
| SRE | Incident response, auditing |
| Cloud Engineer | Zero trust, network segmentation |

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
