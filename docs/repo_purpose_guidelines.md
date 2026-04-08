## **REPOSITORY HIGH-LEVEL REQUIREMENTS**

### **1. Repository Philosophy & Positioning**
**Core Message:** "This is a learning repository. Production homelabs should prioritize simplicity over complexity. Use these advanced techniques to learn skills, not because you need them for daily services."

**Key Teaching Points:**
- Every advanced technique includes: "What you'll learn" + "When you actually need this"
- Emphasize: "Keep it simple for production services you rely on"
- Position as: "Skills development lab" not "Production best practices"
- Include: "Simpler alternative" for every complex solution

---

### **2. Core Sections Required**

#### **A. Foundation & Setup**
- **Initial Configuration**: Community repo setup, security hardening, updates
- **Storage Strategy**: ZFS vs LVM vs Directory (with decision matrix)
- **Networking**: VLANs, bridges, SDN, L2 vs L3 routing
- **Backup Basics**: Local snapshots vs PBS integration

**Key Snippets to Include:**
```bash
# Community repo setup (PVE 8.x)
echo "deb http://download.proxmox.com/debian/pve $(lsb_release -cs) pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
apt update && apt dist-upgrade -y

# Storage decision matrix
# ZFS: Data integrity, snapshots, RAID - Use for: VM storage, critical data
# LVM-Thin: Performance, thin provisioning - Use for: High I/O, smaller setups
# Directory: Simplest - Use for: ISO storage, non-critical data
```

#### **B. GPU Passthrough (AI & Gaming Focus)**
**Two Use Cases:**
1. **Gaming VMs**: Near-native performance for Windows gaming
2. **AI Workloads**: CUDA/ROCm for local LLMs, ML training

**Learning Outcomes:**
- IOMMU groups and VFIO
- BIOS/UEFI configuration
- Driver management in VMs
- Troubleshooting passthrough failures

**Key Snippets:**
```bash
# Enable IOMMU in GRUB
GRUB_CMDLINE_LINUX="amd_iommu=on intel_iommu=on iommu=pt"

# Blacklist GPU drivers on host
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf

# Load VFIO modules
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules
echo "vfio_virqfd" >> /etc/modules

# GPU passthrough configuration (qm set)
qm set 100 --args '-device vfio-pci,host=01:00.0,x-vga=on'

# For AI workloads - NVIDIA CUDA setup in VM
apt install -y nvidia-driver cuda-toolkit nvidia-smi
nvidia-smi  # Verify GPU is accessible

# For AI workloads - AMD ROCm setup in VM
apt install -y rocm-dev hipblas rocblas
rocminfo  # Verify GPU is accessible

# Hugepages for AI workloads (critical for performance)
echo "hugepages=8192" >> /etc/default/grub
update-grub
```

#### **C. DevOps & SRE Automation (Learning Focus)**
**Disclaimer Required:** "These techniques are for learning enterprise skills. A simple homelab running daily services should prioritize stability over automation complexity."

**Techniques to Cover:**
1. **Terraform**: Infrastructure as Code for VM/LXC provisioning
2. **Ansible**: Configuration management and deployment automation
3. **Cloud-init**: Automated VM initialization
4. **GitOps**: Version control for infrastructure
5. **CI/CD**: Automated testing and deployment pipelines

