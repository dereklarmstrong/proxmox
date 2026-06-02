#!/usr/bin/env bash
# Create a Proxmox API token

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") --user <user@realm> --token-name <name> [options]

Create a Proxmox API token with least-privilege scoping.

Required:
  --user <user@realm>   Proxmox user (e.g. root@pam, admin@pve)
  --token-name <name>   Token name/ID (e.g. automation, monitoring)

Optional:
  --privsep              Create a privilege-separated token (recommended)
  --path <path>          Restrict token to API path (e.g. /nodes, /storage)
  --output <file>        Save token to file instead of stdout
  -h, --help             Show this help

Examples:
  $(basename "$0") --user root@pam --token-name automation --privsep
  $(basename "$0") --user admin@pve --token-name monitoring --path /nodes
EOF
}

user=""
token_name=""
privsep=0
path=""
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)       user="$2"; shift 2 ;;
    --token-name) token_name="$2"; shift 2 ;;
    --privsep)    privsep=1; shift ;;
    --path)       path="$2"; shift 2 ;;
    --output)     output_file="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "Unknown option: $1" ;;
  esac
done

[[ -n "$user" ]] || die "--user is required"
[[ -n "$token_name" ]] || die "--token-name is required"

# Validate user format
[[ "$user" =~ .+@.+ ]] || die "User must be in format user@realm (e.g. root@pam)"

# Build token ID
token_id="${user}!${token_name}"

log_info "Creating API token"
log_info "  User:     $user"
log_info "  Token:    $token_id"
[[ $privsep -eq 1 ]] && log_info "  PrivSep:  yes"
[[ -n "$path" ]] && log_info "  Path:     $path"
echo ""

# Create token via pveum
pveum_args=(pveum)
pveum_args+=(user)
pveum_args+=("token")
pveum_args+=("add")
pveum_args+=("$user")
pveum_args+=("$token_name")

if [[ $privsep -eq 1 ]]; then
  pveum_args+=(--privsep 0)
fi

if [[ -n "$path" ]]; then
  pveum_args+=(--path "$path")
fi

token_output=$("${pveum_args[@]}" 2>&1) || {
  echo "$token_output"
  die "Failed to create token"
}

# Extract secret from output
secret=$(echo "$token_output" | grep -oP 'secret=\K\S+' || true)
if [[ -z "$secret" ]]; then
  die "Could not extract token secret from output"
fi

result="Token ID:    $token_id
Secret:        $secret
Privilege Sep: $([ $privsep -eq 1 ] && echo 'yes' || echo 'no')
Path:          ${path:-/ (all paths)}"

if [[ -n "$output_file" ]]; then
  cat > "$output_file" <<TOKENEOF
PROXMOX_API_TOKEN_ID="$token_id"
PROXMOX_API_TOKEN_SECRET="$secret"
TOKENEOF
  chmod 600 "$output_file"
  log_info "Token saved to $output_file"
else
  echo ""
  log_warn "=== Token Created (shown only once) ==="
  echo "$result"
  echo ""
  log_warn "Store the secret securely. It cannot be recovered."
fi

# Print example usage
echo ""
log_info "Example usage:"
echo "  curl -sk -H \"Authorization: APIToken=${token_id}=${secret}\" \\"
echo "    https://\$(hostname -s):8006/api2/json/version"
