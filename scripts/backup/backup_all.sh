#!/usr/bin/env bash
#
# WHAT: Back up all VMs and containers in the Proxmox cluster
# LEARNING: Backup automation, vzdump usage, backup strategies
# WHEN YOU NEED: Regular backup scheduling, disaster recovery preparation
# SIMPLER: Manual backup via Proxmox GUI for single VMs
# PITFALLS: Backup storage exhaustion, backup failures, data corruption
#
# Enterprise Skills You'll Learn:
# - Backup automation
# - vzdump backup tool
# - Backup scheduling
# - Disaster recovery planning
#
# When You Actually Need This in Production:
# - Regular backup scheduling
# - Compliance requirements
# - Disaster recovery preparation
# - Multi-VM/CT environments
#
# Simpler Alternative for Daily Services:
# - Manual backup via GUI for critical VMs only
# - Weekly backup schedule
#
# This is for learning. Production homelabs should prioritize simplicity.
# Use these techniques to build skills, not because you need them for daily services.
# Complexity = More failure points. Keep your production services simple.

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
