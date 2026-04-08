# VM Deployment Patterns Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers VM deployment patterns and best practices:

- **VM Deployment Patterns**: Common VM configuration patterns
- **Template Management**: VM template creation and usage
- **Resource Optimization**: CPU, memory, and storage allocation
- **High Availability**: VM HA and clustering
- **VM Migration**: Live migration techniques

## When You Need This

- Full OS requirements
- Hardware passthrough needs
- Complex application stacks
- High availability requirements
- Multi-tier architectures

## Simpler Alternative

For most homelab users:
- Use containers for lightweight services
- Simple VM for single applications
- Manual VM creation for one-off deployments
- Test patterns in non-production first

---

## VM Deployment Patterns

### Pattern 1: Web Server VM

Create a web server VM.

```bash
# Create web server VM
qm create 100 --name webserver --memory 2048 --cores 2 --cpu host \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-100-disk-0,size=20G \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --ide2 local:iso/ubuntu-24.04.iso,media=cdrom

# Configure VM after installation
qm set 100 --cpu host --cores 2 --memory 2048
qm set 100 --net0 virtio,bridge=vmbr0,firewall=1,ip=192.168.1.100/24,gw=192.168.1.1
qm set 100 --balloon 0

# Install QEMU guest agent
qm set 100 --agent 1

# Enable firewall
qm set 100 --firewall 1

# Start VM
qm start 100
```

> **⚠️ PITFALL**: Over-allocation of resources can affect other VMs.

---

### Pattern 2: Database Server VM

Create a database server VM with optimized settings.

```bash
# Create database server VM
qm create 200 --name database --memory 8192 --cores 4 --cpu host \
  --scsihw virtio-scsi-pci \
  --scsi0 local-zfs:vm-200-disk-0,size=100G \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --ide2 local:iso/ubuntu-24.04.iso,media=cdrom

# Configure VM after installation
qm set 200 --cpu host --cores 4 --memory 8192 --balloon 0
qm set 200 --net0 virtio,bridge=vmbr0,firewall=1,ip=192.168.1.200/24,gw=192.168.1.1
qm set 200 --agent 1

# Enable I/O threading for database performance
qm set 200 --iothread 1

# Configure database-specific firewall rules
pvesh create /firewall/rules \
  --ruleid 200 \
  --action accept \
  --type guest \
  --guest 200 \
  --source 192.168.1.0/24 \
  --dest-port 3306,5432 \
  --proto tcp \
  --name "Allow-Database-App"

# Start VM
qm start 200
```

> **⚠️ PITFALL**: Storage performance and resource contention.

---

### Pattern 3: Application Server VM

Create an application server VM with Docker.

```bash
# Create application server VM
qm create 300 --name appserver --memory 4096 --cores 4 --cpu host \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-300-disk-0,size=50G \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --ide2 local:iso/ubuntu-24.04.iso,media=cdrom

# Configure VM after installation
qm set 300 --cpu host --cores 4 --memory 4096 --balloon 0
qm set 300 --net0 virtio,bridge=vmbr0,firewall=1,ip=192.168.1.300/24,gw=192.168.1.1
qm set 300 --agent 1

# Configure for Docker
qm set 300 --usb0 host=XX:XX,usb3=1

# Start VM
qm start 300

# Inside VM - Install Docker
apt update
apt install -y docker.io docker-compose
systemctl enable docker
systemctl start docker
```

---

### Pattern 4: File Server VM

Create a file server VM with Samba/NFS.

```bash
# Create file server VM
qm create 400 --name fileserver --memory 4096 --cores 2 --cpu host \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-400-disk-0,size=100G \
  --scsi1 local-lvm:vm-400-disk-1,size=500G \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --ide2 local:iso/ubuntu-24.04.iso,media=cdrom

# Configure VM after installation
qm set 400 --cpu host --cores 2 --memory 4096 --balloon 0
qm set 400 --net0 virtio,bridge=vmbr0,firewall=1,ip=192.168.1.400/24,gw=192.168.1.1
qm set 400 --agent 1

# Inside VM - Setup Samba/NFS
apt install -y samba nfs-kernel-server

# Configure Samba
cat > /etc/samba/smb.conf << 'EOF'
[global]
   workgroup = WORKGROUP
   security = user
   map to guest = bad user

[shared]
   path = /srv/samba/shared
   browseable = yes
   writable = yes
   guest ok = no
   create mask = 0755
   directory mask = 0755
EOF

mkdir -p /srv/samba/shared
chmod 2770 /srv/samba/shared
chown root:samba /srv/samba/shared

systemctl enable smbd
systemctl start smbd

# Configure NFS
echo "/srv/nfs *(rw,sync,no_subtree_check)" > /etc/exports
mkdir -p /srv/nfs
systemctl enable nfs-kernel-server
systemctl start nfs-kernel-server
```

---

### Pattern 5: Proxy Server VM

Create a reverse proxy VM.

