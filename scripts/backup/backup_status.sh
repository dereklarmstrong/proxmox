#!/usr/bin/env bash
# Check backup status for VMs and containers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Check backup status for VMs and containers.

Options:
  --vmid <id>        Check specific VMID
  --ctid <id>        Check specific CTID
  --storage <store>  Filter by storage name
  --json             Output in JSON format
  --days <n>         Show backups from last N days (default: 7)
  -h, --help         Show this help

Examples:
  $(basename "$0")                 # Last 7 days, all backups
  $(basename "$0") --vmid 100      # VM 100 only
  $(basename "$0") --days 30       # Last 30 days
EOF
}

vmid=""
ctid=""
storage=""
output_json=0
days=7

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid)     vmid="$2"; shift 2 ;;
    --ctid)     ctid="$2"; shift 2 ;;
    --storage)  storage="$2"; shift 2 ;;
    --json)     output_json=1; shift ;;
    --days)     days="$2"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *)          die "Unknown option: $1" ;;
  esac
done

[[ "$days" =~ ^[0-9]+$ ]] || die "Days must be a positive integer"

is_local=0
if [[ -d /etc/pve ]] || command -v pvesh &>/dev/null && pvesh get /version &>/dev/null 2>&1; then
  is_local=1
fi

log_info "Checking backups from last $days days"
echo ""

declare -a ids=()
declare -a types=()
declare -a dates=()
declare -a sizes=()
declare -a storages=()

