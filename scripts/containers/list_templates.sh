#!/usr/bin/env bash
# List available LXC templates from Proxmox repositories

set -o errexit
set -o pipefail
set -o nounset

if ! command -v pveam >/dev/null 2>&1; then
  echo "pveam not found; run on a Proxmox node" >&2
  exit 1
fi

pveam available
