# Service Deployment Guide

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers common service deployment patterns for Proxmox environments:

- **Service Isolation**: Running services in containers vs VMs
- **Network Configuration**: Service networking patterns
- **Resource Management**: Allocating resources to services
- **High Availability**: Service redundancy and failover
- **Monitoring**: Service health and performance monitoring

## When You Need This

- Deploying production services
- Multi-service architectures
- Resource-constrained environments
- High availability requirements
- Service isolation needs

## Simpler Alternative

For most homelab users:
- Use containers for lightweight services
- Single VM for multiple services
- Manual configuration for one-off deployments
- Basic monitoring with simple scripts

---

## Service Deployment Patterns

### Pattern 1: Single Container Per Service

Best for: Lightweight services, resource efficiency

```bash
# Create container for Pi-hole
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 \
  -cores 2 \
  -memory 512 \
  -swap 256 \
  -net0 name=eth0,bridge=vmbr0,firewall=1,vtag=10 \
  -unprivileged 1 \
  -rootfs local-lvm:100,size=5G

# Start container
pct start 100

# Enter container and install Pi-hole
pct enter 100
curl -sSL https://install.pi-hole.net | bash
```

### Pattern 2: Single VM Per Service

Best for: Full OS requirements, complex services, isolation

```bash
# Create VM for Nextcloud
qm create 200 --name nextcloud --memory 4096 --cores 4 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-200-disk-0,size=50G \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --ide2 local:iso/ubuntu-24.04.iso,media=cdrom

# Configure VM
qm set 200 --cpu host --balloon 0
qm set 200 --agent 1
qm set 200 --firewall 1

# Install Nextcloud inside VM
# apt update && apt install -y apache2 php php-mysql php-gd php-xml php-curl
# Follow Nextcloud installation wizard
```

### Pattern 3: Docker Host VM

Best for: Multiple containerized services, flexibility

```bash
# Create Docker host VM
qm create 300 --name docker-host --memory 8192 --cores 4 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-300-disk-0,size=100G \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --ide2 local:iso/ubuntu-24.04.iso,media=cdrom

# Configure VM
qm set 300 --cpu host --balloon 0
qm set 300 --agent 1

# Inside VM - Install Docker
apt update
apt install -y docker.io docker-compose

# Create docker-compose.yml for services
cat > /root/docker-compose.yml << 'EOF'
version: '3.8'
services:
  pi-hole:
    image: pihole/pihole:latest
    container_name: pi-hole
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "8080:80/tcp"
    environment:
      - TZ=UTC
      - VIRTUAL_HOST=pihole.local
    volumes:
      - ./pihole:/etc/pihole
      - ./dnsmasq:/etc/dnsmasq.d
    networks:
      - internal

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    ports:
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - internal
    restart: always

networks:
  internal:
    driver: bridge

volumes:
  portainer_data:
EOF

# Start services
docker-compose up -d
```

---

## Common Service Deployments

### Pi-hole (DNS Ad Blocking)

```bash
# Deploy as LXC container
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 \
  -cores 2 \
  -memory 512 \
  -swap 256 \
  -net0 name=eth0,bridge=vmbr0,firewall=1,vtag=10 \
  -unprivileged 1

# Install Pi-hole
pct enter 100
curl -sSL https://install.pi-hole.net | bash

# Configure firewall
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --type guest \
  --guest 100 \
  --dest-port 53 \
  --proto udp,tcp \
  --name "Allow-DNS"

pvesh create /firewall/rules \
  --ruleid 101 \
  --action accept \
  --type guest \
  --guest 100 \
  --dest-port 80 \
  --proto tcp \
  --name "Allow-Web"
```

### Portainer (Docker Management)

```bash
# Deploy as container on Docker host
docker run -d -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  portainer/portainer-ce:latest
```

### Home Assistant (Home Automation)

```bash
# Deploy as Docker container
docker run -d \
  --name homeassistant \
  --privileged \
  --restart=unless-stopped \
  -e TZ=America/New_York \
  -v /home/homeassistant/config:/config \
  -v /etc/localtime:/etc/localtime:ro \
  homeassistant/home-assistant:latest
```

### Plex Media Server

```bash
# Deploy as Docker container
docker run -d \
  --name plex \
  --restart=unless-stopped \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=America/New_York \
  -v /media/movies:/movies \
  -v /media/tv:/tv \
  -v /config/plex:/config \
  -v /transcode:/transcode \
  -p 32400:32400 \
  --device /dev/dri:/dev/dri \
  plexinc/pms-docker:latest
```

### Node-RED (IoT Automation)

```bash
# Deploy as Docker container
docker run -d \
  --name node-red \
  --restart=unless-stopped \
  -p 1880:1880 \
  -v node-red-data:/data \
  nodered/node-red:latest
```

### Jellyfin (Media Server)

