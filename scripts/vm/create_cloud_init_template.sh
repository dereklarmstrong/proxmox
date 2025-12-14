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
  -n <name>        Template name (OS-specific default)
  -s <size>        Disk size (e.g. 20G, default: 10G)
  -d <url>         Cloud image URL (override OS default)
  -m <mb>          Memory in MB (default: 2048)
  -c <cores>       vCPU count (default: 2)
  -u <user>        Default username (OS-specific default)
  -p <password>    Default password (optional)
  -k <ssh-key>     Path to SSH public key (optional)
  -b <bridge>      Bridge name (default: $DEFAULT_BRIDGE)
  -t <storage>     Target storage (default: $DEFAULT_STORAGE)
  --os <ubuntu|ol8|ol9>  Image preset (default: ubuntu)
  --sha256 <hash>  Expected SHA256 for the image
  --no-verify      Skip checksum verification (not recommended)
  -h               Show help
EOF
}

vmid="$TEMPLATE_ID_START"
disk_size="10G"
memory_mb=2048
cpu_count=2
ci_password=""
ssh_key=""
bridge="$DEFAULT_BRIDGE"
storage="$DEFAULT_STORAGE"
os_preset="ubuntu"
verify_checksum=1
expected_hash=""

# Track if caller explicitly set values so OS presets don't override them.
image_url_set=0
vm_name_set=0
ci_user_set=0

# OS presets (urls, names, users, hashes)
default_url_ubuntu="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
default_name_ubuntu="ubuntu-24.04-cloudinit"
default_user_ubuntu="ubuntu"
default_hash_ubuntu=""

default_url_ol9="https://yum.oracle.com/templates/OracleLinux/OL9/u6/x86_64/OL9U6_x86_64-kvm-b265.qcow2"
default_name_ol9="oracle-linux-9-cloudinit"
default_user_ol9="opc"
default_hash_ol9="415274f04015112eeb972ed8a4e6941cb71df0318c4acba5a760931b7d7c0c69"

default_url_ol8="https://yum.oracle.com/templates/OracleLinux/OL8/u10/x86_64/OL8U10_x86_64-kvm-b258.qcow2"
default_name_ol8="oracle-linux-8-cloudinit"
default_user_ol8="opc"
default_hash_ol8="9b1f8a4eadc3f6094422674ec0794b292a28ee247593e74fe7310f77ecb8b9b9"

# Initial defaults (Ubuntu preset)
image_url="$default_url_ubuntu"
vm_name="$default_name_ubuntu"
ci_user="$default_user_ubuntu"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i) vmid="$2"; shift 2 ;;
    -n) vm_name="$2"; vm_name_set=1; shift 2 ;;
    -s) disk_size="$2"; shift 2 ;;
    -d) image_url="$2"; image_url_set=1; shift 2 ;;
    -m) memory_mb="$2"; shift 2 ;;
    -c) cpu_count="$2"; shift 2 ;;
    -u) ci_user="$2"; ci_user_set=1; shift 2 ;;
    -p) ci_password="$2"; shift 2 ;;
    -k) ssh_key="$2"; shift 2 ;;
    -b) bridge="$2"; shift 2 ;;
    -t) storage="$2"; shift 2 ;;
    --os) os_preset="$2"; shift 2 ;;
    --sha256) expected_hash="$2"; shift 2 ;;
    --no-verify) verify_checksum=0; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) usage; exit 1 ;;
  esac
done

apply_os_defaults() {
  case "$os_preset" in
    ubuntu)
      if [ $image_url_set -eq 0 ]; then image_url="$default_url_ubuntu"; fi
      if [ $vm_name_set -eq 0 ]; then vm_name="$default_name_ubuntu"; fi
      if [ $ci_user_set -eq 0 ]; then ci_user="$default_user_ubuntu"; fi
      if [ -z "$expected_hash" ]; then expected_hash="$default_hash_ubuntu"; fi
      ;;
    ol9)
      if [ $image_url_set -eq 0 ]; then image_url="$default_url_ol9"; fi
      if [ $vm_name_set -eq 0 ]; then vm_name="$default_name_ol9"; fi
      if [ $ci_user_set -eq 0 ]; then ci_user="$default_user_ol9"; fi
      if [ -z "$expected_hash" ]; then expected_hash="$default_hash_ol9"; fi
      ;;
    ol8)
      if [ $image_url_set -eq 0 ]; then image_url="$default_url_ol8"; fi
      if [ $vm_name_set -eq 0 ]; then vm_name="$default_name_ol8"; fi
      if [ $ci_user_set -eq 0 ]; then ci_user="$default_user_ol8"; fi
      if [ -z "$expected_hash" ]; then expected_hash="$default_hash_ol8"; fi
      ;;
    *)
      log_error "Unsupported --os value: $os_preset"; exit 1 ;;
  esac
}

apply_os_defaults

# Basic validation
[[ "$vmid" =~ ^[0-9]+$ ]] || { log_error "VMID must be numeric"; exit 1; }
[[ -n "$vm_name" ]] || { log_error "Name cannot be empty"; exit 1; }
[[ "$disk_size" =~ ^[0-9]+[GM]$ ]] || { log_error "Size must be like 20G or 20480M"; exit 1; }
[[ "$memory_mb" =~ ^[0-9]+$ ]] || { log_error "Memory must be numeric"; exit 1; }
[[ "$cpu_count" =~ ^[0-9]+$ ]] || { log_error "CPU count must be numeric"; exit 1; }

if [ $verify_checksum -eq 1 ] && [ -z "$expected_hash" ]; then
  log_error "Checksum is required for preset $os_preset; provide --sha256 or use --no-verify"
  exit 1
fi

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
  wget --https-only -O "$image_file" "$image_url"
fi

if [ $verify_checksum -eq 1 ]; then
  if ! echo "$expected_hash  $image_file" | sha256sum -c -; then
    log_error "Checksum verification failed for $image_file"
    rm -f "$image_file"
    exit 1
  fi
  log_info "Checksum verified for $image_file"
else
  log_warn "Checksum verification skipped (--no-verify)"
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
