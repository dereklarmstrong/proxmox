# Beginner Learning Path

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What Enterprise Skills You'll Learn

- **Basic VM/LXC Management**: Creating and managing virtual machines and containers
- **Simple Backup**: Local backup strategies
- **Basic Networking**: Bridge networking, IP configuration
- **System Administration**: Linux basics, package management
- **Proxmox GUI**: Web interface navigation and configuration

## When You Actually Need This in Production

- Small homelab deployments
- Learning virtualization concepts
- Single-node Proxmox setups
- Basic service hosting
- Skill development

## Simpler Alternative for Daily Services

For most homelab users:
- Use Proxmox GUI for all operations
- Manual configuration for one-off deployments
- Default settings for networking
- Simple backup schedules

---

## Week 1-2: Proxmox Basics

### Topics

1. **Proxmox Installation and Setup**
   - Download and install Proxmox VE
   - Initial configuration via web UI
   - User and permission management

2. **Basic VM Creation**
   - Creating a VM from ISO
   - Installing operating system
   - Basic VM configuration

3. **Basic LXC Container Creation**
   - Creating container from template
   - Installing packages
   - Basic container configuration

### Resources

- [docs/cheatsheet.md](docs/cheatsheet.md)
- [qm_cheatsheet.md](qm_cheatsheet.md)

### Hands-On Exercises

```bash
# 1. Create a basic VM
qm create 100 --name test-vm --memory 2048 --cores 2 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-100-disk-0,size=20G \
  --net0 virtio,bridge=vmbr0

# 2. Create a basic container
pct create 200 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 -cores 2 -memory 1024 -swap 512 \
  -net0 name=eth0,bridge=vmbr0,firewall=1 \
  -unprivileged 1

# 3. Start and access VM
qm start 100
qm terminal 100

# 4. Start and access container
pct start 200
pct enter 200
```

---

## Week 3-4: Basic Networking

### Topics

1. **Bridge Networking**
   - Understanding network bridges
   - Configuring vmbr0
   - VM/container network access

2. **IP Address Configuration**
   - Static IP assignment
   - DHCP configuration
   - Network troubleshooting

3. **Basic Firewall**
   - Enabling Proxmox firewall
   - Basic firewall rules
   - Network security basics

### Resources

- [NETWORKING/VLAN_SETUP.md](NETWORKING/VLAN_SETUP.md) - Basic sections only

### Hands-On Exercises

```bash
# 1. Check network configuration
ip addr show
ip route show

# 2. Configure static IP for VM
qm set 100 --net0 virtio,bridge=vmbr0,ip=192.168.1.100/24,gw=192.168.1.1

# 3. Enable firewall
pve-firewall enable
pvesh create /firewall/options --enabled 1

# 4. Create basic firewall rule
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --type guest \
  --guest 100 \
  --dest-port 22 \
  --proto tcp \
  --name "Allow-SSH"
```

---

## Week 5-6: Basic Backup

### Topics

1. **Local Backup**
   - Creating vzdump backups
   - Backup storage configuration
   - Backup scheduling

2. **Backup Restoration**
   - Restoring VM from backup
   - Restoring container from backup
   - Testing restore procedures

3. **Backup Retention**
   - Simple retention policies
   - Storage management
   - Backup verification

### Resources

- [BACKUP_STRATEGY.md](BACKUP_STRATEGY.md) - Basic sections only
- [BACKUP/RESTORE_PROCEDURES.md](BACKUP/RESTORE_PROCEDURES.md) - Basic restore

### Hands-On Exercises

```bash
# 1. Create backup
vzdump 100 --mode snapshot --storage local-backup --compress zstd

# 2. List backups
ls -lt /var/lib/vz/dump/

# 3. Restore VM
qmrestore /var/lib/vz/dump/vzdump-qemu-100-*.vma.zst 200 --storage local-lvm

# 4. Create backup schedule
cat > /etc/cron.d/backup << 'EOF'
0 2 * * * root vzdump 100 --mode snapshot --storage local-backup --compress zstd
EOF
```

---

## Week 7-8: System Administration

### Topics

1. **Linux Package Management**
   - apt package management
   - Installing and updating packages
   - Service management

2. **SSH Configuration**
   - SSH key setup
   - SSH hardening basics
   - Remote access

3. **System Monitoring**
   - Basic system monitoring
   - Log analysis
   - Resource usage

### Resources

- [SECURITY.md](SECURITY.md) - Basic SSH hardening

### Hands-On Exercises

```bash
# 1. Update system
apt update && apt upgrade -y

# 2. Install monitoring tools
apt install -y htop iotop nethogs

# 3. Configure SSH keys
ssh-keygen -t ed25519
ssh-copy-id root@proxmox-server

# 4. Monitor system
htop
iostat -x 1
```

---

## Beginner Milestones

### Checkpoint 1: Week 4

- [ ] Can create VM from ISO
- [ ] Can create LXC container from template
- [ ] Can access VM/container console
- [ ] Can start/stop/restart VMs and containers

### Checkpoint 2: Week 6

- [ ] Can configure static IP for VM/container
- [ ] Can enable and configure basic firewall
- [ ] Can troubleshoot basic network issues
- [ ] Can ping external hosts from VM/container

### Checkpoint 3: Week 8

- [ ] Can create and restore backups
- [ ] Can schedule automated backups
- [ ] Can update and manage system packages
- [ ] Can configure SSH key authentication

---

## Next Steps

After completing the beginner path:

1. **Review and Practice**: Revisit exercises and ensure comfort
2. **Explore More**: Try different operating systems
3. **Document**: Keep notes on what you've learned
4. **Plan Next Path**: Move to intermediate level

---

## Recommended Resources

- **Proxmox Documentation**: https://pve.proxmox.com/pve-docs/
- **Proxmox Community Forum**: https://forum.proxmox.com/
- **Proxmox VE YouTube Channel**: https://www.youtube.com/c/Proxmox

---

## Common Beginner Mistakes

1. **Not backing up before changes**: Always backup before making significant changes
2. **Ignoring firewall**: Enable firewall early for security
3. **Over-allocating resources**: Start with minimal resources
4. **Not testing restores**: Test backup restoration regularly
5. **Skipping documentation**: Document your configuration

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
