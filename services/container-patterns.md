# LXC Container Patterns Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers LXC container patterns and best practices:

- **LXC Container Management**: Lightweight virtualization
- **Container Patterns**: Common deployment patterns
- **Resource Management**: CPU, memory, and storage allocation
- **Network Configuration**: Container networking patterns
- **Security Hardening**: Container isolation and security

## When You Need This

- Lightweight service deployment
- Resource-efficient hosting
- Rapid deployment needs
- Microservices architectures
- Cost-sensitive deployments

## Simpler Alternative

For most homelab users:
- Use VMs for full isolation
- Simple container for single services
- Docker for application containers
- Manual configuration for one-off containers

---

## LXC Container Fundamentals

LXC provides OS-level virtualization, allowing multiple isolated Linux systems to run on a single host.

### LXC vs VM Comparison

| Feature | LXC Container | VM |
|------|------|-|
| Overhead | Minimal | Higher |
| Boot Time | Seconds | Minutes |
| Isolation | OS-level | Hardware-level |
| Resource Usage | Low | Higher |
| Use Case | Lightweight services | Full OS needs |

---

## Container Creation Patterns

### Pattern 1: Basic Unprivileged Container

Create a basic unprivileged container.

```bash
# Create basic unprivileged container
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 \
  -cores 2 \
  -memory 1024 \
  -swap 512 \
  -net0 name=eth0,bridge=vmbr0,firewall=1 \
  -unprivileged 1

# Start container
pct start 100

# Access container console
pct enter 100

# Verify container status
pct status 100
pct config 100
```

> **⚠️ PITFALL**: Unprivileged mode has some limitations compared to privileged containers.

---

### Pattern 2: Container with Static IP

Create a container with a static IP address.

```bash
# Create container with static IP
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 \
  -cores 2 \
  -memory 1024 \
  -swap 512 \
  -net0 name=eth0,bridge=vmbr0,firewall=1,ip=192.168.1.100/24,gw=192.168.1.1 \
  -unprivileged 1

# Configure network inside container
pct enter 100
cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4
EOF

# Restart networking
systemctl restart networking

# Verify network
ip addr show eth0
ping -c 4 google.com
```

---

### Pattern 3: Container with Mount Point

Create a container with persistent mount points.

```bash
# Create container with mount point
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 \
  -cores 2 \
  -memory 1024 \
  -swap 512 \
  -net0 name=eth0,bridge=vmbr0,firewall=1 \
  -mp 0 /mnt/data \
  -mp 1 /home/admin \
  -unprivileged 1

# Configure mount point inside container
pct enter 100
mkdir -p /mnt/data
chmod 755 /mnt/data

# Or configure via config file
pct set 100 --mp0 local:100/vm-100-disk-0,size=10G,mountoptions=exec,dev,suid

# Verify mount point
pct config 100 | grep mp0
```

> **⚠️ PITFALL**: Permission issues can occur with mount points.

---

### Pattern 4: Container with VLAN

Create a container with VLAN tagging.

```bash
# Create container with VLAN
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 \
  -cores 2 \
  -memory 1024 \
  -swap 512 \
  -net0 name=eth0,bridge=vmbr0,firewall=1,vtag=10 \
  -unprivileged 1

# Configure VLAN inside container
pct enter 100
cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto eth0.10
iface eth0.10 inet static
    address 192.168.10.100
    netmask 255.255.255.0
    gateway 192.168.10.1
EOF

# Install vlan package
apt install -y vlan

# Configure VLAN
vconfig add eth0 10
ip addr add 192.168.10.100/24 dev eth0.10
ip link set eth0.10 up
```

---

## Container Resource Management

Configure container resources.

```bash
# Set CPU limit
pct set 100 --cores 2 --cpuunits 512

# Set memory limit
pct set 100 --memory 2048 --swap 1024

# Set CPU limit in seconds
pct set 100 --cpulimit 100

# Set I/O limit
pct set 100 --iothread 1

# View resource usage
pct exec 100 -- top -bn1 | head -20

# Check container limits
pct config 100
```

---

### Container Resource Script

```bash
# Create resource management script
cat > /root/manage_container_resources.sh << 'EOF'
#!/bin/bash
# Container Resource Management Script

CTID="$1"

if [ -z "$CTID" ]; then
    echo "Usage: $0 <container_id>"
    echo ""
    echo "Available containers:"
    pct list
    exit 1
fi

echo "== Container $CTID Resource Status =="
echo "Date: $(date)"
echo ""

# Get container config
echo "Current Configuration:"
pct config $CTID | grep -E "cores|memory|swap|cpuunits"

# Get resource usage
echo ""
echo "Resource Usage:"
pct exec $CTID -- top -bn1 | head -10

# Get disk usage
echo ""
echo "Disk Usage:"
pct exec $CTID -- df -h

# Get network usage
echo ""
echo "Network Usage:"
pct exec $CTID -- ip -s link show eth0

echo ""
echo "== Resource Status Complete =="
EOF
chmod +x /root/manage_container_resources.sh

# Use the script
/root/manage_container_resources.sh 100
```

