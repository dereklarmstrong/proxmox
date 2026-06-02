#!/usr/bin/env bash
# Destroy an LXC container

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") --ctid <id> [options]

Destroy an LXC container.

Required:
  --ctid <id>    Container ID to destroy

Optional:
  --force        Skip confirmation prompt
  -h, --help     Show this help

Examples:
  $(basename "$0") --ctid 200
  $(basename "$0") --ctid 200 --force
EOF
}

ctid=""
force=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ctid)  ctid="$2"; shift 2 ;;
    --force) force=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)       die "Unknown option: $1" ;;
  esac
done

[[ -n "$ctid" ]] || die "--ctid is required"
validate_vmid "$ctid"

check_ct_exists "$ctid" || die "CTID $ctid does not exist"

# Get container details
hostname=$(pct config "$ctid" 2>/dev/null | grep "^hostname:" | head -1 | sed 's/^hostname://')
hostname="${hostname:-unknown}"

status=$(pct status "$ctid" 2>/dev/null | awk '/^status:/ {print $2}')
status="${status:-unknown}"

echo ""
log_warn "=== Destroy Container ==="
log_info "Hostname: $hostname"
log_info "CTID:     $ctid"
log_info "Status:   $status"
echo ""

if [[ $force -eq 0 ]]; then
  confirm "Destroy container $ctid ($hostname)?"
fi

# Stop if running
if [[ "$status" == "running" ]]; then
  log_info "Stopping container $ctid"
  pct stop "$ctid"
fi

# Remove snapshots
snapshots=$(pct listsnapshots "$ctid" 2>/dev/null | tail -n +2 || true)
if [[ -n "$snapshots" ]]; then
  log_info "Removing snapshots..."
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    snap_name=$(echo "$line" | awk '{print $1}')
    pct delsnapshot "$ctid" "$snap_name" 2>/dev/null || true
  done <<< "$snapshots"
fi

# Destroy
log_info "Destroying container $ctid"
pct destroy "$ctid" 2>/dev/null || true

echo ""
log_info "Container $ctid ($hostname) destroyed"
