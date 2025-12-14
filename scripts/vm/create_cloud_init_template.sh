#!/usr/bin/env bash
# Create a cloud-init VM template (QEMU)

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
Usage: $(basename "$0") [options]
  -i <id>          VMID to use (default: $TEMPLATE_ID_START)
  -n <name>        Template name (default: ubuntu-24.04-cloudinit)
  -s <size>        Disk size (e.g. 20G, default: 10G)
  -d <url>         Cloud image URL (default: Ubuntu 24.04 image)
  -m <mb>          Memory in MB (default: 2048)
  -c <cores>       vCPU count (default: 2)
  -u <user>        Default username (default: ubuntu)
  -p <password>    Default password (required if set)
  -k <ssh-key>     Path to SSH public key (optional)
  -b <bridge>      Bridge name (default: $DEFAULT_BRIDGE)
  -t <storage>     Target storage (default: $DEFAULT_STORAGE)
  -h               Show help
EOF
}

vmid="$TEMPLATE_ID_START"
vm_name="ubuntu-24.04-cloudinit"
disk_size="10G"
image_url="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
memory_mb=2048
cpu_count=2
ci_user="ubuntu"
ci_password=""
ssh_key=""
bridge="$DEFAULT_BRIDGE"
storage="$DEFAULT_STORAGE"

while getopts ":i:n:s:d:m:c:u:p:k:b:t:h" opt; do
  case "$opt" in
    i) vmid="$OPTARG" ;;
    n) vm_name="$OPTARG" ;;
    s) disk_size="$OPTARG" ;;
    d) image_url="$OPTARG" ;;
    m) memory_mb="$OPTARG" ;;
    c) cpu_count="$OPTARG" ;;
    u) ci_user="$OPTARG" ;;
    p) ci_password="$OPTARG" ;;
    k) ssh_key="$OPTARG" ;;
    b) bridge="$OPTARG" ;;
    t) storage="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

# Basic validation
[[ "$vmid" =~ ^[0-9]+$ ]] || { log_error "VMID must be numeric"; exit 1; }
[[ -n "$vm_name" ]] || { log_error "Name cannot be empty"; exit 1; }
[[ "$disk_size" =~ ^[0-9]+[GM]$ ]] || { log_error "Size must be like 20G or 20480M"; exit 1; }
[[ "$memory_mb" =~ ^[0-9]+$ ]] || { log_error "Memory must be numeric"; exit 1; }
[[ "$cpu_count" =~ ^[0-9]+$ ]] || { log_error "CPU count must be numeric"; exit 1; }

if [ -n "$ssh_key" ]; then
  ensure_ssh_key "$ssh_key"
fi

if check_vm_exists "$vmid"; then
  log_error "VMID $vmid already exists"
  exit 1
fi

image_file=$(basename "$image_url")

if [ ! -f "$image_file" ]; then
  log_info "Downloading $image_file"
  wget -O "$image_file" "$image_url"
fi

log_info "Creating VM $vmid ($vm_name)"
qm create "$vmid" --memory "$memory_mb" --cores "$cpu_count" --name "$vm_name" --net0 "virtio,bridge=$bridge"

log_info "Importing disk to $storage"
qm importdisk "$vmid" "$image_file" "$storage"

log_info "Attaching disk and cloud-init drive"
qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "$storage:vm-$vmid-disk-0"
qm set "$vmid" --ide2 "$storage:cloudinit"
qm set "$vmid" --boot c --bootdisk scsi0
qm resize "$vmid" scsi0 "$disk_size"

log_info "Configuring cloud-init"
qm set "$vmid" --ciuser "$ci_user"
if [ -n "$ci_password" ]; then
  qm set "$vmid" --cipassword "$ci_password"
fi
if [ -n "$ssh_key" ]; then
  qm set "$vmid" --sshkey "$ssh_key"
fi
qm set "$vmid" --serial0 socket --vga serial0

log_info "Converting VM $vmid to template"
qm template "$vmid"

log_info "Template ready: $vm_name (VMID $vmid). Clone with: qm clone $vmid <newid> --name <name> --full"
