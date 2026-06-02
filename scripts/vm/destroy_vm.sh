#!/usr/bin/env bash
# Destroy a VM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") --vmid <id> [options]

Destroy a VM.

Required:
  --vmid <id>    VMID to destroy

Optional:
  --force        Skip confirmation prompt
  --dry-run      Show what would be done without executing
  --cleanup      Remove associated disk images from storage
  -h, --help     Show this help

Examples:
  $(basename "$0") --vmid 100
  $(basename "$0") --vmid 100 --force
  $(basename "$0") --vmid 100 --force --cleanup
  $(basename "$0") --vmid 100 --dry-run
EOF
}

vmid=""
force=0
dry_run=0
cleanup=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid)    vmid="$2"; shift 2 ;;
    --force)   force=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    --cleanup) cleanup=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)         die "Unknown option: $1" ;;
  esac
done

[[ -n "$vmid" ]] || die "--vmid is required"
validate_vmid "$vmid"

check_vm_exists "$vmid" || die "VMID $vmid does not exist"

# Get VM details
vm_name=$(qm config "$vmid" 2>/dev/null | grep "^name:" | head -1 | sed 's/^name://')
vm_name="${vm_name:-unknown}"

vm_status=$(qm status "$vmid" 2>/dev/null | awk '/^status:/ {print $2}')
vm_status="${vm_status:-unknown}"

# Get disk info
disk_info=$(qm config "$vmid" 2>/dev/null | grep -E "^(scsi|virtio|sata)[0-9]" | sed 's/=.*//' || true)

echo ""
log_warn "=== Destroy VM ==="
log_info "Name:     $vm_name"
log_info "VMID:     $vmid"
log_info "Status:   $vm_status"
[[ -n "$disk_info" ]] && log_info "Disks:    $(echo "$disk_info" | tr '\n' ', ')"
echo ""

if [[ $force -eq 0 && $dry_run -eq 0 ]]; then
  confirm "Destroy VM $vmid ($vm_name)?"
fi

if [[ $dry_run -eq 1 ]]; then
  log_info "DRY RUN - no changes will be made"
  echo ""
  if [[ "$vm_status" == "running" ]]; then
    log_info "Would stop VM $vmid"
  fi
  snapshots=$(qm listsnapshots "$vmid" 2>/dev/null | tail -n +2 || true)
  if [[ -n "$snapshots" ]]; then
    log_info "Would remove snapshots:"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      log_info "  $(echo "$line" | awk '{print $1}')"
    done <<< "$snapshots"
  else
    log_info "No snapshots to remove"
  fi
  log_info "Would destroy VM $vmid"
  if [[ $cleanup -eq 1 ]]; then
    log_info "Would cleanup disk images:"
    while IFS= read -r disk_line; do
      [[ -z "$disk_line" ]] && continue
      if [[ "$disk_line" =~ ^(.+):(.+),size= ]]; then
        log_info "  ${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
      fi
    done < <(qm config "$vmid" 2>/dev/null | grep -E "^(scsi|virtio|sata)[0-9]" || true)
  else
    log_info "Disk cleanup not requested (--cleanup)"
  fi
  echo ""
  log_info "Dry run complete"
  exit 0
fi

# Stop if running
if [[ "$vm_status" == "running" ]]; then
  log_info "Stopping VM $vmid"
  qm stop "$vmid" 2>/dev/null || log_warn "Could not stop VM $vmid"
fi

# Remove snapshots
snapshots=$(qm listsnapshots "$vmid" 2>/dev/null | tail -n +2 || true)
if [[ -n "$snapshots" ]]; then
  log_info "Removing snapshots..."
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    snap_name=$(echo "$line" | awk '{print $1}')
    qm rollback "$vmid" "$snap_name" 2>/dev/null && qm snapshot "$vmid" "$snap_name" --delete 2>/dev/null || \
      qm snapshot "$vmid" "$snap_name" --delete 2>/dev/null || true
  done <<< "$snapshots"
fi

# Destroy VM
log_info "Destroying VM $vmid"
qm destroy "$vmid" 2>/dev/null || log_warn "Could not destroy VM $vmid"

# Cleanup disk images if requested
if [[ $cleanup -eq 1 ]]; then
  log_info "Cleaning up disk images..."
  while IFS= read -r disk_line; do
    [[ -z "$disk_line" ]] && continue
    if [[ "$disk_line" =~ ^(.+):(.+),size= ]]; then
      storage="${BASH_REMATCH[1]}"
      disk_name="${BASH_REMATCH[2]}"
      log_info "  Removing ${storage}:${disk_name}"
      pvesm free "${storage}:${disk_name}" 2>/dev/null || true
    fi
  done < <(qm config "$vmid" 2>/dev/null | grep -E "^(scsi|virtio|sata)[0-9]" || true)
fi

echo ""
log_info "VM $vmid ($vm_name) destroyed"
