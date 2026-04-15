# Intermediate Learning Path

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What Enterprise Skills You'll Learn

- **VLANs and Network Segmentation**: Network isolation and segmentation
- **PBS Backup**: Proxmox Backup Server integration
- **Basic Automation**: Shell scripting and API usage
- **Advanced Networking**: Inter-VLAN routing, bridge configuration
- **Container Orchestration**: Docker and Docker Compose

## When You Actually Need This in Production

- Multi-service environments
- Network segmentation requirements
- Automated backup strategies
- Service isolation needs
- Scalability requirements

## Simpler Alternative for Daily Services

For most homelab users:
- Single network for all services
- Local backups without PBS
- Manual configuration
- Simple service deployment

---

## Week 1-2: Advanced Networking

### Topics

1. **VLAN Configuration**
   - VLAN-aware bridges
   - VLAN tagging
   - VLAN assignment to VMs/containers

2. **Inter-VLAN Routing**
   - Router configuration
   - Firewall rules between VLANs
   - Network segmentation

3. **Network Troubleshooting**
   - tcpdump analysis
   - Network diagnostics
   - VLAN debugging

### Resources

- [networking/vlan-setup.md](networking/vlan-setup.md)
- [networking/firewall-rules.md](networking/firewall-rules.md)

### Hands-On Exercises

```bash
# 1. Create VLAN-aware bridge
cat >> /etc/network/interfaces << 'EOF'

auto vmbr0
iface vmbr0 inet manual
    vlan_aware yes
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
EOF

# 2. Create VM with VLAN
qm create 100 --name vlan-vm --memory 2048 --cores 2 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-100-disk-0,size=20G \
  --net0 vlan=10,bridge=vmbr0,firewall=1

# 3. Create container with VLAN
pct create 200 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 -cores 2 -memory 1024 -swap 512 \
  -net0 name=eth0,bridge=vmbr0,firewall=1,vtag=20 \
  -unprivileged 1

# 4. Configure inter-VLAN routing
cat >> /etc/network/interfaces << 'EOF'

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
EOF

# 5. Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# 6. Configure firewall rules
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --source 192.168.10.0/24 \
  --dest 192.168.20.0/24 \
  --name "Allow-VLAN10-to-VLAN20"
```

---

## Week 3-4: Proxmox Backup Server

### Topics

1. **PBS Installation**
   - PBS server setup
   - Repository configuration
   - Client connection

2. **Backup Configuration**
   - Backup job setup
   - GFS retention
   - Backup encryption

3. **Restore Procedures**
   - VM restore from PBS
   - Container restore
   - Disaster recovery

### Resources

- [backup/pbs-setup.md](backup/pbs-setup.md)
- [backup/gfs-strategy.md](backup/gfs-strategy.md)
- [backup/restore-procedures.md](backup/restore-procedures.md)

### Hands-On Exercises

```bash
# 1. Create PBS repository
pvesh create /storage/pbs-backup \
  --type directory \
  --path /backup \
  --content backup,images

# 2. Configure PBS on Proxmox
cat > /etc/pve/pbs.cfg << 'EOF'
pbs-server pbs.example.com:8007
pbs-user backup-user@pbs
pbs-password your-password
EOF

# 3. Create backup job with GFS
pvesh create /cluster/backupjob \
  --id daily-backup \
  --schedule "0 2 * * *" \
  --storage pbs-backup \
  --mode snapshot \
  --all 1 \
  --enabled 1 \
  --prune-backups 1 \
  --gfs-daily 7 \
  --gfs-weekly 4 \
  --gfs-monthly 12

# 4. Verify backup
pbs-backup-client list --repository pbs-backup

# 5. Restore from PBS
pvesh create /storage/pbs-backup/restore \
  --vmid 200 \
  --backup vzdump-qemu-100-20240101T020000
```

---

## Week 5-6: Basic Automation

### Topics

1. **Shell Scripting**
   - Bash scripting basics
   - Variable usage
   - Control structures

2. **Proxmox API**
   - API token creation
   - API requests
   - Scripting with API

3. **Task Automation**
   - Scheduled tasks with cron
   - Backup automation
   - Monitoring scripts

### Resources

- [scripts/api/api_request.sh](scripts/api/api_request.sh)
- [scripts/backup/backup_all.sh](scripts/backup/backup_all.sh)

### Hands-On Exercises

