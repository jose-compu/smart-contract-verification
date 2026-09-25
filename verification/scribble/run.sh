#!/usr/bin/env bash
# Instrument the annotated SimpleBank and compile the result. This does not prove the properties.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
echo "scribble $(scribble --version)"
work=$(mktemp -d)
cp verification/scribble/SimpleBank.sol "$work/SimpleBank.sol"
printf '{}\n' > "$work/package.json"
(
  cd "$work"
  scribble SimpleBank.sol --output-mode files
)
echo "instrumented:"
find "$work" -type f -print
instr=$(find "$work" -type f -name '*.instrumented' -o -type f -name '*.instrumented.sol' | head -1)
test -n "$instr"
solc --bin --optimize "$instr" --base-path "$work" >/dev/null
echo "scribble: instrumentation compiled"
