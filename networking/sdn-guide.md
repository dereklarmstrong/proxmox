# Software Defined Network (SDN) Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers Proxmox SDN configuration and management:

- **SDN Configuration**: Proxmox SDN setup and management
- **Network Automation**: Automated network provisioning
- **SDN Schemes**: VLAN, VXLAN, and IPAM configurations
- **Network Policies**: Advanced network controls
- **SDN Troubleshooting**: Debugging SDN issues

## When You Need This

- Multi-node cluster management
- Automated network provisioning
- Complex network topologies
- Multi-tenant environments
- Dynamic network requirements

## Simpler Alternative

For most homelab users:
- Standard bridge networking
- Manual VLAN configuration
- Simple firewall rules
- Static IP assignments

---

## SDN Overview

Proxmox SDN provides centralized network management for clusters. It allows you to define network schemes that can be applied across multiple nodes.

### SDN Components

| Component | Description |
|------|-----|
| **VLAN Scheme** | VLAN-based network segmentation |
| **VXLAN Scheme** | Overlay network for multi-site |
| **IPAM** | IP Address Management |
| **Zone** | Network isolation groups |
| **Network** | Virtual network definitions |

---

## SDN Configuration via API

Configure SDN using pvesh.

```bash
# Enable SDN
pvesh create /cluster/network --sdn 1

# Create VLAN scheme
pvesh create /cluster/network/sdn \
  --type vlan \
  --name vlan-scheme \
  --vlan-range 1-4094

# Create IPAM mode
pvesh create /cluster/network/ipam \
  --mode dhcp \
  --subnet 192.168.1.0/24

# Create network
pvesh create /cluster/network/network \
  --name vmbr0 \
  --type bridge \
  --bridge-ports eno1 \
  --bridge-stp off \
  --vlan-raw-device vmbr0

# Assign network to node
pvesh create /cluster/network/node \
  --node pve \
  --network vmbr0
```

> **⚠️ PITFALL**: SDN complexity, API errors.

---

## SDN Configuration via Web UI

Configure SDN using Proxmox web interface.

```bash
# Access SDN configuration
# Web UI: Datacenter -> SDN

# Step 1: Create VLAN Scheme
# 1. Navigate to Datacenter -> SDN -> Schemes
# 2. Click "Add" -> "VLAN"
# 3. Name: vlan-scheme
# 4. VLAN Range: 1-4094
# 5. Click "Add"

# Step 2: Create Zone
# 1. Navigate to Datacenter -> SDN -> Zones
# 2. Click "Add" -> "Zone"
# 3. Name: default
# 4. Click "Add"

# Step 3: Create Network
# 1. Navigate to Datacenter -> SDN -> Networks
# 2. Click "Add" -> "Bridge"
# 3. Name: vmbr0
# 4. Type: Bridge
# 5. Bridge Ports: eno1
# 6. Click "Add"

# Step 4: Assign Network to Nodes
# 1. Navigate to Datacenter -> SDN -> Nodes
# 2. Select node
# 3. Assign network
# 4. Click "Add"
```

---

## IP Address Management (IPAM)

Configure IPAM for automated IP assignment.

```bash
# Create IPAM mode
pvesh create /cluster/network/ipam \
  --mode manual \
  --subnet 192.168.1.0/24 \
  --name ipam-manual

# Create IPAM mode with DHCP
pvesh create /cluster/network/ipam \
  --mode dhcp \
  --subnet 192.168.1.0/24 \
  --name ipam-dhcp

# Create IPAM mode with static range
pvesh create /cluster/network/ipam \
  --mode static \
  --subnet 192.168.1.0/24 \
  --range 192.168.1.100-192.168.1.200 \
  --name ipam-static

# Assign IPAM to network
pvesh create /cluster/network/network \
  --name vmbr0 \
  --type bridge \
  --ipam-mode static \
  --ipam-range 192.168.1.100-192.168.1.200
```

> **⚠️ PITFALL**: IP conflicts, DHCP issues.

---

## SDN Network Schemes

### VLAN Scheme

```bash
# Create VLAN scheme
pvesh create /cluster/network/sdn \
  --type vlan \
  --name vlan-scheme \
  --vlan-range 10-100

# Create VLAN network
pvesh create /cluster/network/network \
  --name vlan10 \
  --type vlan \
  --scheme vlan-scheme \
  --vlan-id 10 \
  --ipam-mode static \
  --ip 192.168.10.1/24

# Create another VLAN network
pvesh create /cluster/network/network \
  --name vlan20 \
  --type vlan \
  --scheme vlan-scheme \
  --vlan-id 20 \
  --ipam-mode static \
  --ip 192.168.20.1/24
```

---

### VXLAN Scheme

