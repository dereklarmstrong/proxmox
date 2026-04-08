#!/usr/bin/env bash
#
# WHAT: Create, list, and delete VM snapshots
# LEARNING: Snapshot concepts, Proxmox snapshot commands, file management
# WHEN YOU NEED: Point-in-time VM recovery, testing before changes
# SIMPLER: Use Proxmox GUI for snapshot management
# PITFALLS: Snapshots consume disk space, too many snapshots can degrade performance
#
# Enterprise Skills You'll Learn:
# - Point-in-time recovery
# - Storage management
# - Change management
#
# When You Actually Need This in Production:
# - Before major updates
# - Before configuration changes
# - Disaster recovery testing
#
# Simpler Alternative for Daily Services:
# - Use Proxmox GUI for occasional snapshots
# - Rely on backups for long-term recovery
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
Usage: $(basename "$0") <command> [options]

Manage VM snapshots.

Commands:
  create <vmid> <name>    Create a snapshot
  list <vmid>             List snapshots for a VM
  delete <vmid> <name>    Delete a snapshot
  cleanup <vmid> <days>   Delete snapshots older than N days

Options:
  -h                      Show this help

Examples:
  $(basename "$0") create 100 before-update
  $(basename "$0") list 100
  $(basename "$0") delete 100 before-update
  $(basename "$0") cleanup 100 7
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

COMMAND="$1"
shift

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

# Check if VM exists
check_vm() {
  local vmid="$1"
  if qm config "$vmid" &>/dev/null; then
    return 0
  fi
  return 1
}

