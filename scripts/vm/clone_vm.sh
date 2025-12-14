#!/usr/bin/env bash
# Full clone a VM template and optionally configure network + SSH key

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../lib/common.sh
source "$REPO_ROOT/lib/common.sh"
source_config
require_root

usage() {
  cat <<EOF
Usage: $(basename "$0") -s <source_vmid> -d <dest_vmid> -n <name> [options]
  -s <id>     Source template/VM ID (required)
  -d <id>     Destination VMID (required)
  -n <name>   Destination VM name (required)
  -i <cidr>   IP address with CIDR (e.g. 192.168.1.50/24). If omitted, DHCP is used.
  -g <gw>     Gateway IP (used only if -i is set). Defaults to first host in subnet.
  -b <bridge> Bridge name (default: $DEFAULT_BRIDGE)
  -k <ssh>    SSH public key path (default: $SSH_KEY_PATH)
  -h          Help
EOF
}

src=""
dst=""
name=""
ip_cidr=""
gateway=""
bridge="$DEFAULT_BRIDGE"
ssh_key="$SSH_KEY_PATH"

while getopts ":s:d:n:i:g:b:k:h" opt; do
  case "$opt" in
    s) src="$OPTARG" ;;
    d) dst="$OPTARG" ;;
    n) name="$OPTARG" ;;
    i) ip_cidr="$OPTARG" ;;
    g) gateway="$OPTARG" ;;
    b) bridge="$OPTARG" ;;
    k) ssh_key="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[[ -n "$src" ]] || { log_error "Source VMID required"; usage; exit 1; }
[[ -n "$dst" ]] || { log_error "Destination VMID required"; usage; exit 1; }
[[ -n "$name" ]] || { log_error "VM name required"; usage; exit 1; }
[[ "$src" =~ ^[0-9]+$ ]] || { log_error "Source VMID must be numeric"; exit 1; }
[[ "$dst" =~ ^[0-9]+$ ]] || { log_error "Destination VMID must be numeric"; exit 1; }

if ! check_vm_exists "$src"; then
  log_error "Source VMID $src does not exist"
  exit 1
fi

if check_vm_exists "$dst"; then
  log_error "Destination VMID $dst already exists"
  exit 1
fi

if [ -n "$ssh_key" ]; then
  ensure_ssh_key "$ssh_key"
fi

log_info "Cloning VM $src -> $dst ($name)"
qm clone "$src" "$dst" --name "$name" --full 1

qm set "$dst" --sshkey "$ssh_key"
qm set "$dst" --net0 "virtio,bridge=$bridge"

if [ -n "$ip_cidr" ]; then
  if [[ "$ip_cidr" != */* ]]; then
    ip_cidr="$ip_cidr/24"
  fi
  if [ -z "$gateway" ]; then
    # derive gateway from first three octets if IPv4
    gateway=$(echo "$ip_cidr" | cut -d'/' -f1 | awk -F. '{print $1"."$2"."$3".1"}')
    log_info "Gateway not provided; using $gateway"
  fi
  log_info "Configuring static IP $ip_cidr (gw $gateway)"
  qm set "$dst" --ipconfig0 "ip=$ip_cidr,gw=$gateway"
else
  log_info "Using DHCP for network configuration"
fi

log_info "Starting VM $dst"
qm start "$dst"

log_info "Clone complete: VMID $dst ($name)"
