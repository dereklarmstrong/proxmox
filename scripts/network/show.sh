#!/usr/bin/env bash
#
# WHAT: Display all network configurations for VMs and containers
# LEARNING: Proxmox networking, bridges, VLANs, IP addressing
# WHEN YOU NEED: Network troubleshooting, IP planning
# SIMPLER: Use Proxmox GUI Network tab
# PITFALLS: Requires root privileges, network config changes can break connectivity
#
# Enterprise Skills You'll Learn:
# - Network topology understanding
# - IP address management
# - Troubleshooting connectivity
#
# When You Actually Need This in Production:
# - Network audits
# - IP conflict resolution
# - Documentation
#
# Simpler Alternative for Daily Services:
# - Use Proxmox web UI for network views
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

# Colors
if [ -t 1 ]; then
  COLOR_RESET="\033[0m"
  COLOR_GREEN="\033[32m"
  COLOR_YELLOW="\033[33m"
  COLOR_RED="\033[31m"
  COLOR_CYAN="\033[36m"
  COLOR_BOLD="\033[1m"
  COLOR_DIM="\033[2m"
else
  COLOR_RESET=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_RED=""
  COLOR_CYAN=""
  COLOR_BOLD=""
  COLOR_DIM=""
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Display network configurations for all VMs and containers.

Options:
  -v              Show VLAN information
  -i              Show IP address assignments
  -b              Show bridge status
  -h              Show this help

Examples:
  $(basename "$0")                    # Full network overview
  $(basename "$0") -v                 # Show VLAN info
  $(basename "$0") -i                 # Show IP assignments
EOF
}

# Parse arguments
SHOW_VLAN=0
SHOW_IP=0
SHOW_BRIDGE=0

while getopts ":vibh" opt; do
  case "$opt" in
    v) SHOW_VLAN=1 ;;
    i) SHOW_IP=1 ;;
    b) SHOW_BRIDGE=1 ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

# If no flags, show everything
if [ "$SHOW_VLAN" -eq 0 ] && [ "$SHOW_IP" -eq 0 ] && [ "$SHOW_BRIDGE" -eq 0 ]; then
  SHOW_VLAN=1
  SHOW_IP=1
  SHOW_BRIDGE=1
fi

# Function to display section
section_header() {
  echo ""
  echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_CYAN}║ $1${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"
}

# Function to display key-value pair
kv() {
  printf "  %-20s: %s\n" "$1" "$2"
}

# Get bridge information
show_bridges() {
  section_header "BRIDGE CONFIGURATION"
  
  # Read /etc/network/interfaces or use ip command
  if [ -f /etc/network/interfaces ]; then
    echo ""
    echo -e "  ${COLOR_BOLD}From /etc/network/interfaces:${COLOR_RESET}"
    echo ""
    
    local in_bridge=0
    local bridge_name=""
    local bridge_ports=""
    
    while IFS= read -r line; do
      # Skip comments and empty lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "${line// }" ]] && continue
      
      # Check for bridge interface
      if [[ "$line" =~ ^auto[[:space:]]+(brv?[0-9]+) ]]; then
        bridge_name="${BASH_REMATCH[1]}"
        bridge_ports=""
        in_bridge=1
        echo -e "  ${COLOR_CYAN}Bridge: ${bridge_name}${COLOR_RESET}"
      elif [[ "$line" =~ ^iface[[:space:]]+(brv?[0-9]+) ]]; then
        bridge_name="${BASH_REMATCH[1]}"
        echo -e "  ${COLOR_CYAN}Bridge: ${bridge_name}${COLOR_RESET}"
      elif [[ "$line" =~ ^bridge-ports[[:space:]]+(.*) ]]; then
        bridge_ports="${BASH_REMATCH[1]}"
        echo -e "    ${COLOR_DIM}Ports:${COLOR_RESET} $bridge_ports"
      elif [[ "$line" =~ ^bridge-stp[[:space:]]+(.*) ]]; then
        echo -e "    ${COLOR_DIM}STP:${COLOR_RESET} ${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^bridge-fd[[:space:]]+(.*) ]]; then
        echo -e "    ${COLOR_DIM}Forward Delay:${COLOR_RESET} ${BASH_REMATCH[1]}"
      fi
    done < /etc/network/interfaces
  else
    echo ""
    echo -e "  ${COLOR_DIM}Using 'ip link' command:${COLOR_RESET}"
    echo ""
    
    # Use ip command to show bridges
    ip link show type bridge 2>/dev/null | while read -r line; do
      if [[ "$line" =~ ^[0-9]+:[[:space:]]+(brv?[0-9]+) ]]; then
        bridge_name="${BASH_REMATCH[1]}"
        echo -e "  ${COLOR_CYAN}Bridge: ${bridge_name}${COLOR_RESET}"
      elif [[ "$line" =~ master[[:space:]]+(brv?[0-9]+) ]]; then
        echo -e "    ${COLOR_DIM}Master:${COLOR_RESET} ${BASH_REMATCH[1]}"
      fi
    done
  fi
  
  echo ""
}

