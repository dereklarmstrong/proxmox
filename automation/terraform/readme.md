# Terraform for Proxmox

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What Enterprise Skills You'll Learn

- **Infrastructure as Code (IaC)**: Managing infrastructure through code
- **State Management**: Terraform state file handling and locking
- **Version Control**: Git-based infrastructure tracking
- **Reproducible Environments**: Consistent deployments across environments
- **Module Development**: Creating reusable Terraform components

## When You Actually Need This in Production

- Multi-node cluster management
- Team collaboration on infrastructure
- Compliance and audit requirements
- Disaster recovery with reproducible setups
- Consistent environment provisioning

## Simpler Alternative for Daily Services

For most homelab users:
- Use Proxmox GUI for single VM creation
- Use scripts for simple automation
- Manual configuration for one-off deployments
- Test Terraform in non-production first

---

## Prerequisites

```bash
# Install Terraform
apt install -y terraform

# Verify installation
terraform --version

# Install Proxmox provider
terraform init

# Create API token in Proxmox
# Web UI: Datacenter -> Permissions -> API Tokens
# Name: terraform
# User: root@pam
# Privilege: PVEAuditor or PVEAdmin
```

---

## Quick Start

### 1. Configure Variables

```bash
# Create terraform.tfvars file
cat > terraform.tfvars << 'EOF'
proxmox_url       = "proxmox.example.com"
api_token_id      = "root@pam!terraform"
api_token_secret  = "your-api-token-secret-here"
tls_insecure      = true

# Web servers
webserver_count   = 2
webserver_cores   = 2
webserver_memory  = 2048
webserver_disk_size = 20

# Database
database_count    = 1
database_cores    = 4
database_memory   = 8192
database_disk_size = 100

# Containers
container_count   = 2
container_cores   = 1
container_memory  = 512
EOF
```

### 2. Initialize Terraform

```bash
# Initialize the working directory
terraform init

# Verify configuration
terraform validate

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 3. Manage Infrastructure

```bash
# View current state
terraform state list

# View specific resource
terraform state show proxmox_vm_qemu.webserver[0]

# Update configuration
terraform apply

# Destroy all resources
terraform destroy
```

---

## Configuration Examples

### Single Web Server

```hcl
# main.tf
resource "proxmox_vm_qemu" "webserver" {
  name        = "webserver-01"
  target_node = "pve"
  clone       = 9999  # Template ID
  
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
```

### Multi-Node Deployment

```hcl
# main.tf
resource "proxmox_vm_qemu" "webserver" {
  count         = 2
  name          = "webserver-${count.index + 1}"
  target_node   = var.node_pool[count.index % length(var.node_pool)]
  clone         = var.template_id
  
  cores    = 2
  memory   = 2048
  
  disk {
    disk_size = 20
    storage   = "local-lvm"
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
}
```

---

## Variable Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| proxmox_url | string | - | Proxmox server URL |
| api_token_id | string | - | API token ID |
| api_token_secret | string | - | API token secret |
| tls_insecure | bool | true | Skip TLS verification |
| webserver_count | number | 2 | Number of web servers |
| webserver_cores | number | 2 | CPU cores per web server |
| webserver_memory | number | 2048 | Memory in MB |
| database_count | number | 1 | Number of database servers |
| container_count | number | 2 | Number of containers |

---

## State Management

### What: Terraform state file tracking

```bash
# Local state (default)
terraform state list

# Remote state (S3 example)
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "proxmox/terraform.tfstate"
    region = "us-east-1"
  }
}

# Remote state (Git example)
terraform {
  backend "remote" {
    organization = "my-org"
    workspaces {
      name = "proxmox-homelab"
    }
  }
}
```

**What You'll Learn**: State file management, remote backends

**When You Need This**: Team collaboration, disaster recovery

**Simpler Alternative**: Local state for single-user use

**Potential Pitfalls**: State file corruption, concurrent access

---

## Module Development

### What: Create reusable Terraform modules

```bash
# Create module structure
mkdir -p modules/vm
touch modules/vm/main.tf
touch modules/vm/variables.tf
touch modules/vm/outputs.tf

# Module example (modules/vm/main.tf)
resource "proxmox_vm_qemu" "this" {
  name        = var.name
  target_node = var.node
  clone       = var.template_id
  
  cores    = var.cores
  memory   = var.memory
  
  disk {
    disk_size = var.disk_size
    storage   = var.storage
  }
  
  network {
    model  = "virtio"
    bridge = var.bridge
  }
}

# Use module
module "webserver" {
  source      = "./modules/vm"
  name        = "webserver-01"
  node        = "pve"
  template_id = 9999
  cores       = 2
  memory      = 2048
}
```

**What You'll Learn**: Module development, code reuse

**When You Need This**: Multiple similar resources

**Simpler Alternative**: Use count for similar resources

**Potential Pitfalls**: Module versioning, dependency management

---

## Learning Path Progression

1. **Beginner**: Basic VM creation with Terraform
2. **Intermediate**: Variables, state management
3. **Advanced**: Modules, remote backends
4. **Enterprise**: CI/CD integration, policy as code

---

## Real-World Job Skill Mapping

- **DevOps Engineer**: All sections apply directly
- **Cloud Engineer**: IaC, infrastructure management
- **SRE**: Reproducible environments, disaster recovery
- **Platform Engineer**: Module development, standards

---

## Common Issues

### Issue 1: API Token Errors

```bash
# Check token permissions
pvesh get /access/tokens

# Regenerate token if needed
pvesh create /access/token --userid root@pam --description "terraform"
```

### Issue 2: Template Not Found

```bash
# List available templates
qm list | grep template

# Create template if needed
bash scripts/vm/create_cloud_init_template.sh -i 9999
```

### Issue 3: State Lock Issues

```bash
# Force unlock (only if no other Terraform running)
terraform force-unlock <LOCK_ID>

# Check for other Terraform processes
ps aux | grep terraform
```

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
