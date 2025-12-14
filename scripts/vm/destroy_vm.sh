#!/usr/bin/env bash
# Destroy one or more VMs by ID

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
Usage: $(basename "$0") -i "100,101" | -i "100 101" | -i 100
  -i <ids>   VMIDs to destroy (comma or space separated)
  -h         Help
EOF
}

ids_raw=""

while getopts ":i:h" opt; do
  case "$opt" in
    i) ids_raw="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[[ -n "$ids_raw" ]] || { log_error "VMID(s) required"; usage; exit 1; }

IFS=', ' read -r -a ids <<< "$ids_raw"

for id in "${ids[@]}"; do
  [[ "$id" =~ ^[0-9]+$ ]] || { log_error "Invalid VMID: $id"; exit 1; }
  if ! check_vm_exists "$id"; then
    log_warn "VMID $id does not exist; skipping"
    continue
  fi
  if qm status "$id" | grep -q running; then
    log_info "Stopping VM $id"
    qm stop "$id"
  fi
  log_info "Destroying VM $id"
  qm destroy "$id"
  log_info "Destroyed VM $id"
fi
