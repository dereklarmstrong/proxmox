#!/usr/bin/env bats

load test_helper.bash

setup() {
  rm -f "$CMD_LOG"
  mkdir -p "$HOME/.ssh"
}

@test "prints usage when no username and proceeds with default after confirmation" {
  run bash scripts/download_github_keys.sh <<'EOF'
y
EOF
  [ "$status" -eq 0 ]
  grep -q "Usage: download_github_keys.sh" "$output" || true
  grep -q "Added keys for dereklarmstrong" <<<"$output"
  [ -f "$HOME/.ssh/authorized_keys" ]
  grep -q "dummy-key" "$HOME/.ssh/authorized_keys"
}

@test "aborts on negative confirmation" {
  run bash scripts/download_github_keys.sh otheruser <<'EOF'
n
EOF
  [ "$status" -ne 0 ]
  [[ "$output" == *"Aborted."* ]]
}
