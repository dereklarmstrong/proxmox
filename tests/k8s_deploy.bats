#!/usr/bin/env bats

load test_helper.bash

setup() {
  rm -f "$CMD_LOG"
}

@test "fails when config file missing" {
  run bash scripts/k8s/deploy_ol_k8s_cluster.sh --config /tmp/doesnotexist --dry-run --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *"Config file not found"* ]]
}

@test "dry-run prints actions without ssh" {
  cat > /tmp/config.k8s.test.sh <<'EOF'
K8S_SSH_USER=opc
K8S_SSH_KEY=/tmp/fakekey
K8S_MASTERS=("10.0.0.1 master1")
K8S_WORKERS=("10.0.0.2 worker1")
EOF
  touch /tmp/fakekey
  run bash scripts/k8s/deploy_ol_k8s_cluster.sh --config /tmp/config.k8s.test.sh --dry-run --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN: ssh"* ]]
}