```bash
# Create proxy server VM
qm create 500 --name proxy --memory 2048 --cores 2 --cpu host \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-500-disk-0,size=20G \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --net1 virtio,bridge=vmbr0,firewall=1 \
  --ide2 local:iso/ubuntu-24.04.iso,media=cdrom

# Configure VM after installation
qm set 500 --cpu host --cores 2 --memory 2048 --balloon 0
qm set 500 --net0 virtio,bridge=vmbr0,firewall=1,ip=192.168.1.500/24,gw=192.168.1.1
qm set 500 --net1 virtio,bridge=vmbr0,firewall=1,ip=10.0.0.1/24
qm set 500 --agent 1

# Inside VM - Setup Reverse Proxy
apt install -y nginx

# Configure nginx as reverse proxy
cat > /etc/nginx/sites-available/proxy << 'EOF'
server {
    listen 80;
    server_name proxy.local;

    location / {
        proxy_pass http://192.168.1.100;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /api {
        proxy_pass http://192.168.1.200:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

---

## VM Template Patterns

Create and use VM templates.

```bash
# Create template from configured VM
qm stop 100
qm set 100 --agent 1
qm template 100

# Clone from template
qm clone 100 101 --name webserver-02 --full

# Create cloud-init template
qm create 9999 --name cloud-init-template --memory 2048 --cores 2 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-9999-disk-0,size=20G \
  --net0 virtio,bridge=vmbr0 \
  --ide2 local:iso/cloud-init.iso,media=cdrom

# Configure cloud-init
qm set 9999 --ciuser admin --sshkey ~/.ssh/id_rsa.pub
qm set 9999 --ipconfig0 ip=192.168.1.50/24,gw=192.168.1.1
qm template 9999

# Clone cloud-init template
qm clone 9999 100 --name webserver-01 --full
```

> **⚠️ PITFALL**: Template drift and outdated templates.

---

## VM Migration Patterns

Migrate VMs between nodes.

```bash
# Online migration (VM stays running)
qm migrate 100 pve2 --online 1

# Offline migration (VM stops during migration)
qm migrate 100 pve2 --offline 1

# Migrate with storage change
qm migrate 100 pve2 --storage local-zfs --online 1

# Migrate with resource adjustment
qm migrate 100 pve2 --online 1 --target-memory 4096

# List migration options
qm migrate 100 --help
```

---

## VM High Availability

Configure VM HA.

```bash
# Enable HA for VM
pvesh create /cluster/ha/groups \
  --groupid default \
  --nodes pve1,pve2,pve3

pvesh create /cluster/ha/resources \
  --rid vm:100 \
  --group default \
  --type qemu \
  --vmid 100

# Configure HA settings
pvesh create /cluster/ha/resources \
  --rid vm:100 \
  --group default \
  --type qemu \
  --vmid 100 \
  --maxrestart 3 \
  --maxrelocate 1

# Check HA status
pvesh get /cluster/ha/resources

# Remove HA from VM
pvesh delete /cluster/ha/resources --rid vm:100
```

> **⚠️ PITFALL**: Quorum requirements and split-brain scenarios.

---

## VM Resource Optimization

Optimize VM resources.

```bash
# Enable KVM acceleration
qm set 100 --kvm 1

# Set CPU type
qm set 100 --cpu host

# Enable NUMA
qm set 100 --numa 1

# Set hugepages for performance
qm set 100 --memory 4096 --balloon 0

# Enable I/O threading
qm set 100 --iothread 1

# Optimize disk I/O
qm set 100 --scsi0 local-lvm:vm-100-disk-0,size=20G,iothread=1

# Check VM performance
qm monitor 100
# Type: info blockstats
# Type: info cpustats
```

---

## VM Backup Patterns

VM backup strategies.

```bash
# Full backup
vzdump 100 --mode stop --storage local-backup --compress zstd

# Snapshot backup (no downtime)
vzdump 100 --mode snapshot --storage local-backup --compress zstd

# Incremental backup
vzdump 100 --mode snapshot --storage local-backup --compress zstd --incremental 1

# Backup with retention
vzdump 100 --mode snapshot --storage local-backup --compress zstd --prune-backups 1

# Backup to PBS
vzdump 100 --mode snapshot --storage pbs-backup --compress zstd

# Schedule backup
cat > /etc/cron.d/vm-backup << 'EOF'
0 2 * * * root vzdump 100 --mode snapshot --storage local-backup --compress zstd
EOF
```

---

## Summary

### Learning Path Progression

1. **Beginner**: Basic VM creation, simple configuration
2. **Intermediate**: Templates, migration, resource optimization
3. **Advanced**: HA configuration, performance tuning
4. **Enterprise**: Multi-node clusters, automated deployment

### Real-World Job Skill Mapping

- **Cloud Engineer**: VM patterns, migration, HA
- **DevOps Engineer**: Template management, automation
- **SRE**: Resource optimization, backup strategies
- **Platform Engineer**: VM deployment patterns

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
