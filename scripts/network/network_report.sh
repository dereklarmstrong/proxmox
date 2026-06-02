#!/usr/bin/env bash
# Generate a network report for the Proxmox host

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Generate a network configuration report.

Options:
  --json             Output in JSON format
  -h, --help         Show this help

Examples:
  $(basename "$0")
  $(basename "$0") --json
EOF
}

output_json=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) output_json=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)      die "Unknown option: $1" ;;
  esac
done

log_info "=== Network Report ==="
echo ""

# Physical interfaces
log_info "--- Physical Interfaces ---"
if command -v ip &>/dev/null; then
  ip -br addr show 2>/dev/null || log_warn "Could not retrieve interface info"
elif command -v ifconfig &>/dev/null; then
  ifconfig -a 2>/dev/null || log_warn "Could not retrieve interface info"
fi
echo ""

# Proxmox network configuration
log_info "--- Proxmox Network Configuration ---"
if [[ -f /etc/network/interfaces ]]; then
  cat /etc/network/interfaces 2>/dev/null || log_warn "Could not read /etc/network/interfaces"
elif command -v pvesh &>/dev/null; then
  pvesh get /nodes/$(hostname)/network 2>/dev/null || log_warn "Could not retrieve network config"
fi
echo ""

# Bridge information
log_info "--- Bridges ---"
if command -v brctl &>/dev/null; then
  brctl show 2>/dev/null || log_warn "Could not retrieve bridge info"
elif command -v ip &>/dev/null; then
  ip link show type bridge 2>/dev/null || log_warn "Could not retrieve bridge info"
fi
echo ""

# DNS configuration
log_info "--- DNS Configuration ---"
if [[ -f /etc/resolv.conf ]]; then
  grep -v '^#' /etc/resolv.conf 2>/dev/null | grep -v '^$' || log_warn "No DNS config found"
fi
echo ""

# Routing table
log_info "--- Routing Table ---"
if command -v ip &>/dev/null; then
  ip route show 2>/dev/null || log_warn "Could not retrieve routing table"
fi
echo ""

# Connected VMs/containers
log_info "--- Network Usage ---"
log_info "Checking VMs..."
qm list 2>/dev/null | awk 'NR>1 {print "  VM " $1 ": " $2}' || true
echo ""
log_info "Checking Containers..."
pct list 2>/dev/null | awk 'NR>1 {print "  CT " $1 ": " $2}' || true
echo ""

log_info "=== End of Report ==="
