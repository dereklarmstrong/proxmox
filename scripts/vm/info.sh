#!/usr/bin/env bash
#
# WHAT: Display detailed information about a specific VM or container
# LEARNING: Proxmox resource attributes, configuration options
# WHEN YOU NEED: Quick details about a VM/container
# SIMPLER: Use `qm config <vmid>` or `pct config <ctid>`
# PITFALLS: Requires root privileges, VM/CT must exist
#
# Enterprise Skills You'll Learn:
# - Resource inspection
# - Configuration analysis
# - Troubleshooting
#
# When You Actually Need This in Production:
# - Quick troubleshooting
# - Resource audits
# - Documentation
#
# Simpler Alternative for Daily Services:
# - Use Proxmox web UI for detailed views
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

Show detailed information about a VM or container.

Arguments:
  vmid_or_name    VM ID (numeric) or container ID

Examples:
  $(basename "$0") 100
  $(basename "$0") webserver
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

TARGET="$1"

# Function to display section header
section_header() {
  echo ""
  echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_CYAN}║ $1${COLOR_RESET}"
  echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"
}

# Function to display key-value pair
kv() {
  printf "  ${COLOR_DIM}%-20s${COLOR_RESET}: %s\n" "$1" "$2"
}

# Check if target is VM or CT
is_vm() {
  qm config "$1" &>/dev/null
}

is_ct() {
  pct config "$1" &>/dev/null
}

# Determine if target is VM or CT
if is_vm "$TARGET"; then
  VMID="$TARGET"
  TYPE="VM"
elif is_ct "$TARGET"; then
  VMID="$TARGET"
  TYPE="CT"
else
  # Try to find by name
  if command -v qm &>/dev/null; then
    FOUND=$(qm list 2>/dev/null | awk -v name="$TARGET" 'NR>1 && $2 ~ name {print $1; exit}')
    if [ -n "$FOUND" ]; then
      VMID="$FOUND"
      TYPE="VM"
    fi
  fi
  
  if [ "$TYPE" != "VM" ] && command -v pct &>/dev/null; then
    FOUND=$(pct list 2>/dev/null | awk -v name="$TARGET" 'NR>1 && $2 ~ name {print $1; exit}')
    if [ -n "$FOUND" ]; then
      VMID="$FOUND"
      TYPE="CT"
    fi
  fi
  
  if [ -z "$VMID" ]; then
    log_error "No VM or container found with ID or name: $TARGET"
    exit 1
  fi
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

