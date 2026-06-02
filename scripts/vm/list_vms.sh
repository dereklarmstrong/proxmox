#!/usr/bin/env bash
# List VMs and containers on a Proxmox node

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

List VMs and containers on the local Proxmox node.

Options:
  --running      Show only running VMs/containers
  --stopped      Show only stopped VMs/containers
  --templates    Show only templates
  --json         Output in JSON format
  -h, --help     Show this help

Examples:
  $(basename "$0")                 # List everything
  $(basename "$0") --running       # List running only
  $(basename "$0") --json          # JSON output
EOF
}

filter_running=0
filter_stopped=0
filter_templates=0
output_json=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --running)   filter_running=1; shift ;;
    --stopped)   filter_stopped=1; shift ;;
    --templates) filter_templates=1; shift ;;
    --json)      output_json=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    *)           die "Unknown option: $1" ;;
  esac
done

# Collect VM data
declare -a vmids=()
declare -a names=()
declare -a statuses=()
declare -a cpus=()
declare -a memories=()
declare -a disks=()
declare -a types=()

# VMs
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  vmid=$(echo "$line" | awk '{print $1}')
  [[ -z "$vmid" ]] && continue

  name=$(qm config "$vmid" 2>/dev/null | grep "^name:" | head -1 | sed 's/^name://')
  name="${name:-}"

  status=$(qm status "$vmid" 2>/dev/null | awk '/^status:/ {print $2}')
  status="${status:-stopped}"

  cpu=$(qm status "$vmid" 2>/dev/null | awk '/^cpu:/{printf "%.1f", $2}')"%"
  cpu="${cpu:-0%}"

  mem_total=$(qm status "$vmid" 2>/dev/null | awk '/^maxmem:/{print $2}')
  mem_used=$(qm status "$vmid" 2>/dev/null | awk '/^mem:/{print $2}')
  if [[ -n "$mem_total" && "$mem_total" -gt 0 ]] 2>/dev/null; then
    mem="$((${mem_used:-0} * 100 / ${mem_total}))%"
  else
    mem="0%"
  fi

  # Get disk usage from config
  disk_line=$(qm config "$vmid" 2>/dev/null | grep -E "^(scsi|virtio|sata)[0-9]" | head -5 | tr '\n' ';')
  disk="N/A"

  vmids+=("$vmid")
  names+=("$name")
  statuses+=("$status")
  cpus+=("$cpu")
  memories+=("$mem")
  disks+=("$disk")
  types+=("vm")
done < <(qm list 2>/dev/null | awk 'NR>1 {print $1}')

# Containers
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  ctid=$(echo "$line" | awk '{print $1}')
  [[ -z "$ctid" ]] && continue

  hostname=$(pct config "$ctid" 2>/dev/null | grep "^hostname:" | head -1 | sed 's/^hostname://')
  hostname="${hostname:-}"

  status=$(pct status "$ctid" 2>/dev/null | awk '/^status:/ {print $2}')
  status="${status:-stopped}"

  cpu=$(pct status "$ctid" 2>/dev/null | awk '/^cpu:/{printf "%.1f", $2}')"%"
  cpu="${cpu:-0%}"

  mem_total=$(pct status "$ctid" 2>/dev/null | awk '/^maxmem:/{print $2}')
  mem_used=$(pct status "$ctid" 2>/dev/null | awk '/^mem:/{print $2}')
  if [[ -n "$mem_total" && "$mem_total" -gt 0 ]] 2>/dev/null; then
    mem="$((${mem_used:-0} * 100 / ${mem_total}))%"
  else
    mem="0%"
  fi

  vmids+=("$ctid")
  names+=("$hostname")
  statuses+=("$status")
  cpus+=("$cpu")
  memories+=("$mem")
  disks+=("N/A")
  types+=("lxc")
done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')

# Apply filters
if [[ $output_json -eq 1 ]]; then
  echo "["
  first=1
  for i in "${!vmids[@]}"; do
    [[ $first -eq 1 ]] && first=0 || echo ","
    status_filter=1
    if [[ $filter_running -eq 1 && "${statuses[$i]}" != "running" ]]; then
      status_filter=0
    fi
    if [[ $filter_stopped -eq 1 && "${statuses[$i]}" != "stopped" ]]; then
      status_filter=0
    fi
    if [[ $filter_templates -eq 1 && "${names[$i]}" == "" ]]; then
      status_filter=0
    fi
    [[ $status_filter -eq 1 ]] || continue
    printf '  {"id": %s, "name": "%s", "type": "%s", "status": "%s", "cpu": "%s", "memory": "%s"}' \
      "${vmids[$i]}" "${names[$i]}" "${types[$i]}" "${statuses[$i]}" "${cpus[$i]}" "${memories[$i]}"
  done
  echo ""
  echo "]"
else
  printf "%-8s %-20s %-8s %-10s %-10s %-10s\n" "ID" "NAME" "TYPE" "STATUS" "CPU" "MEM"
  printf "%-8s %-20s %-8s %-10s %-10s %-10s\n" "--------" "--------------------" "--------" "----------" "----------" "----------"
  for i in "${!vmids[@]}"; do
    status_filter=1
    if [[ $filter_running -eq 1 && "${statuses[$i]}" != "running" ]]; then
      status_filter=0
    fi
    if [[ $filter_stopped -eq 1 && "${statuses[$i]}" != "stopped" ]]; then
      status_filter=0
    fi
    if [[ $filter_templates -eq 1 && "${names[$i]}" == "" ]]; then
      status_filter=0
    fi
    [[ $status_filter -eq 1 ]] || continue
    printf "%-8s %-20s %-8s %-10s %-10s %-10s\n" \
      "${vmids[$i]}" "${names[$i]:0:20}" "${types[$i]}" "${statuses[$i]}" "${cpus[$i]}" "${memories[$i]}"
  done
fi
