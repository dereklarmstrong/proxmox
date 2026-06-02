#!/usr/bin/env bash
# Create an LXC container from a template

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/common.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") --ctid <id> --template <ostemplate> --hostname <name> \
       --ip <ip/cidr> --gateway <gw> [options]

Create an LXC container from a template with network configuration.

Required:
  --ctid <id>        Container ID (must be >= 100)
  --template <name>  Template name (e.g. local:vztmpl/debian-12-standard.tar.zst)
  --hostname <name>  Container hostname
  --ip <ip/cidr>     Static IP with CIDR (e.g. 10.0.1.50/24)
  --gateway <gw>     Gateway IP

Optional:
  --storage <store>  Storage for rootfs (default: $DEFAULT_STORAGE)
  --memory <mb>      Memory in MB (default: 512)
  --swap <mb>        Swap in MB (default: 512)
  --cores <n>        vCPU count (default: 1)
  --unprivileged     Create unprivileged container (default: privileged)
  --start            Start the container after creation
  --sshkey <path>    SSH public key path
  --dns <server>     DNS server (default: gateway IP)
  -h, --help         Show this help

Examples:
  $(basename "$0") --ctid 200 --template local:vztmpl/debian-12-standard.tar.zst \
    --hostname web01 --ip 10.0.1.50/24 --gateway 10.0.1.1 --start
EOF
}

ctid=""
template=""
hostname=""
ip_cidr=""
gateway=""
storage="$DEFAULT_STORAGE"
memory=512
swap=512
cores=1
unprivileged=0
start=0
ssh_key=""
dns=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ctid)       ctid="$2"; shift 2 ;;
    --template)   template="$2"; shift 2 ;;
    --hostname)   hostname="$2"; shift 2 ;;
    --ip)         ip_cidr="$2"; shift 2 ;;
    --gateway)    gateway="$2"; shift 2 ;;
    --storage)    storage="$2"; shift 2 ;;
    --memory)     memory="$2"; shift 2 ;;
    --swap)       swap="$2"; shift 2 ;;
    --cores)      cores="$2"; shift 2 ;;
    --unprivileged) unprivileged=1; shift ;;
    --start)      start=1; shift ;;
    --sshkey)     ssh_key="$2"; shift 2 ;;
    --dns)        dns="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "Unknown option: $1" ;;
  esac
done

# Validate required args
[[ -n "$ctid" ]] || die "--ctid is required"
[[ -n "$template" ]] || die "--template is required"
[[ -n "$hostname" ]] || die "--hostname is required"
[[ -n "$ip_cidr" ]] || die "--ip is required"
[[ -n "$gateway" ]] || die "--gateway is required"

validate_vmid "$ctid"
validate_ip "$ip_cidr"

# Validate numeric params
[[ "$memory" =~ ^[0-9]+$ ]] || die "Memory must be a positive integer"
[[ "$swap" =~ ^[0-9]+$ ]] || die "Swap must be a positive integer"
[[ "$cores" =~ ^[0-9]+$ ]] || die "Cores must be a positive integer"

# Check CT doesn't exist
if check_ct_exists "$ctid"; then
  die "CTID $ctid already exists"
fi

# DNS defaults to gateway
[[ -n "$dns" ]] || dns="$gateway"

# Build pct create command
log_info "Creating container $ctid ($hostname)"

pct create "$ctid" "$template" \
  --hostname "$hostname" \
  --storage "$storage" \
  --rootfs "${storage}:$(printf '%sG' "$((memory / 100 * 8))")" \
  --memory "$memory" \
  --swap "$swap" \
  --cores "$cores" \
  --net0 "name=eth0,bridge=${DEFAULT_BRIDGE},ip=${ip_cidr},gw=${gateway}" \
  --nameserver "$dns" \
  ${unprivileged:+--unprivileged 1}

# SSH key
if [[ -n "$ssh_key" ]]; then
  ensure_ssh_key "$ssh_key"
  pct setkey "$ctid" "$ssh_key" 2>/dev/null || log_warn "Could not set SSH key (template may not support it)"
fi

if [[ $start -eq 1 ]]; then
  log_info "Starting container $ctid"
  pct start "$ctid"
fi

echo ""
log_info "=== Container Ready ==="
log_info "Hostname:  $hostname"
log_info "CTID:      $ctid"
log_info "IP:        $ip_cidr"
log_info "Gateway:   $gateway"
log_info "DNS:       $dns"
log_info "Memory:    ${memory}MB / ${swap}MB swap"
log_info "Cores:     $cores"
[[ $unprivileged -eq 1 ]] && log_info "Mode:      unprivileged"
echo ""
if [[ $start -eq 1 ]]; then
  log_info "SSH: ssh root@$(echo "$ip_cidr" | cut -d/ -f1)"
else
  log_warn "Container not started. Run 'pct start $ctid' to start it."
fi
