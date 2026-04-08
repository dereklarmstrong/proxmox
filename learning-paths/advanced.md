# Advanced Learning Path

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What Enterprise Skills You'll Learn

- **Terraform IaC**: Infrastructure as Code for Proxmox
- **Ansible Automation**: Configuration management
- **GPU Passthrough**: AI and gaming workloads
- **Advanced Security**: Zero trust, compliance
- **Multi-Node Clustering**: HA and distributed systems

## When You Actually Need This in Production

- Multi-node cluster management
- Automated infrastructure provisioning
- AI/ML workloads
- Compliance requirements
- High availability needs

## Simpler Alternative for Daily Services

For most homelab users:
- Manual VM creation
- Simple configuration
- Local backups
- Single-node setup

---

## Week 1-2: Terraform Infrastructure as Code

### Topics

1. **Terraform Basics**
   - Installation and configuration
   - Provider setup
   - Basic resources

2. **Proxmox Provider**
   - API token configuration
   - VM resource management
   - State management

3. **Module Development**
   - Creating reusable modules
   - Variable management
   - Output definitions

### Resources

- [AUTOMATION/TERRAFORM/README.md](AUTOMATION/TERRAFORM/README.md)
- [AUTOMATION/TERRAFORM/main.tf](AUTOMATION/TERRAFORM/main.tf)
- [AUTOMATION/TERRAFORM/variables.tf](AUTOMATION/TERRAFORM/variables.tf)

### Hands-On Exercises

```bash
# 1. Install Terraform
apt install -y terraform

# 2. Create Terraform configuration
cat > main.tf << 'EOF'
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  pm_api_url       = "https://proxmox.example.com:8006/api2/json"
  pm_api_token_id  = "root@pam!terraform"
  pm_api_token_secret = "your-token-secret"
  pm_tls_insecure  = true
}

resource "proxmox_vm_qemu" "webserver" {
  count        = 2
  name         = "webserver-${count.index + 1}"
  target_node  = "pve"
  clone        = 9999
  full_clone   = true
  
  cores    = 2
  memory   = 2048
  scsihw   = "virtio-scsi-pci"
  
  disk {
    disk_size = 20
    format    = "qcow2"
    type      = "scsi"
    storage   = "local-lvm"
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  cloudinit_cdrom_storage = "local"
  os_type                 = "linux"
  ciuser                  = "admin"
}
EOF

# 3. Initialize Terraform
terraform init

# 4. Validate configuration
terraform validate

# 5. Plan deployment
terraform plan

# 6. Apply configuration
terraform apply

# 7. View state
terraform state list

# 8. Destroy resources (when done)
terraform destroy
```

---

## Week 3-4: Ansible Configuration Management

### Topics

1. **Ansible Basics**
   - Installation and setup
   - Inventory management
   - Playbook structure

2. **Proxmox Modules**
   - VM deployment
   - Container management
   - Backup automation

3. **Role Development**
   - Creating reusable roles
   - Variable management
   - Task organization

### Resources

- [AUTOMATION/ANSIBLE/README.md](AUTOMATION/ANSIBLE/README.md)
- [AUTOMATION/ANSIBLE/playbooks/deploy_vm.yml](AUTOMATION/ANSIBLE/playbooks/deploy_vm.yml)
- [AUTOMATION/ANSIBLE/roles/vm_setup/tasks/main.yml](AUTOMATION/ANSIBLE/roles/vm_setup/tasks/main.yml)

### Hands-On Exercises

