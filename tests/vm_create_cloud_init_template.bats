#!/usr/bin/env bats

load test_helper.bash

setup() {
  rm -f "$CMD_LOG"
}

@test "fails when VMID is non-numeric" {
  run bash scripts/vm/create_cloud_init_template.sh -i abc --os ol9 --sha256 dummy --no-verify
  [ "$status" -ne 0 ]
  [[ "$output" == *"VMID must be numeric"* ]]
}

@test "requires checksum when preset hash is not baked (ubuntu default)" {
  run bash scripts/vm/create_cloud_init_template.sh -i 9001
  [ "$status" -ne 0 ]
  [[ "$output" == *"Checksum is required"* ]]
}

@test "creates template with ol9 preset using checksum" {
  run bash scripts/vm/create_cloud_init_template.sh --os ol9 --sha256 415274f04015112eeb972ed8a4e6941cb71df0318c4acba5a760931b7d7c0c69 -i 9100 -n test-ol9
  [ "$status" -eq 0 ]
  [[ -f OL9U6_x86_64-kvm-b265.qcow2 ]]
  grep -q "qm create 9100" "$CMD_LOG"
  grep -q "qm importdisk 9100 OL9U6_x86_64-kvm-b265.qcow2" "$CMD_LOG"
}
