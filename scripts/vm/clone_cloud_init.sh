#!/usr/bin/env bash
# Clone a cloud-init template and configure with static IP, SSH key, and user

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") --template <vmid> --name <name> --vmid <id> \
       --ip <ip/cidr> --gateway <gw> [options]

Clone a cloud-init template and configure a new VM with static IP and SSH key.

Required:
  --template <id>    Source template VMID
  --name <name>      Destination VM name
  --vmid <id>        Destination VMID (must be >= 100)
  --ip <ip/cidr>     Static IP with CIDR (e.g. 10.0.1.50/24)
  --gateway <gw>     Gateway IP (e.g. 10.0.1.1)

Optional:
  --cores <n>        vCPU count (default: 2)
  --memory <mb>      Memory in MB (default: 2048)
  --disk <size>      Disk size (default: 8G)
  --storage <store>  Target storage (default: $DEFAULT_STORAGE)
  --bridge <br>      Network bridge (default: $DEFAULT_BRIDGE)
  --sshkey <path>    SSH public key path
  --user <username>  Cloud-init username (default: ubuntu)
  --dns <server>     DNS server (default: gateway IP)
  --start            Start the VM after cloning
  -h, --help         Show this help

Examples:
  $(basename "$0") --template 9000 --name dev-box --vmid 110 \
    --ip 10.0.1.50/24 --gateway 10.0.1.1 --sshkey ~/.ssh/id_ed25519.pub --start
EOF
}

template=""
name=""
vmid=""
ip_cidr=""
gateway=""
cores=2
memory=2048
disk_size="8G"
storage="$DEFAULT_STORAGE"
bridge="$DEFAULT_BRIDGE"
ssh_key=""
ci_user="ubuntu"
dns=""
start=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template) template="$2"; shift 2 ;;
    --name)     name="$2"; shift 2 ;;
    --vmid)     vmid="$2"; shift 2 ;;
    --ip)       ip_cidr="$2"; shift 2 ;;
    --gateway)  gateway="$2"; shift 2 ;;
    --cores)    cores="$2"; shift 2 ;;
    --memory)   memory="$2"; shift 2 ;;
    --disk)     disk_size="$2"; shift 2 ;;
    --storage)  storage="$2"; shift 2 ;;
    --bridge)   bridge="$2"; shift 2 ;;
    --sshkey)   ssh_key="$2"; shift 2 ;;
    --user)     ci_user="$2"; shift 2 ;;
    --dns)      dns="$2"; shift 2 ;;
    --start)    start=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    *)          die "Unknown option: $1" ;;
  esac
done

# Validate required args
[[ -n "$template" ]] || die "--template is required"
[[ -n "$name" ]] || die "--name is required"
[[ -n "$vmid" ]] || die "--vmid is required"
[[ -n "$ip_cidr" ]] || die "--ip is required"
[[ -n "$gateway" ]] || die "--gateway is required"

validate_vmid "$vmid"
validate_ip "$ip_cidr"

# Validate template exists
check_vm_exists "$template" || die "Template VMID $template does not exist"

# Check destination doesn't exist
if check_vm_exists "$vmid"; then
  die "VMID $vmid already exists"
fi

# Validate numeric params
[[ "$cores" =~ ^[0-9]+$ ]] || die "Cores must be a positive integer"
[[ "$memory" =~ ^[0-9]+$ ]] || die "Memory must be a positive integer"

# DNS defaults to gateway if not specified
[[ -n "$dns" ]] || dns="$gateway"

# SSH key validation
if [[ -n "$ssh_key" ]]; then
  ensure_ssh_key "$ssh_key"
fi

log_info "Cloning template $template -> $vmid ($name)"

# Full clone
qm clone "$template" "$vmid" --name "$name" --full 1
log_info "Clone complete"

# Set resources
qm set "$vmid" --cores "$cores" --memory "$memory"
log_info "Resources: ${cores} cores, ${memory}MB RAM"

# Resize disk if specified
qm set "$vmid" --scsi0 "${storage}:vm-${vmid}-disk-0,size=${disk_size}"
log_info "Disk: ${disk_size}"

# Network with cloud-init
qm set "$vmid" --net0 "virtio,bridge=${bridge},ip=${ip_cidr},gw=${gateway}"
qm set "$vmid" --ipconfig0 "ip=${ip_cidr},gw=${gateway}"
qm set "$vmid" --nameserver "$dns"

# Cloud-init user
qm set "$vmid" --ciuser "$ci_user"

# SSH key
if [[ -n "$ssh_key" ]]; then
  qm set "$vmid" --sshkey "$ssh_key"
  log_info "SSH key deployed"
fi

# Set boot order
qm set "$vmid" --boot c --bootdisk scsi0

if [[ $start -eq 1 ]]; then
  log_info "Starting VM $vmid"
  qm start "$vmid"
fi

echo ""
log_info "=== VM Ready ==="
log_info "Name:    $name"
log_info "VMID:    $vmid"
log_info "IP:      $ip_cidr"
log_info "Gateway: $gateway"
log_info "DNS:     $dns"
[[ -n "$ssh_key" ]] && log_info "SSH key: $ssh_key"
echo ""
if [[ $start -eq 1 ]]; then
  log_info "SSH: ssh ${ci_user}@$(echo "$ip_cidr" | cut -d/ -f1)"
else
  log_warn "VM not started. Run 'qm start $vmid' to start it."
fi
