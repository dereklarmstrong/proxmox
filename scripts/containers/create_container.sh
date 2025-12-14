#!/usr/bin/env bash
# Create an LXC container from a template

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../lib/common.sh
source "$REPO_ROOT/lib/common.sh"
source_config
require_root

usage() {
  cat <<EOF
Usage: $(basename "$0") -i <ctid> -n <name> -t <template> [options]
  -i <id>       Container ID (required)
  -n <name>     Hostname (required)
  -t <tpl>      Template (e.g. local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst)
  -s <storage>  Storage (default: $DEFAULT_STORAGE)
  -r <size>     Rootfs size (e.g. 8G, default: 8G)
  -b <bridge>   Bridge (default: $DEFAULT_BRIDGE)
  -u <cidr>     Static IP (e.g. 192.168.1.60/24); omit for DHCP
  -g <gw>       Gateway (optional if -u set)
  -k <sshkey>   SSH public key path (optional)
  -h            Help
EOF
}

ctid=""
name=""
template=""
storage="$DEFAULT_STORAGE"
rootfs_size="8G"
bridge="$DEFAULT_BRIDGE"
ip_cidr=""
gateway=""
ssh_key=""

while getopts ":i:n:t:s:r:b:u:g:k:h" opt; do
  case "$opt" in
    i) ctid="$OPTARG" ;;
    n) name="$OPTARG" ;;
    t) template="$OPTARG" ;;
    s) storage="$OPTARG" ;;
    r) rootfs_size="$OPTARG" ;;
    b) bridge="$OPTARG" ;;
    u) ip_cidr="$OPTARG" ;;
    g) gateway="$OPTARG" ;;
    k) ssh_key="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[[ -n "$ctid" && "$ctid" =~ ^[0-9]+$ ]] || { log_error "Container ID required and must be numeric"; exit 1; }
[[ -n "$name" ]] || { log_error "Name required"; exit 1; }
[[ -n "$template" ]] || { log_error "Template required"; exit 1; }

if check_ct_exists "$ctid"; then
  log_error "CT $ctid already exists"
  exit 1
fi

if [ -n "$ssh_key" ]; then
  ensure_ssh_key "$ssh_key"
fi

log_info "Creating CT $ctid ($name) from $template"
pct create "$ctid" "$template" \
  --hostname "$name" \
  --storage "$storage" \
  --rootfs "$storage:$rootfs_size" \
  --net0 "name=eth0,bridge=$bridge,ip=${ip_cidr:-dhcp},gw=$gateway" \
  ${ssh_key:+--ssh-public-keys "$ssh_key"}

log_info "Starting CT $ctid"
pct start "$ctid"
log_info "Container created and started: CTID $ctid ($name)"
