#!/usr/bin/env bash
#
# WHAT: Find IP address of a VM or container by name or ID
# LEARNING: Network troubleshooting, VM identification, IP management
# WHEN YOU NEED: Quick IP lookup for SSH/access
# SIMPLER: Check Proxmox GUI or use 'qm set <vmid> --ipconfig0'
# PITFALLS: IP may not be assigned if using DHCP, VM may be offline
#
# Enterprise Skills You'll Learn:
# - Network troubleshooting
# - IP address management
# - Remote access
#
# When You Actually Need This in Production:
# - Quick troubleshooting
# - Documentation
# - Access management
#
# Simpler Alternative for Daily Services:
# - Use Proxmox web UI for IP info
# - Check DHCP server lease table
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
Usage: $(basename "$0") <vmid_or_name>

Find IP address of a VM or container.

Arguments:
  vmid_or_name    VM/CT ID (numeric) or name

Options:
  -a              Show all VMs and their IPs
  -s              Try to get IP from inside VM (requires SSH)
  -h              Show this help

Examples:
  $(basename "$0") 100
  $(basename "$0") webserver
  $(basename "$0") -a                    # Show all VMs with IPs
  $(basename "$0") -s webserver         # Try SSH to get IP
EOF
}

# Parse arguments
SHOW_ALL=0
TRY_SSH=0

while getopts ":ash" opt; do
  case "$opt" in
    a) SHOW_ALL=1 ;;
    s) TRY_SSH=1 ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

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

# Check if target is VM or CT
is_vm() {
  qm config "$1" &>/dev/null
}

is_ct() {
  pct config "$1" &>/dev/null
}

# Find VM/CT by name
find_by_name() {
  local name="$1"
  local found=""
  
  # Search VMs
  if command -v qm &>/dev/null; then
    found=$(qm list 2>/dev/null | awk -v name="$name" 'NR>1 && tolower($2) ~ tolower(name) {print $1; exit}')
  fi
  
  # Search CTs if no VM found
  if [ -z "$found" ] && command -v pct &>/dev/null; then
    found=$(pct list 2>/dev/null | awk -v name="$name" 'NR>1 && tolower($2) ~ tolower(name) {print $1; exit}')
  fi
  
  echo "$found"
}

# Get IP from Proxmox config
get_ip_from_config() {
  local vmid="$1"
  local type="$2"
  
  if [ "$type" = "VM" ]; then
    qm config "$vmid" 2>/dev/null | grep "^ipconfig0" | grep -oE "ip=[^,]+" | cut -d= -f2
  else
    pct config "$vmid" 2>/dev/null | grep "^ipconfig0" | grep -oE "ip=[^,]+" | cut -d= -f2
  fi
}

