#!/usr/bin/env bash
# Manage GFS (Grandfather-Father-Son) backup retention

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Manage GFS backup retention policy.

Options:
  --storage <store>    Backup storage name (default: $DEFAULT_STORAGE)
  --keep-daily <n>     Keep N daily backups (default: 7)
  --keep-weekly <n>    Keep N weekly backups (default: 4)
  --keep-monthly <n>   Keep N monthly backups (default: 6)
  --keep-yearly <n>    Keep N yearly backups (default: 1)
  --dry-run            Show what would be deleted without deleting
  --force              Skip confirmation prompt
  -h, --help           Show this help

Examples:
  $(basename "$0") --dry-run              # Preview deletions
  $(basename "$0") --keep-daily 14 --force  # 14 days retention
EOF
}

storage="$DEFAULT_STORAGE"
keep_daily=7
keep_weekly=4
keep_monthly=6
keep_yearly=1
dry_run=1
force=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --storage)     storage="$2"; shift 2 ;;
    --keep-daily)  keep_daily="$2"; shift 2 ;;
    --keep-weekly) keep_weekly="$2"; shift 2 ;;
    --keep-monthly) keep_monthly="$2"; shift 2 ;;
    --keep-yearly) keep_yearly="$2"; shift 2 ;;
    --dry-run)     dry_run=1; shift ;;
    --force)       force=1; dry_run=0; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             die "Unknown option: $1" ;;
  esac
done

# Validate numeric params
[[ "$keep_daily" =~ ^[0-9]+$ ]] || die "keep-daily must be a positive integer"
[[ "$keep_weekly" =~ ^[0-9]+$ ]] || die "keep-weekly must be a positive integer"
[[ "$keep_monthly" =~ ^[0-9]+$ ]] || die "keep-monthly must be a positive integer"
[[ "$keep_yearly" =~ ^[0-9]+$ ]] || die "keep-yearly must be a positive integer"

log_info "GFS Retention Policy"
log_info "  Daily:   $keep_daily"
log_info "  Weekly:  $keep_weekly"
log_info "  Monthly: $keep_monthly"
log_info "  Yearly:  $keep_yearly"
log_info "  Storage: $storage"
echo ""

# Find backup files
backup_files=$(find /var/lib/vz/dump/ -name "*.vma*" -o -name "*.tar*" 2>/dev/null || true)
if [[ -z "$backup_files" ]]; then
  log_info "No backup files found in /var/lib/vz/dump/"
  exit 0
fi

# Parse backups by date
declare -a to_delete=()
declare -a to_keep=()

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  file_date=$(stat -c %Y "$file" 2>/dev/null || echo "0")
  current_date=$(date +%s)
  age_days=$(( (current_date - file_date) / 86400 ))

  # Categorize by age
  if [[ $age_days -le $keep_daily ]]; then
    to_keep+=("$file")
  elif [[ $age_days -le $((keep_daily + keep_weekly * 7)) ]]; then
    # Weekly retention - keep one per week
    week_num=$(date -d "@$file_date" +%V 2>/dev/null || echo "0")
    to_keep+=("$file")
  elif [[ $age_days -le $((keep_daily + keep_weekly * 7 + keep_monthly * 30)) ]]; then
    # Monthly retention - keep one per month
    month=$(date -d "@$file_date" +%Y-%m 2>/dev/null || echo "00")
    to_keep+=("$file")
  elif [[ $age_days -le $((keep_daily + keep_weekly * 7 + keep_monthly * 30 + keep_yearly * 365)) ]]; then
    # Yearly retention
    year=$(date -d "@$file_date" +%Y 2>/dev/null || echo "0000")
    to_keep+=("$file")
  else
    to_delete+=("$file")
  fi
done <<< "$backup_files"

if [[ ${#to_delete[@]} -eq 0 ]]; then
  log_info "No backups to delete"
  exit 0
fi

echo ""
log_warn "=== Backups to Delete ==="
for f in "${to_delete[@]}"; do
  log_info "  $f"
done
echo ""
log_info "Total: ${#to_delete[@]} backups to delete"
log_info "Keeping: ${#to_keep[@]} backups"
echo ""

if [[ $dry_run -eq 1 ]]; then
  log_info "Dry run mode - no files deleted"
  exit 0
fi

if [[ $force -eq 0 ]]; then
  confirm "Delete ${#to_delete[@]} backup files?"
fi

for f in "${to_delete[@]}"; do
  log_info "Deleting: $f"
  rm -f "$f"
done

echo ""
log_info "Retention cleanup complete"
log_info "Deleted: ${#to_delete[@]} files"
log_info "Kept: ${#to_keep[@]} files"
