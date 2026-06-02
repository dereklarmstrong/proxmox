# API Reference

## Authentication

### API Token (Recommended)

Create a token via Proxmox GUI: Datacenter → Permissions → API Tokens

```bash
# Use token with api_wrapper.sh
./scripts/api/api_wrapper.sh \
  --token root@pam!mytoken \
  --secret "your-secret-here" \
  GET /version
```

### Username/Password (Legacy)

```bash
./scripts/api/api_wrapper.sh \
  --user root@pam \
  --password "your_password" \
  GET /version
```

## Common API Calls

### Version

```bash
./scripts/api/api_wrapper.sh GET /version
```

### Nodes

```bash
# List all nodes
./scripts/api/api_wrapper.sh GET /cluster/resources --data '{"type":"node"}'

# Node status
./scripts/api/api_wrapper.sh GET /nodes/pve/status
```

### VMs

```bash
# List all VMs
./scripts/api/api_wrapper.sh GET /cluster/resources --data '{"type":"vm"}'

# VM status
./scripts/api/api_wrapper.sh GET /nodes/pve/qemu/100/status/current

# Start VM
./scripts/api/api_wrapper.sh POST /nodes/pve/qemu/100/status/start --data '{}'

# Stop VM
./scripts/api/api_wrapper.sh POST /nodes/pve/qemu/100/status/stop --data '{"unmount":true}'

# Shutdown VM
./scripts/api/api_wrapper.sh POST /nodes/pve/qemu/100/status/shutdown --data '{}'
```

### Containers

```bash
# List all containers
./scripts/api/api_wrapper.sh GET /cluster/resources --data '{"type":"lxc"}'

# Container status
./scripts/api/api_wrapper.sh GET /nodes/pve/lxc/200/status/current
```

### Storage

```bash
# List storages
./scripts/api/api_wrapper.sh GET /nodes/pve/storage

# Storage status
./scripts/api/api_wrapper.sh GET /nodes/pve/storage/local-lvm/status
```

### Backups

```bash
# List backups
./scripts/api/api_wrapper.sh GET /nodes/pve/storage/backup-lvm/content

# Create backup
./scripts/api/api_wrapper.sh POST /nodes/pve/storage/backup-lvm/content \
  --data '{"vmid":100,"mode":"snapshot","storage":"backup-lvm"}'
```

### Network

```bash
# List networks
./scripts/api/api_wrapper.sh GET /nodes/pve/network

# Create VLAN
./scripts/api/api_wrapper.sh POST /nodes/pve/network \
  --data '{"iface":"vmbr100.100","method":"manual","vlan-raw-device":"vmbr100","vlan-id":"100"}'
```

## API Patterns

### Filter Resources

```bash
# VMs only
./scripts/api/api_wrapper.sh GET /cluster/resources --data '{"type":"vm"}'

# Node only
./scripts/api/api_wrapper.sh GET /cluster/resources --data '{"type":"node"}'

# Storage only
./scripts/api/api_wrapper.sh GET /cluster/resources --data '{"type":"storage"}'
```

### JSON Output

All API calls output JSON by default. Pipe to `jq` for formatting:

```bash
./scripts/api/api_wrapper.sh GET /cluster/resources | jq '.data[] | {id, name, type}'
```

### Error Handling

API errors return HTTP status codes:

- `200` — Success
- `400` — Bad request (invalid parameters)
- `401` — Unauthorized (bad credentials/token)
- `403` — Forbidden (no permissions)
- `404` — Not found
- `500` — Server error

## Using pvesh

The `pvesh` command-line tool is built into Proxmox:

```bash
# List VMs
pvesh get /cluster/resources --type vm

# Get node info
pvesh get /nodes/pve

# Create VM
pvesh create /nodes/pve/qemu --memory 2048 --cores 2 --name test-vm
```

## API Wrapper Functions

`lib/common.sh` includes helper functions:

```bash
source lib/common.sh

# Get data via pvesh
pvesh_get /nodes/pve/qemu/100/status/current

# Post data via pvesh
pvesh_post /nodes/pve/qemu/100/status/start --data '{}'
```
