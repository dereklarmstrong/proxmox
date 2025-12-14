#!/usr/bin/env bash
# Create a Proxmox API token for automation

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
Usage: $(basename "$0") -u <user> -t <token_name> [options]
  -u <user>     Username (without realm) (required)
  -t <token>    Token name (required)
  -r <realm>    Realm (default: pve)
  -R <role>     Role to grant (default: PVEAdmin)
  -h            Help
EOF
}

user=""
token_name=""
realm="pve"
role="PVEAdmin"

while getopts ":u:t:r:R:h" opt; do
  case "$opt" in
    u) user="$OPTARG" ;;
    t) token_name="$OPTARG" ;;
    r) realm="$OPTARG" ;;
    R) role="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[[ -n "$user" ]] || { log_error "User required"; usage; exit 1; }
[[ -n "$token_name" ]] || { log_error "Token name required"; usage; exit 1; }

full_user="$user@$realm"

if ! pveum user list | awk '{print $1}' | grep -qx "$full_user"; then
  log_info "Creating user $full_user"
  pveum user add "$full_user"
fi

log_info "Ensuring user $full_user has role $role on /"
pveum acl modify / -user "$full_user" -role "$role" >/dev/null 2>&1 || pveum acl add / -user "$full_user" -role "$role"

log_info "Creating token $token_name for $full_user"
secret_output=$(pveum user token add "$full_user" "$token_name")

echo "Token created. Save these values now:"
echo "TOKEN_ID=${full_user}!${token_name}"
echo "$secret_output"