# Display header
echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}║  $TYPE INFORMATION: $VMID${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"

# Basic Info
section_header "BASIC INFORMATION"
kv "VMID/CTID" "$VMID"
kv "Status" "${STATUS_COLOR}${STATUS}${COLOR_RESET}"

if [ "$TYPE" = "VM" ]; then
  NAME=$(qm config "$VMID" 2>/dev/null | grep "^name:" | awk '{print $2}')
else
  NAME=$(pct config "$VMID" 2>/dev/null | grep "^hostname:" | awk '{print $2}')
fi
kv "Name" "${NAME:-N/A}"

# Hardware Info
section_header "HARDWARE"

if [ "$TYPE" = "VM" ]; then
  # CPU
  CPU=$(qm config "$VMID" 2>/dev/null | grep "^cores:" | awk '{print $2}')
  SOCKET=$(qm config "$VMID" 2>/dev/null | grep "^sockets:" | awk '{print $2}')
  CPU_MODEL=$(qm config "$VMID" 2>/dev/null | grep "^cpu:" | awk '{print $2}')
  CPU_TYPE=$(qm config "$VMID" 2>/dev/null | grep "^cpulimit:" | awk '{print $2}')
  
  kv "Cores" "${CPU:-1}"
  kv "Sockets" "${SOCKET:-1}"
  kv "CPU Model" "${CPU_MODEL:-host}"
  kv "CPU Limit" "${CPU_TYPE:-unlimited}"
  
  # Memory
  MEM=$(qm config "$VMID" 2>/dev/null | grep "^memory:" | awk '{print $2}')
  KV=$(qm config "$VMID" 2>/dev/null | grep "^balloon:" | awk '{print $2}')
  kv "Memory" "${MEM:-512} MB"
  kv "Balloon" "${KV:-0} MB"
  
  # Disk
  echo ""
  echo -e "  ${COLOR_BOLD}Disks:${COLOR_RESET}"
  qm config "$VMID" 2>/dev/null | grep "^virtio\|^sata\|^scsi\|^ide" | while read -r line; do
    DISK_TYPE=$(echo "$line" | awk -F: '{print $1}')
    DISK_CONFIG=$(echo "$line" | cut -d: -f2-)
    echo -e "    ${COLOR_DIM}${DISK_TYPE}${COLOR_RESET}: ${DISK_CONFIG}"
  done
  
  # Network
  echo ""
  echo -e "  ${COLOR_BOLD}Network:${COLOR_RESET}"
  qm config "$VMID" 2>/dev/null | grep "^net" | while read -r line; do
    NET_TYPE=$(echo "$line" | awk -F: '{print $1}')
    NET_CONFIG=$(echo "$line" | cut -d: -f2-)
    echo -e "    ${COLOR_DIM}${NET_TYPE}${COLOR_RESET}: ${NET_CONFIG}"
  done
  
  # BIOS
  BIOS=$(qm config "$VMID" 2>/dev/null | grep "^bios:" | awk '{print $2}')
  kv "BIOS" "${BIOS:-seabios}"
  
  # Boot order
  BOOT=$(qm config "$VMID" 2>/dev/null | grep "^boot:" | awk '{print $2}')
  kv "Boot Order" "${BOOT:-cdn}"
  
else
  # Container Hardware
  CPU=$(pct config "$VMID" 2>/dev/null | grep "^cpuunits:" | awk '{print $2}')
  MEM=$(pct config "$VMID" 2>/dev/null | grep "^memory:" | awk '{print $2}')
  SWAP=$(pct config "$VMID" 2>/dev/null | grep "^swap:" | awk '{print $2}')
  ROOTFS=$(pct config "$VMID" 2>/dev/null | grep "^rootfs:" | awk '{print $2}')
  
  kv "CPU Units" "${CPU:-512}"
  kv "Memory" "${MEM:-512} MB"
  kv "Swap" "${SWAP:-512} MB"
  kv "RootFS" "${ROOTFS:-N/A}"
  
  # Network
  echo ""
  echo -e "  ${COLOR_BOLD}Network:${COLOR_RESET}"
  pct config "$VMID" 2>/dev/null | grep "^net" | while read -r line; do
    NET_TYPE=$(echo "$line" | awk -F: '{print $1}')
    NET_CONFIG=$(echo "$line" | cut -d: -f2-)
    echo -e "    ${COLOR_DIM}${NET_TYPE}${COLOR_RESET}: ${NET_CONFIG}"
  done
fi

# Additional Info
section_header "ADDITIONAL"

if [ "$TYPE" = "VM" ]; then
  # Template status
  TEMPLATE=$(qm config "$VMID" 2>/dev/null | grep "^template:" | awk '{print $2}')
  kv "Template" "${TEMPLATE:-0}"
  
  # QEMU agent
  QEMU_AGENT=$(qm config "$VMID" 2>/dev/null | grep "^agent:" | awk '{print $2}')
  kv "QEMU Agent" "${QEMU_AGENT:-0}"
  
  # Serial
  SERIAL=$(qm config "$VMID" 2>/dev/null | grep "^serial:" | awk '{print $2}')
  kv "Serial Port" "${SERIAL:-none}"
  
  # Cloud-init
  CI_CONFIG=$(qm config "$VMID" 2>/dev/null | grep "^ciuser:\|^cipassword:\|^cipassword:\|^ipconfig")
  if [ -n "$CI_CONFIG" ]; then
    echo ""
    echo -e "  ${COLOR_BOLD}Cloud-init:${COLOR_RESET}"
    qm config "$VMID" 2>/dev/null | grep "^ciuser:\|^cipassword:\|^ipconfig" | while read -r line; do
      CI_TYPE=$(echo "$line" | awk -F: '{print $1}')
      CI_VALUE=$(echo "$line" | cut -d: -f2-)
      echo -e "    ${COLOR_DIM}${CI_TYPE}${COLOR_RESET}: ${CI_VALUE}"
    done
  fi
else
  # Container type
  CT_TYPE=$(pct config "$VMID" 2>/dev/null | grep "^ostype:" | awk '{print $2}')
  kv "OS Type" "${CT_TYPE:-N/A}"
  
  # Unprivileged
  UNPRIV=$(pct config "$VMID" 2>/dev/null | grep "^unprivileged:" | awk '{print $2}')
  kv "Unprivileged" "${UNPRIV:-0}"
fi

echo ""
echo -e "${COLOR_DIM}Use 'qm console $VMID' or 'pct console $VMID' to access the console${COLOR_RESET}"
echo ""
