#!/usr/bin/env bash
# Shared helper functions for Proxmox utility scripts

set -o errexit
set -o pipefail
set -o nounset

# --- Colors ---
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  CYAN=''
  NC=''
fi

# --- Logging ---
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${BLUE}[DEBUG]${NC} $*"; }

# --- Error handling ---
die() { log_error "$@"; exit 1; }

# --- Dependency checks ---
require_cmd() {
  command -v "$1" &>/dev/null || die "Required command '$1' not found. Install it and retry."
}

require_root() {
  if [[ "${REQUIRE_ROOT_BYPASS:-0}" == "1" ]]; then
    return
  fi
  [[ "$(id -u)" -eq 0 ]] || die "This script must be run as root."
}

# --- Proxmox checks ---
require_proxmox() {
  require_cmd pvesh
  require_cmd qm
  require_cmd pct
}

# --- Input validation ---
validate_vmid() {
  local vmid="$1"
  [[ "$vmid" =~ ^[0-9]+$ ]] || die "Invalid VMID: '$vmid'. Must be a positive integer."
  [[ "$vmid" -ge 100 ]] || die "VMID must be >= 100. Got: $vmid"
}

validate_ip() {
  local ip="$1"
  [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$ ]] \
    || die "Invalid IP address: '$ip'"
}

# --- Proxmox API helpers ---
pvesh_get()  { pvesh get "$@" --output-format json 2>/dev/null; }
pvesh_post() { pvesh create "$@" --output-format json 2>/dev/null; }

# --- Confirmation prompt ---
confirm() {
  local msg="${1:-Are you sure?}"
  read -rp "$msg [y/N]: " response
  [[ "$response" =~ ^[Yy]$ ]] || die "Aborted by user."
}

# --- VM/CT existence ---
check_vm_exists() {
  local vmid="$1"
  qm config "$vmid" &>/dev/null
}

check_ct_exists() {
  local ctid="$1"
  pct config "$ctid" &>/dev/null
}

# --- Config loading ---
source_config() {
  local config_file="${CONFIG_FILE:-./config.sh}"
  if [[ -f "$config_file" ]]; then
    # shellcheck disable=SC1090
    source "$config_file"
  fi
}

# Defaults (can be overridden by config.sh)
: "${GITHUB_USERNAME:=}"
: "${DEFAULT_STORAGE:=local-lvm}"
: "${DEFAULT_BRIDGE:=vmbr0}"
: "${SSH_KEY_PATH:=~/.ssh/id_rsa.pub}"
: "${DEFAULT_GATEWAY:=}"
: "${TEMPLATE_ID_START:=9000}"
: "${BACKUP_STORAGE:=local}"
: "${BACKUP_RETENTION_DAYS:=30}"

# --- System info ---
get_pve_version() {
  if command -v pveversion &>/dev/null; then
    pveversion | awk -F'[ /]' 'NR==1 {print $2}'
  fi
}

get_debian_codename() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "$VERSION_CODENAME"
    return
  fi
  if command -v lsb_release &>/dev/null; then
    lsb_release -cs
    return
  fi
  log_warn "Could not determine Debian codename; defaulting to bookworm"
  echo "bookworm"
}

# --- SSH key helper ---
ensure_ssh_key() {
  local key_path="$1"
  [[ -f "$key_path" ]] || die "SSH key not found at $key_path"
}