# Create snapshot
do_create() {
  if [ $# -lt 2 ]; then
    log_error "Usage: create <vmid> <name>"
    exit 1
  fi
  
  local vmid="$1"
  local name="$2"
  
  if ! check_vm "$vmid"; then
    log_error "VM $vmid does not exist"
    exit 1
  fi
  
  # Check if VM is running
  local status
  status=$(qm status "$vmid" 2>/dev/null | awk '{print $2}')
  
  if [ "$status" = "stopped" ]; then
    log_warn "VM is stopped. Creating snapshot may not capture current state."
    read -r -p "Continue anyway? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      echo -e "  ${COLOR_DIM}Cancelled${COLOR_RESET}"
      exit 0
    fi
  fi
  
  echo -e "  ${COLOR_BOLD}Creating snapshot '${name}' for VM $vmid...${COLOR_RESET}"
  
  if qm snapshot "$vmid" "$name" 2>&1; then
    echo -e "  ${COLOR_GREEN}Snapshot created successfully${COLOR_RESET}"
  else
    log_error "Failed to create snapshot"
    exit 1
  fi
}

# List snapshots
do_list() {
  if [ $# -lt 1 ]; then
    log_error "Usage: list <vmid>"
    exit 1
  fi
  
  local vmid="$1"
  
  if ! check_vm "$vmid"; then
    log_error "VM $vmid does not exist"
    exit 1
  fi
  
  section_header "SNAPSHOTS FOR VM $vmid"
  
  # Get snapshot list
  local snapshots
  snapshots=$(qm snapshot "$vmid" 2>/dev/null | tail -n +2)
  
  if [ -z "$snapshots" ]; then
    echo -e "  ${COLOR_YELLOW}No snapshots found${COLOR_RESET}"
    return
  fi
  
  echo ""
  printf "  %-20s  %-20s  %-20s  %-15s\n" "NAME" "DESCRIPTION" "DATE" "VM STATE"
  printf "  %-20s  %-20s  %-20s  %-15s\n" "--------------------" "--------------------" "--------------------" "---------------"
  
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    name=$(echo "$line" | awk '{print $1}')
    desc=$(echo "$line" | awk '{print $2}')
    date=$(echo "$line" | awk '{print $3}')
    state=$(echo "$line" | awk '{print $4}')
    
    # Truncate long names
    if [ ${#name} -gt 20 ]; then
      name="${name:0:17}..."
    fi
    if [ ${#desc} -gt 20 ]; then
      desc="${desc:0:17}..."
    fi
    
    printf "  %-20s  %-20s  %-20s  %-15s\n" "$name" "$desc" "$date" "$state"
  done <<< "$snapshots"
  
  echo ""
  echo -e "  ${COLOR_DIM}Use '$(basename "$0") delete $vmid <name>' to remove a snapshot${COLOR_RESET}"
}

# Delete snapshot
do_delete() {
  if [ $# -lt 2 ]; then
    log_error "Usage: delete <vmid> <name>"
    exit 1
  fi
  
  local vmid="$1"
  local name="$2"
  
  if ! check_vm "$vmid"; then
    log_error "VM $vmid does not exist"
    exit 1
  fi
  
  # Check if snapshot exists
  local snapshots
  snapshots=$(qm snapshot "$vmid" 2>/dev/null | grep -E "^$name " || true)
  
  if [ -z "$snapshots" ]; then
    log_error "Snapshot '$name' not found for VM $vmid"
    exit 1
  fi
  
  echo -e "  ${COLOR_YELLOW}Deleting snapshot '$name' from VM $vmid...${COLOR_RESET}"
  read -r -p "Are you sure? [y/N] " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo -e "  ${COLOR_DIM}Cancelled${COLOR_RESET}"
    exit 0
  fi
  
  if qm snapshot "$vmid" - "$name" 2>&1; then
    echo -e "  ${COLOR_GREEN}Snapshot deleted successfully${COLOR_RESET}"
  else
    log_error "Failed to delete snapshot"
    exit 1
  fi
}

# Cleanup old snapshots
do_cleanup() {
  if [ $# -lt 2 ]; then
    log_error "Usage: cleanup <vmid> <days>"
    exit 1
  fi
  
  local vmid="$1"
  local days="$2"
  
  if ! check_vm "$vmid"; then
    log_error "VM $vmid does not exist"
    exit 1
  fi
  
  if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    log_error "Days must be a number"
    exit 1
  fi
  
  section_header "CLEANING UP SNAPSHOTS OLDER THAN $days DAYS FOR VM $vmid"
  
  # Get current time
  local now
  now=$(date +%s)
  
  # Get snapshot list with dates
  local snapshots
  snapshots=$(qm snapshot "$vmid" 2>/dev/null | tail -n +2)
  
  if [ -z "$snapshots" ]; then
    echo -e "  ${COLOR_GREEN}No snapshots found${COLOR_RESET}"
    return
  fi
  
  local deleted=0
  local kept=0
  
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    local name date_str
    name=$(echo "$line" | awk '{print $1}')
    date_str=$(echo "$line" | awk '{print $3}')
    
    # Convert date to timestamp
    local snap_time
    snap_time=$(date -d "$date_str" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$date_str" +%s 2>/dev/null || echo "0")
    
    if [ "$snap_time" -gt 0 ]; then
      local age_days=$(( (now - snap_time) / 86400 ))
      
      if [ "$age_days" -gt "$days" ]; then
        echo -e "  ${COLOR_YELLOW}Deleting '$name' (${age_days} days old)${COLOR_RESET}"
        if qm snapshot "$vmid" - "$name" 2>&1; then
          ((deleted++))
        fi
      else
        echo -e "  ${COLOR_DIM}Keeping '$name' (${age_days} days old)${COLOR_RESET}"
        ((kept++))
      fi
    fi
  done <<< "$snapshots"
  
  echo ""
  echo -e "  ${COLOR_GREEN}Deleted: $deleted${COLOR_RESET}"
  echo -e "  ${COLOR_DIM}Kept: $kept${COLOR_RESET}"
}

# Main command dispatcher
case "$COMMAND" in
  create)
    do_create "$@"
    ;;
  list)
    do_list "$@"
    ;;
  delete)
    do_delete "$@"
    ;;
  cleanup)
    do_cleanup "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    log_error "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