# Show VLAN information
show_vlans() {
  section_header "VLAN CONFIGURATION"
  
  # Check for VLAN interfaces
  if [ -f /etc/network/interfaces ]; then
    local found_vlan=0
    
    while IFS= read -r line; do
      if [[ "$line" =~ vlan[[:space:]]+([0-9]+)[[:space:]]+(.*) ]]; then
        vlan_id="${BASH_REMATCH[1]}"
        iface="${BASH_REMATCH[2]}"
        echo -e "  ${COLOR_CYAN}VLAN ${vlan_id}:${COLOR_RESET} $iface"
        found_vlan=1
      fi
    done < /etc/network/interfaces
    
    if [ "$found_vlan" -eq 0 ]; then
      echo -e "  ${COLOR_DIM}No VLANs configured${COLOR_RESET}"
    fi
  else
    # Use ip command
    local found_vlan=0
    ip -o link show 2>/dev/null | grep -q vlan && found_vlan=1
    
    if [ "$found_vlan" -eq 1 ]; then
      ip -o link show 2>/dev/null | grep -E "vlan|@.*:" | while read -r line; do
        echo -e "  ${COLOR_CYAN}$line${COLOR_RESET}"
      done
    else
      echo -e "  ${COLOR_DIM}No VLANs configured${COLOR_RESET}"
    fi
  fi
  
  echo ""
}

