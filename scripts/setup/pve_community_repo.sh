#!/usr/bin/env bash
# Configure Proxmox VE to use the no-subscription repository (8.x-friendly)

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../lib/common.sh
source "$REPO_ROOT/lib/common.sh"
source_config
require_root

codename=$(get_debian_codename)
community_list=/etc/apt/sources.list.d/pve-no-subscription.list
enterprise_list=/etc/apt/sources.list.d/pve-enterprise.list

log_info "Setting up Proxmox community repository for $codename"
if [ -f "$community_list" ]; then
  cp "$community_list" "$community_list.bak.$(date +%Y%m%d%H%M%S)"
fi
echo "deb http://download.proxmox.com/debian/pve $codename pve-no-subscription" > "$community_list"

if [ -f "$enterprise_list" ]; then
  cp "$enterprise_list" "$enterprise_list.bak.$(date +%Y%m%d%H%M%S)"
  sed -i 's/^deb/#deb/' "$enterprise_list"
fi

log_info "Updating package lists"
apt update
log_info "You can now run: apt upgrade -y"