# Try to get IP from inside VM via SSH
get_ip_from_ssh() {
  local vmid="$1"
  local type="$2"
  local ip=""
  
  # Get VM IP from config for SSH
  local vm_ip
  vm_ip=$(get_ip_from_config "$vmid" "$type")
  
  if [ -z "$vm_ip" ]; then
    echo ""
    return
  fi
  
  # Try common SSH users
  for user in root admin; do
    if command -v ssh &>/dev/null; then
      # Try to get IP from inside VM
      local result
      result=$(ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$user@$vm_ip" "hostname -I 2>/dev/null || ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1" 2>/dev/null | head -1)
      
      if [ -n "$result" ]; then
        echo "$result"
        return
      fi
    fi
  done
  
  echo ""
}

# Main execution
if [ "$SHOW_ALL" -eq 1 ]; then
  # Show all VMs with IPs
  echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_CYAN}║  ALL VMs AND CONTAINERS WITH IPs                          ║${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"
  echo ""
  
  printf "\n  %-6s  %-20s  %-15s  %-10s\n" "ID" "NAME" "IP ADDRESS" "TYPE"
  printf "  %-6s  %-20s  %-15s  %-10s\n" "----" "-----" "----------" "----"
  
  # VMs
  if command -v qm &>/dev/null; then
    mapfile -t vm_lines < <(qm list 2>/dev/null)
    
    for line in "${vm_lines[@]:1}"; do
      [ -z "$line" ] && continue
      
      local vmid name ip
      vmid=$(echo "$line" | awk '{print $1}')
      name=$(echo "$line" | awk '{print $2}')
      ip=$(get_ip_from_config "$vmid" "VM")
      
      # Truncate long names
      if [ ${#name} -gt 20 ]; then
        name="${name:0:17}..."
      fi
      
      if [ -n "$ip" ]; then
        printf "  %-6s  %-20s  %-15s  %-10s\n" "$vmid" "$name" "$ip" "VM"
      fi
    done
  fi
  
  # Containers
  if command -v pct &>/dev/null; then
    mapfile -t ct_lines < <(pct list 2>/dev/null)
    
    for line in "${ct_lines[@]:1}"; do
      [ -z "$line" ] && continue
      
      local ctid name ip
      ctid=$(echo "$line" | awk '{print $1}')
      name=$(echo "$line" | awk '{print $2}')
      ip=$(get_ip_from_config "$ctid" "CT")
      
      # Truncate long names
      if [ ${#name} -gt 20 ]; then
        name="${name:0:17}..."
      fi
      
      if [ -n "$ip" ]; then
        printf "  %-6s  %-20s  %-15s  %-10s\n" "$ctid" "$name" "$ip" "CT"
      fi
    done
  fi
  
  echo ""
  exit 0
fi

# Find specific VM/CT
if [ $# -lt 1 ]; then
  usage
  exit 1
fi

TARGET="$1"
VMID=""
TYPE=""

if is_vm "$TARGET"; then
  VMID="$TARGET"
  TYPE="VM"
elif is_ct "$TARGET"; then
  VMID="$TARGET"
  TYPE="CT"
else
  # Try to find by name
  FOUND=$(find_by_name "$TARGET")
  if [ -n "$FOUND" ]; then
    VMID="$FOUND"
    if is_vm "$FOUND"; then
      TYPE="VM"
    else
      TYPE="CT"
    fi
  fi
fi

if [ -z "$VMID" ]; then
  log_error "No VM or container found with ID or name: $TARGET"
  exit 1
fi

# Get name
if [ "$TYPE" = "VM" ]; then
  NAME=$(qm config "$VMID" 2>/dev/null | grep "^name:" | awk '{print $2}')
else
  NAME=$(pct config "$VMID" 2>/dev/null | grep "^hostname:" | awk '{print $2}')
fi

# Get status
if [ "$TYPE" = "VM" ]; then
  STATUS=$(qm status "$VMID" 2>/dev/null | awk '{print $2}')
else
  STATUS=$(pct status "$VMID" 2>/dev/null | awk '{print $2}')
fi

# Color code status
case "$STATUS" in
  "running"|"up")
    STATUS_COLOR="$COLOR_GREEN"
    ;;
  "stopped")
    STATUS_COLOR="$COLOR_YELLOW"
    ;;
  *)
    STATUS_COLOR="$COLOR_RED"
    ;;
esac

# Display info
echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}║  IP ADDRESS LOOKUP: $VMID${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"

section_header "TARGET INFORMATION"
kv "Type" "$TYPE"
kv "VMID/CTID" "$VMID"
kv "Name" "${NAME:-N/A}"
kv "Status" "${STATUS_COLOR}${STATUS}${COLOR_RESET}"

section_header "IP ADDRESS"

# Get IP from Proxmox config
IP=$(get_ip_from_config "$VMID" "$TYPE")

if [ -n "$IP" ]; then
  echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} IP Address: $IP"
  echo ""
  echo -e "  ${COLOR_DIM}This is the configured static IP from Proxmox${COLOR_RESET}"
  echo ""
  
  # If SSH option was requested, try to verify
  if [ "$TRY_SSH" -eq 1 ]; then
    echo -e "  ${COLOR_DIM}Attempting to verify IP via SSH...${COLOR_RESET}"
    echo ""
    
    SSH_IP=$(get_ip_from_ssh "$VMID" "$TYPE")
    
    if [ -n "$SSH_IP" ]; then
      echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} Verified IP (via SSH): $SSH_IP"
      echo ""
      
      if [ "$IP" != "$SSH_IP" ]; then
        echo -e "  ${COLOR_YELLOW}⚠ Warning: Configured IP ($IP) differs from actual IP ($SSH_IP)${COLOR_RESET}"
        echo -e "  ${COLOR_DIM}This may indicate DHCP assignment or network configuration issue${COLOR_RESET}"
      fi
    else
      echo -e "  ${COLOR_YELLOW}⚠ Could not verify IP via SSH${COLOR_RESET}"
      echo -e "  ${COLOR_DIM}Possible reasons:${COLOR_RESET}"
      echo -e "    - SSH not available on the VM"
      echo -e "    - SSH keys not configured"
      echo -e "    - VM is not running"
    fi
  fi
else
  echo -e "  ${COLOR_YELLOW}⚠ No static IP configured${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_DIM}Possible reasons:${COLOR_RESET}"
  echo -e "    - VM is using DHCP"
  echo -e "    - Network not yet configured"
  echo -e "    - VM is not running"
  echo ""
  echo -e "  ${COLOR_BOLD}Suggestions:${COLOR_RESET}"
  echo -e "    1. Check if VM is running: qm status $VMID"
  echo -e "    2. Check network config: qm config $VMID | grep net"
  echo -e "    3. Check DHCP server for assigned IP"
  echo -e "    4. Use Proxmox GUI to view VM network details"
  echo ""
fi

echo -e "${COLOR_DIM}Use 'scripts/vm/info.sh $VMID' for detailed VM information${COLOR_RESET}"
echo ""
