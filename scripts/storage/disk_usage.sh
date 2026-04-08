#!/usr/bin/env bash
#
# WHAT: Show disk usage by VM and container
# LEARNING: Storage management, capacity planning, disk types
# WHEN YOU NEED: Identify storage consumers, plan capacity
# SIMPLER: Use Proxmox GUI Storage tab
# PITFALLS: Disk usage may differ from actual VM usage
#
# Enterprise Skills You'll Learn:
# - Storage capacity planning
# - Resource allocation
# - Cost optimization
#
# When You Actually Need This in Production:
# - Capacity planning
# - Cost allocation
# - Storage migration planning
#
# Simpler Alternative for Daily Services:
# - Use Proxmox web UI for storage views
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

Show disk usage by VM and container.

Options:
  -s <storage>  Filter by storage name
  -h            Show this help

Examples:
  $(basename "$0")                    # Show all storage
  $(basename "$0") -s local-lvm       # Show specific storage
EOF
}

# Parse arguments
FILTER_STORAGE=""

while getopts ":s:h" opt; do
  case "$opt" in
    s) FILTER_STORAGE="$OPTARG" ;;
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

# Function to format bytes
format_size() {
  local bytes="$1"
  if [ "$bytes" -ge 1073741824 ]; then
    echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
  elif [ "$bytes" -ge 1048576 ]; then
    echo "$(echo "scale=2; $bytes / 1048576" | bc) MB"
  elif [ "$bytes" -ge 1024 ]; then
    echo "$(echo "scale=2; $bytes / 1024" | bc) KB"
  else
    echo "$bytes bytes"
  fi
}

# Function to get disk size from config
get_disk_size() {
  local vmid="$1"
  local disk_type="$2"
  
  local config
  config=$(qm config "$vmid" 2>/dev/null | grep "^${disk_type}:")
  
  if [ -n "$config" ]; then
    # Extract size from config like "virtio0: local-lvm:vm-100-disk-0,size=20G"
    echo "$config" | grep -oE "size=[0-9]+[KMGT]?" | head -1 | sed 's/size=//'
  fi
}

# Function to get actual disk usage from filesystem
get_actual_usage() {
  local vmid="$1"
  local disk_path="$2"
  
  if [ -d "$disk_path" ]; then
    du -sb "$disk_path" 2>/dev/null | cut -f1
  else
    echo "0"
  fi
}

# Get storage list
get_storages() {
  if [ -n "$FILTER_STORAGE" ]; then
    echo "$FILTER_STORAGE"
  else
    pvesm status 2>/dev/null | awk 'NR>1 {print $1}'
  fi
}

# Show VM disk usage
show_vm_usage() {
  section_header "VM DISK USAGE"
  
  if ! command -v qm &>/dev/null; then
    echo -e "  ${COLOR_YELLOW}qm command not found${COLOR_RESET}"
    return
  fi
  
  mapfile -t vm_lines < <(qm list 2>/dev/null)
  
  if [ ${#vm_lines[@]} -le 1 ]; then
    echo -e "  ${COLOR_DIM}No VMs found${COLOR_RESET}"
    return
  fi
  
  printf "\n  %-6s  %-20s  %-12s  %-10s  %-10s\n" "VMID" "NAME" "STORAGE" "SIZE" "USAGE"
  printf "  %-6s  %-20s  %-12s  %-10s  %-10s\n" "-----" "-----" "-----" "-----" "-----"
  
  local total_size=0
  local total_used=0
  
  for line in "${vm_lines[@]:1}"; do
    [ -z "$line" ] && continue
    
    local vmid name
    vmid=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{print $2}')
    
    # Truncate long names
    if [ ${#name} -gt 20 ]; then
      name="${name:0:17}..."
    fi
    
    # Get disk info
    local total_size_bytes=0
    local storage_list=""
    
    # Check all disk types
    for disk_type in virtio sata scsi ide; do
      local disk_config
      disk_config=$(qm config "$vmid" 2>/dev/null | grep "^${disk_type}:")
      
      if [ -n "$disk_config" ]; then
        # Extract storage and size
        local storage size
        storage=$(echo "$disk_config" | cut -d: -f2 | awk '{print $1}')
        size=$(echo "$disk_config" | grep -oE "size=[0-9]+[KMGT]?" | head -1 | sed 's/size=//')
        
        if [ -n "$storage" ]; then
          storage_list="${storage_list}${storage}, "
          
          # Convert size to bytes
          local size_num
          size_num=$(echo "$size" | sed 's/[^0-9]//g')
          local size_unit
          size_unit=$(echo "$size" | sed 's/[0-9]//g')
          
          case "$size_unit" in
            "K") total_size_bytes=$((total_size_bytes + size_num * 1024)) ;;
            "M") total_size_bytes=$((total_size_bytes + size_num * 1048576)) ;;
            "G") total_size_bytes=$((total_size_bytes + size_num * 1073741824)) ;;
            "T") total_size_bytes=$((total_size_bytes + size_num * 1099511627776)) ;;
            *) [ -n "$size_num" ] && total_size_bytes=$((total_size_bytes + size_num)) ;;
          esac
        fi
      fi
    done
    
    # Get actual disk usage
    local actual_usage=0
    local disk_path="/var/lib/vz/images/$vmid"
    if [ -d "$disk_path" ]; then
      actual_usage=$(du -sb "$disk_path" 2>/dev/null | cut -f1 || echo "0")
    fi
    
    # Filter by storage if specified
    if [ -n "$FILTER_STORAGE" ]; then
      if [[ ! " $storage_list " =~ " $FILTER_STORAGE " ]]; then
        continue
      fi
    fi
    
    local formatted_size formatted_usage
    formatted_size=$(format_size "$total_size_bytes")
    formatted_usage=$(format_size "$actual_usage")
    
    printf "  %-6s  %-20s  %-12s  %-10s  %-10s\n" "$vmid" "$name" "${storage_list%, }" "$formatted_size" "$formatted_usage"
    
    total_size=$((total_size + total_size_bytes))
    total_used=$((total_used + actual_usage))
  done
  
  echo ""
  echo -e "  ${COLOR_BOLD}Total:${COLOR_RESET} $(format_size "$total_size") allocated, $(format_size "$total_used") used"
  echo ""
}