```bash
# 1. Install Ansible
apt install -y ansible

# 2. Install Proxmox collection
ansible-galaxy collection install community.general

# 3. Create inventory
cat > inventory.ini << 'EOF'
[proxmox_nodes]
pve ansible_host=192.168.1.100

[proxmox_nodes:vars]
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/id_rsa
EOF

# 4. Create playbook
cat > playbooks/deploy_vm.yml << 'EOF'
---
- name: Deploy VMs from template
  hosts: proxmox_nodes
  gather_facts: no
  
  vars:
    proxmox_api_host: "192.168.1.100"
    proxmox_api_user: "root@pam"
    proxmox_api_token_id: "terraform"
    proxmox_api_token_secret: "{{ lookup('env', 'PROXMOX_API_TOKEN') }}"
    vm_template: 9999
  
  tasks:
    - name: Deploy VMs
      proxmox_kvm:
        api_host: "{{ proxmox_api_host }}"
        api_user: "{{ proxmox_api_user }}"
        api_token_id: "{{ proxmox_api_token_id }}"
        api_token_secret: "{{ proxmox_api_token_secret }}"
        node: "pve"
        name: "webserver-{{ item }}"
        vmid: "{{ 100 + item - 1 }}"
        clone: "{{ vm_template }}"
        cores: 2
        memory: 2048
        state: present
      loop: "{{ range(1, 3) | list }}"
EOF

# 5. Run playbook
ansible-playbook playbooks/deploy_vm.yml -i inventory.ini

# 6. Create role structure
mkdir -p roles/vm_setup/tasks
touch roles/vm_setup/tasks/main.yml

# 7. Create role tasks
cat > roles/vm_setup/tasks/main.yml << 'EOF'
---
- name: Install common packages
  apt:
    name:
      - curl
      - wget
      - vim
    state: present

- name: Configure SSH
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "^PermitRootLogin"
    line: "PermitRootLogin prohibit-password"
  notify: restart sshd
EOF
```

---

## Week 5-6: GPU Passthrough

### Topics

1. **IOMMU and VFIO**
   - IOMMU configuration
   - VFIO module setup
   - Driver blacklisting

2. **GPU Passthrough**
   - VM configuration
   - Driver installation in VM
   - Performance tuning

3. **AI Workloads**
   - CUDA setup for NVIDIA
   - ROCm setup for AMD
   - Hugepages configuration

### Resources

- [GPU_PASSTHROUGH/README.md](GPU_PASSTHROUGH/README.md)
- [GPU_PASSTHROUGH/NVIDIA_CUDA.md](GPU_PASSTHROUGH/NVIDIA_CUDA.md)
- [GPU_PASSTHROUGH/AMD_ROCM.md](GPU_PASSTHROUGH/AMD_ROCM.md)
- [GPU_PASSTHROUGH/TROUBLESHOOTING.md](GPU_PASSTHROUGH/TROUBLESHOOTING.md)

### Hands-On Exercises

```bash
# 1. Enable IOMMU in GRUB
cat > /etc/default/grub.d/iommu.cfg << 'EOF'
GRUB_CMDLINE_LINUX="amd_iommu=on intel_iommu=on iommu=pt"
EOF
update-grub

# 2. Blacklist GPU drivers
cat > /etc/modprobe.d/blacklist-gpu.conf << 'EOF'
blacklist nvidia
blacklist nouveau
blacklist amdgpu
EOF

# 3. Configure VFIO modules
cat > /etc/modules-load.d/vfio.conf << 'EOF'
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF

# 4. Find GPU IOMMU group
for i in /sys/kernel/iommu_groups/*; do 
    echo "IOMMU Group $(basename $i):"; 
    lspci -nnv -D -s $(ls $i/* | sed 's|.*/||' | head -1); 
done

# 5. Create VM with GPU passthrough
qm create 100 --name gpu-vm --memory 8192 --cores 4 --cpu host \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-100-disk-0,size=100G \
  --net0 virtio,bridge=vmbr0 \
  --args '-device vfio-pci,host=01:00.0,x-vga=on'

# 6. Install CUDA in VM (for NVIDIA)
# Inside VM:
apt update
apt install -y nvidia-driver cuda-toolkit
nvidia-smi

# 7. Install ROCm in VM (for AMD)
# Inside VM:
curl -fsSL https://repo.radeon.com/rocm/rocm.gpg.key | apt-key add -
echo "deb [arch=amd64] https://repo.radeon.com/rocm/apt/5.6.1 jammy main" > /etc/apt/sources.list.d/rocm.list
apt update
apt install -y rocm-dev hipblas rocblas
rocminfo

# 8. Configure hugepages for AI
echo "hugepages=8192" >> /etc/default/grub
update-grub
```

---

## Week 7-8: Advanced Security

### Topics

1. **Zero Trust Architecture**
   - Network segmentation
   - Identity management
   - Least privilege access

