#!/usr/bin/env bash
# Create a snapshot of a VM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") --vmid <id> [options]

Create a snapshot of a VM.

Required:
  --vmid <id>        VMID to snapshot

Optional:
  --name <name>      Snapshot name (default: YYYY-MM-DD-HHMMSS)
  --description <d>  Snapshot description
  -h, --help         Show this help

Examples:
  $(basename "$0") --vmid 100
  $(basename "$0") --vmid 100 --name before-upgrade --description "Pre-upgrade state"
EOF
}

vmid=""
snap_name=""
description=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid)        vmid="$2"; shift 2 ;;
    --name)        snap_name="$2"; shift 2 ;;
    --description) description="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *)             die "Unknown option: $1" ;;
  esac
done

[[ -n "$vmid" ]] || die "--vmid is required"
validate_vmid "$vmid"

check_vm_exists "$vmid" || die "VMID $vmid does not exist"

# Default snapshot name
if [[ -z "$snap_name" ]]; then
  snap_name="$(date +%Y-%m-%d-%H%M%S)"
fi

# Check VM status
vm_status=$(qm status "$vmid" 2>/dev/null | awk '/^status:/ {print $2}')
if [[ "$vm_status" == "stopped" ]]; then
  log_warn "VM is stopped. Snapshot may not capture current state."
  confirm "Continue anyway?"
fi

log_info "Creating snapshot '${snap_name}' for VM $vmid"
qm snapshot "$vmid" "$snap_name" 2>&1 || die "Failed to create snapshot"

if [[ -n "$description" ]]; then
  qm set "$vmid" --description "$description" 2>&1 || log_warn "Could not set snapshot description"
fi

echo ""
log_info "Snapshot created: $snap_name"
log_info "Rollback: qm rollback $vmid $snap_name"