```bash
# Create VXLAN scheme
pvesh create /cluster/network/sdn \
  --type vxlan \
  --name vxlan-scheme \
  --vxlan-id 100 \
  --subnet 10.0.0.0/8

# Create VXLAN network
pvesh create /cluster/network/network \
  --name vxlan100 \
  --type vxlan \
  --scheme vxlan-scheme \
  --vxlan-id 100 \
  --ipam-mode static \
  --ip 10.0.100.1/24

# Assign VXLAN to nodes
pvesh create /cluster/network/node \
  --node pve1 \
  --network vxlan100

pvesh create /cluster/network/node \
  --node pve2 \
  --network vxlan100
```

> **⚠️ PITFALL**: Performance overhead, complexity.

---

## SDN Network Policies

Configure network policies.

```bash
# Create firewall policy
pvesh create /cluster/network/policy \
  --name default \
  --firewall 1

# Create network policy with specific rules
pvesh create /cluster/network/policy \
  --name restricted \
  --firewall 1 \
  --inbound drop \
  --outbound accept

# Assign policy to network
pvesh create /cluster/network/network \
  --name vmbr0 \
  --policy restricted
```

---

## SDN Zone Configuration

Configure SDN zones for isolation.

```bash
# Create zone
pvesh create /cluster/network/zone \
  --name production \
  --description "Production network zone"

# Create zone for development
pvesh create /cluster/network/zone \
  --name development \
  --description "Development network zone"

# Assign network to zone
pvesh create /cluster/network/network \
  --name vmbr0 \
  --zone production

# Create zone-based firewall rules
pvesh create /cluster/network/firewall \
  --zone production \
  --rule 100 \
  --action accept \
  --source 192.168.10.0/24 \
  --dest 192.168.20.0/24
```

---

## SDN Troubleshooting

Debug SDN issues.

```bash
# Check SDN status
pvesh get /cluster/network

# List all SDN components
pvesh get /cluster/network/sdn
pvesh get /cluster/network/zone
pvesh get /cluster/network/network
pvesh get /cluster/network/node

# Check network configuration on node
pvesh get /nodes/pve/network

# Verify IPAM configuration
pvesh get /cluster/network/ipam

# Check for conflicts
pvesh get /cluster/network/conflicts

# Test network connectivity
# From VM, test connectivity
ping -c 4 192.168.10.1
ping -c 4 192.168.20.1

# Check SDN logs
journalctl -u pvedaemon | grep -i sdn
```

---

## SDN Best Practices

```bash
# 1. Document SDN configuration
cat > /root/sdn_documentation.md << 'EOF'
# SDN Documentation

## Schemes
| Name | Type | Range/Config |
|--|------|--|
| vlan-scheme | VLAN | 10-100 |
| vxlan-scheme | VXLAN | ID 100 |

## Zones
| Name | Description |
|------|-----|
| production | Production network |
| development | Development network |

## Networks
| Name | Type | Subnet | Gateway |
|------|------|--------|-------|
| vmbr0 | Bridge | 192.168.1.0/24 | 192.168.1.1 |
| vlan10 | VLAN | 192.168.10.0/24 | 192.168.10.1 |
| vlan20 | VLAN | 192.168.20.0/24 | 192.168.20.1 |
EOF

# 2. Use consistent naming
# All networks should follow naming convention

# 3. Implement IPAM
# Use IPAM for automated IP management

# 4. Enable firewall
# All networks should have firewall enabled

# 5. Monitor SDN status
cat > /root/monitor_sdn.sh << 'EOF'
#!/bin/bash
# Monitor SDN status

echo "== SDN Status Monitor =="
echo "Date: $(date)"
echo ""

# Check SDN enabled
SDN_STATUS=$(pvesh get /cluster/network | grep sdn)
echo "SDN Status: $SDN_STATUS"

# List networks
echo ""
echo "Networks:"
pvesh get /cluster/network/network | grep -E "name|type"

# List zones
echo ""
echo "Zones:"
pvesh get /cluster/network/zone | grep -E "name|description"

# List schemes
echo ""
echo "Schemes:"
pvesh get /cluster/network/sdn | grep -E "name|type"

echo ""
echo "== Monitor Complete =="
EOF
chmod +x /root/monitor_sdn.sh
```

---

## Summary

### Learning Path Progression

1. **Beginner**: Basic bridge networking
2. **Intermediate**: VLAN configuration, manual IPAM
3. **Advanced**: SDN schemes, automated provisioning
4. **Enterprise**: Multi-site SDN, VXLAN overlay

### Real-World Job Skill Mapping

- **Network Engineer**: All sections apply directly
- **DevOps Engineer**: Network automation, SDN
- **Cloud Engineer**: Multi-site networking, overlay networks
- **Security Engineer**: Network policies, isolation

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
