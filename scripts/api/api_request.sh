#!/usr/bin/env bash
# Minimal wrapper for Proxmox API requests using API token auth

set -o errexit
set -o pipefail
set -o nounset

usage() {
  cat <<EOF
Usage: $(basename "$0") -X <GET|POST|PUT|DELETE> -p <api_path> [-d data]
Env required:
  PVE_API_URL       e.g. https://pve.example.com:8006/api2/json
  PVE_TOKEN_ID      e.g. root@pve!mytoken
  PVE_TOKEN_SECRET  token value
EOF
}

method="GET"
path=""
data=""

while getopts ":X:p:d:h" opt; do
  case "$opt" in
    X) method="$OPTARG" ;;
    p) path="$OPTARG" ;;
    d) data="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

: "${PVE_API_URL:?PVE_API_URL required}"
: "${PVE_TOKEN_ID:?PVE_TOKEN_ID required}"
: "${PVE_TOKEN_SECRET:?PVE_TOKEN_SECRET required}"

[[ -n "$path" ]] || { echo "API path required" >&2; usage; exit 1; }

url="$PVE_API_URL$path"

curl -sS -k -X "$method" \
  -H "Authorization: PVEAPIToken=$PVE_TOKEN_ID=$PVE_TOKEN_SECRET" \
  ${data:+-d "$data"} \
  "$url"
