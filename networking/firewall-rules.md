# Firewall Rules Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers Proxmox firewall configuration and management:

- **Firewall Configuration**: Proxmox firewall setup and management
- **Security Rules**: Creating and managing firewall rules
- **Network Policies**: Advanced network security controls
- **Firewall Troubleshooting**: Debugging firewall issues
- **Security Best Practices**: Network security hardening

## When You Need This

- Multi-tenant environments
- Compliance requirements
- Security-conscious deployments
- Network segmentation needs
- Audit requirements

## Simpler Alternative

For most homelab users:
- Basic firewall enabled
- Default allow rules
- Manual rule management
- Simple network isolation

---

## Proxmox Firewall Overview

Proxmox VE provides a built-in firewall that can be enabled at multiple levels:
- **Node Level**: Firewall for all VMs/containers on a node
- **Cluster Level**: Firewall for the entire cluster
- **VM/Container Level**: Individual firewall for each VM/container

### Firewall Levels

| Level | Scope | Use Case |
|----|-------|--------|
| Node | All VMs on node | Node-level security |
| Cluster | All nodes in cluster | Centralized management |
| VM/Container | Individual VM/CT | Per-workload security |

---

## Enabling Firewall

Enable firewall at different levels.

```bash
# Enable firewall at node level
pve-firewall enable

# Enable firewall at cluster level
pvesh create /firewall/options --enabled 1

# Enable firewall on specific VM
qm set 100 --firewall 1

# Enable firewall on specific container
pct set 200 --firewall 1

# Check firewall status
pve-firewall status
pvesh get /firewall/options
```

> **⚠️ PITFALL**: Locking out access - keep an active session when making changes.

---

## Creating Firewall Rules

Create firewall rules via API.

```bash
# Create accept rule
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --name "Allow-SSH" \
  --source 192.168.1.0/24 \
  --dest-port 22 \
  --proto tcp

# Create drop rule
pvesh create /firewall/rules \
  --ruleid 200 \
  --action drop \
  --name "Block-All-External" \
  --source 0.0.0.0/0

# Create rule for specific VM
pvesh create /firewall/rules \
  --ruleid 300 \
  --action accept \
  --type guest \
  --guest 100 \
  --dest-port 80,443 \
  --proto tcp \
  --name "Allow-Web-VM100"

# Create rule for container
pvesh create /firewall/rules \
  --ruleid 400 \
  --action accept \
  --type guest \
  --guest 200 \
  --dest-port 8080 \
  --proto tcp \
  --name "Allow-Web-CT200"
```

---

## Firewall Rule Types

### Guest Rules (VM/Container Specific)

```bash
# Allow all traffic from VM 100
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --type guest \
  --guest 100

# Allow specific ports for VM
pvesh create /firewall/rules \
  --ruleid 101 \
  --action accept \
  --type guest \
  --guest 100 \
  --dest-port 22,80,443 \
  --proto tcp

# Block specific IP from VM
pvesh create /firewall/rules \
  --ruleid 102 \
  --action drop \
  --type guest \
  --guest 100 \
  --source 10.0.0.0/8

# Allow ICMP (ping) for VM
pvesh create /firewall/rules \
  --ruleid 103 \
  --action accept \
  --type guest \
  --guest 100 \
  --proto icmp
```

---

### Host Rules (Node/Cluster Level)

```bash
# Allow SSH to host
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --type host \
  --dest-port 22 \
  --proto tcp \
  --source 192.168.1.0/24

# Allow HTTP/HTTPS to host
pvesh create /firewall/rules \
  --ruleid 101 \
  --action accept \
  --type host \
  --dest-port 80,443 \
  --proto tcp

# Block all other traffic to host
pvesh create /firewall/rules \
  --ruleid 999 \
  --action drop \
  --type host
```

---

### Network Rules (Bridge Level)

```bash
# Allow traffic between VLANs
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --type network \
  --source 192.168.10.0/24 \
  --dest 192.168.20.0/24

# Block traffic between VLANs
pvesh create /firewall/rules \
  --ruleid 200 \
  --action drop \
  --type network \
  --source 192.168.30.0/24 \
  --dest 192.168.40.0/24

# Allow DNS traffic
pvesh create /firewall/rules \
  --ruleid 300 \
  --action accept \
  --type network \
  --dest-port 53 \
  --proto udp,tcp
```

---

## Firewall Rule Ordering

Understand rule priority.

```bash
# List all rules with order
pvesh get /firewall/rules

# Rule priority:
# 1. Lowest ruleid has highest priority
# 2. Rules are evaluated top to bottom
# 3. First matching rule wins

# Example rule ordering:
# Rule 100: Accept SSH from 192.168.1.0/24 (highest priority)
# Rule 200: Accept HTTP/HTTPS from any
# Rule 300: Drop all other traffic (lowest priority)

# Reorder rules by deleting and recreating
pvesh delete /firewall/rules --ruleid 200
pvesh create /firewall/rules \
  --ruleid 150 \
  --action accept \
  --name "New-Middle-Rule" \
  --dest-port 8080
```

> **⚠️ PITFALL**: Wrong rule order can break expected behavior.

---

## Firewall Configuration Examples

### Example 1: Web Server Firewall

