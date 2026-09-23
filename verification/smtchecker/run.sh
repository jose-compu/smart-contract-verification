#!/bin/sh
# CHC run of verification/smtchecker/SimpleBank.sol. solc 0.8.24, z3 on PATH.
# An unproved assertion, a counterexample, or a solver error fails the process.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
DIR="$ROOT/verification/smtchecker"

if [ -z "${SOLC:-}" ]; then
  for candidate in \
    "$HOME/Library/Application Support/svm/0.8.24/solc-0.8.24" \
    "$HOME/.svm/0.8.24/solc-0.8.24"
  do
    if [ -x "$candidate" ]; then
      SOLC=$candidate
      break
    fi
  done
fi

if [ -z "${SOLC:-}" ] || [ ! -x "$SOLC" ]; then
  echo "solc 0.8.24 not found. Set SOLC to the binary." >&2
  exit 1
fi

if ! command -v z3 >/dev/null 2>&1; then
  echo "z3 is not on PATH. SMTChecker needs the z3 binary." >&2
  exit 1
fi

echo "solc=$SOLC"
"$SOLC" --version
echo "z3=$(command -v z3)"
z3 --version

for line in \
  "balances[msg.sender] += value;" \
  "_credit(msg.value);" \
  "require(balances[msg.sender] >= amount);" \
  "balances[msg.sender] -= amount;" \
  "payable(msg.sender).transfer(amount);"
do
  if ! grep -qF "$line" "$DIR/SimpleBank.sol"; then
    echo "harness is missing: $line" >&2
    exit 1
  fi
done

for line in \
  "balances[msg.sender] += msg.value;" \
  "require(balances[msg.sender] >= amount);" \
  "balances[msg.sender] -= amount;" \
  "payable(msg.sender).transfer(amount);"
do
  if ! grep -qF "$line" "$ROOT/src/SimpleBank.sol"; then
    echo "src/SimpleBank.sol no longer contains: $line" >&2
    exit 1
  fi
done

out=$(mktemp)
trap 'rm -f "$out"' EXIT

set +e
(
  cd "$DIR"
  "$SOLC" --no-color \
    --model-checker-engine chc \
    --model-checker-solvers z3 \
    --model-checker-targets assert \
    --model-checker-timeout 20000 \
    --model-checker-show-proved-safe \
    --model-checker-show-unproved \
    --model-checker-contracts SimpleBank.sol:SimpleBank \
    SimpleBank.sol >"$out" 2>&1
)
status=$?
set -e

cat "$out"

if [ "$status" -ne 0 ]; then
  echo "solc exited $status" >&2
  exit "$status"
fi

python3 - "$out" "$DIR/SimpleBank.sol" <<'PY'
import sys

log = open(sys.argv[1], encoding="utf-8").read()
source = open(sys.argv[2], encoding="utf-8").read()
safe = log.count("Assertion violation check is safe!")
unproved = log.count("might happen")
violations = log.count("Assertion violation happens")
counterexamples = log.count("Counterexample:")
asserts = source.count("assert(")
print(
    f"smtchecker safe={safe} asserts={asserts} unproved={unproved} "
    f"violations={violations} counterexamples={counterexamples}"
)
if "Error:" in log or unproved or violations or counterexamples or safe != asserts or asserts == 0:
    sys.exit(1)
PY
