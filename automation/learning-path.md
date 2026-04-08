# Automation Learning Path

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What You'll Learn

This guide covers automation skills for Proxmox environments:

- **Infrastructure as Code**: Terraform, Ansible, and configuration management
- **Automated Provisioning**: Cloud-init and automated VM setup
- **Version Control**: Git-based infrastructure tracking
- **CI/CD Integration**: Automated testing and deployment
- **GitOps**: Infrastructure as code with version control

## When You Need This

- Multi-node cluster management
- Team collaboration on infrastructure
- Compliance and audit requirements
- Disaster recovery with reproducible setups
- Consistent environment provisioning across environments

## Simpler Alternative

For most homelab users:
- Use Proxmox GUI for single VM creation
- Use simple shell scripts for basic automation
- Manual configuration for one-off deployments
- Test automation in non-production first

---

## Learning Path Overview

### Beginner: Basic Automation

**Duration**: 1-2 weeks

**Topics**:
- Understanding automation benefits
- Basic shell scripting
- Proxmox API basics
- Simple backup automation

**Skills**:
- Write basic shell scripts for common tasks
- Use Proxmox API for simple operations
- Automate backup schedules
- Understand idempotency concepts

**Resources**:
- [`scripts/backup/backup_all.sh`](scripts/backup/backup_all.sh)
- [`scripts/api/api_request.sh`](scripts/api/api_request.sh)
- [`docs/cheatsheet.md`](docs/cheatsheet.md)

**Project**: Create a script that backs up all VMs and emails the result

---

### Intermediate: Configuration Management

**Duration**: 2-4 weeks

**Topics**:
- Ansible basics
- Playbook development
- Role organization
- Variable management

**Skills**:
- Write Ansible playbooks for VM deployment
- Create reusable roles
- Manage variables and secrets
- Implement idempotent configurations

**Resources**:
- [`AUTOMATION/ANSIBLE/README.md`](AUTOMATION/ANSIBLE/README.md)
- [`AUTOMATION/ANSIBLE/playbooks/deploy_vm.yml`](AUTOMATION/ANSIBLE/playbooks/deploy_vm.yml)
- [`AUTOMATION/ANSIBLE/roles/vm_setup/tasks/main.yml`](AUTOMATION/ANSIBLE/roles/vm_setup/tasks/main.yml)

**Project**: Create an Ansible playbook that deploys and configures multiple VMs

---

### Advanced: Infrastructure as Code

**Duration**: 4-8 weeks

**Topics**:
- Terraform fundamentals
- State management
- Module development
- Remote backends

**Skills**:
- Write Terraform configurations for Proxmox
- Manage Terraform state
- Create reusable modules
- Implement CI/CD for infrastructure

**Resources**:
- [`AUTOMATION/TERRAFORM/README.md`](AUTOMATION/TERRAFORM/README.md)
- [`AUTOMATION/TERRAFORM/main.tf`](AUTOMATION/TERRAFORM/main.tf)
- [`AUTOMATION/TERRAFORM/variables.tf`](AUTOMATION/TERRAFORM/variables.tf)

**Project**: Create a Terraform configuration that deploys a complete infrastructure stack

---

### Expert: GitOps and CI/CD

**Duration**: 8+ weeks

**Topics**:
- GitOps principles
- CI/CD pipeline design
- Automated testing
- Policy as code

**Skills**:
- Implement GitOps workflows
- Create automated testing for infrastructure
- Implement policy enforcement
- Design self-healing systems

**Resources**:
- [`AUTOMATION/TERRAFORM/README.md`](AUTOMATION/TERRAFORM/README.md) - State management section
- [`AUTOMATION/ANSIBLE/README.md`](AUTOMATION/ANSIBLE/README.md) - Role development section

**Project**: Create a complete GitOps workflow with automated testing and deployment

---

## Skill Progression Checklist

### Beginner Checklist

- [ ] Understand what automation is and why it matters
- [ ] Write basic shell scripts
- [ ] Use Proxmox API for simple operations
- [ ] Automate backup schedules
- [ ] Understand idempotency
- [ ] Create a backup automation script

### Intermediate Checklist

- [ ] Install and configure Ansible
- [ ] Write basic playbooks
- [ ] Create roles and tasks
- [ ] Manage variables and secrets
- [ ] Implement idempotent configurations
- [ ] Deploy VMs with Ansible

### Advanced Checklist

- [ ] Install and configure Terraform
- [ ] Write basic Terraform configurations
- [ ] Manage Terraform state
- [ ] Create Terraform modules
- [ ] Implement remote backends
- [ ] Deploy infrastructure with Terraform

### Expert Checklist

- [ ] Understand GitOps principles
- [ ] Design CI/CD pipelines
- [ ] Implement automated testing
- [ ] Create policy as code
- [ ] Design self-healing systems
- [ ] Implement complete GitOps workflow

---

## Real-World Job Skill Mapping

| Skill Level | DevOps Engineer | SRE | Cloud Engineer | AI/ML Engineer |
|-----|-----------------|-----|----------------|----------------|
| Beginner | Basic scripting | Backup automation | VM provisioning | Environment setup |
| Intermediate | Ansible playbooks | Configuration mgmt | Infrastructure mgmt | ML environment setup |
| Advanced | Terraform IaC | Disaster recovery | Multi-cloud IaC | GPU cluster setup |
| Expert | GitOps, CI/CD | Self-healing systems | Platform engineering | MLOps pipelines |

---

## Time Investment Guide

| Level | Study Time | Practice Time | Project Time |
|-----|------------|---------------|--------------|
| Beginner | 5-10 hours | 10-20 hours | 5-10 hours |
| Intermediate | 10-20 hours | 20-40 hours | 10-20 hours |
| Advanced | 20-40 hours | 40-80 hours | 20-40 hours |
| Expert | 40+ hours | 80+ hours | 40+ hours |

---

## Recommended Learning Order

1. **Start with shell scripting** - Understand automation basics
2. **Learn Proxmox API** - Understand the platform you're automating
3. **Move to Ansible** - Configuration management is easier to start
4. **Learn Terraform** - Infrastructure as code builds on Ansible concepts
5. **Implement GitOps** - Combine all skills into a workflow

---

## Common Pitfalls to Avoid

1. **Over-automation**: Don't automate everything immediately
2. **Ignoring documentation**: Document your automation as you build it
3. **Skipping testing**: Test automation before deploying to production
4. **Hardcoding secrets**: Use proper secrets management
5. **Not versioning**: Always version control your automation code

---

## Next Steps

After completing this learning path:
- Contribute to open-source automation projects
- Build a portfolio of automation projects
- Consider certifications (HashiCorp, Red Hat, etc.)
- Share your knowledge through blogs or talks

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
