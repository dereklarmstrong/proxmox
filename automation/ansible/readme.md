# Ansible for Proxmox

> **⚠️ Learning Repository Disclaimer**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services. Complexity = More failure points. Keep your production services simple.

---

## What Enterprise Skills You'll Learn

- **Configuration Management**: Automated system configuration
- **Idempotency**: Safe, repeatable operations
- **Role Development**: Modular, reusable playbooks
- **Inventory Management**: Dynamic and static host management
- **Secrets Management**: Secure credential handling

## When You Actually Need This in Production

- Large-scale VM/container provisioning
- Consistent configuration across environments
- Compliance requirements
- Team collaboration on configurations
- Automated deployment pipelines

## Simpler Alternative for Daily Services

For most homelab users:
- Use Proxmox GUI for single VM creation
- Use simple shell scripts for basic tasks
- Manual configuration for one-off deployments
- Test Ansible in non-production first

---

## Prerequisites

```bash
# Install Ansible
apt install -y ansible

# Verify installation
ansible --version

# Install Proxmox collection
ansible-galaxy collection install community.general

# Create API token in Proxmox
# Web UI: Datacenter -> Permissions -> API Tokens
```

---

## Quick Start

### 1. Create Inventory

```ini
# inventory/proxmox.ini
[proxmox_nodes]
pve ansible_host=192.168.1.100

[proxmox_nodes:vars]
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### 2. Create Playbook

```yaml
# playbooks/deploy_vm.yml
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
        name: "webserver-01"
        vmid: 100
        clone: "{{ vm_template }}"
        state: present
```

### 3. Run Playbook

```bash
# Validate playbook
ansible-playbook playbooks/deploy_vm.yml --check

# Run playbook
ansible-playbook playbooks/deploy_vm.yml -i inventory/proxmox.ini
```

---

## Playbook Examples

### Deploy Multiple VMs

```yaml
# playbooks/deploy_multiple_vms.yml
---
- name: Deploy multiple VMs
  hosts: proxmox_nodes
  gather_facts: no
  
  vars:
    vm_template: 9999
    proxmox_api_host: "192.168.1.100"
    proxmox_api_user: "root@pam"
    proxmox_api_token_id: "terraform"
    proxmox_api_token_secret: "{{ lookup('env', 'PROXMOX_API_TOKEN') }}"
  
  tasks:
    - name: Deploy web servers
      proxmox_kvm:
        api_host: "{{ proxmox_api_host }}"
        api_user: "{{ proxmox_api_user }}"
        api_token_id: "{{ proxmox_api_token_id }}"
        api_token_secret: "{{ proxmox_api_token_secret }}"
        node: "{{ proxmox_node }}"
        name: "webserver-{{ item }}"
        vmid: "{{ 100 + item }}"
        clone: "{{ vm_template }}"
        cores: 2
        memory: 2048
        state: present
      loop: [1, 2, 3]
    
    - name: Configure networking
      proxmox_kvm:
        api_host: "{{ proxmox_api_host }}"
        api_user: "{{ proxmox_api_user }}"
        api_token_id: "{{ proxmox_api_token_id }}"
        api_token_secret: "{{ proxmox_api_token_secret }}"
        node: "{{ proxmox_node }}"
        vmid: "{{ 100 + item }}"
        net0: "bridge=vmbr0,ip=192.168.1.{{ 150 + item }}/24,gateway=192.168.1.1"
      loop: [1, 2, 3]
```

### Deploy LXC Containers

```yaml
# playbooks/deploy_containers.yml
---
- name: Deploy LXC containers
  hosts: proxmox_nodes
  gather_facts: no
  
  tasks:
    - name: Create container
      proxmox_lxc:
        api_host: "{{ proxmox_api_host }}"
        api_user: "{{ proxmox_api_user }}"
        api_token_id: "{{ proxmox_api_token_id }}"
        api_token_secret: "{{ proxmox_api_token_secret }}"
        node: "{{ proxmox_node }}"
        vmid: 200
        ostemplate: "local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst"
        hostname: "container-01"
        storage: "local"
        cores: 1
        memory: 512
        swap: 512
        unprivileged: true
        state: present
    
    - name: Start container
      proxmox_lxc:
        api_host: "{{ proxmox_api_host }}"
        api_user: "{{ proxmox_api_user }}"
        api_token_id: "{{ proxmox_api_token_id }}"
        api_token_secret: "{{ proxmox_api_token_secret }}"
        node: "{{ proxmox_node }}"
        vmid: 200
        state: started
```

### Backup Management

```yaml
# playbooks/backup_management.yml
---
- name: Manage backups
  hosts: proxmox_nodes
  gather_facts: no
  
  tasks:
    - name: Create backup job
      proxmox_backup:
        api_host: "{{ proxmox_api_host }}"
        api_user: "{{ proxmox_api_user }}"
        api_token_id: "{{ proxmox_api_token_id }}"
        api_token_secret: "{{ proxmox_api_token_secret }}"
        schedule: "0 2 * * *"
        storage: "local-backup"
        mode: "snapshot"
        enabled: true
        state: present
    
    - name: Run backup
      proxmox_backup:
        api_host: "{{ proxmox_api_host }}"
        api_user: "{{ proxmox_api_user }}"
        api_token_id: "{{ proxmox_api_token_id }}"
        api_token_secret: "{{ proxmox_api_token_secret }}"
        vmid: 100
        mode: "snapshot"
        storage: "local-backup"
        state: present
```

---

## Role Structure

```
roles/
├── vm_setup/
│   ├── tasks/
│   │   └── main.yml
│   ├── handlers/
│   │   └── main.yml
│   ├── vars/
│   │   └── main.yml
│   └── templates/
│       └── config.j2
├── container_setup/
│   └── (same structure)
└── backup_setup/
    └── (same structure)
```

### Example Role

```yaml
# roles/vm_setup/tasks/main.yml
---
- name: Install common packages
  apt:
    name:
      - curl
      - wget
      - vim
      - htop
    state: present

- name: Configure SSH
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "{{ item.regexp }}"
    line: "{{ item.line }}"
    state: present
  loop:
    - { regexp: '^PermitRootLogin', line: 'PermitRootLogin prohibit-password' }
    - { regexp: '^PasswordAuthentication', line: 'PasswordAuthentication no' }
  notify: restart sshd

- name: Create admin user
  user:
    name: admin
    groups: sudo
    shell: /bin/bash
    create_home: yes
```

---

## Learning Path Progression

1. **Beginner**: Simple playbooks for VM deployment
2. **Intermediate**: Roles, variables, conditionals
3. **Advanced**: Dynamic inventory, secrets management
4. **Enterprise**: CI/CD integration, policy enforcement

---

## Real-World Job Skill Mapping

- **DevOps Engineer**: All sections apply directly
- **SRE**: Configuration management, automation
- **Cloud Engineer**: Infrastructure automation
- **Platform Engineer**: Role development, standards

---

## Common Issues

### Issue 1: API Authentication

```bash
# Check API token
pvesh get /access/tokens

# Regenerate if needed
pvesh create /access/token --userid root@pam --description "ansible"
```

### Issue 2: Collection Not Found

```bash
# Install collection
ansible-galaxy collection install community.general

# Verify
ansible-galaxy collection list
```

---

> **Remember**: This is for learning. Production homelabs should prioritize simplicity. Use these techniques to build skills, not because you need them for daily services.
