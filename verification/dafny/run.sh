#!/usr/bin/env bash
# Verify verification/dafny/SimpleBank.dfy with Dafny 4.11 (Boogie / Z3).
set -euo pipefail
cd "$(dirname "$0")"
exec dafny verify --verification-time-limit 30 SimpleBank.dfy
