#!/usr/bin/env bash
# Symbolic proofs of SimpleBank on KEVM via Kontrol. A green run is a proof of these tests, in the KEVM model.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
image="${KONTROL_IMAGE:-runtimeverificationinc/kontrol:ubuntu-jammy-1.0.255}"
cd "$root"
docker run --rm --platform linux/amd64 \
  -v "$root:/work" \
  -w /work \
  --user root \
  -e PATH=/home/user/.local/bin:/home/user/.foundry/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  -e HOME=/home/user \
  "$image" \
  bash -lc '
    set -euo pipefail
    echo "kontrol $(kontrol version)"
    # LLVM kompile of KEVM is not required for `kontrol prove` and is killed on an 8 GB Docker VM.
    kontrol build --no-llvm-kompile
    tests=(
      SimpleBankKontrolTest.test_p1_deposit
      SimpleBankKontrolTest.test_p2_withdraw
      SimpleBankKontrolTest.test_p2_withdraw_short_reverts
      SimpleBankKontrolTest.test_p3_other_credit_untouched
      SimpleBankKontrolTest.test_p4_solvent_after_deposit
      SimpleBankKontrolTest.test_p5_rejector_reverts
    )
    for test in "${tests[@]}"; do
      echo "===== prove $test ====="
      kontrol prove --match-test "$test" --reinit
    done
    echo "kontrol: all listed tests proved"
  '
