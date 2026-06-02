#!/usr/bin/env bash
# Back up a single VM or container

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") --vmid <id> [options]
       $(basename "$0") --ctid <id> [options]

Back up a single VM or container using vzdump.

Required (choose one):
  --vmid <id>    VMID to back up
  --ctid <id>    Container ID to back up

Optional:
  --storage <store>  Target backup storage (default: $BACKUP_STORAGE)
  --mode <mode>      Backup mode: snapshot, suspend, stop (default: snapshot)
  --compress <alg>   Compression: zstd, gzip, lzo, none (default: zstd)
  --description <d>  Backup description
  -h, --help         Show this help

Examples:
  $(basename "$0") --vmid 100
  $(basename "$0") --vmid 100 --storage PBS --mode stop --compress gzip
  $(basename "$0") --ctid 200 --description "Pre-migration backup"
EOF
}

vmid=""
ctid=""
storage="$BACKUP_STORAGE"
mode="snapshot"
compress="zstd"
description=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid)        vmid="$2"; shift 2 ;;
    --ctid)        ctid="$2"; shift 2 ;;
    --storage)     storage="$2"; shift 2 ;;
    --mode)        mode="$2"; shift 2 ;;
    --compress)    compress="$2"; shift 2 ;;
    --description) description="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *)             die "Unknown option: $1" ;;
  esac
done

[[ -n "$vmid" || -n "$ctid" ]] || die "Specify --vmid or --ctid"
[[ -z "$vmid" || -z "$ctid" ]] || die "Specify only one of --vmid or --ctid"

validate_vmid "${vmid:-$ctid}"

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

# Check ID exists
if [[ -n "$vmid" ]]; then
  check_vm_exists "$vmid" || die "VMID $vmid does not exist"
  id_type="vm"
else
  check_ct_exists "$ctid" || die "CTID $ctid does not exist"
  id_type="ct"
fi

log_info "Starting backup"
log_info "  Type:     $id_type"
log_info "  ID:       ${vmid:-$ctid}"
log_info "  Storage:  $storage"
log_info "  Mode:     $mode"
log_info "  Compress: $compress"
[[ -n "$description" ]] && log_info "  Desc:     $description"
echo ""

# Build vzdump command
vz_cmd=(vzdump)
vz_cmd+=("${vmid:-$ctid}")
vz_cmd+=(--storage "$storage")
vz_cmd+=(--mode "$mode")
vz_cmd+=(--compress "$compress")

if [[ -n "$description" ]]; then
  vz_cmd+=(--description "$description")
fi

# Run backup
log_info "Running vzdump..."
vzdump_output=$("${vz_cmd[@]}" 2>&1) || {
  echo "$vzdump_output"
  die "Backup failed"
}

echo "$vzdump_output"

# Extract backup file path from output
backup_file=$(echo "$vzdump_output" | grep -oP '/var/lib/vz/dump/\K\S+' | head -1 || true)
if [[ -n "$backup_file" && -f "$backup_file" ]]; then
  backup_size=$(du -h "$backup_file" | awk '{print $1}')
  echo ""
  log_info "=== Backup Complete ==="
  log_info "File:   $backup_file"
  log_info "Size:   $backup_size"
else
  echo ""
  log_info "Backup complete (file path not detected in output)"
fi
