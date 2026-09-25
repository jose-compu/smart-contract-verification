#!/usr/bin/env bash
# Discharge every Why3 goal. A green run is a proof of this model, not of the EVM.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
echo "why3 $(why3 --version)"
why3 config detect
why3 prove -P alt-ergo -a split_vc -t 20 verification/why3/simple_bank.mlw
echo "why3: all goals valid"
