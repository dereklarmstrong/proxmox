# VLAN Setup Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers VLAN configuration for network segmentation:

- **VLAN Configuration**: Network segmentation using VLANs
- **Bridge Configuration**: VLAN-aware bridge setup
- **Network Isolation**: Service separation using VLANs
- **Inter-VLAN Routing**: Communication between VLANs
- **Network Troubleshooting**: VLAN debugging techniques

## When You Need This

- Multi-tenant environments
- Security compliance requirements
- Service isolation needs
- Broadcast domain reduction
- Network traffic management

## Simpler Alternative

For most homelab users:
- Single network for all services
- Firewall rules for isolation
- Separate physical networks for critical services
- VLANs only for specific requirements

---

## VLAN Fundamentals

VLANs allow you to create multiple logical networks on a single physical network infrastructure. Each VLAN is a separate broadcast domain.

### VLAN Tagging

- **Untagged (Access) Ports**: Single VLAN, no tag in frames
- **Tagged (Trunk) Ports**: Multiple VLANs, 802.1Q tags in frames
- **PVID (Port VLAN ID)**: Default VLAN for untagged traffic

### Common VLAN IDs

| VLAN ID | Purpose |
|-----|---|
| 10 | Management |
| 20 | VMs |
| 30 | Containers |
| 40 | Storage |
| 50 | Guest/DMZ |

---

## VLAN-Aware Bridge Configuration

Create a VLAN-aware bridge on Proxmox.

```bash
# Edit network configuration
nano /etc/network/interfaces

# Add VLAN-aware bridge configuration
cat >> /etc/network/interfaces << 'EOF'

# VLAN-aware bridge
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

# Verify bridge configuration
ip link show vmbr0
brctl show vmbr0
```

> **⚠️ PITFALL**: Network disruption during restart - use remote console access.

---

### Bridge Configuration with Multiple Ports

```bash
# Bridge with link aggregation (bonding)
cat >> /etc/network/interfaces << 'EOF'

# Bond interface for redundancy
auto bond0
iface bond0 inet manual
    bond-slaves eno1 eno2
    bond-mode 802.3ad
    bond-miimon 100

# VLAN-aware bridge with bond
auto vmbr0
iface vmbr0 inet manual
    vlan_aware yes
    bridge-ports bond0
    bridge-stp off
    bridge-fd 0
EOF

# Restart networking
systemctl restart networking
```

> **⚠️ PITFALL**: Switch configuration requirements for bonding.

---

## Assigning VLANs to VMs/Containers

Configure VM/Container with VLAN.

```bash
# Create VM with VLAN
qm create 100 --name vm-vlan --memory 2048 --cores 2 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-100-disk-0,size=20G \
  --net0 vlan=10,bridge=vmbr0,firewall=1

# Create container with VLAN
pct create 200 local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst \
  -arch amd64 -cores 2 -memory 1024 -swap 512 \
  -net0 name=eth0,bridge=vmbr0,firewall=1,vtag=10 \
  -unprivileged 1

# Modify existing VM to use VLAN
qm set 100 --net0 vlan=20,bridge=vmbr0,firewall=1

# Verify VM network configuration
qm config 100 | grep net0
```

> **⚠️ PITFALL**: VLAN not configured on switch.

---

## VLAN Configuration on Switch

Configure switch for VLANs.

```bash
# Example: Cisco switch configuration
# Access port (single VLAN)
interface GigabitEthernet0/1
 description VM-Network-VLAN10
 switchport mode access
 switchport access vlan 10
 spanning-tree portfast

# Trunk port (multiple VLANs)
interface GigabitEthernet0/24
 description Proxmox-Uplink
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30
 switchport trunk native vlan 99
 spanning-tree portfast trunk

# Example: pfSense VLAN configuration
# Interfaces -> Assignments -> Add VLAN
# Parent: igb0
# VLAN Tag: 10
# Description: VM-Network
```

---

## Inter-VLAN Routing

Enable communication between VLANs.

### Option 1: Proxmox Host as Router

```bash
# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Create VLAN interfaces
cat >> /etc/network/interfaces << 'EOF'

# VLAN interfaces for routing
auto vlan10
iface vlan10 inet static
    address 192.168.10.1
    netmask 255.255.255.0
    vlan-raw-device vmbr0

auto vlan20
iface vlan20 inet static
    address 192.168.20.1
    netmask 255.255.255.0
    vlan-raw-device vmbr0

auto vlan30
iface vlan30 inet static
    address 192.168.30.1
    netmask 255.255.255.0
    vlan-raw-device vmbr0
EOF

# Restart networking
systemctl restart networking

# Configure firewall for inter-VLAN routing
pvesh create /firewall/options --enabled 1

# Allow forwarding between VLANs
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --source 192.168.10.0/24 \
  --dest 192.168.20.0/24 \
  --name "Allow-VLAN10-to-VLAN20"

pvesh create /firewall/rules \
  --ruleid 101 \
  --action accept \
  --source 192.168.20.0/24 \
  --dest 192.168.10.0/24 \
  --name "Allow-VLAN20-to-VLAN10"
```