# Show container disk usage
show_ct_usage() {
  section_header "CONTAINER DISK USAGE"
  
  if ! command -v pct &>/dev/null; then
    echo -e "  ${COLOR_YELLOW}pct command not found${COLOR_RESET}"
    return
  fi
  
  mapfile -t ct_lines < <(pct list 2>/dev/null)
  
  if [ ${#ct_lines[@]} -le 1 ]; then
    echo -e "  ${COLOR_DIM}No containers found${COLOR_RESET}"
    return
  fi
  
  printf "\n  %-6s  %-20s  %-12s  %-10s  %-10s\n" "CTID" "NAME" "STORAGE" "SIZE" "USAGE"
  printf "  %-6s  %-20s  %-12s  %-10s  %-10s\n" "-----" "-----" "-----" "-----" "-----"
  
  local total_size=0
  local total_used=0
  
  for line in "${ct_lines[@]:1}"; do
    [ -z "$line" ] && continue
    
    local ctid name
    ctid=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{print $2}')
    
    # Truncate long names
    if [ ${#name} -gt 20 ]; then
      name="${name:0:17}..."
    fi
    
    # Get rootfs info
    local rootfs
    rootfs=$(pct config "$ctid" 2>/dev/null | grep "^rootfs:" | head -1)
    
    if [ -n "$rootfs" ]; then
      local storage size
      storage=$(echo "$rootfs" | cut -d: -f2 | awk '{print $1}')
      size=$(echo "$rootfs" | grep -oE "size=[0-9]+[KMGT]?" | head -1 | sed 's/size=//')
      
      # Convert size to bytes
      local size_bytes=0
      if [ -n "$size" ]; then
        local size_num
        size_num=$(echo "$size" | sed 's/[^0-9]//g')
        local size_unit
        size_unit=$(echo "$size" | sed 's/[0-9]//g')
        
        case "$size_unit" in
          "K") size_bytes=$((size_num * 1024)) ;;
          "M") size_bytes=$((size_num * 1048576)) ;;
          "G") size_bytes=$((size_num * 1073741824)) ;;
          "T") size_bytes=$((size_num * 1099511627776)) ;;
          *) size_bytes=$size_num ;;
        esac
      fi
      
      # Get actual usage
      local actual_usage=0
      local ct_path="/var/lib/lxc/$ctid"
      if [ -d "$ct_path" ]; then
        actual_usage=$(du -sb "$ct_path" 2>/dev/null | cut -f1 || echo "0")
      fi
      
      # Filter by storage if specified
      if [ -n "$FILTER_STORAGE" ]; then
        if [[ ! " $storage " =~ " $FILTER_STORAGE " ]]; then
          continue
        fi
      fi
      
      local formatted_size formatted_usage
      formatted_size=$(format_size "$size_bytes")
      formatted_usage=$(format_size "$actual_usage")
      
      printf "  %-6s  %-20s  %-12s  %-10s  %-10s\n" "$ctid" "$name" "$storage" "$formatted_size" "$formatted_usage"
      
      total_size=$((total_size + size_bytes))
      total_used=$((total_used + actual_usage))
    fi
  done
  
  echo ""
  echo -e "  ${COLOR_BOLD}Total:${COLOR_RESET} $(format_size "$total_size") allocated, $(format_size "$total_used") used"
  echo ""
}

# Show storage summary
show_storage_summary() {
  section_header "STORAGE SUMMARY"
  
  if ! command -v pvesm &>/dev/null; then
    echo -e "  ${COLOR_YELLOW}pvesm command not found${COLOR_RESET}"
    return
  fi
  
  echo ""
  printf "  %-15s  %-15s  %-15s  %-15s  %-10s\n" "STORAGE" "TYPE" "TOTAL" "USED" "AVAIL"
  printf "  %-15s  %-15s  %-15s  %-15s  %-10s\n" "-------" "----" "-----" "----" "-----"
  
  pvesm status 2>/dev/null | while IFS= read -r line; do
    [ -z "$line" ] && continue
    
    local storage type total used avail
    storage=$(echo "$line" | awk '{print $1}')
    type=$(echo "$line" | awk '{print $2}')
    total=$(echo "$line" | awk '{print $3}')
    used=$(echo "$line" | awk '{print $4}')
    avail=$(echo "$line" | awk '{print $5}')
    
    # Filter by storage if specified
    if [ -n "$FILTER_STORAGE" ] && [ "$storage" != "$FILTER_STORAGE" ]; then
      continue
    fi
    
    printf "  %-15s  %-15s  %-15s  %-15s  %-10s\n" "$storage" "$type" "$total" "$used" "$avail"
  done
  
  echo ""
}

# Main execution
echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}║  DISK USAGE REPORT                                        ║${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"

if [ -n "$FILTER_STORAGE" ]; then
  echo -e "${COLOR_DIM}Filtering by storage: $FILTER_STORAGE${COLOR_RESET}"
fi

show_storage_summary
show_vm_usage
show_ct_usage

echo -e "${COLOR_DIM}Use 'qm config <vmid>' to see detailed disk configuration${COLOR_RESET}"
echo -e "${COLOR_DIM}Use 'pct config <ctid>' to see detailed container configuration${COLOR_RESET}"
echo ""
