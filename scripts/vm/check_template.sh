#!/usr/bin/env bash
#
# WHAT: Validate VM templates and check cloud-init configuration
# LEARNING: Template best practices, cloud-init, VM optimization
# WHEN YOU NEED: Verify templates before deployment
# SIMPLER: Manual inspection via Proxmox GUI
# PITFALLS: Template validation doesn't guarantee successful deployment
#
# Enterprise Skills You'll Learn:
# - Template management
# - Cloud-init configuration
# - VM optimization
#
# When You Actually Need This in Production:
# - Before deploying from templates
# - Template maintenance
# - Compliance checks
#
# Simpler Alternative for Daily Services:
# - Use Proxmox GUI to inspect templates
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

Validate VM templates and check cloud-init configuration.

Options:
  -v <vmid>     Check specific VM/template
  -a            Check all VMs (filter for templates)
  -c            Check cloud-init configuration only
  -h            Show this help

Examples:
  $(basename "$0") -v 9999              # Check specific template
  $(basename "$0") -a                   # Check all templates
  $(basename "$0") -c -v 9999           # Check cloud-init only
EOF
}

# Parse arguments
CHECK_ALL=0
CHECK_CLOUD_INIT=0
TARGET_VMID=""

while getopts ":v:ach" opt; do
  case "$opt" in
    v) TARGET_VMID="$OPTARG" ;;
    a) CHECK_ALL=1 ;;
    c) CHECK_CLOUD_INIT=1 ;;
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

# Function to display check result
check_result() {
  local status="$1"
  local message="$2"
  
  case "$status" in
    "ok")
      echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $message"
      ;;
    "warn")
      echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} $message"
      ;;
    "error")
      echo -e "  ${COLOR_RED}✗${COLOR_RESET} $message"
      ;;
  esac
}

# Check if VM exists
check_vm() {
  local vmid="$1"
  qm config "$vmid" &>/dev/null
}

# Get VM config value
get_config() {
  local vmid="$1"
  local key="$2"
  qm config "$vmid" 2>/dev/null | grep "^${key}:" | awk '{print $2}'
}

# Check template validity
check_template() {
  local vmid="$1"
  local name
  name=$(get_config "$vmid" "name" || pct config "$vmid" 2>/dev/null | grep "^hostname:" | awk '{print $2}')
  
  echo -e "${COLOR_BOLD}Checking template: $vmid${COLOR_RESET} (${name:-N/A})"
  echo ""
  
  local issues=0
  local warnings=0
  
  # Check if template flag is set
  local template
  template=$(get_config "$vmid" "template")
  if [ "$template" = "1" ]; then
    check_result "ok" "Template flag is set"
  else
    check_result "warn" "Template flag is not set (template=0)"
    ((warnings++))
  fi
  
  # Check for QEMU agent
  local agent
  agent=$(get_config "$vmid" "agent")
  if [ -n "$agent" ] && [ "$agent" != "0" ]; then
    check_result "ok" "QEMU agent enabled"
  else
    check_result "warn" "QEMU agent not enabled"
    ((warnings++))
  fi
  
  # Check for cloud-init
  local ci_user
  ci_user=$(get_config "$vmid" "ciuser")
  local ci_config
  ci_config=$(qm config "$vmid" 2>/dev/null | grep "^cipassword:\|^ipconfig" || pct config "$vmid" 2>/dev/null | grep "^ipconfig" || true)
  
  if [ -n "$ci_user" ] || [ -n "$ci_config" ]; then
    check_result "ok" "Cloud-init configuration present"
    
    if [ -n "$ci_user" ]; then
      echo -e "    ${COLOR_DIM}CI User:${COLOR_RESET} $ci_user"
    fi
    
    if [ -n "$ci_config" ]; then
      echo -e "    ${COLOR_DIM}Cloud-init config:${COLOR_RESET}"
      echo "$ci_config" | while read -r line; do
        echo -e "      ${COLOR_DIM}$line${COLOR_RESET}"
      done
    fi
  else
    check_result "warn" "No cloud-init configuration found"
    ((warnings++))
  fi
  
  # Check disk configuration
  local disks
  disks=$(qm config "$vmid" 2>/dev/null | grep -E "^virtio\|^sata\|^scsi\|^ide" | wc -l)
  if [ "$disks" -gt 0 ]; then
    check_result "ok" "Disk configuration found ($disks disk(s))"
  else
    check_result "error" "No disk configuration found"
    ((issues++))
  fi
  
  # Check network configuration
  local networks
  networks=$(qm config "$vmid" 2>/dev/null | grep "^net" | wc -l)
  if [ "$networks" -gt 0 ]; then
    check_result "ok" "Network configuration found ($networks interface(s))"
  else
    check_result "warn" "No network configuration found"
    ((warnings++))
  fi
  
  # Check memory
  local memory
  memory=$(get_config "$vmid" "memory")
  if [ -n "$memory" ] && [ "$memory" -gt 0 ] 2>/dev/null; then
    check_result "ok" "Memory configured: ${memory} MB"
  else
    check_result "error" "No memory configured"
    ((issues++))
  fi
  
  # Check CPU
  local cores
  cores=$(get_config "$vmid" "cores")
  if [ -n "$cores" ] && [ "$cores" -gt 0 ] 2>/dev/null; then
    check_result "ok" "CPU cores configured: $cores"
  else
    check_result "warn" "No CPU cores configured (defaulting to 1)"
    ((warnings++))
  fi
  
  # Check for SSH key injection
  local sshkey
  sshkey=$(get_config "$vmid" "sshkey")
  if [ -n "$sshkey" ]; then
    check_result "ok" "SSH key injection configured"
  else
    check_result "warn" "No SSH key injection configured"
    ((warnings++))
  fi
  
  # Summary
  echo ""
  if [ "$issues" -eq 0 ] && [ "$warnings" -eq 0 ]; then
    echo -e "  ${COLOR_GREEN}✓ Template validation PASSED${COLOR_RESET}"
  elif [ "$issues" -eq 0 ]; then
    echo -e "  ${COLOR_YELLOW}⚠ Template validation PASSED with $warnings warning(s)${COLOR_RESET}"
  else
    echo -e "  ${COLOR_RED}✗ Template validation FAILED with $issues issue(s)${COLOR_RESET}"
  fi
  
  return $issues
}

