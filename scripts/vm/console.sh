#!/usr/bin/env bash
#
# WHAT: Quick console access to VMs and containers
# LEARNING: SSH, console access, VM identification
# WHEN YOU NEED: Quick access to VM console
# SIMPLER: Use Proxmox web UI console
# PITFALLS: Requires SSH keys configured, VM must be running
#
# Enterprise Skills You'll Learn:
# - Remote access management
# - SSH key management
# - Console protocols
#
# When You Actually Need This in Production:
# - Quick troubleshooting
# - Emergency access
# - KVM-over-IP alternatives
#
# Simpler Alternative for Daily Services:
# - Use Proxmox web UI for console access
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

Quick console access to a VM or container.

Arguments:
  vmid_or_name    VM/CT ID (numeric) or name

Examples:
  $(basename "$0") 100
  $(basename "$0") webserver
  $(basename "$0") web  # Will match any VM/CT with 'web' in name

Options:
  -t              Use SPICE/TUI console instead of SSH
  -h              Show this help

Notes:
  - For VMs: Uses qm terminal (SPICE/TUI) if available
  - For containers: Uses pct terminal
  - Falls back to SSH if available
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

TARGET="$1"
USE_SPICE=0

while getopts ":th" opt; do
  case "$opt" in
    t) USE_SPICE=1 ;;
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

# Determine if target is VM or CT
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
    log_warn "VM/CT is stopped. Console access may not work."
    ;;
  *)
    STATUS_COLOR="$COLOR_RED"
    ;;
esac

# Get name
if [ "$TYPE" = "VM" ]; then
  NAME=$(qm config "$VMID" 2>/dev/null | grep "^name:" | awk '{print $2}')
else
  NAME=$(pct config "$VMID" 2>/dev/null | grep "^hostname:" | awk '{print $2}')
fi

# Display info
echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}║  CONSOLE ACCESS: $VMID${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"

section_header "TARGET INFORMATION"
kv "Type" "$TYPE"
kv "VMID/CTID" "$VMID"
kv "Name" "${NAME:-N/A}"
kv "Status" "${STATUS_COLOR}${STATUS}${COLOR_RESET}"

# Try console access methods
echo ""
section_header "CONSOLE ACCESS"

if [ "$USE_SPICE" -eq 1 ]; then
  # Try SPICE/TUI console
  if [ "$TYPE" = "VM" ]; then
    echo -e "  ${COLOR_DIM}Attempting SPICE console...${COLOR_RESET}"
    if command -v spicec &>/dev/null; then
      spicec -h $(hostname) -t "$VMID"
      exit 0
    elif command -v qm &>/dev/null; then
      echo -e "  ${COLOR_DIM}Using qm terminal...${COLOR_RESET}"
      qm terminal "$VMID"
      exit 0
    fi
  else
    echo -e "  ${COLOR_DIM}Using pct terminal...${COLOR_RESET}"
    pct terminal "$VMID"
    exit 0
  fi
fi

# Try qm terminal for VMs
if [ "$TYPE" = "VM" ] && command -v qm &>/dev/null; then
  echo -e "  ${COLOR_DIM}Attempting qm terminal...${COLOR_RESET}"
  if qm terminal "$VMID" 2>&1; then
    exit 0
  fi
fi

# Try pct terminal for containers
if [ "$TYPE" = "CT" ] && command -v pct &>/dev/null; then
  echo -e "  ${COLOR_DIM}Attempting pct terminal...${COLOR_RESET}"
  if pct terminal "$VMID" 2>&1; then
    exit 0
  fi
fi

# Fall back to SSH
echo -e "  ${COLOR_DIM}Attempting SSH connection...${COLOR_RESET}"
echo ""

# Get IP address
IP=""
if [ "$TYPE" = "VM" ]; then
  IP=$(qm config "$VMID" 2>/dev/null | grep "^ipconfig0" | grep -oE "ip=[^,]+" | cut -d= -f2 || echo "")
else
  IP=$(pct config "$VMID" 2>/dev/null | grep "^ipconfig0" | grep -oE "ip=[^,]+" | cut -d= -f2 || echo "")
fi

if [ -n "$IP" ]; then
  echo -e "  ${COLOR_CYAN}IP Address:${COLOR_RESET} $IP"
  echo ""
  echo -e "  ${COLOR_BOLD}SSH Command:${COLOR_RESET}"
  echo -e "    ssh root@$IP"
  echo ""
  echo -e "  ${COLOR_DIM}Attempting SSH connection...${COLOR_RESET}"
  
  # Try SSH
  if command -v ssh &>/dev/null; then
    # Try common SSH users
    for user in root admin; do
      if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$user@$IP" "exit" 2>/dev/null; then
        echo ""
        echo -e "  ${COLOR_GREEN}Connecting to $user@$IP...${COLOR_RESET}"
        ssh -o StrictHostKeyChecking=no "$user@$IP"
        exit 0
      fi
    done
  fi
fi

# If we get here, no console access worked
echo ""
echo -e "  ${COLOR_RED}Could not establish console connection${COLOR_RESET}"
echo ""
echo -e "  ${COLOR_DIM}Suggestions:${COLOR_RESET}"
echo -e "    1. Ensure VM/CT is running"
echo -e "    2. Check network configuration"
echo -e "    3. Verify SSH keys are configured"
echo -e "    4. Use Proxmox web UI for console access"
echo ""