```bash
# Deploy as Docker container
docker run -d \
  --name jellyfin \
  --restart=unless-stopped \
  -e UID=1000 \
  -e GID=1000 \
  -v /media/movies:/movies \
  -v /media/tv:/tv \
  -v /config/jellyfin:/config \
  -p 8096:8096 \
  --device /dev/dri:/dev/dri \
  jellyfin/jellyfin:latest
```

---

## Service Networking

### Service Network Isolation

```bash
# Create isolated network for services
cat > /etc/network/interfaces.d/vmbr1 << 'EOF'
auto vmbr1
iface vmbr1 inet manual
    vlan_aware yes
    bridge-ports eno2
    bridge-stp off
    bridge-fd 0
EOF

# Restart networking
systemctl restart networking

# Deploy services on isolated network
pct create 200 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 \
  -cores 2 \
  -memory 1024 \
  -net0 name=eth0,bridge=vmbr1,firewall=1,vtag=100 \
  -unprivileged 1
```

### Reverse Proxy Configuration

```bash
# Create reverse proxy VM
qm create 300 --name proxy --memory 2048 --cores 2 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-300-disk-0,size=20G \
  --net0 virtio,bridge=vmbr0,firewall=1 \
  --net1 virtio,bridge=vmbr1,firewall=1 \
  --ide2 local:iso/ubuntu-24.04.iso,media=cdrom

# Configure nginx as reverse proxy
cat > /etc/nginx/sites-available/proxy << 'EOF'
server {
    listen 80;
    server_name homelab.local;

    location /pihole {
        proxy_pass http://192.168.10.100;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /portainer {
        proxy_pass http://192.168.10.101:9443;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /homeassistant {
        proxy_pass http://192.168.10.102:8123;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /jellyfin {
        proxy_pass http://192.168.10.103:8096;
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

## Service Monitoring

### Health Check Script

```bash
# Create service health monitoring script
cat > /root/service_monitor.sh << 'EOF'
#!/bin/bash
# Service Health Monitoring Script

LOG_FILE="/var/log/service_monitor.log"
ALERT_EMAIL="admin@example.com"
DATE=$(date +%Y%m%d-%H%M%S)

echo "[$(date)] Service Health Check" >> $LOG_FILE

# Check Docker containers
echo "Checking Docker containers..."
CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
echo "Running containers: $CONTAINERS" >> $LOG_FILE

# Check specific services
check_service() {
    local name=$1
    local port=$2
    local proto=${3:-tcp}
    
    if nc -z -w2 127.0.0.1 $port 2>/dev/null; then
        echo "✓ $name is running" >> $LOG_FILE
    else
        echo "✗ $name is NOT running" >> $LOG_FILE
        echo "ALERT: $name is not responding on port $port" | mail -s "Service Alert" $ALERT_EMAIL
    fi
}

# Check common services
check_service "Pi-hole" 80
check_service "Portainer" 9443
check_service "Home Assistant" 8123
check_service "Jellyfin" 8096
check_service "Node-RED" 1880

echo "[$(date)] Health check completed" >> $LOG_FILE
EOF
chmod +x /root/service_monitor.sh

# Schedule monitoring
echo "*/15 * * * * /root/service_monitor.sh" | crontab -
```

### Resource Usage Monitoring

```bash
# Create resource monitoring script
cat > /root/resource_monitor.sh << 'EOF'
#!/bin/bash
# Service Resource Monitoring Script

LOG_FILE="/var/log/resource_monitor.log"
DATE=$(date +%Y%m%d)

echo "[$(date)] Resource Usage Report" >> $LOG_FILE

# CPU usage
echo "CPU Usage:" >> $LOG_FILE
top -bn1 | grep "Cpu(s)" | awk '{print "  User: "$2"% System: "$4"%"}' >> $LOG_FILE

# Memory usage
echo "Memory Usage:" >> $LOG_FILE
free -h | awk '/^Mem:/ {print "  Total: "$2" Used: "$3" Available: "$7}' >> $LOG_FILE

# Disk usage
echo "Disk Usage:" >> $LOG_FILE
df -h | awk '$5 > 80 {print "  WARNING: "$1" is "$5" full"}' >> $LOG_FILE

# Docker container resource usage
echo "Container Resource Usage:" >> $LOG_FILE
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" >> $LOG_FILE

echo "[$(date)] Resource check completed" >> $LOG_FILE
EOF
chmod +x /root/resource_monitor.sh

# Schedule resource monitoring
echo "0 */6 * * * /root/resource_monitor.sh" | crontab -
```

---

## Service Backup

### Container Backup

```bash
# Backup container configuration
pct config 100 > /root/backups/container-100-config.txt

# Backup container data
pct export 100 /root/backups/container-100-backup.tar.gz

# Schedule container backup
cat > /root/backup_containers.sh << 'EOF'
#!/bin/bash
# Container Backup Script
DATE=$(date +%Y%m%d)
BACKUP_DIR="/root/backups"

