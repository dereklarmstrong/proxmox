#!/usr/bin/env bash
# Create a cloud-init enabled VM template

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") --image <url|path> --name <template-name> --vmid <id> [options]

Create a cloud-init enabled VM template from a disk image.

Required:
  --image <url|path>   Cloud image URL or local file path
  --name <name>        Template name
  --vmid <id>          VMID for the template (must be >= 100)

Optional:
  --storage <store>    Target storage (default: $DEFAULT_STORAGE)
  --disk <size>        Disk size (default: 10G)
  --cores <n>          vCPU count (default: 2)
  --memory <mb>        Memory in MB (default: 2048)
  --user <username>    Cloud-init username (default: ubuntu)
  --sshkey <path>      SSH public key path
  -h, --help           Show this help

Examples:
  $(basename "$0") --image https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img \
    --name ubuntu-2404-template --vmid 9000
EOF
}

image=""
name=""
vmid=""
storage="$DEFAULT_STORAGE"
disk_size="10G"
cores=2
memory=2048
ci_user="ubuntu"
ssh_key=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)  image="$2"; shift 2 ;;
    --name)   name="$2"; shift 2 ;;
    --vmid)   vmid="$2"; shift 2 ;;
    --storage) storage="$2"; shift 2 ;;
    --disk)   disk_size="$2"; shift 2 ;;
    --cores)  cores="$2"; shift 2 ;;
    --memory) memory="$2"; shift 2 ;;
    --user)   ci_user="$2"; shift 2 ;;
    --sshkey) ssh_key="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)        die "Unknown option: $1" ;;
  esac
done

# Validate required args
[[ -n "$image" ]] || die "--image is required"
[[ -n "$name" ]] || die "--name is required"
[[ -n "$vmid" ]] || die "--vmid is required"

validate_vmid "$vmid"

# Validate numeric params
[[ "$cores" =~ ^[0-9]+$ ]] || die "Cores must be a positive integer"
[[ "$memory" =~ ^[0-9]+$ ]] || die "Memory must be a positive integer"

# Check VMID doesn't already exist
if check_vm_exists "$vmid"; then
  die "VMID $vmid already exists"
fi

# Download image if URL
image_file="$(basename "$image")"
if [[ "$image" =~ ^https?:// ]]; then
  log_info "Downloading image from $image"
  if [[ ! -f "$image_file" ]]; then
    wget --https-only -O "$image_file" "$image" || die "Failed to download image"
  fi
elif [[ ! -f "$image" ]]; then
  die "Image file not found: $image"
fi

log_info "Creating VM $vmid ($name)"
qm create "$vmid" --memory "$memory" --cores "$cores" --name "$name" \
  --net0 "virtio,bridge=$DEFAULT_BRIDGE"

log_info "Importing disk to $storage"
qm importdisk "$vmid" "$image_file" "$storage"

log_info "Configuring VM"
qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "${storage}:vm-${vmid}-disk-0"
qm set "$vmid" --ide2 "${storage}:cloudinit"
qm set "$vmid" --boot c --bootdisk scsi0
qm resize "$vmid" scsi0 "$disk_size"
qm set "$vmid" --ciuser "$ci_user"
qm set "$vmid" --serial0 socket --vga serial0

if [[ -n "$ssh_key" ]]; then
  ensure_ssh_key "$ssh_key"
  qm set "$vmid" --sshkey "$ssh_key"
  log_info "SSH key attached"
fi

log_info "Converting to template"
qm template "$vmid"

echo ""
log_info "=== Template Ready ==="
log_info "Name:  $name"
log_info "VMID:  $vmid"
log_info "User:  $ci_user"
[[ -n "$ssh_key" ]] && log_info "SSH:   $ssh_key"
echo ""
log_info "Clone with: $(basename "$0") --template $vmid ..."
