#!/usr/bin/env bash
# Check verification/fstar/SimpleBank.fst with F* and Z3.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
echo "F* $(fstar.exe --version | head -1)"
echo "Z3 $(z3 --version)"
cache=$(mktemp -d)
fstar.exe --cache_dir "$cache" --z3rlimit 30 --already_cached 'Prims FStar' verification/fstar/SimpleBank.fst
echo "fstar: verified"
