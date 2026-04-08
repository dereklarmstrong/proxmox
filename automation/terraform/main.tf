# Proxmox Terraform Configuration
#
# WHAT: Infrastructure as Code for Proxmox VM/LXC provisioning
# LEARNING: IaC principles, state management, version control, reproducible environments
# WHEN YOU NEED: Multi-node deployments, reproducible environments, team collaboration
# SIMPLER: Manual creation via Proxmox GUI for single VMs
# PITFALLS: State file corruption, credential management, learning curve

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

# Provider Configuration
#
# WHAT: Configure connection to Proxmox API
# LEARNING: Provider configuration, authentication, TLS settings
# WHEN YOU NEED: Automated Proxmox management
# SIMPLER: Use Proxmox GUI for occasional changes
# PITFALLS: API token security, TLS certificate validation

provider "proxmox" {
  pm_api_url       = "https://${var.proxmox_url}:8006/api2/json"
  pm_api_token_id  = var.api_token_id
  pm_api_token_secret = var.api_token_secret
  pm_tls_insecure  = var.tls_insecure
}

# Variable Definitions
#
# WHAT: Define configurable variables for the infrastructure
# LEARNING: Terraform variables, type constraints, defaults
# WHEN YOU NEED: Flexible, reusable infrastructure code
# SIMPLER: Hardcode values for single-environment use
# PITFALLS: Sensitive data in variables, type mismatches

variable "proxmox_url" {
  description = "Proxmox VE server hostname or IP"
  type        = string
  sensitive   = false
}

variable "api_token_id" {
  description = "Proxmox API token ID (e.g., root@pam!terraform)"
  type        = string
  sensitive   = true
}

variable "api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "tls_insecure" {
  description = "Skip TLS verification (for self-signed certs)"
  type        = bool
  default     = true
}

variable "datacenter" {
  description = "Proxmox datacenter name"
  type        = string
  default     = "datacenter"
}

# Node Configuration
#
# WHAT: Define Proxmox nodes in the cluster
# LEARNING: Resource definitions, node management
# WHEN YOU NEED: Multi-node cluster management
# SIMPLER: Single-node setup without node resources
# PITFALLS: Node name mismatches, connectivity issues

resource "proxmox_lxc_environment" "environment" {
  count = var.enable_environment ? 1 : 0
  
  node_name = var.primary_node
}

# VM Resource - Web Server
#
# WHAT: Create a web server VM with cloud-init
# LEARNING: VM resource configuration, networking, storage
# WHEN YOU NEED: Automated VM deployment with consistent configuration
# SIMPLER: Manual VM creation for one-off deployments
# PITFALLS: Template availability, network configuration errors

resource "proxmox_vm_qemu" "webserver" {
  count        = var.webserver_count
  name         = "webserver-${count.index + 1}"
  target_node  = var.primary_node
  clone        = var.vm_template_id
  full_clone   = true
  
  # CPU Configuration
  cores    = var.webserver_cores
  sockets = 1
  cpu      = "host"
  numa     = var.enable_numa
  
  # Memory Configuration
  memory     = var.webserver_memory
  balloon    = var.webserver_balloon
  
  # Storage Configuration
  scsihw = "virtio-scsi-pci"
  
  disk {
    disk_size    = var.webserver_disk_size
    format       = "qcow2"
    type         = "scsi"
    storage      = var.default_storage
    iothread     = var.enable_iothread
  }
  
  # Network Configuration
  network {
    model    = "virtio"
    bridge   = var.default_bridge
    firewall = var.enable_firewall
    vlan     = var.webserver_vlan
  }
  
  # Cloud-init Configuration
  cloudinit_cdrom_storage = var.cloudinit_storage
  os_type                 = "linux"
  ciuser                  = var.cloudinit_username
  sshkeys                 = var.ssh_public_key
  
  # IP Configuration
  ipconfig0 = "ip=${var.webserver_ip}/24,gw=${var.gateway_ip}"
  
  # USB Configuration
  usb {
    host = var.usb_passthrough
  }
  
  # Boot Order
  boot = "order=cdn;net0"
  
  # Serial Console
  serial = "socket"
  
  # Agent
  agent = var.enable_agent
  
  # Timeout
  timeout_clone = 600
  timeout_create = 600
  timeout_migrate = 600
  timeout_reboot = 300
  timeout_shutdown_vm = 300
  timeout_start_vm = 300
  timeout_stop_vm = 300
  
  # Tags
  tags = "web,production,terraform"
  
  # Dependencies
  depends_on = [proxmox_lxc_environment.environment]
}

