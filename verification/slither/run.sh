#!/usr/bin/env bash
# Scan src/SimpleBank.sol with Slither. Default detectors are expected to stay quiet.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
out=$(mktemp -d)/slither.json
echo "slither $(slither --version) on src/SimpleBank.sol"
slither src/SimpleBank.sol --json "$out"
python3 - "$out" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
if not data.get("success", False):
    sys.exit(f"slither reported failure: {data.get('error')}")
detectors = data.get("results", {}).get("detectors", [])
print(f"detectors fired: {len(detectors)}")
for item in detectors:
    print(f"  {item.get('impact')} {item.get('check')}: {item.get('description', '').splitlines()[0]}")
if detectors:
    sys.exit("expected no Slither detector results on src/SimpleBank.sol")
print("slither: 0 results")
PY
