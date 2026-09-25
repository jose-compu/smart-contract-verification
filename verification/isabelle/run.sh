#!/usr/bin/env bash
# Kernel-check the Isabelle/HOL model. A green build is a proof of the theory, not of the EVM.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
isabelle="${ISABELLE:-isabelle}"
echo "isabelle $("$isabelle" version)"
"$isabelle" build -v -d "$root/verification/isabelle" SimpleBank
echo "isabelle: SimpleBank session checked"
