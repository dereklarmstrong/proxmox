# Terraform Variables for Proxmox
#
# WHAT: Variable definitions for Proxmox infrastructure
# LEARNING: Terraform variable types, defaults, validation
# WHEN YOU NEED: Configurable, reusable infrastructure
# SIMPLER: Hardcoded values for single use
# PITFALLS: Missing required variables, type mismatches

# =============================================================================
# Proxmox Connection Settings
# =============================================================================

variable "proxmox_url" {
  description = "Proxmox VE server hostname or IP address"
  type        = string
  
  validation {
    condition     = length(var.proxmox_url) > 0
    error_message = "Proxmox URL is required."
  }
}

variable "api_token_id" {
  description = "Proxmox API token ID (format: user@realm!token-name)"
  type        = string
  sensitive   = true
  
  validation {
    condition     = can(regex("^.*!.*$", var.api_token_id))
    error_message = "API token ID must be in format 'user@realm!token-name'."
  }
}

variable "api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "tls_insecure" {
  description = "Skip TLS certificate verification (use only for testing)"
  type        = bool
  default     = true
}

# =============================================================================
# Cluster Configuration
# =============================================================================

variable "datacenter" {
  description = "Proxmox datacenter name"
  type        = string
  default     = "datacenter"
}

variable "primary_node" {
  description = "Primary Proxmox node name"
  type        = string
  default     = "pve"
}

variable "secondary_nodes" {
  description = "Additional Proxmox nodes for HA"
  type        = list(string)
  default     = []
}

# =============================================================================
# Storage Configuration
# =============================================================================

variable "default_storage" {
  description = "Default storage for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "database_storage" {
  description = "Storage for database VMs (recommended: ZFS)"
  type        = string
  default     = "local-zfs"
}

variable "cloudinit_storage" {
  description = "Storage for cloud-init ISO"
  type        = string
  default     = "local"
}

variable "iso_storage" {
  description = "Storage for ISO images"
  type        = string
  default     = "local"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "default_bridge" {
  description = "Default network bridge"
  type        = string
  default     = "vmbr0"
}

variable "gateway_ip" {
  description = "Default gateway IP"
  type        = string
  default     = "192.168.1.1"
}

variable "enable_firewall" {
  description = "Enable Proxmox firewall"
  type        = bool
  default     = true
}

# =============================================================================
# Web Server Configuration
# =============================================================================

variable "webserver_count" {
  description = "Number of web server VMs to create"
  type        = number
  default     = 2
  
  validation {
    condition     = var.webserver_count >= 0 && var.webserver_count <= 10
    error_message = "Web server count must be between 0 and 10."
  }
}

variable "webserver_cores" {
  description = "Number of CPU cores per web server"
  type        = number
  default     = 2
}

variable "webserver_memory" {
  description = "Memory in MB per web server"
  type        = number
  default     = 2048
}

variable "webserver_disk_size" {
  description = "Disk size in GB per web server"
  type        = number
  default     = 20
}

variable "webserver_vlan" {
  description = "VLAN ID for web servers (0 for no VLAN)"
  type        = number
  default     = 0
}

variable "webserver_ip" {
  description = "Static IP address for web servers"
  type        = string
  default     = "192.168.1.100"
}

variable "webserver_balloon" {
  description = "Balloon memory in MB for web servers (0 to disable)"
  type        = number
  default     = 0
}

# =============================================================================
# Database Server Configuration
# =============================================================================

variable "database_count" {
  description = "Number of database server VMs to create"
  type        = number
  default     = 1
  
  validation {
    condition     = var.database_count >= 0 && var.database_count <= 5
    error_message = "Database server count must be between 0 and 5."
  }
}

variable "database_cores" {
  description = "Number of CPU cores per database server"
  type        = number
  default     = 4
}

variable "database_memory" {
  description = "Memory in MB per database server"
  type        = number
  default     = 8192
}

variable "database_disk_size" {
  description = "Disk size in GB per database server"
  type        = number
  default     = 100
}

variable "database_vlan" {
  description = "VLAN ID for database servers (0 for no VLAN)"
  type        = number
  default     = 0
}

variable "database_ip" {
  description = "Static IP address for database servers"
  type        = string
  default     = "192.168.1.200"
}

# =============================================================================
# Container Configuration
# =============================================================================

variable "container_count" {
  description = "Number of LXC containers to create"
  type        = number
  default     = 2
  
  validation {
    condition     = var.container_count >= 0 && var.container_count <= 20
    error_message = "Container count must be between 0 and 20."
  }
}

variable "container_template" {
  description = "LXC template path (e.g., local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst)"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst"
}

variable "container_cores" {
  description = "Number of CPU cores per container"
  type        = number
  default     = 1
}

variable "container_memory" {
  description = "Memory in MB per container"
  type        = number
  default     = 512
}

variable "container_swap" {
  description = "Swap size in MB per container"
  type        = number
  default     = 512
}

variable "container_disk_size" {
  description = "Root disk size in GB per container"
  type        = number
  default     = 4
}

variable "container_vlan" {
  description = "VLAN ID for containers (0 for no VLAN)"
  type        = number
  default     = 0
}

variable "container_password" {
  description = "Container root password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "unprivileged" {
  description = "Create unprivileged containers (recommended for security)"
  type        = bool
  default     = true
}

# =============================================================================
# Cloud-init Configuration
# =============================================================================

variable "vm_template_id" {
  description = "Template VM ID for cloning"
  type        = number
  default     = 9999
}

variable "cloudinit_username" {
  description = "Cloud-init username"
  type        = string
  default     = "admin"
}

variable "ssh_public_key" {
  description = "SSH public key for cloud-init"
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# Feature Flags
# =============================================================================

variable "enable_numa" {
  description = "Enable NUMA topology"
  type        = bool
  default     = false
}

variable "enable_iothread" {
  description = "Enable I/O threads for storage"
  type        = bool
  default     = true
}

variable "enable_agent" {
  description = "Enable QEMU agent"
  type        = bool
  default     = true
}

variable "enable_environment" {
  description = "Create Proxmox environment resource"
  type        = bool
  default     = false
}

variable "usb_passthrough" {
  description = "USB device to pass through (format: bus:dev)"
  type        = string
  default     = ""
}

# =============================================================================
# Tags
# =============================================================================

variable "environment_tags" {
  description = "Tags to apply to all resources"
  type        = list(string)
  default     = ["terraform", "homelab"]
}
