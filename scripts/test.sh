#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BATS="$ROOT_DIR/tests/vendor/bats-core/bin/bats"

if [ ! -x "$BATS" ]; then
  echo "Bats not found at $BATS" >&2
  exit 1
fi

cd "$ROOT_DIR"
"$BATS" tests "$@"
