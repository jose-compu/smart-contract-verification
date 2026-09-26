#!/usr/bin/env bash
# Equivalence of src/SimpleBank.sol and verification/act/SimpleBank.act, via Act's hevm backend.
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
rev="${ACT_REV:-de0f98e78104148c1365171dab91f42987c2cedd}"
spec="$root/verification/act/SimpleBank.act"
sol="$root/src/SimpleBank.sol"

run_equiv() {
  local bin="$1"
  echo "using $bin"
  "$bin" equiv \
    --spec "$spec" \
    --sol "$sol" \
    --solver cvc5 \
    --smttimeout 60000 \
    --numsolvers 2
  echo "act: SimpleBank equivalent to the spec"
}

nix_build_and_prove() {
  local out
  out=$(mktemp -d)
  nix build --accept-flake-config --out-link "$out/act" "github:ethereum/act/${rev}#act"
  run_equiv "$out/act/bin/act"
}

if [[ -n "${ACT_BIN:-}" ]]; then
  run_equiv "$ACT_BIN"
elif command -v nix >/dev/null 2>&1; then
  nix_build_and_prove
else
  image="${ACT_NIX_IMAGE:-nixos/nix:2.30.2}"
  docker run --rm --platform linux/amd64 \
    -v "$root:/work" \
    -w /work \
    -e ACT_REV="$rev" \
    "$image" \
    bash -lc '
      set -euo pipefail
      mkdir -p /etc/nix
      cat >> /etc/nix/nix.conf <<EOF
experimental-features = nix-command flakes
accept-flake-config = true
sandbox = false
sandbox-fallback = false
filter-syscalls = false
substituters = https://cache.nixos.org https://dapp.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= dapp.cachix.org-1:9GJt9Ja8IQwR7YW/aF0QvCa6OmjGmsKoZIist0dG+Rs=
EOF
      out=$(mktemp -d)
      nix build --accept-flake-config --option sandbox false --out-link "$out/act" "github:ethereum/act/${ACT_REV}#act"
      "$out/act/bin/act" equiv \
        --spec /work/verification/act/SimpleBank.act \
        --sol /work/src/SimpleBank.sol \
        --solver cvc5 \
        --smttimeout 60000 \
        --numsolvers 2
      echo "act: SimpleBank equivalent to the spec"
    '
fi
