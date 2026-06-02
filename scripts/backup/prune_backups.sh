#!/usr/bin/env bash
# Prune vzdump backups older than retention days

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
Usage: $(basename "$0") [-d /path/to/dump] [-r days]
  -d <dir>   Backup directory (default: /var/lib/vz/dump)
  -r <days>  Retention in days (default: $BACKUP_RETENTION_DAYS)
  -h         Help
EOF
}

dump_dir="/var/lib/vz/dump"
retention="$BACKUP_RETENTION_DAYS"

while getopts ":d:r:h" opt; do
  case "$opt" in
    d) dump_dir="$OPTARG" ;;
    r) retention="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[[ -d "$dump_dir" ]] || { log_error "Backup dir not found: $dump_dir"; exit 1; }
[[ "$retention" =~ ^[0-9]+$ ]] || { log_error "Retention must be numeric"; exit 1; }

log_info "Pruning backups older than $retention days in $dump_dir"
find "$dump_dir" -maxdepth 1 -type f \( -name 'vzdump-*.tar.zst' -o -name 'vzdump-*.tar.gz' -o -name 'vzdump-*.tar.lzo' \) -mtime "+$retention" -print -delete
log_info "Prune complete"
