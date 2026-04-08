#!/usr/bin/env bash
#
# WHAT: Display status of all VMs and containers in a dashboard format
# LEARNING: Proxmox CLI tools, parsing output, bash scripting
# WHEN YOU NEED: Quick overview of all VMs and containers
# SIMPLER: Manual `qm list` or `pct list` commands
# PITFALLS: Requires root privileges, some VMs may be offline
#
# Enterprise Skills You'll Learn:
# - System monitoring
# - Status reporting
# - Data visualization in CLI
#
# When You Actually Need This in Production:
# - Quick health checks
# - Monitoring dashboards
# - Incident response
#
# Simpler Alternative for Daily Services:
# - Use Proxmox web UI for visual overview
#
# This is for learning. Production homelabs should prioritize simplicity.
# Use these techniques to build skills, not because you need them for daily services.
# Complexity = More failure points. Keep your production services simple.

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=../lib/common.sh
source "$REPO_ROOT/lib/common.sh"

# Colors
if [ -t 1 ]; then
  COLOR_RESET="\033[0m"
  COLOR_GREEN="\033[32m"
  COLOR_YELLOW="\033[33m"
  COLOR_RED="\033[31m"
  COLOR_CYAN="\033[36m"
  COLOR_BOLD="\033[1m"
else
  COLOR_RESET=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_RED=""
  COLOR_CYAN=""
  COLOR_BOLD=""
fi

# Header
echo -e "${COLOR_BOLD}${COLOR_CYAN}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}║         PROXMOX VM & CONTAINER STATUS DASHBOARD              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
echo ""

# Counters
vm_count=0
ct_count=0
running_vms=0
stopped_vms=0
running_cts=0
stopped_cts=0

# VM Status Table
echo -e "${COLOR_BOLD}${COLOR_CYAN}┌───────────────────────────────────────────────────────────────┐${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}│  VIRTUAL MACHINES (VMs)                                       │${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}└───────────────────────────────────────────────────────────────┘${COLOR_RESET}"
echo ""

if command -v qm &>/dev/null; then
  # Get VM list with status
  mapfile -t vm_lines < <(qm list 2>/dev/null)
  
  if [ ${#vm_lines[@]} -gt 1 ]; then
    printf "${COLOR_BOLD}  %-6s  %-20s  %-8s  %-8s  %-8s  %-10s${COLOR_RESET}\n" "VMID" "NAME" "STATUS" "CPUS" "MEM" "UPTIME"
    printf "  %-6s  %-20s  %-8s  %-8s  %-8s  %-10s\n" "------" "--------------------" "--------" "--------" "--------" "----------"
    
    for line in "${vm_lines[@]:1}"; do
      [ -z "$line" ] && continue
      
      vmid=$(echo "$line" | awk '{print $1}')
      name=$(echo "$line" | awk '{print $2}')
      status=$(echo "$line" | awk '{print $3}')
      cpus=$(echo "$line" | awk '{print $4}')
      mem=$(echo "$line" | awk '{print $5}')
      uptime=$(echo "$line" | awk '{print $6}')
      
      # Truncate long names
      if [ ${#name} -gt 20 ]; then
        name="${name:0:17}..."
      fi
      
      # Color code status
      case "$status" in
        "up")
          status_color="$COLOR_GREEN"
          ((running_vms++))
          ;;
        "stopped")
          status_color="$COLOR_YELLOW"
          ((stopped_vms++))
          ;;
        *)
          status_color="$COLOR_RED"
          ;;
      esac
      
      printf "  ${COLOR_RESET}%-6s  ${COLOR_RESET}%-20s  ${status_color}%-8s${COLOR_RESET}  ${cpus:-0}  ${mem:-0}  ${uptime:-0}\n" "$vmid" "$name" "$status"
      ((vm_count++))
    done
  else
    echo -e "  ${COLOR_YELLOW}No VMs found${COLOR_RESET}"
  fi
else
  echo -e "  ${COLOR_RED}qm command not found. Are you on a Proxmox node?${COLOR_RESET}"
fi

echo ""

# Container Status Table
echo -e "${COLOR_BOLD}${COLOR_CYAN}┌───────────────────────────────────────────────────────────────┐${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}│  LXC CONTAINERS                                               │${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}└───────────────────────────────────────────────────────────────┘${COLOR_RESET}"
echo ""

if command -v pct &>/dev/null; then
  # Get CT list with status
  mapfile -t ct_lines < <(pct list 2>/dev/null)
  
  if [ ${#ct_lines[@]} -gt 1 ]; then
    printf "${COLOR_BOLD}  %-6s  %-20s  %-8s  %-8s  %-8s${COLOR_RESET}\n" "CTID" "NAME" "STATUS" "CPU%" "MEM"
    printf "  %-6s  %-20s  %-8s  %-8s  %-8s\n" "------" "--------------------" "--------" "--------" "--------"
    
    for line in "${ct_lines[@]:1}"; do
      [ -z "$line" ] && continue
      
      ctid=$(echo "$line" | awk '{print $1}')
      name=$(echo "$line" | awk '{print $2}')
      status=$(echo "$line" | awk '{print $3}')
      cpu=$(echo "$line" | awk '{print $4}')
      mem=$(echo "$line" | awk '{print $5}')
      
      # Truncate long names
      if [ ${#name} -gt 20 ]; then
        name="${name:0:17}..."
      fi
      
      # Color code status
      case "$status" in
        "running")
          status_color="$COLOR_GREEN"
          ((running_cts++))
          ;;
        "stopped")
          status_color="$COLOR_YELLOW"
          ((stopped_cts++))
          ;;
        *)
          status_color="$COLOR_RED"
          ;;
      esac
      
      printf "  ${COLOR_RESET}%-6s  ${COLOR_RESET}%-20s  ${status_color}%-8s${COLOR_RESET}  ${cpu:-0}  ${mem:-0}\n" "$ctid" "$name" "$status"
      ((ct_count++))
    done
  else
    echo -e "  ${COLOR_YELLOW}No containers found${COLOR_RESET}"
  fi
else
  echo -e "  ${COLOR_RED}pct command not found. Are you on a Proxmox node?${COLOR_RESET}"
fi

# Summary
echo ""
echo -e "${COLOR_BOLD}${COLOR_CYAN}┌───────────────────────────────────────────────────────────────┐${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}│  SUMMARY                                                      │${COLOR_RESET}"
echo -e "${COLOR_BOLD}${COLOR_CYAN}└───────────────────────────────────────────────────────────────┘${COLOR_RESET}"
echo ""

printf "  ${COLOR_GREEN}Running:${COLOR_RESET}  ${running_vms} VMs + ${running_cts} CTs = $((running_vms + running_cts)) total\n"
printf "  ${COLOR_YELLOW}Stopped:${COLOR_RESET}  ${stopped_vms} VMs + ${stopped_cts} CTs = $((stopped_vms + stopped_cts)) total\n"
printf "  ${COLOR_CYAN}Total:${COLOR_RESET}    ${vm_count} VMs + ${ct_count} CTs = $((vm_count + ct_count)) total\n"

echo ""
echo -e "${COLOR_BOLD}Legend:${COLOR_RESET}"
echo -e "  ${COLOR_GREEN}Running${COLOR_RESET}  ${COLOR_YELLOW}Stopped${COLOR_RESET}  ${COLOR_RED}Unknown${COLOR_RESET}"
echo ""