# Check cloud-init configuration only
check_cloud_init() {
  local vmid="$1"
  local name
  name=$(get_config "$vmid" "name" || pct config "$vmid" 2>/dev/null | grep "^hostname:" | awk '{print $2}')
  
  echo -e "${COLOR_BOLD}Checking cloud-init: $vmid${COLOR_RESET} (${name:-N/A})"
  echo ""
  
  # Check CI user
  local ci_user
  ci_user=$(get_config "$vmid" "ciuser")
  if [ -n "$ci_user" ]; then
    check_result "ok" "CI user: $ci_user"
  else
    check_result "warn" "No CI user configured"
  fi
  
  # Check CI password
  local ci_pass
  ci_pass=$(get_config "$vmid" "cipassword")
  if [ -n "$ci_pass" ]; then
    check_result "ok" "CI password configured (hidden)"
  else
    check_result "warn" "No CI password configured"
  fi
  
  # Check CI nameserver
  local ci_ns
  ci_ns=$(get_config "$vmid" "nameserver")
  if [ -n "$ci_ns" ]; then
    check_result "ok" "Nameserver: $ci_ns"
  else
    check_result "warn" "No nameserver configured"
  fi
  
  # Check CI searchdomain
  local ci_sd
  ci_sd=$(get_config "$vmid" "searchdomain")
  if [ -n "$ci_sd" ]; then
    check_result "ok" "Search domain: $ci_sd"
  else
    check_result "warn" "No search domain configured"
  fi
  
  # Check IP configuration
  local ipconfig
  ipconfig=$(qm config "$vmid" 2>/dev/null | grep "^ipconfig" || true)
  if [ -n "$ipconfig" ]; then
    check_result "ok" "IP configuration present"
    echo "$ipconfig" | while read -r line; do
      echo -e "    ${COLOR_DIM}$line${COLOR_RESET}"
    done
  else
    check_result "warn" "No IP configuration configured (DHCP only)"
  fi
  
  # Check SSH keys
  local sshkeys
  sshkeys=$(qm config "$vmid" 2>/dev/null | grep "^sshkeys:" || true)
  if [ -n "$sshkeys" ]; then
    check_result "ok" "SSH keys configured"
  else
    check_result "warn" "No SSH keys configured"
  fi
  
  echo ""
}

# Main execution
echo -e "${COLOR_BOLD}${COLOR_CYAN}╔═══════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}║  TEMPLATE VALIDATION UTILITY                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}╚═══════════════════════════════════════════════════════════╝${COLOR_RESET}"

if [ -n "$TARGET_VMID" ]; then
  # Check specific VM
  if ! check_vm "$TARGET_VMID"; then
    log_error "VM $TARGET_VMID does not exist"
    exit 1
  fi
  
  if [ "$CHECK_CLOUD_INIT" -eq 1 ]; then
    check_cloud_init "$TARGET_VMID"
  else
    check_template "$TARGET_VMID"
  fi
elif [ "$CHECK_ALL" -eq 1 ]; then
  # Check all templates
  echo -e "${COLOR_BOLD}Scanning for templates...${COLOR_RESET}"
  echo ""
  
  mapfile -t vm_lines < <(qm list 2>/dev/null)
  
  for line in "${vm_lines[@]:1}"; do
    [ -z "$line" ] && continue
    
    vmid=$(echo "$line" | awk '{print $1}')
    template=$(get_config "$vmid" "template")
    
    if [ "$template" = "1" ]; then
      if check_template "$vmid"; then
        echo ""
      fi
    fi
  done
else
  usage
fi

echo ""
