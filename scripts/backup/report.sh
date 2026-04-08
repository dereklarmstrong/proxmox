#!/usr/bin/env bash
#
# WHAT: Generate backup status report for all VMs and containers
# LEARNING: Backup systems, vzdump, disaster recovery
# WHEN YOU NEED: Verify recent backups, identify backup gaps
# SIMPLER: Use Proxmox GUI Backup tab
# PITFALLS: Backup status may not reflect actual data integrity
#
# Enterprise Skills You'll Learn:
# - Backup verification
# - Disaster recovery planning
# - Compliance reporting
#
# When You Actually Need This in Production:
# - Regular backup audits
# - Compliance requirements
# - DR testing
#
# Simpler Alternative for Daily Services:
# - Use Proxmox web UI for backup status
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

# Default retention in days
RETENTION_DAYS=${RETENTION_DAYS:-7}

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Generate backup status report for all VMs and containers.

Options:
  -d <days>     Days to check for recent backups (default: $RETENTION_DAYS)
  -s <storage>  Filter by storage name
  -h            Show this help

Examples:
  $(basename "$0")                    # Full report
  $(basename "$0") -d 3               # Check last 3 days
  $(basename "$0") -s local-backup    # Specific storage
EOF
}

# Parse arguments
while getopts ":d:s:h" opt; do
  case "$opt" in
    d) RETENTION_DAYS="$OPTARG" ;;
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

# Function to get file age in days
get_file_age_days() {
  local file="$1"
  if [ -f "$file" ]; then
    local mtime now age
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
    now=$(date +%s)
    age=$(( (now - mtime) / 86400 ))
    echo "$age"
  else
    echo "999"
  fi
}

# Get backup directory
get_backup_dir() {
  if [ -n "$FILTER_STORAGE" ]; then
    # Try to find backup directory for specific storage
    local backup_dir="/var/lib/vz/dump"
    if [ -d "$backup_dir" ]; then
      echo "$backup_dir"
    else
      echo ""
    fi
  else
    echo "/var/lib/vz/dump"
  fi
}

# Get most recent backup for a VM
get_latest_backup() {
  local vmid="$1"
  local backup_dir="$2"
  local pattern="vzdump-${vmid}-*"
  
  local latest=""
  local latest_time=0
  
  if [ -d "$backup_dir" ]; then
    for file in "$backup_dir"/$pattern; do
      [ -f "$file" ] || continue
      
      local mtime
      mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
      
      if [ "$mtime" -gt "$latest_time" ]; then
        latest_time="$mtime"
        latest="$file"
      fi
    done
  fi
  
  echo "$latest"
}

# Get backup info from filename
get_backup_info() {
  local file="$1"
  
  # Extract info from filename: vzdump-<vmid>-<date>-<time>.<type>
  local basename
  basename=$(basename "$file")
  
  # Parse date from filename
  local date_part
  date_part=$(echo "$basename" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}" | head -1)
  
  # Parse time from filename
  local time_part
  time_part=$(echo "$basename" | grep -oE "[0-9]{2}-[0-9]{2}-[0-9]{2}" | head -1)
  
  # Get file size
  local size
  size=$(du -h "$file" 2>/dev/null | cut -f1)
  
  # Get file age
  local age
  age=$(get_file_age_days "$file")
  
  echo "$date_part|$time_part|$size|$age"
}

# Check VM backup status
check_vm_backup() {
  local vmid="$1"
  local backup_dir="$2"
  
  local latest
  latest=$(get_latest_backup "$vmid" "$backup_dir")
  
  if [ -n "$latest" ] && [ -f "$latest" ]; then
    local info age
    info=$(get_backup_info "$latest")
    age=$(echo "$info" | cut -d'|' -f4)
    
    if [ "$age" -le "$RETENTION_DAYS" ]; then
      echo "OK|$latest|$age"
    else
      echo "OLD|$latest|$age"
    fi
  else
    echo "MISSING||"
  fi
}

# Check container backup status
check_ct_backup() {
  local ctid="$1"
  local backup_dir="$2"
  
  local latest
  latest=$(get_latest_backup "$ctid" "$backup_dir")
  
  if [ -n "$latest" ] && [ -f "$latest" ]; then
    local info age
    info=$(get_backup_info "$latest")
    age=$(echo "$info" | cut -d'|' -f4)
    
    if [ "$age" -le "$RETENTION_DAYS" ]; then
      echo "OK|$latest|$age"
    else
      echo "OLD|$latest|$age"
    fi
  else
    echo "MISSING||"
  fi
}