---

## Container Security Patterns

Secure container configuration.

```bash
# Create container with security features
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 \
  -cores 2 \
  -memory 1024 \
  -swap 512 \
  -net0 name=eth0,bridge=vmbr0,firewall=1 \
  -unprivileged 1 \
  -rootfs local-lvm:100,size=10G \
  -cpulimit 100 \
  -cores 2 \
  -cpuunits 512

# Enable container firewall
pct set 100 --firewall 1

# Configure container firewall rules
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --type guest \
  --guest 100 \
  --dest-port 22 \
  --proto tcp \
  --source 192.168.1.0/24 \
  --name "Allow-SSH-Management"

pvesh create /firewall/rules \
  --ruleid 101 \
  --action accept \
  --type guest \
  --guest 100 \
  --dest-port 80,443 \
  --proto tcp \
  --name "Allow-Web"

pvesh create /firewall/rules \
  --ruleid 999 \
  --action drop \
  --type guest \
  --guest 100 \
  --name "Default-Drop"

# Configure SELinux/AppArmor (if available)
pct set 100 --selinux 1
```

---

### Container Security Checklist

```bash
# Create security checklist script
cat > /root/container_security_check.sh << 'EOF'
#!/bin/bash
# Container Security Checklist

CTID="$1"

if [ -z "$CTID" ]; then
    echo "Usage: $0 <container_id>"
    exit 1
fi

echo "== Container $CTID Security Checklist =="
echo "Date: $(date)"
echo ""

# Check 1: Is container unprivileged?
echo "1. Unprivileged Mode:"
if pct config $CTID | grep -q "unprivileged: 1"; then
    echo "   ✓ Container is unprivileged"
else
    echo "   ✗ Container is privileged (security risk)"
fi

# Check 2: Is firewall enabled?
echo ""
echo "2. Firewall Status:"
if pct config $CTID | grep -q "firewall: 1"; then
    echo "   ✓ Firewall is enabled"
else
    echo "   ✗ Firewall is disabled"
fi

# Check 3: CPU limit set?
echo ""
echo "3. CPU Limit:"
if pct config $CTID | grep -q "cpulimit"; then
    echo "   ✓ CPU limit is set"
else
    echo "   ⚠ No CPU limit set"
fi

# Check 4: Memory limit set?
echo ""
echo "4. Memory Limit:"
if pct config $CTID | grep -q "memory:"; then
    echo "   ✓ Memory limit is set"
else
    echo "   ⚠ No memory limit set"
fi

# Check 5: Root password set?
echo ""
echo "5. Root Password:"
pct exec $CTID -- passwd -S root | grep -q "P" && echo "   ✓ Root password is set" || echo "   ✗ Root password is not set"

# Check 6: SSH keys configured?
echo ""
echo "6. SSH Keys:"
pct exec $CTID -- test -f /root/.ssh/authorized_keys && echo "   ✓ SSH keys configured" || echo "   ⚠ No SSH keys configured"

echo ""
echo "== Security Checklist Complete =="
EOF
chmod +x /root/container_security_check.sh

# Run security check
/root/container_security_check.sh 100
```

---

## Container Backup Patterns

Container backup strategies.

```bash
# Backup container
vzdump 100 --mode snapshot --storage local-backup --compress zstd

# Backup with stop mode (for critical data)
vzdump 100 --mode stop --storage local-backup --compress zstd

# Backup to specific storage
vzdump 100 --mode snapshot --storage pbs-backup --compress zstd

# Backup with retention
vzdump 100 --mode snapshot --storage local-backup --compress zstd --prune-backups 1

# List backups
ls -lt /var/lib/vz/dump/vzdump-lxc-100*.tar.zst

# Restore container
vzrestore /var/lib/vz/dump/vzdump-lxc-100-2024_01_01-02_00_00.tar.zst 200
```

---

## Summary

### Learning Path Progression

1. **Beginner**: Basic container creation, simple configuration
2. **Intermediate**: Static IP, mount points, resource management
3. **Advanced**: Security hardening, VLAN configuration
4. **Enterprise**: Automated deployment, security compliance

### Real-World Job Skill Mapping

- **DevOps Engineer**: Container patterns, automation
- **SRE**: Resource management, monitoring
- **Security Engineer**: Container security, hardening
- **Cloud Engineer**: Lightweight virtualization

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