# VM Resource - Database Server
#
# WHAT: Create a database server VM with optimized storage
# LEARNING: Resource customization, storage optimization
# WHEN YOU NEED: Specialized VM configurations
# SIMPLER: Use same template for all VMs
# PITFALLS: Storage type compatibility, performance issues

resource "proxmox_vm_qemu" "database" {
  count        = var.database_count
  name         = "database-${count.index + 1}"
  target_node  = var.primary_node
  clone        = var.vm_template_id
  full_clone   = true
  
  # CPU Configuration
  cores    = var.database_cores
  sockets = 1
  cpu      = "host"
  numa     = var.enable_numa
  
  # Memory Configuration (larger for database)
  memory     = var.database_memory
  balloon    = 0  # Disable ballooning for database
  
  # Storage Configuration (ZFS for database)
  scsihw = "virtio-scsi-pci"
  
  disk {
    disk_size    = var.database_disk_size
    format       = "qcow2"
    type         = "scsi"
    storage      = var.database_storage
    iothread     = true
  }
  
  # Network Configuration
  network {
    model    = "virtio"
    bridge   = var.default_bridge
    firewall = true
    vlan     = var.database_vlan
  }
  
  # Cloud-init Configuration
  cloudinit_cdrom_storage = var.cloudinit_storage
  os_type                 = "linux"
  ciuser                  = var.cloudinit_username
  sshkeys                 = var.ssh_public_key
  
  # IP Configuration
  ipconfig0 = "ip=${var.database_ip}/24,gw=${var.gateway_ip}"
  
  # Agent
  agent = var.enable_agent
  
  # Tags
  tags = "database,production,terraform"
  
  # Timeout
  timeout_clone = 600
  timeout_create = 600
}

# LXC Container - Lightweight Service
#
# WHAT: Create an LXC container for lightweight services
# LEARNING: Container vs VM, resource efficiency
# WHEN YOU NEED: Lightweight, fast-deploying services
# SIMPLER: Use VM for full isolation
# PITFALLS: Unprivileged container limitations

resource "proxmox_lxc" "container" {
  count        = var.container_count
  hostname     = "container-${count.index + 1}"
  target_node  = var.primary_node
  ostemplate   = var.container_template
  storage      = var.default_storage
  
  # CPU Configuration
  cores = var.container_cores
  
  # Memory Configuration
  memory = var.container_memory
  swap   = var.container_swap
  
  # Network Configuration
  network {
    bridge = var.default_bridge
    firewall = var.enable_firewall
    vlan   = var.container_vlan
  }
  
  # Root Disk
  rootfs {
    storage = var.default_storage
    size    = var.container_disk_size
  }
  
  # Unprivileged Container
  unprivileged = var.unprivileged
  
  # Password
  password = var.container_password
  
  # User Data
  unprivileged_user = var.cloudinit_username
  
  # Tags
  tags = "container,service,terraform"
}

# Output Values
#
# WHAT: Export important information after deployment
# LEARNING: Terraform outputs, state management
# WHEN YOU NEED: Access to deployed resource information
# SIMPLER: Manual inspection of Proxmox UI
# PITFALLS: Sensitive data in outputs

output "webserver_ips" {
  description = "IP addresses of web servers"
  value       = proxmox_vm_qemu.webserver[*].ipconfig0
}

output "database_ips" {
  description = "IP addresses of database servers"
  value       = proxmox_vm_qemu.database[*].ipconfig0
}

output "container_ips" {
  description = "IP addresses of containers"
  value       = proxmox_lxc.container[*].network0
}

output "webserver_ids" {
  description = "VM IDs of web servers"
  value       = proxmox_vm_qemu.webserver[*].vmid
}

output "database_ids" {
  description = "VM IDs of database servers"
  value       = proxmox_vm_qemu.database[*].vmid
}
