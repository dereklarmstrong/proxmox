#!/usr/bin/env bash
#
# WHAT: Configure Proxmox VE to use the no-subscription repository (8.x-friendly)
# LEARNING: Package management, repository configuration, system updates
# WHEN YOU NEED: Setting up Proxmox for production use without subscription
# SIMPLER: Use default enterprise repo during evaluation period
# PITFALLS: Breaking package management, missing dependencies
#
# Enterprise Skills You'll Learn:
# - APT package management
# - Repository configuration
# - System update procedures
#
# When You Actually Need This in Production:
# - Setting up Proxmox for production use
# - Compliance requirements for no-subscription environments
# - Cost-sensitive deployments
#
# Simpler Alternative for Daily Services:
# - Use enterprise repo during evaluation (30 days)
# - Manual package updates via GUI
#
# This is for learning. Production homelabs should prioritize simplicity.
# Use these techniques to build skills, not because you need them for daily services.
# Complexity = More failure points. Keep your production services simple.

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
ceph_enterprise_list=/etc/apt/sources.list.d/ceph.list
backup_dir=/etc/apt/sources.list.d/backup

backup_file() {
  local src=$1
  if [ ! -f "$src" ]; then
    return
  fi
  mkdir -p "$backup_dir"
  local base
  base=$(basename "$src")
  cp "$src" "$backup_dir/$base.bak.$(date +%Y%m%d%H%M%S)"
}

ensure_proxmox_keyring() {
  local keyring=/etc/apt/trusted.gpg.d/proxmox-release.gpg
  if [ -f "$keyring" ]; then
    return
  fi
  log_info "Installing Proxmox repository key"
  # Using direct download avoids depending on a repo before the key is present
  if ! wget -qO "$keyring" "https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg"; then
    log_error "Failed to download Proxmox keyring"
    exit 1
  fi
}

sanitize_enterprise_repos() {
  # Comment out any enterprise lines that may live in other list files
  # and disable any .sources definitions.
  local files=()
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find /etc/apt -maxdepth 2 -type f \( -name "*.list" -o -name "*.sources" \) -print0)

  for file in "${files[@]}"; do
     if [[ "$file" == *pve-enterprise.sources || "$file" == *ceph*.sources ]] || \
       grep -Eq "enterprise\.proxmox\.com|ceph-squid" "$file"; then
      backup_file "$file"
      if [[ "$file" == *.list ]]; then
        sed -i -E "s@^[[:space:]]*deb(.*enterprise\.proxmox\.com.*)@#deb\1@" "$file"
        sed -i -E "s@^[[:space:]]*deb(.*ceph-squid.*)@#deb\1@" "$file"
      else
        # For .sources files, back them up and rename so apt ignores them entirely.
        local disabled="${file}.disabled"
        if [ -f "$disabled" ]; then
          log_info "Enterprise sources already disabled at $disabled"
        else
          mv "$file" "$disabled"
          log_info "Moved $file -> $disabled"
        fi
        continue
      fi
      log_info "Disabled enterprise entries in $file"
    fi
  done
}

log_info "Setting up Proxmox community repository for $codename"
if [ -f "$community_list" ]; then
  backup_file "$community_list"
fi
echo "deb http://download.proxmox.com/debian/pve $codename pve-no-subscription" > "$community_list"

if [ -f "$enterprise_list" ]; then
  backup_file "$enterprise_list"
  sed -i 's/^deb/#deb/' "$enterprise_list"
else
  log_info "No pve-enterprise list found; nothing to disable"
fi

if [ -f "$ceph_enterprise_list" ]; then
  backup_file "$ceph_enterprise_list"
  sed -i 's/^deb/#deb/' "$ceph_enterprise_list"
else
  log_info "No Ceph enterprise list found; nothing to disable"
fi

sanitize_enterprise_repos
ensure_proxmox_keyring

log_info "Updating package lists"
apt update
log_info "You can now run: apt upgrade -y"