**Key Snippets:**
```bash
# Terraform provider setup (main.tf)
terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  pm_api_url = "https://your-proxmox:8006/api2/json"
  pm_api_token_id = "root@pam!terraform"
  pm_api_token_secret = "your-token-secret"
  pm_tls_insecure = true
}

# Terraform VM resource example
resource "proxmox_vm_qemu" "webserver" {
  count = 2
  name = "webserver-${count.index}"
  target_node = "pve"
  cores = 2
  sockets = 1
  cpu = "host"
  memory = 2048
  scsihw = "virtio-scsi-pci"
  
  disk {
    disk_size = 20
    format = "qcow2"
    type = "scsi"
    storage = "local-lvm"
  }
  
  network {
    model = "virtio"
    bridge = "vmbr0"
    firewall = "true"
  }
  
  cloudinit_cdrom_storage = "local"
  os_type = "cloud-init"
  os_type = "l26"
}

# Ansible playbook for VM deployment (site.yml)
---
- name: Deploy and configure VMs
  hosts: proxmox_nodes
  gather_facts: no
  tasks:
    - name: Create VM from template
      proxmox_kvm:
        api_host: "{{ proxmox_api_host }}"
        api_user: "{{ proxmox_api_user }}"
        api_token_id: "{{ proxmox_api_token_id }}"
        api_token_secret: "{{ proxmox_api_token_secret }}"
        node: "{{ proxmox_node }}"
        name: "{{ vm_name }}"
        vmid: "{{ vm_id }}"
        clone: "{{ vm_template }}"
        state: present
    
    - name: Configure VM networking
      proxmox_kvm:
        api_host: "{{ proxmox_api_host }}"
        api_user: "{{ proxmox_api_user }}"
        api_token_id: "{{ proxmox_api_token_id }}"
        api_token_secret: "{{ proxmox_api_token_secret }}"
        node: "{{ proxmox_node }}"
        vmid: "{{ vm_id }}"
        net0: "bridge=vmbr0,ip={{ vm_ip }}/24,gateway={{ vm_gateway }}"
        state: present

# Cloud-init user-data example
#cloud-config
hostname: webserver-01
timezone: UTC
users:
  - name: admin
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAA... your-public-key
chpasswd:
  expire: false
packages:
  - nginx
  - docker.io
runcmd:
  - systemctl enable nginx
  - systemctl start nginx
  - usermod -aG docker admin
```

#### **D. Security Hardening (Real-World Job Skills)**
**Learning Outcomes:**
- CIS benchmark compliance
- Zero Trust architecture concepts
- Incident response preparation
- Security auditing and monitoring

**Key Snippets:**
```bash
# SSH hardening
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
systemctl restart sshd

# Enable 2FA for web interface
apt install libpam-google-authenticator
pam-auth-update --enable pam_google_authenticator
nano /etc/pam.d/common-auth
# Add: auth required pam_google_authenticator.so

# Proxmox firewall configuration
pve-firewall enable
pvesh create /firewall/options --enabled 1
pvesh create /firewall/rules --ruleid 100 --action accept --type guest

# TLS certificate hardening
# Generate self-signed cert with strong settings
openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
  -keyout /etc/pve/pve-ssl.key \
  -out /etc/pve/pve-ssl.crt \
  -subj "/CN=your-proxmox"

# Update cipher suites
echo "SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256" > /etc/default/pveproxy

# Security auditing with Lynis
apt install lynis
lynis audit system
```

#### **E. Backup & Disaster Recovery (Production-Grade Skills)**
**Learning Outcomes:**
- 3-2-1 backup rule implementation
- GFS (Grandfather-Father-Son) retention strategy
- Incremental vs differential backups
- Disaster recovery testing

**Key Snippets:**
```bash
# Proxmox Backup Server setup
# Install PBS on separate server
# Create backup repository
pvesh create /storage/pbs-backup --type directory --path /backup

# Configure backup job with GFS retention
pvesh create /cluster/backup \
  --id datacenter-backup \
  --schedule "0 2 * * *" \
  --storage pbs-backup \
  --mode snapshot \
  --all 1 \
  --enabled 1 \
  --prune-backups 1 \
  --gfs-weekly 4 \
  --gfs-monthly 12 \
  --gfs-yearly 2

# Backup command with encryption
vzdump 100 --mode stop --storage pbs-backup --compress zstd \
  --password-file /etc/pve/pve-backup.json

# Restore from backup
vzdump 100 --restore-storage pbs-backup --target pbs-backup

# Backup verification script
#!/bin/bash
BACKUP_ID=$(proxmox-backup-client list --repository your-repo | tail -1 | awk '{print $1}')
proxmox-backup-client verify --repository your-repo --id $BACKUP_ID

# GFS Retention Strategy Example
# Daily (Son): Keep 7 days
# Weekly (Father): Keep 4 weeks  
# Monthly (Grandfather): Keep 12 months
# Yearly: Keep 2 years
```

#### **F. Service Deployment Patterns**
**Learning Outcomes:**
- Container orchestration concepts
- Service isolation strategies
- Network segmentation
- Resource management

**Key Snippets:**
```bash
# LXC container for lightweight services
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.gz \
  -arch amd64 -cores 2 -memory 1024 -swap 512 \
  -net0 name=eth0,bridge=vmbr0,firewall=1,vtag=10 \
  -unprivileged 1

# VM for Docker with ZFS storage
qm create 200 --name docker-host --memory 4096 --cores 4 \
  --scsi0 local-zfs:vm-200-disk-0,size=50G \
  --net0 virtio,bridge=vmbr0,firewall=1

# Docker inside VM (recommended for isolation)
docker run -d -p 8006:8000 -p 9443:9443 \
  --name portainer --restart=always \
  -v /mnt/pve/docker-storage:/var/lib/docker \
  portainer/portainer-ce:latest

# Docker Compose for multi-service stacks
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

# Network segmentation with VLANs
# Create VLAN-aware bridge
auto vmbr0
iface vmbr0 inet manual
    vlan_aware yes
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0

# Assign VM to specific VLAN
net0: vlan=10,bridge=vmbr0,firewall=1
```

