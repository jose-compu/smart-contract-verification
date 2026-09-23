#!/bin/sh
# Clone the pinned academic libraries. They are not vendored: coq-evm is
# LGPL-3.0 and bbv is MIT.
set -eu
cd "$(dirname "$0")"
mkdir -p deps

clone_pin() {
  name="$1"
  url="$2"
  rev="$3"
  dest="deps/$name"
  if [ -d "$dest/.git" ]; then
    current=$(git -C "$dest" rev-parse HEAD)
    if [ "$current" = "$rev" ]; then
      return 0
    fi
  fi
  rm -rf "$dest"
  git init -q -b main "$dest"
  git -C "$dest" remote add origin "$url"
  git -C "$dest" fetch --depth 1 origin "$rev"
  git -C "$dest" checkout --detach FETCH_HEAD
}

clone_pin bbv https://github.com/mit-plv/bbv.git 5ddb730f10a23f022e850b411098b64d4e3525ed
clone_pin coq-evm https://github.com/ivan71kmayshan27/coq-evm.git ea40f62b5536c2a9229983b65c9ae85711d24a7e

# Coq 8.20 removed Coq.Arith.Lt. The import is unused in evmModel.v.
if grep -q 'Require Import Coq.Arith.Lt.' deps/coq-evm/evmModel.v; then
  grep -v 'Require Import Coq.Arith.Lt.' deps/coq-evm/evmModel.v > deps/coq-evm/evmModel.v.tmp
  mv deps/coq-evm/evmModel.v.tmp deps/coq-evm/evmModel.v
fi