```bash
# Web server firewall configuration
# Rule 100: Allow SSH from management network
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --type guest \
  --guest 100 \
  --source 192.168.1.0/24 \
  --dest-port 22 \
  --proto tcp \
  --name "Allow-SSH-Management"

# Rule 101: Allow HTTP from any
pvesh create /firewall/rules \
  --ruleid 101 \
  --action accept \
  --type guest \
  --guest 100 \
  --dest-port 80 \
  --proto tcp \
  --name "Allow-HTTP"

# Rule 102: Allow HTTPS from any
pvesh create /firewall/rules \
  --ruleid 102 \
  --action accept \
  --type guest \
  --guest 100 \
  --dest-port 443 \
  --proto tcp \
  --name "Allow-HTTPS"

# Rule 999: Drop all other traffic
pvesh create /firewall/rules \
  --ruleid 999 \
  --action drop \
  --type guest \
  --guest 100 \
  --name "Default-Drop"
```

---

### Example 2: Database Server Firewall

```bash
# Database server firewall configuration
# Rule 100: Allow MySQL from application servers only
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --type guest \
  --guest 200 \
  --source 192.168.20.0/24 \
  --dest-port 3306 \
  --proto tcp \
  --name "Allow-MySQL-App"

# Rule 101: Allow SSH from management network
pvesh create /firewall/rules \
  --ruleid 101 \
  --action accept \
  --type guest \
  --guest 200 \
  --source 192.168.1.0/24 \
  --dest-port 22 \
  --proto tcp \
  --name "Allow-SSH-Management"

# Rule 999: Drop all other traffic
pvesh create /firewall/rules \
  --ruleid 999 \
  --action drop \
  --type guest \
  --guest 200 \
  --name "Default-Drop"
```

---

### Example 3: Container Firewall

```bash
# Container firewall configuration
# Rule 100: Allow HTTP from any
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --type guest \
  --guest 300 \
  --dest-port 80 \
  --proto tcp \
  --name "Allow-HTTP"

# Rule 101: Allow HTTPS from any
pvesh create /firewall/rules \
  --ruleid 101 \
  --action accept \
  --type guest \
  --guest 300 \
  --dest-port 443 \
  --proto tcp \
  --name "Allow-HTTPS"

# Rule 102: Allow SSH from management
pvesh create /firewall/rules \
  --ruleid 102 \
  --action accept \
  --type guest \
  --guest 300 \
  --source 192.168.1.0/24 \
  --dest-port 22 \
  --proto tcp \
  --name "Allow-SSH-Management"

# Rule 999: Drop all other traffic
pvesh create /firewall/rules \
  --ruleid 999 \
  --action drop \
  --type guest \
  --guest 300 \
  --name "Default-Drop"
```

---

## Firewall Troubleshooting

Debug firewall issues.

```bash
# Check firewall status
pve-firewall status

# List all rules
pvesh get /firewall/rules

# Check VM firewall status
qm config 100 | grep firewall

# Check container firewall status
pct config 200 | grep firewall

# Monitor firewall logs
journalctl -u pve-firewall -f

# Test connectivity
# From VM, test if port is accessible
nc -zv 192.168.1.100 22
nc -zv 192.168.1.100 80

# Check if rule is matching
pvesh get /firewall/log

# Temporarily disable firewall for testing
pve-firewall disable
# Test connectivity
pve-firewall enable
```

> **⚠️ PITFALL**: Security risks during testing - re-enable immediately.

---

## Firewall Best Practices

```bash
# 1. Enable firewall by default
pve-firewall enable
pvesh create /firewall/options --enabled 1

# 2. Use descriptive rule names
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --name "Allow-SSH-From-Management-Network" \
  --source 192.168.1.0/24 \
  --dest-port 22

# 3. Document all rules
cat > /root/firewall_documentation.md << 'EOF'
# Firewall Rules Documentation

## VM 100 (Web Server)
| Rule ID | Action | Source | Dest Port | Protocol | Name |
|-----|------|--------|-----|---|------|
| 100 | Accept | 192.168.1.0/24 | 22 | tcp | Allow-SSH-Management |
| 101 | Accept | Any | 80 | tcp | Allow-HTTP |
| 102 | Accept | Any | 443 | tcp | Allow-HTTPS |
| 999 | Drop | Any | Any | Any | Default-Drop |

## VM 200 (Database)
| Rule ID | Action | Source | Dest Port | Protocol | Name |
|-----|------|--------|-----|---|------|
| 100 | Accept | 192.168.20.0/24 | 3306 | tcp | Allow-MySQL-App |
| 101 | Accept | 192.168.1.0/24 | 22 | tcp | Allow-SSH-Management |
| 999 | Drop | Any | Any | Any | Default-Drop |
EOF

# 4. Use default deny policy
pvesh create /firewall/rules \
  --ruleid 999 \
  --action drop \
  --name "Default-Drop-All"

# 5. Enable logging
pvesh create /firewall/options --log-level info

# 6. Regular review
cat > /root/review_firewall.sh << 'EOF'
#!/bin/bash
# Review firewall rules

echo "== Firewall Rules Review =="
echo "Date: $(date)"
echo ""

# List all rules
pvesh get /firewall/rules | grep -E "ruleid|name|action"

echo ""
echo "== Review Complete =="
EOF
chmod +x /root/review_firewall.sh
```

---

## Summary

### Learning Path Progression

1. **Beginner**: Basic firewall enablement, simple rules
2. **Intermediate**: Guest rules, rule ordering
3. **Advanced**: Network rules, policies
4. **Enterprise**: Automated firewall, compliance

### Real-World Job Skill Mapping

- **Security Engineer**: All sections apply directly
- **DevOps Engineer**: Firewall automation, security
- **SRE**: Network security, incident response
- **Cloud Engineer**: Network policies, compliance

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
