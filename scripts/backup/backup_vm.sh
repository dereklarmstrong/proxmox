#!/usr/bin/env bash
# Run vzdump for a single VM or CT

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
Usage: $(basename "$0") -i <vmid|ctid> [options]
  -i <id>       VMID/CTID to back up (required)
  -s <storage>  Target storage (default: $BACKUP_STORAGE)
  -m <mode>     Mode: snapshot|stop|suspend (default: snapshot)
  -c <comp>     Compression: zstd|lzo|gzip (default: zstd)
  -h            Help
EOF
}

id=""
storage="$BACKUP_STORAGE"
mode="snapshot"
compress="zstd"

while getopts ":i:s:m:c:h" opt; do
  case "$opt" in
    i) id="$OPTARG" ;;
    s) storage="$OPTARG" ;;
    m) mode="$OPTARG" ;;
    c) compress="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[[ -n "$id" && "$id" =~ ^[0-9]+$ ]] || { log_error "ID required and must be numeric"; exit 1; }

log_info "Backing up ID $id to storage $storage (mode=$mode, compress=$compress)"
vzdump "$id" --storage "$storage" --mode "$mode" --compress "$compress"
log_info "Backup complete for ID $id"