```bash
# 1. Create API token
pvesh create /access/token \
  --userid root@pam \
  --description "automation" \
  --privsep 0

# 2. Create backup automation script
cat > /root/backup_all.sh << 'EOF'
#!/bin/bash
# Backup all VMs and containers

BACKUP_STORAGE="local-backup"
LOG_FILE="/var/log/backup_all.log"

echo "Starting backup at $(date)" >> $LOG_FILE

# Get all VM IDs
VM_IDS=$(qm list | grep -E "^[0-9]+" | awk '{print $1}')

# Backup each VM
for VM_ID in $VM_IDS; do
    echo "Backing up VM $VM_ID..." >> $LOG_FILE
    vzdump $VM_ID --mode snapshot --storage $BACKUP_STORAGE --compress zstd
    echo "Completed VM $VM_ID" >> $LOG_FILE
done

# Get all container IDs
CT_IDS=$(pct list | grep -E "^[0-9]+" | awk '{print $1}')

# Backup each container
for CT_ID in $CT_IDS; do
    echo "Backing up CT $CT_ID..." >> $LOG_FILE
    vzdump $CT_ID --mode snapshot --storage $BACKUP_STORAGE --compress zstd
    echo "Completed CT $CT_ID" >> $LOG_FILE
done

echo "Backup completed at $(date)" >> $LOG_FILE
EOF
chmod +x /root/backup_all.sh

# 3. Schedule backup
echo "0 2 * * * /root/backup_all.sh" | crontab -

# 4. Create monitoring script
cat > /root/monitor_system.sh << 'EOF'
#!/bin/bash
# System monitoring script

LOG_FILE="/var/log/monitor.log"

# Check disk usage
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
echo "$(date): Disk usage: ${DISK_USAGE}%" >> $LOG_FILE

# Check memory usage
MEM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
echo "$(date): Memory usage: ${MEM_USAGE}%" >> $LOG_FILE

# Check for failed services
FAILED=$(systemctl --failed --no-legend | wc -l)
echo "$(date): Failed services: $FAILED" >> $LOG_FILE

# Alert if thresholds exceeded
if [ $DISK_USAGE -gt 80 ]; then
    echo "WARNING: Disk usage exceeds 80%" | mail -s "Alert" admin@example.com
fi

if [ $(echo "$MEM_USAGE > 80" | bc) -eq 1 ]; then
    echo "WARNING: Memory usage exceeds 80%" | mail -s "Alert" admin@example.com
fi
EOF
chmod +x /root/monitor_system.sh
```

---

## Week 7-8: Docker and Container Orchestration

### Topics

1. **Docker Basics**
   - Container concepts
   - Docker commands
   - Image management

2. **Docker Compose**
   - Multi-service stacks
   - Network configuration
   - Volume management

3. **Service Deployment**
   - Web server deployment
   - Database deployment
   - Monitoring stack

### Resources

- [services/container-patterns.md](services/container-patterns.md)
- [services/service-deployments.md](services/service-deployments.md)

### Hands-On Exercises

```bash
# 1. Install Docker
apt update
apt install -y docker.io docker-compose

# 2. Deploy Pi-hole
docker run -d \
  --name pi-hole \
  -p 53:53/tcp \
  -p 53:53/udp \
  -p 8080:80/tcp \
  -e TZ=UTC \
  -v ./pihole:/etc/pihole \
  -v ./dnsmasq:/etc/dnsmasq.d \
  --restart=always \
  pihole/pihole:latest

# 3. Create docker-compose.yml
cat > /root/docker-compose.yml << 'EOF'
version: '3.8'

services:
  web:
    image: nginx:alpine
    container_name: web
    ports:
      - "80:80"
    volumes:
      - ./web/html:/usr/share/nginx/html:ro
    restart: always

  database:
    image: postgres:15-alpine
    container_name: database
    environment:
      - POSTGRES_USER=app
      - POSTGRES_PASSWORD=secret
      - POSTGRES_DB=appdb
    volumes:
      - postgres-data:/var/lib/postgresql/data
    restart: always

volumes:
  postgres-data:
EOF

# 4. Start stack
docker-compose up -d

# 5. Create monitoring stack
cat > /root/docker-compose-monitoring.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus-data:/prometheus
    restart: always

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
    restart: always
    depends_on:
      - prometheus

volumes:
  prometheus-data:
  grafana-data:
EOF

docker-compose -f docker-compose-monitoring.yml up -d
```

---

## Intermediate Milestones

### Checkpoint 1: Week 4

- [ ] Can create and configure VLANs
- [ ] Can set up inter-VLAN routing
- [ ] Can configure firewall rules between VLANs
- [ ] Can troubleshoot network issues with tcpdump

### Checkpoint 2: Week 6

- [ ] Can install and configure PBS
- [ ] Can create backup jobs with GFS retention
- [ ] Can restore VMs and containers from PBS
- [ ] Can verify backup integrity

### Checkpoint 3: Week 8

- [ ] Can write basic bash scripts
- [ ] Can use Proxmox API for automation
- [ ] Can schedule automated tasks with cron
- [ ] Can deploy multi-service stacks with Docker Compose

---

## Next Steps

After completing the intermediate path:

1. **Review and Practice**: Revisit exercises and ensure comfort
2. **Explore More**: Try Terraform and Ansible
3. **Document**: Keep notes on what you've learned
4. **Plan Next Path**: Move to advanced level

---

## Recommended Resources

- **Proxmox Documentation**: https://pve.proxmox.com/pve-docs/
- **Docker Documentation**: https://docs.docker.com/
- **Bash Scripting Guide**: https://linuxconfig.org/bash-scripting-tutorial
- **Ansible Documentation**: https://docs.ansible.com/

---

## Common Intermediate Mistakes

1. **Over-complicating network**: Start simple, add complexity gradually
2. **Not testing PBS restores**: Always test restore procedures
3. **Hardcoding in scripts**: Use variables and configuration files
4. **Ignoring security**: Enable firewall, use strong passwords
5. **Not monitoring**: Set up monitoring early

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
