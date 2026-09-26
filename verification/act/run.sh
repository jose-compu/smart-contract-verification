#!/usr/bin/env bash
# Equivalence of src/SimpleBank.sol and verification/act/SimpleBank.act, via Act's hevm backend.
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
rev="${ACT_REV:-de0f98e78104148c1365171dab91f42987c2cedd}"
# nixpkgs that still has cvc5. Act's own lock pins an older nixpkgs whose solc cannot compile 0.8.24.
nixpkgs_rev="${ACT_NIXPKGS_REV:-3549532663732bfd89993204d40543e9edaec4f2}"
solc_url="${ACT_SOLC_URL:-https://github.com/ethereum/solidity/releases/download/v0.8.24/solc-static-linux}"
spec="$root/verification/act/SimpleBank.act"
sol="$root/src/SimpleBank.sol"

if [[ -n "${ACT_INSIDE_DOCKER:-}" ]]; then
  mkdir -p /etc/nix
  cat >> /etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
accept-flake-config = true
sandbox = false
sandbox-fallback = false
filter-syscalls = false
substituters = https://cache.nixos.org https://dapp.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= dapp.cachix.org-1:9GJt9Ja8IQwR7YW/aF0QvCa6OmjGmsKoZIist0dG+Rs=
EOF
fi

fetch_solc() {
  local dest="$1/solc"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$dest" "$solc_url"
  else
    nix shell --accept-flake-config "github:NixOS/nixpkgs/${nixpkgs_rev}#curl" --command \
      curl -fsSL -o "$dest" "$solc_url"
  fi
  chmod +x "$dest"
  "$dest" --version
}

run_equiv() {
  local bin="$1"
  echo "using $bin"
  echo "solc $(command -v solc)"
  echo "cvc5 $(command -v cvc5)"
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
  nix build --accept-flake-config --out-link "$out/cvc5" "github:NixOS/nixpkgs/${nixpkgs_rev}#cvc5"
  fetch_solc "$out"
  PATH="$out:$out/cvc5/bin:$PATH" run_equiv "$out/act/bin/act"
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
    -e ACT_NIXPKGS_REV="$nixpkgs_rev" \
    -e ACT_INSIDE_DOCKER=1 \
    "$image" \
    bash -lc 'exec /work/verification/act/run.sh'
fi
