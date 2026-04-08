# Automation Documentation

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## Overview

This section covers infrastructure automation for Proxmox, including configuration management, infrastructure as code, and automated provisioning.

## Documentation Index

| Document | Description | Difficulty |
|-----|-----|-----|
| [`learning-path.md`](learning-path.md) | Complete automation learning path | All levels |
| [`ansible/readme.md`](ansible/readme.md) | Ansible configuration management | Intermediate |
| [`terraform/readme.md`](terraform/readme.md) | Terraform infrastructure as code | Advanced |

### Quick Reference

- **Getting Started**: Start with [`learning-path.md`](learning-path.md)
- **Configuration Management**: See [`ansible/readme.md`](ansible/readme.md)
- **Infrastructure as Code**: Follow [`terraform/readme.md`](terraform/readme.md)

## Learning Path Overview

### Beginner (1-2 weeks)
- Basic shell scripting
- Proxmox API basics
- Simple backup automation
- Understand idempotency concepts

### Intermediate (2-4 weeks)
- Ansible basics and playbooks
- Role development
- Variable management
- VM deployment automation

### Advanced (4-8 weeks)
- Terraform fundamentals
- State management
- Module development
- Remote backends

### Expert (8+ weeks)
- GitOps principles
- CI/CD pipeline design
- Automated testing
- Policy as code

## Technology Comparison

| Tool | Purpose | Best For | Learning Curve |
|------|------|------|------|
| Shell Scripts | Simple automation | Quick tasks, scripts | Low |
| Ansible | Configuration management | VM setup, app deployment | Medium |
| Terraform | Infrastructure as code | VM provisioning, multi-cloud | Medium-High |
| Cloud-init | VM initialization | Automated OS setup | Low |

## Related Documentation

- **Proxmox Basics**: See [`README.md`](../README.md) for Proxmox fundamentals
- **Security**: See [`security.md`](../security.md) for security automation
- **Backup**: See [`backup/`](../backup/) for backup automation
- **Networking**: See [`networking/`](../networking/) for network automation

## Common Automation Patterns

### Pattern 1: VM Deployment
```
Shell Script → Cloud-init Template → VM Clone → Ansible Configuration
```

### Pattern 2: Infrastructure as Code
```
Terraform → Proxmox API → VM Creation → State Management
```

### Pattern 3: Configuration Management
```
Ansible Playbook → Inventory → Tasks → Idempotent Configuration
```

## Tools and Resources

| Tool | Purpose | Documentation |
|------|------|------|
| Ansible | Configuration management | [`ansible/readme.md`](ansible/readme.md) |
| Terraform | Infrastructure as code | [`terraform/readme.md`](terraform/readme.md) |
| Cloud-init | VM initialization | [`cloud-init/examples/`](cloud-init/examples/) |
| Proxmox API | Programmatic access | [`scripts/api/`](../scripts/api/) |

## Job Skill Mapping

| Role | Automation Skills |
|------|------|
| DevOps Engineer | Ansible, Terraform, CI/CD |
| SRE | Backup automation, monitoring |
| Cloud Engineer | Terraform, multi-cloud IaC |
| AI/ML Engineer | GPU cluster setup, environment automation |

## Automation Scripts

The following scripts are available for automation:

### API Automation
- [`scripts/api/create_api_token.sh`](../scripts/api/create_api_token.sh:1) — create a Proxmox API token with a role
  - Usage: `bash scripts/api/create_api_token.sh -u <user> -t <token_name> [options]`
  - Options: `-r <realm>` (default: pve), `-R <role>` (default: PVEAdmin)
  - See: [`scripts/api/api_request.sh`](../scripts/api/api_request.sh:1) for API usage

- [`scripts/api/api_request.sh`](../scripts/api/api_request.sh:1) — minimal curl wrapper for Proxmox API requests
  - Usage: `bash scripts/api/api_request.sh -X <GET|POST|PUT|DELETE> -p <api_path> [-d data]`
  - Environment: `PVE_API_URL`, `PVE_TOKEN_ID`, `PVE_TOKEN_SECRET`
  - See: [`README.md`](../README.md) for API token creation

### Kubernetes Deployment
- [`scripts/k8s/deploy_ol_k8s_cluster.sh`](../scripts/k8s/deploy_ol_k8s_cluster.sh:1) — deploy Oracle Linux Kubernetes cluster
  - Usage: `bash scripts/k8s/deploy_ol_k8s_cluster.sh [--config <path>] [--yes] [--dry-run]`
  - Config file: `config.k8s.sh` (copy from `config.k8s.example.sh`)
  - See: [`README.md`](../README.md) for Kubernetes deployment examples

### VM Deployment Automation
- [`scripts/deploy_base_vm_set.sh`](../scripts/deploy_base_vm_set.sh:1) — deploy a base set of VMs for Kubernetes clusters
  - Creates: dev boxes, load balancers, Rancher/Kubernetes nodes
  - Automatically generates `config.k8s.sh` for cluster deployment
  - See: [`scripts/create_vm_full_clone.sh`](../scripts/create_vm_full_clone.sh:1) for VM cloning

- [`scripts/create_vm_full_clone.sh`](../scripts/create_vm_full_clone.sh:1) — full clone a VM template with network + SSH key
  - Usage: `bash scripts/create_vm_full_clone.sh -s <source> -d <dest> -n <name> [options]`
  - Options: `-i <cidr>` (IP), `-g <gw>` (gateway), `-b <bridge>`, `-k <ssh_key>`
  - See: [`scripts/vm/clone_vm.sh`](../scripts/vm/clone_vm.sh:1) for similar functionality

### SSH Key Management
- [`scripts/download_github_keys.sh`](../scripts/download_github_keys.sh:1) — download GitHub user SSH keys to authorized_keys
  - Usage: `bash scripts/download_github_keys.sh [github_username]`
  - Default user: `dereklarmstrong`
  - See: [`scripts/deploy_base_vm_set.sh`](../scripts/deploy_base_vm_set.sh:1) for usage example

## Integration with Other Documentation

| Documentation | Automation Integration |
|------|-----|
| [`backup/readme.md`](../backup/readme.md) | Schedule backup scripts via cron |
| [`networking/readme.md`](../networking/readme.md) | Network automation patterns |
| [`services/service-deployments.md`](../services/service-deployments.md) | Automated service deployment |
| [`gpu-passthrough/readme.md`](../gpu-passthrough/readme.md) | GPU VM automation |

## Automation Best Practices

### 1. Start Simple
- Begin with shell scripts for basic tasks
- Use existing scripts as templates
- Gradually add complexity

### 2. Test Before Production
- Use `--dry-run` flags where available
- Test in isolated environments
- Version control all automation scripts

### 3. Document Your Automation
- Add usage examples to scripts
- Document configuration requirements
- Maintain a changelog

### 4. Security Considerations
- Use API tokens instead of passwords
- Store secrets securely
- Implement least privilege access
- See: [`security.md`](../security.md) for security best practices

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
