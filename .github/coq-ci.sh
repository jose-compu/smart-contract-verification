#!/bin/sh
# Runs inside coqorg/coq:8.20. See .github/workflows/test.yml.
set -eu
export PATH="/home/coq/.opam/4.13.1+flambda/bin:${PATH}"
if ! command -v coqc >/dev/null 2>&1; then
  echo "coqc not on PATH=${PATH}" >&2
  ls -la /home/coq/.opam >&2 || true
  exit 1
fi
coqc --version
make -C verification/coq
make -C verification/evm-coq
