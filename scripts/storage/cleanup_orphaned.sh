#!/usr/bin/env bash
# Clean up orphaned disk images

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Find and clean up orphaned disk images that are not referenced by any VM.

Options:
  --storage <store>  Storage name to scan (default: all)
  --dry-run          Show orphaned files without deleting
  --force            Skip confirmation prompt
  -h, --help         Show this help

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") --storage local-lvm --force
EOF
}

storage=""
dry_run=1
force=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --storage) storage="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --force)   force=1; dry_run=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *)         die "Unknown option: $1" ;;
  esac
done

log_info "=== Orphaned Disk Cleanup ==="
echo ""

# Get list of VMs
declare -a vm_ids=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  vm_id=$(echo "$line" | awk '{print $1}')
  [[ -n "$vm_id" ]] && vm_ids+=("$vm_id")
done < <(qm list 2>/dev/null | awk 'NR>1 {print $1}')

# Get list of containers
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  ct_id=$(echo "$line" | awk '{print $1}')
  [[ -n "$ct_id" ]] && vm_ids+=("$ct_id")
done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')

log_info "Known VMs: ${#vm_ids[@]}"

# Find disk images
declare -a orphaned=()
declare -a total_size=0

# Search common storage locations
search_dirs=()
if [[ -n "$storage" ]]; then
  search_dirs+=("/var/lib/vz/${storage}" "/var/lib/vz/dump")
else
  search_dirs+=("/var/lib/vz" "/var/lib/vz/dump")
  # Add additional storage paths
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    store_name=$(echo "$line" | awk '{print $1}')
    [[ "$store_name" == "name" ]] && continue
    search_dirs+=("/var/lib/vz/${store_name}")
  done < <(pvesm status --content images 2>/dev/null | awk 'NR>1 {print $1}' || true)
fi

for dir in "${search_dirs[@]}"; do
  [[ -d "$dir" ]] || continue
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Check if file is referenced by any VM config
    referenced=0
    for vm_id in "${vm_ids[@]}"; do
      if qm config "$vm_id" 2>/dev/null | grep -q "$file"; then
        referenced=1
        break
      fi
    done
    if [[ $referenced -eq 0 ]]; then
      file_size=$(stat -c %s "$file" 2>/dev/null || echo "0")
      orphaned+=("$file")
      total_size=$((total_size + file_size))
    fi
  done < <(find "$dir" -name "*.qcow2" -o -name "*.raw" -o -name "*.img" -o -name "*.vmdk" 2>/dev/null || true)
done

if [[ ${#orphaned[@]} -eq 0 ]]; then
  log_info "No orphaned disk images found"
  exit 0
fi

echo ""
log_warn "=== Orphaned Files Found ==="
for f in "${orphaned[@]}"; do
  file_size=$(stat -c %s "$f" 2>/dev/null || echo "0")
  human_size=$(numfmt --to=iec $file_size 2>/dev/null || echo "${file_size}B")
  log_info "  $f (${human_size})"
done
echo ""

human_total=$(numfmt --to=iec $total_size 2>/dev/null || echo "${total_size}B")
log_info "Total orphaned: ${#orphaned[@]} files (${human_total})"
echo ""

if [[ $dry_run -eq 1 ]]; then
  log_info "Dry run mode - no files deleted"
  exit 0
fi

if [[ $force -eq 0 ]]; then
  confirm "Delete ${#orphaned[@]} orphaned files (${human_total})?"
fi

deleted=0
for f in "${orphaned[@]}"; do
  log_info "Deleting: $f"
  rm -f "$f" && deleted=$((deleted + 1))
done

echo ""
log_info "Cleanup complete"
log_info "Deleted: $deleted files"