# Main execution
echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}║  BACKUP STATUS REPORT                                     ║${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"

echo -e "${COLOR_DIM}Checking backups from last $RETENTION_DAYS days${COLOR_RESET}"

if [ -n "$FILTER_STORAGE" ]; then
  echo -e "${COLOR_DIM}Filtering by storage: $FILTER_STORAGE${COLOR_RESET}"
fi

echo ""

# Get backup directory
BACKUP_DIR=$(get_backup_dir)

if [ ! -d "$BACKUP_DIR" ]; then
  echo -e "  ${COLOR_RED}Backup directory not found: $BACKUP_DIR${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_DIM}Ensure vzdump is configured and backups are being created${COLOR_RESET}"
  exit 1
fi

# Counters
total_vms=0
total_cts=0
ok_vms=0
old_vms=0
missing_vms=0
ok_cts=0
old_cts=0
missing_cts=0

# Check VM backups
section_header "VM BACKUPS"

if command -v qm &>/dev/null; then
  mapfile -t vm_lines < <(qm list 2>/dev/null)
  
  if [ ${#vm_lines[@]} -gt 1 ]; then
    printf "\n  %-6s  %-20s  %-10s  %-15s  %-10s\n" "VMID" "NAME" "STATUS" "LAST BACKUP" "AGE"
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
      
      ((total_vms++))
      
      local result
      result=$(check_vm_backup "$vmid" "$BACKUP_DIR")
      local status file age
      status=$(echo "$result" | cut -d'|' -f1)
      file=$(echo "$result" | cut -d'|' -f2)
      age=$(echo "$result" | cut -d'|' -f3)
      
      case "$status" in
        "OK")
          echo -e "  ${COLOR_GREEN}✓${COLOR_RESET}  %-6s  %-20s  %-10s  %-15s  %-10s\n" "$vmid" "$name" "OK" "$(basename "$file")" "${age}d"
          ((ok_vms++))
          ;;
        "OLD")
          echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET}  %-6s  %-20s  %-10s  %-15s  %-10s\n" "$vmid" "$name" "OLD" "$(basename "$file")" "${age}d"
          ((old_vms++))
          ;;
        "MISSING")
          echo -e "  ${COLOR_RED}✗${COLOR_RESET}  %-6s  %-20s  %-10s  %-15s  %-10s\n" "$vmid" "$name" "MISSING" "N/A" "N/A"
          ((missing_vms++))
          ;;
      esac
    done
  else
    echo -e "  ${COLOR_DIM}No VMs found${COLOR_RESET}"
  fi
else
  echo -e "  ${COLOR_YELLOW}qm command not found${COLOR_RESET}"
fi

# Check container backups
section_header "CONTAINER BACKUPS"

if command -v pct &>/dev/null; then
  mapfile -t ct_lines < <(pct list 2>/dev/null)
  
  if [ ${#ct_lines[@]} -gt 1 ]; then
    printf "\n  %-6s  %-20s  %-10s  %-15s  %-10s\n" "CTID" "NAME" "STATUS" "LAST BACKUP" "AGE"
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
      
      ((total_cts++))
      
      local result
      result=$(check_ct_backup "$ctid" "$BACKUP_DIR")
      local status file age
      status=$(echo "$result" | cut -d'|' -f1)
      file=$(echo "$result" | cut -d'|' -f2)
      age=$(echo "$result" | cut -d'|' -f3)
      
      case "$status" in
        "OK")
          echo -e "  ${COLOR_GREEN}✓${COLOR_RESET}  %-6s  %-20s  %-10s  %-15s  %-10s\n" "$ctid" "$name" "OK" "$(basename "$file")" "${age}d"
          ((ok_cts++))
          ;;
        "OLD")
          echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET}  %-6s  %-20s  %-10s  %-15s  %-10s\n" "$ctid" "$name" "OLD" "$(basename "$file")" "${age}d"
          ((old_cts++))
          ;;
        "MISSING")
          echo -e "  ${COLOR_RED}✗${COLOR_RESET}  %-6s  %-20s  %-10s  %-15s  %-10s\n" "$ctid" "$name" "MISSING" "N/A" "N/A"
          ((missing_cts++))
          ;;
      esac
    done
  else
    echo -e "  ${COLOR_DIM}No containers found${COLOR_RESET}"
  fi
else
  echo -e "  ${COLOR_YELLOW}pct command not found${COLOR_RESET}"
fi

# Summary
section_header "BACKUP SUMMARY"

echo ""
echo -e "  ${COLOR_BOLD}Virtual Machines:${COLOR_RESET}"
printf "    ${COLOR_GREEN}  OK:${COLOR_RESET}     $ok_vms\n"
printf "    ${COLOR_YELLOW}  OLD:${COLOR_RESET}    $old_vms\n"
printf "    ${COLOR_RED}  MISSING:${COLOR_RESET} $missing_vms\n"
echo ""
echo -e "  ${COLOR_BOLD}Containers:${COLOR_RESET}"
printf "    ${COLOR_GREEN}  OK:${COLOR_RESET}     $ok_cts\n"
printf "    ${COLOR_YELLOW}  OLD:${COLOR_RESET}    $old_cts\n"
printf "    ${COLOR_RED}  MISSING:${COLOR_RESET} $missing_cts\n"
echo ""

# Issues found
local total_issues=$((old_vms + missing_vms + old_cts + missing_cts))
if [ "$total_issues" -gt 0 ]; then
  echo -e "  ${COLOR_YELLOW}⚠ Issues found: $total_issues VMs/CTs need attention${COLOR_RESET}"
  echo ""
  echo -e "  ${COLOR_DIM}Suggestions:${COLOR_RESET}"
  if [ "$missing_vms" -gt 0 ] || [ "$missing_cts" -gt 0 ]; then
    echo -e "    - Configure backup jobs for missing VMs/CTs"
  fi
  if [ "$old_vms" -gt 0 ] || [ "$old_cts" -gt 0 ]; then
    echo -e "    - Review backup retention policy"
    echo -e "    - Run backup manually: backup_vm.sh -i <vmid>"
  fi
fi

echo ""
echo -e "${COLOR_DIM}Use 'backup_all.sh' to backup all VMs and containers${COLOR_RESET}"
echo -e "${COLOR_DIM}Use 'prune_backups.sh' to clean up old backups${COLOR_RESET}"
echo ""
