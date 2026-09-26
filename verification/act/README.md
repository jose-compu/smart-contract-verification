# Act spec of SimpleBank

Equivalence between [`src/SimpleBank.sol`](../../src/SimpleBank.sol) and [`SimpleBank.act`](SimpleBank.act), checked by **Act** at `de0f98e` (the `ethereum/act` commit pinned in `run.sh`) through its hevm backend.

Class: specification overlay. The check is bytecode equivalence, not a kernel-checked proof. The solver is cvc5.

## What is in scope

| Id | Transition | Claim |
| --- | --- | --- |
| P1 | `deposit` | When the additions fit in `uint256`, the caller's credit and the contract's ETH balance both increase by `CALLVALUE` |
| P2 | `withdraw` | Succeeds when the caller's credit and the contract's ETH balance are both at least `amount`; then both decrease by `amount` |
| P3 | `deposit`, `withdraw` | Only `balances[CALLER]` is written |
| P4 | `deposit`, `withdraw` | `BALANCE` moves with the credit of the caller, by the same amount |
| — | `balances` | The public getter returns `balances[account]` and writes nothing |

P5 (a reverting or gas-heavy receiver) is not a separate transition. `withdraw` in the source uses `transfer`. If that call can fail while the preconditions hold, equivalence fails and this README is wrong until the spec is narrowed.

## Run

Nix, or Docker image `nixos/nix:2.30.2`. The script builds Act from the pinned commit, using the public `dapp` Cachix cache, then runs `act equiv`. On an emulated amd64 container the script turns Nix's seccomp filter off; that filter does not load under QEMU.

```shell
verification/act/run.sh
```

The script fails unless Act reports the bytecode equivalent to the spec.

## Trust

The EVM model is hevm's, and the storage layout is solc's. The Act Nix build does not put `solc` or `cvc5` on `PATH`, so the script uses the Solidity 0.8.24 static Linux binary and cvc5 from nixpkgs `354953266373`. A passing check is equivalence of this spec and that bytecode, inside the fragment hevm explores. It is not a proof that every `uint256` trace of the chain preserves solvency, and it does not model a receiver that reverts inside the 2300-gas stipend unless the equivalence check rejects the spec for that reason.
