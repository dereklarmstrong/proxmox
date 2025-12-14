#!/usr/bin/env bash
# Back up all VMs and containers

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../lib/common.sh
source "$REPO_ROOT/lib/common.sh"
source_config
require_root

BACKUP_VM_SCRIPT="$SCRIPT_DIR/backup_vm.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
  -s <storage>  Target storage (default: $BACKUP_STORAGE)
  -m <mode>     Mode: snapshot|stop|suspend (default: snapshot)
  -c <comp>     Compression: zstd|lzo|gzip (default: zstd)
  -h            Help
EOF
}

storage="$BACKUP_STORAGE"
mode="snapshot"
compress="zstd"

while getopts ":s:m:c:h" opt; do
  case "$opt" in
    s) storage="$OPTARG" ;;
    m) mode="$OPTARG" ;;
    c) compress="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

mapfile -t vm_ids < <(qm list | awk 'NR>1 {print $1}')
mapfile -t ct_ids < <(pct list | awk 'NR>1 {print $1}')

to_backup=("${vm_ids[@]}" "${ct_ids[@]}")

for id in "${to_backup[@]}"; do
  [ -n "$id" ] || continue
  log_info "Backing up ID $id"
  "$BACKUP_VM_SCRIPT" -i "$id" -s "$storage" -m "$mode" -c "$compress"

done

log_info "All backups completed"
