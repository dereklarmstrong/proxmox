#!/usr/bin/env bash
# Set up a VLAN network configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") --vlan <id> --bridge <name> --parent <iface> [options]

Set up a VLAN network configuration on Proxmox.

Required:
  --vlan <id>        VLAN ID (1-4094)
  --bridge <name>    Bridge name (e.g. vmbr10)
  --parent <iface>   Parent physical interface (e.g. eth0)

Optional:
  --description <d>  Bridge description
  --dry-run          Show changes without applying
  -h, --help         Show this help

Examples:
  $(basename "$0") --vlan 100 --bridge vmbr100 --parent eth0 --description "VLAN 100 - Dev"
EOF
}

vlan=""
bridge=""
parent=""
description=""
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vlan)        vlan="$2"; shift 2 ;;
    --bridge)      bridge="$2"; shift 2 ;;
    --parent)      parent="$2"; shift 2 ;;
    --description) description="$2"; shift 2 ;;
    --dry-run)     dry_run=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             die "Unknown option: $1" ;;
  esac
done

# Validate required args
[[ -n "$vlan" ]] || die "--vlan is required"
[[ -n "$bridge" ]] || die "--bridge is required"
[[ -n "$parent" ]] || die "--parent is required"

# Validate VLAN ID
[[ "$vlan" =~ ^[0-9]+$ ]] || die "VLAN ID must be a positive integer"
[[ "$vlan" -ge 1 && "$vlan" -le 4094 ]] || die "VLAN ID must be between 1 and 4094"

# Validate bridge name format
[[ "$bridge" =~ ^[a-z][a-z0-9]*$ ]] || die "Bridge name must start with a letter"

# Validate parent interface
[[ "$parent" =~ ^[a-z0-9.]+$ ]] || die "Invalid parent interface name"

log_info "=== VLAN Network Setup ==="
log_info "VLAN:       $vlan"
log_info "Bridge:     $bridge"
log_info "Parent:     $parent"
[[ -n "$description" ]] && log_info "Description: $description"
echo ""

# Check parent interface exists
if ! ip link show "$parent" &>/dev/null; then
  die "Parent interface $parent not found"
fi

# Generate network config
network_config="/etc/network/interfaces.d/${bridge}.cfg"

config_line="auto ${bridge}.${vlan}
iface ${bridge}.${vlan} inet manual
    vlan-raw-device ${parent}
    vlan-id ${vlan}"

if [[ -n "$description" ]]; then
  config_line="${config_line}
    # ${description}"
fi

echo ""
log_info "=== Network Configuration ==="
echo "$config_line"
echo ""

if [[ $dry_run -eq 1 ]]; then
  log_info "Dry run mode - no changes applied"
  exit 0
fi

# Create config file
if [[ -f "$network_config" ]]; then
  log_warn "Config file exists: $network_config"
  confirm "Overwrite?"
fi

log_info "Writing config to $network_config"
echo "$config_line" > "$network_config"

# Apply network config
log_info "Applying network configuration..."
if command -v pvesh &>/dev/null; then
  pvesh set /nodes/$(hostname)/network 2>/dev/null || log_warn "Could not apply network config via pvesh"
fi

# Try to reload network
if command -v ifreload &>/dev/null; then
  ifreload -a 2>/dev/null || log_warn "Could not reload network interfaces"
fi

echo ""
log_info "=== VLAN Setup Complete ==="
log_info "Bridge: ${bridge}.${vlan}"
log_info "Config: $network_config"
echo ""
log_info "You may need to restart networking: systemctl restart networking"
