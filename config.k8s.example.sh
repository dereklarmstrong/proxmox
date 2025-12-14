# Kubernetes cluster deployment config for Oracle Linux nodes
# Copy to config.k8s.sh and adjust values.

# SSH
K8S_SSH_USER=${K8S_SSH_USER:-"opc"}
K8S_SSH_KEY=${K8S_SSH_KEY:-"~/.ssh/id_rsa"}

# Cluster
K8S_VERSION=${K8S_VERSION:-"1.30.2"}
K8S_POD_CIDR=${K8S_POD_CIDR:-"10.244.0.0/16"}
K8S_SERVICE_CIDR=${K8S_SERVICE_CIDR:-"10.96.0.0/12"}
K8S_CLUSTER_NAME=${K8S_CLUSTER_NAME:-"lab-cluster"}
K8S_API_ADVERTISE_ADDRESS=${K8S_API_ADVERTISE_ADDRESS:-"192.168.1.41"}

# Nodes (ordered)
K8S_MASTERS=(
  "192.168.1.41 master1"
)
K8S_WORKERS=(
  "192.168.1.42 worker1"
  "192.168.1.43 worker2"
)

# Optional: custom CNI manifest URL (defaults to Calico manifest)
K8S_CNI_URL=${K8S_CNI_URL:-"https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml"}
