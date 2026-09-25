#!/usr/bin/env bash
# Fuzz SimpleBankMedusa. A green run is not a proof.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
echo "medusa $(medusa --version)"
cfg=$(mktemp)
python3 - "$cfg" <<'PY'
import json, os, sys, tempfile
cfg = json.load(open("verification/medusa/medusa.json"))
root = os.getcwd()
target = os.path.abspath("verification/medusa/SimpleBankMedusa.sol")
cfg["compilation"]["platformConfig"]["target"] = target
cfg["compilation"]["platformConfig"]["args"] = [
    "--compile-force-framework", "solc",
    "--solc-args", "--allow-paths " + root,
]
# Coverage off crashes Medusa 1.5.1 in CoverageTracer. Keep the report out of the tree.
cfg["fuzzing"]["coverageEnabled"] = True
cfg["fuzzing"]["coverageFormats"] = ["lcov"]
cfg["fuzzing"]["corpusDirectory"] = tempfile.mkdtemp(prefix="medusa-corpus-")
cfg["fuzzing"]["workers"] = 1
json.dump(cfg, open(sys.argv[1], "w"))
print("target", target)
print("corpus", cfg["fuzzing"]["corpusDirectory"])
PY
medusa fuzz --config "$cfg"
echo "medusa: campaign finished"
