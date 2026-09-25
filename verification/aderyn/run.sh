#!/usr/bin/env bash
# Scan the Foundry project with Aderyn and lock the known High finding.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
out=$(mktemp)
echo "aderyn $(aderyn --version) on $root"
aderyn "$root" --output "$out"
python3 - "$out" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
print(text)
high = re.search(r"^\| High \| (\d+) \|", text, re.M)
low = re.search(r"^\| Low \| (\d+) \|", text, re.M)
if not high or not low:
    sys.exit("issue summary table not found")
print(f"parsed high={high.group(1)} low={low.group(1)}")
if high.group(1) != "1":
    sys.exit(f"expected exactly 1 high finding, got {high.group(1)}")
if "ETH transferred without address checks" not in text:
    sys.exit("expected the withdraw transfer finding")
print("aderyn: 1 high finding, the withdraw transfer")
PY
