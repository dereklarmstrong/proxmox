#!/usr/bin/env bash
# List LXC containers on a Proxmox node

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

List LXC containers on the local Proxmox node.

Options:
  --running    Show only running containers
  --stopped    Show only stopped containers
  --json       Output in JSON format
  -h, --help   Show this help

Examples:
  $(basename "$0")              # List all containers
  $(basename "$0") --running    # List running only
  $(basename "$0") --json       # JSON output
EOF
}

filter_running=0
filter_stopped=0
output_json=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --running)  filter_running=1; shift ;;
    --stopped)  filter_stopped=1; shift ;;
    --json)     output_json=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    *)          die "Unknown option: $1" ;;
  esac
done

# Collect container data
declare -a ctids=()
declare -a hostnames=()
declare -a statuses=()
declare -a cpus=()
declare -a memories=()
declare -a disks=()

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

  ctids+=("$ctid")
  hostnames+=("$hostname")
  statuses+=("$status")
  cpus+=("$cpu")
  memories+=("$mem")
  disks+=("N/A")
done < <(pct list 2>/dev/null | awk 'NR>1 {print $1}')

if [[ $output_json -eq 1 ]]; then
  echo "["
  first=1
  for i in "${!ctids[@]}"; do
    [[ $first -eq 1 ]] && first=0 || echo ","
    status_filter=1
    [[ $filter_running -eq 1 && "${statuses[$i]}" != "running" ]] && status_filter=0
    [[ $filter_stopped -eq 1 && "${statuses[$i]}" != "stopped" ]] && status_filter=0
    [[ $status_filter -eq 1 ]] || continue
    printf '  {"id": %s, "hostname": "%s", "status": "%s", "cpu": "%s", "memory": "%s"}' \
      "${ctids[$i]}" "${hostnames[$i]}" "${statuses[$i]}" "${cpus[$i]}" "${memories[$i]}"
  done
  echo ""
  echo "]"
else
  printf "%-8s %-20s %-10s %-10s %-10s\n" "CTID" "HOSTNAME" "STATUS" "CPU" "MEM"
  printf "%-8s %-20s %-10s %-10s %-10s\n" "--------" "--------------------" "----------" "----------" "----------"
  for i in "${!ctids[@]}"; do
    status_filter=1
    [[ $filter_running -eq 1 && "${statuses[$i]}" != "running" ]] && status_filter=0
    [[ $filter_stopped -eq 1 && "${statuses[$i]}" != "stopped" ]] && status_filter=0
    [[ $status_filter -eq 1 ]] || continue
    printf "%-8s %-20s %-10s %-10s %-10s\n" \
      "${ctids[$i]}" "${hostnames[$i]:0:20}" "${statuses[$i]}" "${cpus[$i]}" "${memories[$i]}"
  done
fi