if [[ $is_local -eq 1 ]]; then
  # Parse vzdump entries from syslog
  local_days=$((days + 1))
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    # Extract timestamp (last 24 chars before "vzdump")
    ts=$(echo "$line" | sed -n 's/.*\(....-..-.. ..:..:..\).*vzdump/\1/p')
    [[ -z "$ts" ]] && continue

    # Extract ID, type, status, storage
    id=$(echo "$line" | grep -oP '(?:vm|lxc|container)[_-](\d+)' | head -1 | grep -oP '\d+')
    [[ -z "$id" ]] && id=$(echo "$line" | grep -oP 'vzdump[._-]*(\d+)' | head -1 | grep -oP '\d+')
    [[ -z "$id" ]] && continue

    if echo "$line" | grep -qP 'vzdump(?:\.qemu|\.lxc)?(?:[_-](\d+))?' ; then
      if echo "$line" | grep -q 'vm'; then
        type="vm"
      elif echo "$line" | grep -qP 'lxc|container'; then
        type="ct"
      else
        type="vm"
      fi
    else
      type="vm"
    fi

    status="unknown"
    if echo "$line" | grep -qi 'finished OK'; then
      status="success"
    elif echo "$line" | grep -qi 'ERR\|fail\|ERROR'; then
      status="failed"
    fi

    stg=$(echo "$line" | grep -oP 'storage[= ]+\K\S+' | head -1)
    [[ -z "$stg" ]] && stg=$(echo "$line" | grep -oP '(?:backup/|dump\.|\.)(\S+?)(?:/|\.|vz)' | head -1)
    [[ -z "$stg" ]] && stg="unknown"

    # Filter by storage
    if [[ -n "$storage" && "$stg" != "$storage" ]]; then
      continue
    fi

    # Filter by ID type
    if [[ -n "$vmid" && "$type" != "vm" && "$id" != "$vmid" ]]; then
      continue
    fi
    if [[ -n "$ctid" && "$type" != "ct" && "$id" != "$ctid" ]]; then
      continue
    fi

    date_str=$(date -d "$ts" +%Y-%m-%d 2>/dev/null || echo "unknown")

    ids+=("$id")
    types+=("$type")
    dates+=("$date_str")
    sizes+=("$(echo "$line" | grep -oP '[0-9]+[KMGT]B' | head -1 || echo 'unknown')")
    storages+=("$stg")
  done < <(grep -i 'vzdump' /var/log/syslog 2>/dev/null | tail -500 || true)

  # Also scan backup storage directories for files
  for storage_name in $(ls -d /var/lib/vz/dump/* 2>/dev/null | xargs -I{} basename {} || true); do
    [[ -z "$storage_name" ]] && continue
    [[ -n "$storage" && "$storage_name" != "$storage" ]] && continue

    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      fname=$(basename "$file")

      id=""
      type="vm"
      if [[ "$fname" =~ ^vzdump-qemu-([0-9]+)- ]]; then
        id="${BASH_REMATCH[1]}"
        type="vm"
      elif [[ "$fname" =~ ^vzdump-lxc-([0-9]+)- ]]; then
        id="${BASH_REMATCH[1]}"
        type="ct"
      elif [[ "$fname" =~ ^vzdump-([0-9]+)- ]]; then
        id="${BASH_REMATCH[1]}"
        type="vm"
      fi

      [[ -z "$id" ]] && continue

      if [[ -n "$vmid" && "$id" != "$vmid" ]]; then continue; fi
      if [[ -n "$ctid" && "$id" != "$ctid" ]]; then continue; fi

      file_date=$(stat -f '%Sm' -t '%Y-%m-%d' "$file" 2>/dev/null || echo "unknown")
      file_size=$(stat -f '%z' "$file" 2>/dev/null || echo 0)
      file_size_human=""
      if [[ $file_size -gt 1073741824 ]]; then
        file_size_human="$((file_size / 1073741824))G"
      elif [[ $file_size -gt 1048576 ]]; then
        file_size_human="$((file_size / 1048576))M"
      elif [[ $file_size -gt 1024 ]]; then
        file_size_human="$((file_size / 1024))K"
      fi

      ids+=("$id")
      types+=("$type")
      dates+=("$file_date")
      sizes+=("${file_size_human:-unknown}")
      storages+=("$storage_name")
    done < <(find "/var/lib/vz/dump/${storage_name}" -maxdepth 1 -type f \( -name '*.tar*' -o -name '*.zst' -o -name '*.gz' -o -name '*.lzo' \) 2>/dev/null || true)
  done

  # Also check other storage locations
  while IFS= read -r storage_path; do
    [[ -z "$storage_path" ]] && continue
    [[ -d "$storage_path/backups" ]] || continue
    stg_name=$(echo "$storage_path" | sed 's|.*/pve/storage/||;s|/.*||')
    [[ -n "$storage" && "$stg_name" != "$storage" ]] && continue

    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      fname=$(basename "$file")

      id=""
      type="vm"
      if [[ "$fname" =~ ^vzdump-qemu-([0-9]+)- ]]; then
        id="${BASH_REMATCH[1]}"
        type="vm"
      elif [[ "$fname" =~ ^vzdump-lxc-([0-9]+)- ]]; then
        id="${BASH_REMATCH[1]}"
        type="ct"
      elif [[ "$fname" =~ ^vzdump-([0-9]+)- ]]; then
        id="${BASH_REMATCH[1]}"
        type="vm"
      fi

      [[ -z "$id" ]] && continue

      if [[ -n "$vmid" && "$id" != "$vmid" ]]; then continue; fi
      if [[ -n "$ctid" && "$id" != "$ctid" ]]; then continue; fi

      file_date=$(stat -f '%Sm' -t '%Y-%m-%d' "$file" 2>/dev/null || echo "unknown")
      file_size=$(stat -f '%z' "$file" 2>/dev/null || echo 0)
      file_size_human=""
      if [[ $file_size -gt 1073741824 ]]; then
        file_size_human="$((file_size / 1073741824))G"
      elif [[ $file_size -gt 1048576 ]]; then
        file_size_human="$((file_size / 1048576))M"
      elif [[ $file_size -gt 1024 ]]; then
        file_size_human="$((file_size / 1024))K"
      fi

      ids+=("$id")
      types+=("$type")
      dates+=("$file_date")
      sizes+=("${file_size_human:-unknown}")
      storages+=("$stg_name")
    done < <(find "$storage_path/backups" -maxdepth 1 -type f \( -name '*.tar*' -o -name '*.zst' -o -name '*.gz' -o -name '*.lzo' \) 2>/dev/null || true)
  done < <(find /etc/pve -name 'storage.conf' -exec dirname {} \; 2>/dev/null || true)
else
  # Remote mode: use pvesh to list backup content from each storage
  log_info "Remote mode: querying API for backup content"

  while IFS= read -r node; do
    [[ -z "$node" ]] && continue
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      [[ "$line" == "type:"* ]] && continue

      stg=$(echo "$line" | awk -F: '{print $1}' | xargs)
      [[ -n "$storage" && "$stg" != "$storage" ]] && continue

      while IFS= read -r bfile; do
        [[ -z "$bfile" ]] && continue
        bname=$(basename "$bfile")

        id=""
        type="vm"
        if [[ "$bname" =~ ^vzdump-qemu-([0-9]+)- ]]; then
          id="${BASH_REMATCH[1]}"
          type="vm"
        elif [[ "$bname" =~ ^vzdump-lxc-([0-9]+)- ]]; then
          id="${BASH_REMATCH[1]}"
          type="ct"
        elif [[ "$bname" =~ ^dump\. ]]; then
          id=$(echo "$bname" | sed 's/dump\.//;s/\.lzo//;s/\.gz//;s/\.zst//;s/\.tar//')
          type="vm"
        fi

        [[ -z "$id" ]] && continue

        if [[ -n "$vmid" && "$id" != "$vmid" ]]; then continue; fi
        if [[ -n "$ctid" && "$id" != "$ctid" ]]; then continue; fi

        ids+=("$id")
        types+=("$type")
        dates+=("unknown")
        sizes+=("unknown")
        storages+=("$stg")
      done < <(pvesh get "/nodes/$node/storage/$stg/content" --content backup 2>/dev/null || true)
    done < <(pvesh get "/nodes/$node/storage" 2>/dev/null || true)
  done < <(pvesh get /nodes 2>/dev/null | awk -F: '{print $1}' || true)
fi

# Deduplicate by id+date+storage
declare -A seen=()
declare -a u_ids=()
declare -a u_types=()
declare -a u_dates=()
declare -a u_sizes=()
declare -a u_storages=()

for i in "${!ids[@]}"; do
  key="${ids[$i]}-${dates[$i]}-${storages[$i]}"
  if [[ -z "${seen[$key]:-}" ]]; then
    seen[$key]=1
    u_ids+=("${ids[$i]}")
    u_types+=("${types[$i]}")
    u_dates+=("${dates[$i]}")
    u_sizes+=("${sizes[$i]}")
    u_storages+=("${storages[$i]}")
  fi
done

if [[ $output_json -eq 1 ]]; then
  echo "["
  first=1
  for i in "${!u_ids[@]}"; do
    [[ $first -eq 1 ]] && first=0 || echo ","
    printf '  {"id": %s, "type": "%s", "date": "%s", "size": "%s", "storage": "%s"}' \
      "${u_ids[$i]}" "${u_types[$i]}" "${u_dates[$i]}" "${u_sizes[$i]}" "${u_storages[$i]}"
  done
  echo ""
  echo "]"
else
  printf "%-8s %-6s %-12s %-12s %-15s\n" "ID" "TYPE" "DATE" "SIZE" "STORAGE"
  printf "%-8s %-6s %-12s %-12s %-15s\n" "--------" "------" "------------" "------------" "---------------"
  for i in "${!u_ids[@]}"; do
    printf "%-8s %-6s %-12s %-12s %-15s\n" \
      "${u_ids[$i]}" "${u_types[$i]}" "${u_dates[$i]}" "${u_sizes[$i]}" "${u_storages[$i]}"
  done
fi

echo ""
log_info "Total backups found: ${#u_ids[@]}"