---

### **3. Repository Structure Requirements**

```
proxmox-homelab-tips/
├── README.md                    # Philosophy, learning outcomes, disclaimer
├── SECURITY.md                  # Security hardening guide
├── BACKUP_STRATEGY.md           # GFS, 3-2-1, disaster recovery
├── GPU_PASSTHROUGH/
│   ├── README.md                # AI vs Gaming use cases
│   ├── NVIDIA_CUDA.md           # CUDA setup for ML
│   ├── AMD_ROCM.md              # ROCm setup for ML
│   ├── GAMING.md                # Windows gaming setup
│   └── TROUBLESHOOTING.md       # Common issues
├── AUTOMATION/
│   ├── TERRAFORM/               # IaC examples
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── README.md
│   ├── ANSIBLE/                 # Configuration management
│   │   ├── playbooks/
│   │   ├── roles/
│   │   └── README.md
│   ├── CLOUD_INIT/              # VM initialization
│   │   └── examples/
│   └── LEARNING_PATH.md         # Skills progression
├── SECURITY/
│   ├── CIS_BENCHMARKS.md        # Compliance guide
│   ├── ZERO_TRUST.md            # Architecture patterns
│   ├── AUDITING.md              # Security tools
│   └── INCIDENT_RESPONSE.md     # DR planning
├── BACKUP/
│   ├── PBS_SETUP.md             # Proxmox Backup Server
│   ├── GFS_STRATEGY.md          # Retention policies
│   ├── RESTORE_PROCEDURES.md    # Disaster recovery
│   └── VERIFICATION.md          # Testing backups
├── NETWORKING/
│   ├── VLAN_SETUP.md            # Network segmentation
│   ├── SDN_GUIDE.md             # Software Defined Network
│   └── FIREWALL_RULES.md        # Security groups
├── SERVICES/
│   ├── CONTAINER_PATTERNS.md    # LXC best practices
│   ├── VM_PATTERNS.md           # VM best practices
│   └── SERVICE_DEPLOYMENTS.md   # Common services
└── LEARNING_PATHS/
    ├── BEGINNER.md              # Start here
    ├── INTERMEDIATE.md          # After basics
    └── ADVANCED.md              # Enterprise skills
```

---

### **4. Key Messaging Throughout Repository**

**Required Disclaimers:**
- "This is for learning. Production homelabs should prioritize simplicity."
- "Use these techniques to build skills, not because you need them for daily services."
- "Complexity = More failure points. Keep your production services simple."

**Learning Outcomes per Section:**
- Every guide must include: "What Enterprise Skills You'll Learn"
- Every guide must include: "When You Actually Need This in Production"
- Every guide must include: "Simpler Alternative for Daily Services"

**Example Learning Path:**
```
Beginner: Basic VM/LXC, simple backup, basic networking
Intermediate: VLANs, PBS backup, basic automation
Advanced: Terraform + Ansible, GPU passthrough, security hardening
Enterprise: Multi-node clustering, CI/CD, zero-trust architecture
```

---

### **5. Real-World Job Skill Mapping**

**Map every technique to industry roles:**
- **DevOps Engineer**: Terraform, Ansible, CI/CD, GitOps
- **SRE**: Monitoring, backup strategies, incident response
- **Security Engineer**: Hardening, auditing, compliance
- **Cloud Engineer**: Virtualization, networking, automation
- **AI/ML Engineer**: GPU passthrough, CUDA/ROCm, containerization

---

### **6. Code Snippet Requirements**

**Every snippet must include:**
1. What it does
2. What you'll learn from it
3. When you actually need it
4. Simpler alternative if available
5. Potential pitfalls

**Example:**
```bash
# Terraform VM deployment
# WHAT: Automates VM creation across multiple nodes
# LEARNING: Infrastructure as Code, state management, version control
# WHEN YOU NEED: Multi-node deployments, reproducible environments
# SIMPLER: Manual creation via GUI for single VMs
# PITFALLS: State file corruption, credential management
```

