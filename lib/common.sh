#!/usr/bin/env bash
# Shared helper functions for Proxmox utility scripts

set -o errexit
set -o pipefail
set -o nounset

# Colors for log output
if [ -t 1 ]; then
  COLOR_RESET="\033[0m"
  COLOR_GREEN="\033[32m"
  COLOR_YELLOW="\033[33m"
  COLOR_RED="\033[31m"
else
  COLOR_RESET=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_RED=""
fi

log_info() { echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $*"; }
log_warn() { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"; }
log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" 1>&2; }

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    log_error "This script must be run as root."
    exit 1
  fi
}

# Load configuration file if present; fall back to built-in defaults
source_config() {
  local config_file=${CONFIG_FILE:-"./config.sh"}
  if [ -f "$config_file" ]; then
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
: "${BACKUP_STORAGE:=local}" # vzdump target storage
: "${BACKUP_RETENTION_DAYS:=30}"

get_pve_version() {
  if command -v pveversion >/dev/null 2>&1; then
    pveversion | awk -F'[ /]' 'NR==1 {print $2}'
  fi
}

get_debian_codename() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "$VERSION_CODENAME"
    return
  fi
  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -cs
    return
  fi
  log_warn "Could not determine Debian codename; defaulting to bookworm"
  echo "bookworm"
}

check_vm_exists() {
  local vmid="$1"
  if qm config "$vmid" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

check_ct_exists() {
  local ctid="$1"
  if pct config "$ctid" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

ensure_ssh_key() {
  local key_path="$1"
  if [ ! -f "$key_path" ]; then
    log_error "SSH key not found at $key_path"
    exit 1
  fi
}
