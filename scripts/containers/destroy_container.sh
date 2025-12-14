#!/usr/bin/env bash
# Destroy one or more LXC containers

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
Usage: $(basename "$0") -i "101,102" | -i 101
  -i <ids>   CTIDs to destroy (comma or space separated)
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

[[ -n "$ids_raw" ]] || { log_error "CTID(s) required"; usage; exit 1; }
IFS=', ' read -r -a ids <<< "$ids_raw"

for id in "${ids[@]}"; do
  [[ "$id" =~ ^[0-9]+$ ]] || { log_error "Invalid CTID: $id"; exit 1; }
  if ! check_ct_exists "$id"; then
    log_warn "CTID $id does not exist; skipping"
    continue
  fi
  if pct status "$id" | grep -q running; then
    log_info "Stopping CT $id"
    pct stop "$id"
  fi
  log_info "Destroying CT $id"
  pct destroy "$id"
  log_info "Destroyed CT $id"
fi