# Export all containers
for ctid in $(pct list | grep -E "^[0-9]+" | awk '{print $1}'); do
    echo "Backing up container $ctid..."
    pct export $ctid $BACKUP_DIR/container-$ctid-$DATE.tar.gz
done

# Clean up old backups (keep 30 days)
find $BACKUP_DIR -name "container-*.tar.gz" -mtime +30 -delete
EOF
chmod +x /root/backup_containers.sh

# Add to crontab
echo "0 3 * * * /root/backup_containers.sh" | crontab -
```

### Docker Volume Backup

```bash
# Create Docker volume backup script
cat > /root/backup_docker_volumes.sh << 'EOF'
#!/bin/bash
# Docker Volume Backup Script
DATE=$(date +%Y%m%d)
BACKUP_DIR="/root/backups/docker-volumes"

# List all volumes
docker volume ls -q | while read volume; do
    echo "Backing up volume: $volume"
    docker run --rm \
        -v $volume:/data \
        -v $BACKUP_DIR:/backup \
        alpine tar czf /backup/${volume}-${DATE}.tar.gz /data
done

# Clean up old backups
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
EOF
chmod +x /root/backup_docker_volumes.sh
```

---

## High Availability

### Service Redundancy

```bash
# Deploy multiple instances of critical services
# Instance 1
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 \
  -cores 2 \
  -memory 1024 \
  -net0 name=eth0,bridge=vmbr0,firewall=1,vtag=10 \
  -unprivileged 1

# Instance 2 (backup)
pct create 101 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -arch amd64 \
  -cores 2 \
  -memory 1024 \
  -net0 name=eth0,bridge=vmbr0,firewall=1,vtag=10 \
  -unprivileged 1

# Configure load balancing with nginx
cat > /etc/nginx/sites-available/loadbalance << 'EOF'
upstream services {
    server 192.168.10.100:8080;
    server 192.168.10.101:8080 backup;
}

server {
    listen 80;
    
    location / {
        proxy_pass http://services;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF
```

---

## Service Deployment Scripts

The following scripts can help with service deployment:

### Container Management
- [`scripts/containers/create_container.sh`](../scripts/containers/create_container.sh:1) — create LXC containers from templates
  - Usage: `bash scripts/containers/create_container.sh -i <ctid> -n <name> -t <template> [options]`
  - See: Pattern 1 above for container deployment

- [`scripts/containers/destroy_container.sh`](../scripts/containers/destroy_container.sh:1) — destroy containers
  - Usage: `bash scripts/containers/destroy_container.sh -i <ctid(s)>`

- [`scripts/containers/list_templates.sh`](../scripts/containers/list_templates.sh:1) — list available LXC templates
  - Usage: `bash scripts/containers/list_templates.sh`

### VM Management
- [`scripts/vm/clone_vm.sh`](../scripts/vm/clone_vm.sh:1) — clone VMs from templates
  - Usage: `bash scripts/vm/clone_vm.sh -s <source> -d <dest> -n <name> [options]`
  - See: Pattern 2 above for VM deployment

- [`scripts/vm/destroy_vm.sh`](../scripts/vm/destroy_vm.sh:1) — destroy VMs
  - Usage: `bash scripts/vm/destroy_vm.sh -i <vmid(s)>`

- [`scripts/vm/info.sh`](../scripts/vm/info.sh:1) — display detailed VM/container information
  - Usage: `bash scripts/vm/info.sh <vmid_or_name>`
  - Useful for service inventory

- [`scripts/vm/find_ip.sh`](../scripts/vm/find_ip.sh:1) — find IP address of VM/container
  - Usage: `bash scripts/vm/find_ip.sh <vmid_or_name>`
  - Useful for service access

### Network Management
- [`scripts/network/show.sh`](../scripts/network/show.sh:1) — display network configurations
  - Usage: `bash scripts/network/show.sh [options]`
  - Options: `-v` (VLAN), `-i` (IP), `-b` (bridge)
  - Useful for service network planning

### Status & Monitoring
- [`scripts/status.sh`](../scripts/status.sh:1) — display VM/container status dashboard
  - Usage: `bash scripts/status.sh`
  - Useful for service health overview

---

## Learning Path Progression

1. **Beginner**: Deploy single services in containers
2. **Intermediate**: Multiple services with Docker Compose
3. **Advanced**: Service isolation, networking, monitoring
4. **Enterprise**: High availability, automated deployment

## Real-World Job Skill Mapping

- **DevOps Engineer**: All sections apply directly
- **SRE**: Service monitoring, high availability
- **Cloud Engineer**: Service deployment patterns
- **Platform Engineer**: Infrastructure for services

---

## Related Documentation

- **Container Patterns**: See [`container-patterns.md`](container-patterns.md)
- **VM Patterns**: See [`vm-patterns.md`](vm-patterns.md)
- **Networking**: See [`networking/`](../networking/)
- **Security**: See [`security/`](../security/)
- **Backup**: See [`backup/`](../backup/) for service backup strategies

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
