#!/usr/bin/env bash
# Check that the bytecode embedded in SimpleBankEVM.lean is what solc produces.
#
# `bankRuntimeHex` is a literal so the Lean project builds without solc in the loop.
# That literal can drift from src/SimpleBank.sol, so CI compares the two.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

forge build --silent

actual="0x$(jq -r '.deployedBytecode.object' out/SimpleBank.sol/SimpleBank.json | sed 's/^0x//')"
embedded="$(grep -o '"0x[0-9a-f]\{100,\}"' verification/evm-lean/SimpleBankEVM.lean | head -1 | tr -d '"')"

if [ "$actual" = "$embedded" ]; then
  echo "bankRuntimeHex matches solc output (${#actual} hex chars)"
  exit 0
fi

echo "MISMATCH between src/SimpleBank.sol and verification/evm-lean/SimpleBankEVM.lean"
echo "solc:     $actual"
echo "embedded: $embedded"
echo
echo "Update bankRuntimeHex in verification/evm-lean/SimpleBankEVM.lean to the solc value."
exit 1
