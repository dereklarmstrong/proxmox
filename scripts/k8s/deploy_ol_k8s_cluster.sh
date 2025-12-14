#!/usr/bin/env bash
# Deploy a Kubernetes cluster on Oracle Linux nodes using CRI-O (best-practice kubeadm)

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
CONFIG_FILE=${CONFIG_FILE:-"$REPO_ROOT/config.k8s.sh"}
AUTO_APPROVE=0
DRY_RUN=${DRY_RUN:-0}

usage() {
  cat <<EOF
Usage: $(basename "$0") [--config <path>] [--yes] [--dry-run]
  --config <path>   Path to config file (default: $CONFIG_FILE)
  --yes             Skip confirmation prompt
  --dry-run         Print planned actions, do not execute remote commands
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --yes) AUTO_APPROVE=1; shift 1 ;;
    --dry-run) DRY_RUN=1; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

# Load config
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
else
  echo "Config file not found: $CONFIG_FILE" >&2
  echo "Copy config.k8s.example.sh to config.k8s.sh and adjust, or export CONFIG_FILE." >&2
  exit 1
fi

K8S_SSH_USER=${K8S_SSH_USER:-"opc"}
K8S_SSH_KEY=${K8S_SSH_KEY:-"~/.ssh/id_rsa"}
K8S_VERSION=${K8S_VERSION:-"1.30.2"}
K8S_POD_CIDR=${K8S_POD_CIDR:-"10.244.0.0/16"}
K8S_SERVICE_CIDR=${K8S_SERVICE_CIDR:-"10.96.0.0/12"}
K8S_CLUSTER_NAME=${K8S_CLUSTER_NAME:-"lab-cluster"}
K8S_API_ADVERTISE_ADDRESS=${K8S_API_ADVERTISE_ADDRESS:-""}
K8S_CNI_URL=${K8S_CNI_URL:-"https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml"}

if [ -z "${K8S_MASTERS:-}" ]; then
  echo "K8S_MASTERS is empty; define at least one master in $CONFIG_FILE" >&2
  exit 1
fi

readarray -t MASTERS <<< "${K8S_MASTERS[@]}"
readarray -t WORKERS <<< "${K8S_WORKERS[@]:-}"

SSH_OPTS=(-i "$K8S_SSH_KEY" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)

if [ ! -f "$K8S_SSH_KEY" ]; then
  echo "SSH key not found at $K8S_SSH_KEY" >&2
  exit 1
fi

confirm() {
  read -r -p "$1 [y/N]: " ans
  [[ $ans =~ ^[Yy]$ ]]
}

run_ssh() {
  local host="$1"; shift
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: ssh $K8S_SSH_USER@$host $*" >&2
    return 0
  fi
  ssh "${SSH_OPTS[@]}" "$K8S_SSH_USER@$host" "$@"
}

scp_to() {
  local host="$1"; shift
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY-RUN: scp $* -> $host" >&2
    return 0
  fi
  scp "${SSH_OPTS[@]}" "$@" "$K8S_SSH_USER@$host:"
}

prep_node() {
  local host="$1" hostname="$2"
  run_ssh "$host" "sudo hostnamectl set-hostname $hostname"
  run_ssh "$host" "sudo swapoff -a && sudo sed -i '/ swap / s/^/#/' /etc/fstab"
  run_ssh "$host" "sudo modprobe overlay && sudo modprobe br_netfilter"
  run_ssh "$host" "echo -e 'net.bridge.bridge-nf-call-iptables = 1\nnet.bridge.bridge-nf-call-ip6tables = 1\nnet.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-k8s.conf >/dev/null && sudo sysctl --system"
  run_ssh "$host" "sudo dnf install -y oraclelinux-developer-release-el8 oracle-epel-release-el8"
  run_ssh "$host" "sudo dnf install -y cri-o" 
  run_ssh "$host" "sudo systemctl enable --now crio"
  run_ssh "$host" "sudo dnf install -y kubeadm-$K8S_VERSION kubelet-$K8S_VERSION kubectl-$K8S_VERSION --disableexcludes=kubernetes"
  run_ssh "$host" "sudo systemctl enable --now kubelet"
}

init_control_plane() {
  local host="$1" hostname="$2"
  local advertise="${K8S_API_ADVERTISE_ADDRESS:-$host}"
  run_ssh "$host" "sudo kubeadm init --kubernetes-version $K8S_VERSION --pod-network-cidr $K8S_POD_CIDR --service-cidr $K8S_SERVICE_CIDR --control-plane-endpoint $advertise:6443 --upload-certs"
  run_ssh "$host" "mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown $(id -u):$(id -g) ~/.kube/config"
  # Save join commands
  run_ssh "$host" "sudo kubeadm token create --print-join-command" > /tmp/kubeadm-join-worker.sh
  local cert_key
  cert_key=$(run_ssh "$host" "sudo kubeadm init phase upload-certs --upload-certs | tail -1" | tail -1)
  run_ssh "$host" "sudo kubeadm token create --print-join-command --certificate-key $cert_key" > /tmp/kubeadm-join-controlplane.sh
  # Apply CNI
  run_ssh "$host" "kubectl apply -f $K8S_CNI_URL"
}

join_node() {
  local host="$1" role="$2"
  local cmd_file="/tmp/kubeadm-join-${role}.sh"
  if [ ! -f "$cmd_file" ]; then
    echo "Join command file missing: $cmd_file" >&2
    exit 1
  fi
  local join_cmd
  join_cmd=$(cat "$cmd_file")
  run_ssh "$host" "sudo $join_cmd"
}

main() {
  echo "Masters: ${MASTERS[*]}" >&2
  echo "Workers: ${WORKERS[*]}" >&2
  if [ "$AUTO_APPROVE" -ne 1 ]; then
    confirm "Proceed to configure nodes and deploy Kubernetes?" || { echo "Aborted."; exit 1; }
  fi

  for entry in "${MASTERS[@]}"; do
    set -- $entry
    prep_node "$1" "$2"
  done
  for entry in "${WORKERS[@]}"; do
    set -- $entry
    prep_node "$1" "$2"
  done

  # init control plane on first master
  set -- ${MASTERS[0]}
  init_control_plane "$1" "$2"

  # join additional control planes (if any)
  if [ "${#MASTERS[@]}" -gt 1 ]; then
    for entry in "${MASTERS[@]:1}"; do
      set -- $entry
      join_node "$1" "controlplane"
    done
  fi

  # join workers
  for entry in "${WORKERS[@]}"; do
    set -- $entry
    join_node "$1" "worker"
  done

  echo "Cluster deployment complete. Kubeconfig resides on first master (~/.kube/config)." >&2
}

main "$@"
