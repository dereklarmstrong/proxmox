#!/usr/bin/env bash
#
# WHAT: Find and remove unused storage resources (ISOs, old backups, disk images)
# LEARNING: File management, Proxmox storage types, disk cleanup
# WHEN YOU NEED: Free up storage space
# SIMPLER: Manual deletion via Proxmox GUI
# PITFALLS: Cannot undo deletions, may delete important files
#
# Enterprise Skills You'll Learn:
# - Storage management
# - Resource cleanup
# - Capacity planning
#
# When You Actually Need This in Production:
# - Regular storage maintenance
# - Cost optimization
# - Compliance with retention policies
#
# Simpler Alternative for Daily Services:
# - Use Proxmox GUI to delete unused ISOs
# - Manual cleanup of old backups
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

# Default values
ISO_STORAGE="${ISO_STORAGE:-local}"
BACKUP_STORAGE="${BACKUP_STORAGE:-local}"
DRY_RUN="${DRY_RUN:-0}"
INTERACTIVE="${INTERACTIVE:-1}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Find and remove unused storage resources.

Options:
  -i <storage>  ISO storage (default: $ISO_STORAGE)
  -b <storage>  Backup storage (default: $BACKUP_STORAGE)
  -n            Dry run (show what would be deleted)
  -y            Skip confirmation prompts
  -h            Show this help

Examples:
  $(basename "$0")                    # Interactive cleanup
  $(basename "$0") -n                 # Dry run
  $(basename "$0") -y -i local-zfs    # Non-interactive, specific storage
EOF
}

# Parse arguments
while getopts ":i:b:nhy" opt; do
  case "$opt" in
    i) ISO_STORAGE="$OPTARG" ;;
    b) BACKUP_STORAGE="$OPTARG" ;;
    n) DRY_RUN=1 ;;
    y) INTERACTIVE=0 ;;
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

# Function to display item
item() {
  printf "  %-60s %s\n" "$1" "$2"
}

# Function to get file size
get_size() {
  local file="$1"
  if [ -f "$file" ]; then
    du -h "$file" 2>/dev/null | cut -f1
  else
    echo "N/A"
  fi
}

# Function to get file age
get_age() {
  local file="$1"
  if [ -f "$file" ]; then
    local mtime
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
    local now
    now=$(date +%s)
    local age_days=$(( (now - mtime) / 86400 ))
    echo "${age_days} days"
  else
    echo "N/A"
  fi
}

# Check if running as root
if [ "${EUID:-$(id -u)}" -ne 0 ] && [ "$DRY_RUN" -eq 0 ]; then
  log_error "This script must be run as root for actual deletions"
  log_info "Use -n flag for dry run without root"
  exit 1
fi

echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}║  STORAGE CLEANUP UTILITY                                  ║${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"

if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "${COLOR_YELLOW}  DRY RUN MODE - No files will be deleted${COLOR_RESET}"
fi

# Find ISOs older than 90 days
section_header "ISO IMAGES (older than 90 days)"

ISO_DIR="/var/lib/vz/dump"
if [ -d "$ISO_DIR" ]; then
  OLD_ISOS=()
  TOTAL_SIZE=0
  
  while IFS= read -r -d '' iso; do
    size=$(get_size "$iso")
    age=$(get_age "$iso")
    item "$iso" "${size} (${age})"
    OLD_ISOS+=("$iso")
    TOTAL_SIZE=$((TOTAL_SIZE + $(du -b "$iso" 2>/dev/null | cut -f1)))
  done < <(find "$ISO_DIR" -maxdepth 1 -type f \( -name "*.iso" -o -name "*.img" -o -name "*.qcow2" \) -mtime +90 -print0 2>/dev/null)
  
  if [ ${#OLD_ISOS[@]} -eq 0 ]; then
    echo -e "  ${COLOR_GREEN}No old ISOs found${COLOR_RESET}"
  else
    echo ""
    echo -e "  ${COLOR_BOLD}Total size:${COLOR_RESET} $(numfmt --to=iec-i --suffix=B "$TOTAL_SIZE" 2>/dev/null || echo "$TOTAL_SIZE bytes")"
    
    if [ "$INTERACTIVE" -eq 1 ]; then
      read -r -p "Delete ${#OLD_ISOS[@]} old ISO(s)? [y/N] " answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo -e "  ${COLOR_DIM}Cancelled${COLOR_RESET}"
        exit 0
      fi
    fi
    
    for iso in "${OLD_ISOS[@]}"; do
      if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "  ${COLOR_DIM}[DRY-RUN] Would delete: $iso${COLOR_RESET}"
      else
        rm -f "$iso"
        echo -e "  ${COLOR_GREEN}Deleted: $iso${COLOR_RESET}"
      fi
    done
  fi
else
  echo -e "  ${COLOR_YELLOW}ISO directory not found: $ISO_DIR${COLOR_RESET}"
fi

# Find old backups (older than 30 days)
section_header "BACKUP FILES (older than 30 days)"

BACKUP_DIR="/var/lib/vz/dump"
if [ -d "$BACKUP_DIR" ]; then
  OLD_BACKUPS=()
  TOTAL_SIZE=0
  
  while IFS= read -r -d '' backup; do
    size=$(get_size "$backup")
    age=$(get_age "$backup")
    item "$backup" "${size} (${age})"
    OLD_BACKUPS+=("$backup")
    TOTAL_SIZE=$((TOTAL_SIZE + $(du -b "$backup" 2>/dev/null | cut -f1)))
  done < <(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "vzdump-*" \) -mtime +30 -print0 2>/dev/null)
  
  if [ ${#OLD_BACKUPS[@]} -eq 0 ]; then
    echo -e "  ${COLOR_GREEN}No old backups found${COLOR_RESET}"
  else
    echo ""
    echo -e "  ${COLOR_BOLD}Total size:${COLOR_RESET} $(numfmt --to=iec-i --suffix=B "$TOTAL_SIZE" 2>/dev/null || echo "$TOTAL_SIZE bytes")"
    
    if [ "$INTERACTIVE" -eq 1 ]; then
      read -r -p "Delete ${#OLD_BACKUPS[@]} old backup(s)? [y/N] " answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo -e "  ${COLOR_DIM}Cancelled${COLOR_RESET}"
        exit 0
      fi
    fi
    
    for backup in "${OLD_BACKUPS[@]}"; do
      if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "  ${COLOR_DIM}[DRY-RUN] Would delete: $backup${COLOR_RESET}"
      else
        rm -f "$backup"
        echo -e "  ${COLOR_GREEN}Deleted: $backup${COLOR_RESET}"
      fi
    done
  fi
else
  echo -e "  ${COLOR_YELLOW}Backup directory not found: $BACKUP_DIR${COLOR_RESET}"
fi

# Find orphaned disk images (VMs that no longer exist)
section_header "ORPHANED DISK IMAGES"

# Get list of existing VMs
EXISTING_VMS=()
if command -v qm &>/dev/null; then
  mapfile -t EXISTING_VMS < <(qm list 2>/dev/null | awk 'NR>1 {print $1}')
fi

# Check common disk locations
for disk_dir in "/var/lib/vz/images" "/mnt/local-lvm/images"; do
  if [ -d "$disk_dir" ]; then
    for vm_dir in "$disk_dir"/*; do
      [ -d "$vm_dir" ] || continue
      vmid=$(basename "$vm_dir")
      
      # Check if VM exists
      if [[ ! " ${EXISTING_VMS[*]} " =~ " ${vmid} " ]]; then
        size=$(du -sh "$vm_dir" 2>/dev/null | cut -f1)
        item "$vm_dir" "${size}"
        
        if [ "$INTERACTIVE" -eq 1 ]; then
          read -r -p "Delete orphaned disk for VM $vmid? [y/N] " answer
          if [[ "$answer" =~ ^[Yy]$ ]]; then
            if [ "$DRY_RUN" -eq 1 ]; then
              echo -e "  ${COLOR_DIM}[DRY-RUN] Would delete: $vm_dir${COLOR_RESET}"
            else
              rm -rf "$vm_dir"
              echo -e "  ${COLOR_GREEN}Deleted: $vm_dir${COLOR_RESET}"
            fi
          fi
        else
          if [ "$DRY_RUN" -eq 1 ]; then
            echo -e "  ${COLOR_DIM}[DRY-RUN] Would delete: $vm_dir${COLOR_RESET}"
          else
            rm -rf "$vm_dir"
            echo -e "  ${COLOR_GREEN}Deleted: $vm_dir${COLOR_RESET}"
          fi
        fi
      fi
    done
  fi
done

echo ""
echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}║  CLEANUP COMPLETE                                         ║${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"
echo ""
