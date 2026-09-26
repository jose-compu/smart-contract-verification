# Act spec of SimpleBank

Equivalence between the `deposit` and `balances` behaviours of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) and [`SimpleBank.act`](SimpleBank.act), checked by **Act** at `de0f98e` (the `ethereum/act` commit pinned in `run.sh`) through its hevm backend.

Class: specification overlay. The check is bytecode equivalence, not a kernel-checked proof. The solver is cvc5.

## What is in scope

| Id | Transition | Claim |
| --- | --- | --- |
| P1 | `deposit` | When the additions fit in `uint256`, the caller's credit and the contract's ETH balance both increase by `CALLVALUE` |
| P3 | `deposit` | Only `balances[CALLER]` is written |
| P4 | `deposit` | `BALANCE` increases by the same `CALLVALUE` as that credit |
| — | `balances` | The public getter returns `balances[account]` and writes nothing |

`withdraw` is not in the spec. A first run that included it was not equivalent: hevm reported `call target has unknown code` on the `CALL` inside `transfer` (program counter 386) and produced no success end state, while the spec still accepted withdrawals. P2 and P5 are that call. They are not claimed here.

## Run

Nix, or Docker image `nixos/nix:2.30.2`. The script builds Act from the pinned commit, using the public `dapp` Cachix cache, then runs `act equiv`. On an emulated amd64 container the script turns Nix's seccomp filter off; that filter does not load under QEMU.

```shell
verification/act/run.sh
```

The script fails unless Act reports the bytecode equivalent to the spec.

## Trust

The EVM model is hevm's, and the storage layout is solc's. The Act Nix build does not put `solc` or `cvc5` on `PATH`, so the script uses the Solidity 0.8.24 static Linux binary and cvc5 from nixpkgs `354953266373`. A passing check is equivalence of this spec and that bytecode, inside the fragment hevm explores. It is not a proof that every `uint256` trace of the chain preserves solvency, and it does not model a receiver that reverts inside the 2300-gas stipend unless the equivalence check rejects the spec for that reason.