> **⚠️ PITFALL**: Security risks, firewall misconfiguration.

---

### Option 2: External Router

```bash
# Configure VMs with gateway pointing to external router
qm set 100 --net0 vlan=10,bridge=vmbr0,firewall=1,ip=192.168.10.100/24,gw=192.168.10.1

# Configure router (example: pfSense)
# Interface: VLAN10
# IP: 192.168.10.1/24
# DHCP: 192.168.10.100-192.168.10.200

# Interface: VLAN20
# IP: 192.168.20.1/24
# DHCP: 192.168.20.100-192.168.20.200

# Firewall rules on router
# Allow VLAN10 to VLAN20
# Allow VLAN20 to VLAN10
```

---

## VLAN Security

Secure VLAN configuration.

```bash
# Enable Proxmox firewall
pve-firewall enable
pvesh create /firewall/options --enabled 1

# Create VLAN-specific firewall rules
# Block all inter-VLAN traffic by default
pvesh create /firewall/rules \
  --ruleid 999 \
  --action drop \
  --name "Default-Drop-All"

# Allow specific traffic
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --source 192.168.10.0/24 \
  --dest-port 22 \
  --proto tcp \
  --name "Allow-SSH-Management"

pvesh create /firewall/rules \
  --ruleid 101 \
  --action accept \
  --source 192.168.20.0/24 \
  --dest 192.168.10.0/24 \
  --dest-port 80,443 \
  --proto tcp \
  --name "Allow-Web-Access"

# Enable firewall on VMs
qm set 100 --firewall 1
pct set 200 --firewall 1
```

---

## VLAN Troubleshooting

Debug VLAN issues.

```bash
# Check VLAN configuration
ip link show | grep vlan
brctl show

# Check VLAN traffic
tcpdump -i vmbr0 -n vlan

# Test connectivity between VLANs
# From VM in VLAN10
ping 192.168.20.1
ping 192.168.20.100

# From VM in VLAN20
ping 192.168.10.1
ping 192.168.10.100

# Check firewall rules
pvesh get /firewall/rules

# Check bridge VLAN configuration
cat /sys/class/net/vmbr0/bridge/vids

# Test VLAN tagging
# On VM, check interface configuration
ip addr show eth0
# Should show VLAN tag if configured correctly
```

---

## VLAN Best Practices

```bash
# 1. Use consistent VLAN numbering
# Management: VLAN 10
# VMs: VLAN 20
# Containers: VLAN 30
# Storage: VLAN 40
# Guest: VLAN 50

# 2. Document VLAN assignments
cat > /root/vlan_documentation.md << 'EOF'
# VLAN Documentation

| VLAN ID | Name | Purpose | Subnet | Gateway |
|-----|------|---------|--------|---------|
| 10 | Management | Proxmox management | 192.168.10.0/24 | 192.168.10.1 |
| 20 | VMs | VM network | 192.168.20.0/24 | 192.168.20.1 |
| 30 | Containers | LXC network | 192.168.30.0/24 | 192.168.30.1 |
| 40 | Storage | iSCSI/NFS | 192.168.40.0/24 | 192.168.40.1 |
| 50 | Guest | Guest network | 192.168.50.0/24 | 192.168.50.1 |
EOF

# 3. Use descriptive names
qm set 100 --name "webserver-vlan20"
pct set 200 --hostname "container-vlan30"

# 4. Enable firewall on all VLANs
# All VMs and containers should have firewall enabled

# 5. Monitor VLAN traffic
cat > /root/monitor_vlan.sh << 'EOF'
#!/bin/bash
# Monitor VLAN traffic

echo "== VLAN Traffic Monitor =="
echo "Date: $(date)"
echo ""

# Count packets per VLAN
for vlan in 10 20 30 40 50; do
    COUNT=$(tcpdump -i vmbr0 -n -c 100 vlan $vlan 2>/dev/null | wc -l)
    echo "VLAN $vlan: $COUNT packets"
done

echo ""
echo "== Monitor Complete =="
EOF
chmod +x /root/monitor_vlan.sh
```

---

## Summary

### Learning Path Progression

1. **Beginner**: Basic VLAN assignment to VMs
2. **Intermediate**: VLAN-aware bridges, inter-VLAN routing
3. **Advanced**: VLAN security, troubleshooting
4. **Enterprise**: Multi-site VLANs, SDN integration

### Real-World Job Skill Mapping

- **Network Engineer**: All sections apply directly
- **DevOps Engineer**: Network segmentation, isolation
- **Security Engineer**: VLAN security, firewall rules
- **Cloud Engineer**: Network architecture, routing

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
