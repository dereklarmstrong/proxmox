#!/usr/bin/env bash
# Report storage pool usage

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Report storage pool usage with capacity warnings.

Options:
  --storage <store>  Show details for specific storage pool
  --json             Output in JSON format
  -h, --help         Show this help

Examples:
  $(basename "$0")
  $(basename "$0") --storage local-lvm
  $(basename "$0") --json
EOF
}

target_storage=""
output_json=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --storage) target_storage="$2"; shift 2 ;;
    --json)    output_json=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)         die "Unknown option: $1" ;;
  esac
done

# Get storage info from pvesm
declare -a storages=()
declare -a types=()
declare -a totals=()
declare -a useds=()
declare -a availables=()
declare -a percentages=()

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" == "content"* ]] && continue
  [[ "$line" == "volname"* ]] && continue

  name=$(echo "$line" | awk '{print $1}')
  type=$(echo "$line" | awk '{print $2}')
  vtotal=$(echo "$line" | awk '{print $3}')
  vfree=$(echo "$line" | awk '{print $4}')
  used=$(echo "$line" | awk '{print $5}')

  [[ -z "$name" || "$name" == "content" ]] && continue

  # Skip if filtering by storage name
  if [[ -n "$target_storage" && "$name" != "$target_storage" ]]; then
    continue
  fi

  # Calculate percentage
  pct=0
  if [[ "$vtotal" =~ ^[0-9]+$ && "$vtotal" -gt 0 ]]; then
    pct=$(( used * 100 / vtotal ))
  fi

  storages+=("$name")
  types+=("$type")
  totals+=("$vtotal")
  useds+=("$used")
  availables+=("$vfree")
  percentages+=("$pct")
done < <(pvesm status 2>/dev/null || true)

if [[ ${#storages[@]} -eq 0 ]]; then
  die "No storage pools found. Are you running on a Proxmox node?"
fi

if [[ $output_json -eq 1 ]]; then
  echo "["
  first=1
  for i in "${!storages[@]}"; do
    [[ $first -eq 1 ]] && first=0 || echo ","
    printf '  {"storage": "%s", "type": "%s", "total": "%s", "used": "%s", "available": "%s", "pct": %s}' \
      "${storages[$i]}" "${types[$i]}" "${totals[$i]}" "${useds[$i]}" "${availables[$i]}" "${percentages[$i]}"
  done
  echo ""
  echo "]"
else
  printf "%-20s %-10s %-15s %-15s %-15s %-10s\n" "STORAGE" "TYPE" "TOTAL" "USED" "AVAILABLE" "USE%"
  printf "%-20s %-10s %-15s %-15s %-15s %-10s\n" "--------------------" "----------" "---------------" "---------------" "---------------" "----------"

  for i in "${!storages[@]}"; do
    color="$GREEN"
    if [[ ${percentages[$i]} -ge 90 ]]; then
      color="$RED"
    elif [[ ${percentages[$i]} -ge 80 ]]; then
      color="$YELLOW"
    fi
    printf "%-20s %-10s %-15s %-15s %-15s ${color}%-6s%%${NC}\n" \
      "${storages[$i]}" "${types[$i]}" "${totals[$i]}" "${useds[$i]}" "${availables[$i]}" "${percentages[$i]}"
  done

  echo ""
  # Warnings
  warned=0
  for i in "${!storages[@]}"; do
    if [[ ${percentages[$i]} -ge 80 ]]; then
      warn_color="$RED"
      if [[ ${percentages[$i]} -lt 90 ]]; then
        warn_color="$YELLOW"
      fi
      printf "${warn_color}  WARNING: ${storages[$i]} is ${percentages[$i]}%% full${NC}\n"
      warned=1
    fi
  done
  [[ $warned -eq 0 ]] && log_info "All storage pools below 80% capacity"
fi

# Show contents if specific storage requested
if [[ -n "$target_storage" ]]; then
  echo ""
  log_info "Contents of $target_storage:"
  echo ""
  printf "%-40s %-10s %-10s\n" "NAME" "TYPE" "SIZE"
  printf "%-40s %-10s %-10s\n" "----------------------------------------" "----------" "----------"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{print $1}')
    type=$(echo "$line" | awk '{print $2}')
    size=$(echo "$line" | awk '{print $3}')
    [[ "$name" == "content"* || "$name" == "volname"* ]] && continue
    printf "%-40s %-10s %-10s\n" "$name" "$type" "$size"
  done < <(pvesh get "/nodes/$(hostname -s)/storage/$target_storage/content" --content images,vztmpl,iso,backup 2>/dev/null | awk -F: '{print $1, $2, $3}' || true)
fi
