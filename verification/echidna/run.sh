#!/usr/bin/env bash
# Fuzz SimpleBankEchidna in assertion mode. A green run is not a proof.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
echo "echidna $(echidna --version)"
corpus=$(mktemp -d)
echidna verification/echidna/SimpleBankEchidna.sol \
  --contract SimpleBankEchidna \
  --config verification/echidna/echidna.yaml \
  --format text \
  --corpus-dir "$corpus" \
  --crytic-args "--compile-force-framework solc --solc-args=--allow-paths=$root"
echo "echidna: assertion campaign finished"
