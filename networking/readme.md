# Networking Documentation

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## Overview

This section covers Proxmox networking configuration, from basic bridge setup to advanced Software Defined Networking (SDN) and network security.

## Documentation Index

| Document | Description | Difficulty |
|-----|-----|-----|
| [`vlan-setup.md`](vlan-setup.md) | VLAN configuration and network segmentation | Intermediate |
| [`firewall-rules.md`](firewall-rules.md) | Proxmox firewall configuration and rules | Intermediate |
| [`sdn-guide.md`](sdn-guide.md) | Software Defined Network (SDN) setup | Advanced |

### Quick Reference

- **Getting Started**: Start with [`vlan-setup.md`](vlan-setup.md)
- **Security**: See [`firewall-rules.md`](firewall-rules.md)
- **Advanced Networking**: Follow [`sdn-guide.md`](sdn-guide.md)

## Learning Path

### Beginner
1. Understand basic bridge networking
2. Configure simple VLAN assignments
3. Enable basic firewall rules

### Intermediate
1. Set up VLAN-aware bridges in [`vlan-setup.md`](vlan-setup.md)
2. Configure inter-VLAN routing
3. Implement firewall policies in [`firewall-rules.md`](firewall-rules.md)

### Advanced
1. Deploy SDN schemes in [`sdn-guide.md`](sdn-guide.md)
2. Configure VXLAN overlay networks
3. Implement network policies and automation

## Network Topology Examples

### Basic Setup
```
┌─────────────────────────────────────┐
│         Physical Network            │
│         (Switch/Router)             │
└──────────────┬──────────────────────┘
               │
        ┌──────▼──────┐
        │   vmbr0     │
        │  (Bridge)   │
        └──────┬──────┘
               │
     ┌──────────┼──────────┐
     │          │          │
┌───▼───┐  ┌───▼───┐  ┌───▼───┐
│ VM 10 │  │ VM 20 │  │  CT 1 │
│VLAN 10│  │VLAN 20│  │VLAN 10│
└───────┘  └───────┘  └───────┘
```

### Segmented Setup
```
┌─────────────────────────────────────────────────┐
│              Physical Network                   │
└───────────────────┬─────────────────────────────┘
                    │
           ┌────────▼────────┐
           │   vmbr0 (VLAN)  │
           │  vlan_aware:yes │
           └────────┬────────┘
                    │
     ┌───────────────┼───────────────┐
     │               │               │
┌───▼─────┐   ┌─────▼────┐   ┌─────▼────┐
│ VLAN 10 │   │ VLAN 20  │   │ VLAN 30  │
│ Mgmt    │   │ VMs      │   │ Containers│
└─────────┘   └──────────┘   └──────────┘
```

## Related Documentation

- **Storage**: See [`docs/storage_strategy.md`](../docs/storage_strategy.md) for storage networking
- **Security**: See [`security.md`](../security.md) for security hardening
- **Backup**: See [`backup/`](../backup/) for backup network considerations

## Common Network Configurations

| Configuration | Recommended Document |
|------|------|
| Single network | Basic bridge configuration |
| Network segmentation | [`vlan-setup.md`](vlan-setup.md) |
| Security hardening | [`firewall-rules.md`](firewall-rules.md) |
| Multi-site networking | [`sdn-guide.md`](sdn-guide.md) |

## Key Concepts

### VLANs
- Network segmentation using 802.1Q tagging
- Isolate different service types
- Reduce broadcast domain size
- See: [`vlan-setup.md`](vlan-setup.md)

### Firewall
- Node-level, cluster-level, and VM/container-level rules
- Default deny policies
- Logging and monitoring
- See: [`firewall-rules.md`](firewall-rules.md)

### SDN
- Centralized network management
- Automated IP address management (IPAM)
- VXLAN overlay networks
- See: [`sdn-guide.md`](sdn-guide.md)

## Network Scripts

The following scripts are available for network management:

### Network Configuration Viewer
- [`scripts/network/show.sh`](../scripts/network/show.sh:1) — display all network configurations for VMs and containers
  - Usage: `bash scripts/network/show.sh [options]`
  - Options:
    - `-v` — Show VLAN information
    - `-i` — Show IP address assignments
    - `-b` — Show bridge status
  - Displays:
    - Bridge configuration from `/etc/network/interfaces`
    - VLAN configuration
    - VM network configurations (bridge, VLAN, MAC)
    - Container network configurations
    - IP address assignments
  - See: [`vlan-setup.md`](vlan-setup.md) for VLAN configuration details

## Network Script Examples

### View All Network Information
```bash
bash scripts/network/show.sh
```

### View VLAN Configuration Only
```bash
bash scripts/network/show.sh -v
```

### View IP Address Assignments Only
```bash
bash scripts/network/show.sh -i
```

### View Bridge Status Only
```bash
bash scripts/network/show.sh -b
```

## Integration with Other Documentation

| Documentation | Network Integration |
|-----|-----|
| [`backup/readme.md`](../backup/readme.md) | Backup network considerations |
| [`services/service-deployments.md`](../services/service-deployments.md) | Service networking patterns |
| [`gpu-passthrough/readme.md`](../gpu-passthrough/readme.md) | GPU VM network configuration |

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
