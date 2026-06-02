#!/usr/bin/env bash
# Back up all VMs and containers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Back up all VMs and containers using vzdump --all.

Options:
  --storage <store>    Target backup storage (default: $BACKUP_STORAGE)
  --mode <mode>        Backup mode: snapshot, suspend, stop (default: snapshot)
  --exclude <list>     Comma-separated VMID/CTIDs to exclude (e.g. 999,200)
  --compress <alg>     Compression: zstd, gzip, lzo, none (default: zstd)
  --dry-run            Show what would be backed up without running
  -h, --help           Show this help

Examples:
  $(basename "$0")
  $(basename "$0") --storage PBS --mode stop
  $(basename "$0") --exclude 999,200 --compress gzip
EOF
}

storage="$BACKUP_STORAGE"
mode="snapshot"
exclude=""
compress="zstd"
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --storage)    storage="$2"; shift 2 ;;
    --mode)       mode="$2"; shift 2 ;;
    --exclude)    exclude="$2"; shift 2 ;;
    --compress)   compress="$2"; shift 2 ;;
    --dry-run)    dry_run=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "Unknown option: $1" ;;
  esac
done

# Validate mode
case "$mode" in
  snapshot|suspend|stop) ;;
  *) die "Mode must be snapshot, suspend, or stop" ;;
esac

# Validate compression
case "$compress" in
  zstd|gzip|lzo|none) ;;
  *) die "Compression must be zstd, gzip, lzo, or none" ;;
esac

# Build exclude list
exclude_args=""
if [[ -n "$exclude" ]]; then
  IFS=',' read -ra exclude_arr <<< "$exclude"
  for eid in "${exclude_arr[@]}"; do
    exclude_args+=" --exclude $eid"
  done
fi

log_info "Backup all VMs and containers"
log_info "  Storage:  $storage"
log_info "  Mode:     $mode"
log_info "  Compress: $compress"
[[ -n "$exclude" ]] && log_info "  Exclude:  $exclude"
echo ""

# Enumerate what would be backed up
log_info "Enumerating VMs..."
declare -a vm_list=()
while IFS= read -r vmid; do
  [[ -z "$vmid" ]] && continue
  if [[ -n "$exclude" ]]; then
    skip=0
    IFS=',' read -ra exclude_arr <<< "$exclude"
    for eid in "${exclude_arr[@]}"; do
      [[ "$vmid" == "$eid" ]] && skip=1
    done
    [[ $skip -eq 1 ]] && continue
  fi
  vm_list+=("$vmid")
done < <(qm list 2>/dev/null | awk 'NR>1 {print $1}')

log_info "Enumerating containers..."
declare -a ct_list=()
while IFS= read -r ctid; do
  [[ -z "$ctid" ]] && continue
  if [[ -n "$exclude" ]]; then
    skip=0
    IFS=',' read -ra exclude_arr <<< "$exclude"
    for eid in "${exclude_arr[@]}"; do
      [[ "$ctid" == "$eid" ]] && skip=1
    done
    [[ $skip -eq 1 ]] && continue
  fi
  ct_list+=("$ctid")
done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')

total=$((${#vm_list[@]} + ${#ct_list[@]}))
if [[ $total -eq 0 ]]; then
  log_info "No VMs or containers to back up"
  exit 0
fi

log_info "Found $total items to back up (${#vm_list[@]} VMs, ${#ct_list[@]} containers)"
echo ""

if [[ $dry_run -eq 1 ]]; then
  log_info "Dry run mode - skipping actual backup"
  echo ""
  log_info "VMs:"
  for v in "${vm_list[@]}"; do
    vname=$(qm config "$v" 2>/dev/null | grep "^name:" | head -1 | sed 's/^name://' || echo "-")
    log_info "  VM $v ($vname)"
  done
  echo ""
  log_info "Containers:"
  for c in "${ct_list[@]}"; do
    chost=$(pct config "$c" 2>/dev/null | grep "^hostname:" | head -1 | sed 's/^hostname://' || echo "-")
    log_info "  CT $c ($chost)"
  done
  exit 0
fi

# Run vzdump --all
log_info "Starting vzdump --all..."
vzdump_args=(--storage "$storage" --mode "$mode" --compress "$compress")
if [[ -n "$exclude" ]]; then
  IFS=',' read -ra exclude_arr <<< "$exclude"
  for eid in "${exclude_arr[@]}"; do
    vzdump_args+=(--exclude "$eid")
  done
fi

vzdump_output=$(vzdump --all "${vzdump_args[@]}" 2>&1) || {
  echo "$vzdump_output"
  die "Backup failed"
}

echo ""
log_info "=== Backup Complete ==="
log_info "Total items: $total"

# Parse summary from output
backup_count=$(echo "$vzdump_output" | grep -cP 'INFO: backup' || true)
log_info "Backup jobs started: $backup_count"

# Show backup files created
echo ""
log_info "Backup files:"
while IFS= read -r bfile; do
  [[ -z "$bfile" ]] && continue
  fname=$(basename "$bfile")
  fsize=$(du -h "$bfile" | awk '{print $1}')
  log_info "  $fname ($fsize)"
done < <(find /var/lib/vz/dump/ -name "vzdump*" -newer /tmp/.backup_start_marker 2>/dev/null || true)
