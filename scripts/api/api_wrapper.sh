#!/usr/bin/env bash
# Wrapper for Proxmox VE API calls

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <method> <path> [options]

Make API calls to the Proxmox VE API.

Required:
  <method>     HTTP method: GET, POST, PUT, DELETE
  <path>       API path (e.g. /nodes/pve/storage/status)

Options:
  --data <json>  JSON data for POST/PUT requests
  --output <f>   Output file (default: stdout)
  --token <id>   API token ID (e.g. root@pam!mytoken)
  --secret <s>   API token secret
  --host <h>     Proxmox host (default: $PROXMOX_HOST)
  --user <u>     Username (default: $PROXMOX_USER)
  --password <p> Password (default: $PROXMOX_PASSWORD)
  -h, --help     Show this help

Examples:
  $(basename "$0") GET /version
  $(basename "$0") GET /nodes/pve/storage/status
  $(basename "$0") POST /nodes/pve/qemu/100/status/stop --data '{"unmount":true}'
  $(basename "$0") DELETE /nodes/pve/lxc/200
EOF
}

method=""
api_path=""
data=""
output_file=""
token_id=""
token_secret=""
host=""
user=""
password=""

# Parse positional args
if [[ $# -ge 1 ]]; then
  method=$(echo "$1" | tr '[:lower:]' '[:upper:]')
fi
if [[ $# -ge 2 ]]; then
  api_path="$2"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --data)     data="$2"; shift 2 ;;
    --output)   output_file="$2"; shift 2 ;;
    --token)    token_id="$2"; shift 2 ;;
    --secret)   token_secret="$2"; shift 2 ;;
    --host)     host="$2"; shift 2 ;;
    --user)     user="$2"; shift 2 ;;
    --password) password="$2"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *)          shift ;;
  esac
done

# Validate method
[[ "$method" =~ ^(GET|POST|PUT|DELETE)$ ]] || die "Method must be GET, POST, PUT, or DELETE"

# Validate path
[[ "$api_path" =~ ^/ ]] || die "Path must start with /"

# Set defaults
host="${host:-$PROXMOX_HOST}"
user="${user:-$PROXMOX_USER}"
password="${password:-$PROXMOX_PASSWORD}"

log_info "API Call: $method $api_path"
[[ -n "$data" ]] && log_info "Data: $data"
echo ""

# Build curl command
curl_cmd=(curl -s -k)
curl_cmd+=(-H "Accept: application/json")

# Authentication
if [[ -n "$token_id" && -n "$token_secret" ]]; then
  curl_cmd+=(-H "Authorization: APIToken=${token_id}=${token_secret}")
elif [[ -n "$user" && -n "$password" ]]; then
  # Get ticket
  ticket_data=$(curl -s -k -X POST "https://${host}:8006/api2/json/access/ticket" \
    -d "username=${user}&password=${password}" 2>/dev/null)
  ticket=$(echo "$ticket_data" | grep -o '"ticket":"[^"]*"' | cut -d'"' -f4)
  csrf=$(echo "$ticket_data" | grep -o '"CSRFPreventionToken":"[^"]*"' | cut -d'"' -f4)
  if [[ -z "$ticket" ]]; then
    die "Failed to authenticate with Proxmox API"
  fi
  curl_cmd+=(-b "PVEAuthCookie=${ticket}")
  curl_cmd+=(-H "CSRFPreventionToken: ${csrf}")
fi

# Build URL
url="https://${host}:8006/api2/json${api_path}"

# Add data for POST/PUT
if [[ "$method" == "POST" || "$method" == "PUT" ]]; then
  curl_cmd+=(-X "$method" -H "Content-Type: application/json" -d "$data" "$url")
elif [[ "$method" == "DELETE" ]]; then
  curl_cmd+=(-X DELETE "$url")
else
  curl_cmd+=(-X GET "$url")
fi

# Execute
result=$("${curl_cmd[@]}" 2>/dev/null) || die "API call failed"

# Output
if [[ -n "$output_file" ]]; then
  echo "$result" > "$output_file"
  log_info "Output written to $output_file"
else
  echo "$result"
fi