# Show VM network configurations
show_vm_networks() {
  section_header "VM NETWORK CONFIGURATIONS"
  
  if ! command -v qm &>/dev/null; then
    echo -e "  ${COLOR_YELLOW}qm command not found${COLOR_RESET}"
    return
  fi
  
  mapfile -t vm_lines < <(qm list 2>/dev/null)
  
  if [ ${#vm_lines[@]} -le 1 ]; then
    echo -e "  ${COLOR_DIM}No VMs found${COLOR_RESET}"
    return
  fi
  
  printf "\n  %-6s  %-20s  %-10s  %-15s  %-10s\n" "VMID" "NAME" "BRIDGE" "VLAN" "MAC"
  printf "  %-6s  %-20s  %-10s  %-15s  %-10s\n" "-----" "-----" "-----" "-----" "-----"
  
  for line in "${vm_lines[@]:1}"; do
    [ -z "$line" ] && continue
    
    local vmid name
    vmid=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{print $2}')
    
    # Truncate long names
    if [ ${#name} -gt 20 ]; then
      name="${name:0:17}..."
    fi
    
    # Get network config
    local net_config
    net_config=$(qm config "$vmid" 2>/dev/null | grep "^net0" || echo "")
    
    if [ -n "$net_config" ]; then
      local bridge vlan mac
      bridge=$(echo "$net_config" | grep -oE "bridge=[^,]+" | cut -d= -f2 || echo "N/A")
      vlan=$(echo "$net_config" | grep -oE "tag=[0-9]+" | cut -d= -f2 || echo "N/A")
      mac=$(echo "$net_config" | grep -oE "macaddr=[^,]+" | cut -d= -f2 || echo "N/A")
      
      [ -z "$bridge" ] && bridge="N/A"
      [ -z "$vlan" ] && vlan="N/A"
      [ -z "$mac" ] && mac="N/A"
      
      printf "  %-6s  %-20s  %-10s  %-15s  %-10s\n" "$vmid" "$name" "$bridge" "$vlan" "$mac"
    fi
  done
  
  echo ""
}

# Show container network configurations
show_ct_networks() {
  section_header "CONTAINER NETWORK CONFIGURATIONS"
  
  if ! command -v pct &>/dev/null; then
    echo -e "  ${COLOR_YELLOW}pct command not found${COLOR_RESET}"
    return
  fi
  
  mapfile -t ct_lines < <(pct list 2>/dev/null)
  
  if [ ${#ct_lines[@]} -le 1 ]; then
    echo -e "  ${COLOR_DIM}No containers found${COLOR_RESET}"
    return
  fi
  
  printf "\n  %-6s  %-20s  %-10s  %-15s  %-10s\n" "CTID" "NAME" "BRIDGE" "VLAN" "MAC"
  printf "  %-6s  %-20s  %-10s  %-15s  %-10s\n" "-----" "-----" "-----" "-----" "-----"
  
  for line in "${ct_lines[@]:1}"; do
    [ -z "$line" ] && continue
    
    local ctid name
    ctid=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{print $2}')
    
    # Truncate long names
    if [ ${#name} -gt 20 ]; then
      name="${name:0:17}..."
    fi
    
    # Get network config
    local net_config
    net_config=$(pct config "$ctid" 2>/dev/null | grep "^net0" || echo "")
    
    if [ -n "$net_config" ]; then
      local bridge vlan mac
      bridge=$(echo "$net_config" | grep -oE "bridge=[^,]+" | cut -d= -f2 || echo "N/A")
      vlan=$(echo "$net_config" | grep -oE "tag=[0-9]+" | cut -d= -f2 || echo "N/A")
      mac=$(echo "$net_config" | grep -oE "macaddr=[^,]+" | cut -d= -f2 || echo "N/A")
      
      [ -z "$bridge" ] && bridge="N/A"
      [ -z "$vlan" ] && vlan="N/A"
      [ -z "$mac" ] && mac="N/A"
      
      printf "  %-6s  %-20s  %-10s  %-15s  %-10s\n" "$ctid" "$name" "$bridge" "$vlan" "$mac"
    fi
  done
  
  echo ""
}

# Show IP address assignments
show_ip_assignments() {
  section_header "IP ADDRESS ASSIGNMENTS"
  
  local found_any=0
  
  # Check VMs
  if command -v qm &>/dev/null; then
    mapfile -t vm_lines < <(qm list 2>/dev/null)
    
    for line in "${vm_lines[@]:1}"; do
      [ -z "$line" ] && continue
      
      local vmid name
      vmid=$(echo "$line" | awk '{print $1}')
      name=$(echo "$line" | awk '{print $2}')
      
      # Get IP config from VM
      local ip_config
      ip_config=$(qm config "$vmid" 2>/dev/null | grep "^ipconfig0" || echo "")
      
      if [ -n "$ip_config" ]; then
        local ip gw
        ip=$(echo "$ip_config" | grep -oE "ip=[^,]+" | cut -d= -f2 || echo "N/A")
        gw=$(echo "$ip_config" | grep -oE "gw=[^,]+" | cut -d= -f2 || echo "N/A")
        
        if [ -n "$ip" ] && [ "$ip" != "N/A" ]; then
          [ ${#name} -gt 20 ] && name="${name:0:17}..."
          printf "  %-6s  %-20s  IP: %-15s  GW: %s\n" "$vmid" "$name" "$ip" "$gw"
          found_any=1
        fi
      fi
    done
  fi
  
  # Check containers
  if command -v pct &>/dev/null; then
    mapfile -t ct_lines < <(pct list 2>/dev/null)
    
    for line in "${ct_lines[@]:1}"; do
      [ -z "$line" ] && continue
      
      local ctid name
      ctid=$(echo "$line" | awk '{print $1}')
      name=$(echo "$line" | awk '{print $2}')
      
      # Get IP config from CT
      local ip_config
      ip_config=$(pct config "$ctid" 2>/dev/null | grep "^ipconfig0" || echo "")
      
      if [ -n "$ip_config" ]; then
        local ip gw
        ip=$(echo "$ip_config" | grep -oE "ip=[^,]+" | cut -d= -f2 || echo "N/A")
        gw=$(echo "$ip_config" | grep -oE "gw=[^,]+" | cut -d= -f2 || echo "N/A")
        
        if [ -n "$ip" ] && [ "$ip" != "N/A" ]; then
          [ ${#name} -gt 20 ] && name="${name:0:17}..."
          printf "  %-6s  %-20s  IP: %-15s  GW: %s\n" "$ctid" "$name" "$ip" "$gw"
          found_any=1
        fi
      fi
    done
  fi
  
  if [ "$found_any" -eq 0 ]; then
    echo -e "  ${COLOR_DIM}No static IP addresses configured${COLOR_RESET}"
  fi
  
  echo ""
}

# Main execution
echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}║  NETWORK CONFIGURATION VIEWER                             ║${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"

if [ "$SHOW_BRIDGE" -eq 1 ]; then
  show_bridges
fi

if [ "$SHOW_VLAN" -eq 1 ]; then
  show_vlans
fi

show_vm_networks
show_ct_networks

if [ "$SHOW_IP" -eq 1 ]; then
  show_ip_assignments
fi

echo -e "${COLOR_DIM}Use 'qm set <vmid> --net0 ...' to modify VM network config${COLOR_RESET}"
echo -e "${COLOR_DIM}Use 'pct set <ctid> --net0 ...' to modify container network config${COLOR_RESET}"
echo ""