2. **CIS Benchmarks**
   - Compliance frameworks
   - Security hardening
   - Audit preparation

3. **Incident Response**
   - Detection and analysis
   - Containment strategies
   - Recovery procedures

### Resources

- [SECURITY/ZERO_TRUST.md](SECURITY/ZERO_TRUST.md)
- [SECURITY/CIS_BENCHMARKS.md](SECURITY/CIS_BENCHMARKS.md)
- [SECURITY/AUDITING.md](SECURITY/AUDITING.md)
- [SECURITY/INCIDENT_RESPONSE.md](SECURITY/INCIDENT_RESPONSE.md)

### Hands-On Exercises

```bash
# 1. Enable 2FA for web interface
apt install -y libpam-google-authenticator
pam-auth-update --enable pam_google_authenticator

# 2. Configure SSH hardening
cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
Port 2222
MaxAuthTries 3
EOF
systemctl restart sshd

# 3. Enable Proxmox firewall
pve-firewall enable
pvesh create /firewall/options --enabled 1

# 4. Create firewall rules
pvesh create /firewall/rules \
  --ruleid 100 \
  --action accept \
  --source 192.168.1.0/24 \
  --dest-port 22 \
  --proto tcp \
  --name "Allow-SSH-Management"

pvesh create /firewall/rules \
  --ruleid 999 \
  --action drop \
  --name "Default-Drop"

# 5. Run security audit
apt install -y lynis
lynis audit system

# 6. Create incident response plan
cat > /root/incident-response-plan.md << 'EOF'
# Incident Response Plan

## Emergency Contacts
- Admin: admin@example.com

## Incident Classification
- Critical: System compromise, data breach
- High: Service disruption
- Medium: Suspicious activity
- Low: Minor security events

## Response Procedures
1. Detect and identify
2. Contain the incident
3. Eradicate the threat
4. Recover systems
5. Document and learn
EOF

# 7. Set up monitoring
apt install -y rsyslog logwatch fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

---

## Advanced Milestones

### Checkpoint 1: Week 4

- [ ] Can create Terraform configurations for Proxmox
- [ ] Can manage Terraform state
- [ ] Can create Ansible playbooks for VM deployment
- [ ] Can create and use Ansible roles

### Checkpoint 2: Week 6

- [ ] Can configure IOMMU and VFIO
- [ ] Can pass through GPU to VM
- [ ] Can install CUDA/ROCm in VM
- [ ] Can troubleshoot GPU passthrough issues

### Checkpoint 3: Week 8

- [ ] Can implement zero trust principles
- [ ] Can configure CIS benchmark compliance
- [ ] Can create incident response procedures
- [ ] Can set up security monitoring

---

## Next Steps

After completing the advanced path:

1. **Review and Practice**: Revisit exercises and ensure comfort
2. **Explore More**: Multi-node clustering, CI/CD pipelines
3. **Document**: Keep notes on what you've learned
4. **Share**: Contribute to community, write blog posts

---

## Enterprise Skills Mapping

| Skill | DevOps Engineer | SRE | Security Engineer | Cloud Engineer |
|------|-----------------|-----|-------------------|----------------|
| Terraform | ✓ | ✓ | ✓ | ✓ |
| Ansible | ✓ | ✓ | - | ✓ |
| GPU Passthrough | - | - | - | ✓ |
| Zero Trust | - | ✓ | ✓ | ✓ |
| CIS Benchmarks | - | ✓ | ✓ | ✓ |
| Incident Response | - | ✓ | ✓ | - |

---

## Recommended Resources

- **Terraform Documentation**: https://developer.hashicorp.com/terraform/docs
- **Ansible Documentation**: https://docs.ansible.com/
- **NVIDIA CUDA Documentation**: https://docs.nvidia.com/cuda/
- **AMD ROCm Documentation**: https://rocm.docs.amd.com/
- **CIS Benchmarks**: https://www.cisecurity.org/benchmark

---

## Common Advanced Mistakes

1. **Over-automating**: Don't automate everything immediately
2. **Ignoring state management**: Always manage Terraform state properly
3. **Not testing GPU passthrough**: Test in non-production first
4. **Skipping documentation**: Document your infrastructure
5. **Not monitoring**: Set up comprehensive monitoring

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
