#!/usr/bin/env bash
set -euo pipefail
# Set up PATH with stubs first
STUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stubs"
export PATH="$STUB_DIR:$PATH"
# Temp log for command recording
export CMD_LOG="${TMPDIR:-/tmp}/cmd.log"
rm -f "$CMD_LOG"
# Ensure tests think they are root
export EUID=0
