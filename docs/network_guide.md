# Network Configuration Guide

## Network Architecture

### Standard Setup

```
eth0 (physical)
  └── vmbr0 (bridge)
        ├── VMs (VLAN 100)
        ├── Containers (VLAN 200)
        └── Management traffic
```

### VLAN Configuration

#### Create a VLAN Bridge

```bash
./scripts/network/vlan_setup.sh \
  --vlan 100 \
  --bridge vmbr100 \
  --parent eth0 \
  --description "Development VLAN"
```

#### Manual VLAN Setup

Edit `/etc/network/interfaces`:

```
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.3/24
    gateway 192.168.1.1
    bridge-ports eth0
    bridge-stp off
    bridge-fd 0

# VLAN 100
auto vmbr100.100
iface vmbr100.100 inet manual
    vlan-raw-device vmbr100
    vlan-id 100
```

### Firewall Rules

#### Basic VM Firewall

```bash
# Enable firewall on VM 100
qm set 100 --firewall 1

# Allow SSH inbound
qm set 100 --firewall_policy inbound:tcp,22,allow

# Allow HTTP/HTTPS
qm set 100 --firewall_policy inbound:tcp,80,allow
qm set 100 --firewall_policy inbound:tcp,443,allow
```

#### Container Firewall

```bash
pct set 200 --firewall 1
pct set 200 --firewall_policy inbound:tcp,22,allow
```

## Network Diagnostics

### Check Network Status

```bash
./scripts/network/network_report.sh
```

### Find VM IP Address

```bash
# From Proxmox shell
arp -a | grep <MAC_address>

# Or use the API
./scripts/api/api_wrapper.sh GET /nodes/pve/qemu/100/status/state
```

### Test Connectivity

```bash
# From Proxmox node
ping -c 3 10.0.1.50

# Check routing
ip route get 10.0.1.50

# Check bridge members
brctl show vmbr0
```

## Common Issues

### VM Cannot Reach Network

1. Check bridge configuration: `cat /etc/network/interfaces`
2. Verify VM network settings: `qm config <vmid>`
3. Check bridge is up: `ip link show vmbr0`
4. Verify DHCP/static IP configuration

### VLAN Not Working

1. Check VLAN is configured: `ip link show | grep vlan`
2. Verify VLAN ID on switch port
3. Check bridge VLAN filtering: `bridge vlan show`

### DNS Resolution Fails

1. Check `/etc/resolv.conf`
2. Verify nameserver in VM config: `qm config <vmid> | grep nameserver`
3. Test DNS: `nslookup example.com`

## Advanced Topics

### SDN (Software Defined Networking)

SDN provides automated IP allocation, VLAN management, and firewall rules.

```bash
# Create SDN zone
pvesh create /cluster/sdn/zones --name dev-vlan --type vlan --vid 100

# Assign IP range
pvesh create /cluster/sdn/ipspaces --name dev-ips --type ipset \
  --ips 10.0.100.0/24
```

### MACVLAN for Containers

```bash
pct set 200 --net0 "name=eth0,bridge=vmbr0,hwaddr=,ip=dhcp,tag=100,type=macvlan"
```
