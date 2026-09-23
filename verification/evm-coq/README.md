# coq-evm model of a SimpleBank deposit fragment

[`src/SimpleBank.sol`](../../src/SimpleBank.sol) is not executed here. This folder proves one stack program inside an existing academic EVM interpreter.

Class: interactive theorem proving, on a third-party semantics. The plain vault, with P1–P5, is [`verification/coq/`](../coq/).

## Library

[ivan71kmayshan27/coq-evm](https://github.com/ivan71kmayshan27/coq-evm) at `ea40f62`, the concrete interpreter FORVES cites as its departing point. Words are [bbv](https://github.com/mit-plv/bbv) `word 256` (MIT), pinned in `pins.txt`. coq-evm itself is **LGPL-3.0** and is cloned by `deps.sh`, not vendored.

`CALL`, `SHA3`, `CREATE`, `DELEGATECALL`, and `SELFDESTRUCT` are `NotImplemented`. `SLOAD` pushes the loaded word onto the stack from *before* the pop. Two lemmas in `evmModel.v` are `Admitted`. The theorems below do not use those lemmas; `make` checks `Print Assumptions`. `deps.sh` drops the unused `Require Import Coq.Arith.Lt`, which Coq 8.20 no longer ships. Nothing else in the interpreter is edited.

Hirai's Lem export ([pirapira/eth-isabelle](https://github.com/pirapira/eth-isabelle)) and FORVES ([costa-group/forves](https://github.com/costa-group/forves), GPL-3.0, jump-free blocks, Coq 8.15) are the other published Coq EVM developments. A further embedding would be its own subfolder.

## What is proved

Initial stack: `old :: value :: slot :: tail`.

| Step | Interpreter | Result |
| --- | --- | --- |
| `ADD` | `addActionPure` | top becomes `wplus old value` (mod 2^256) |
| `SWAP1` | `swapActionPure (natToWord 4 0)` | `slot` moves above the sum |
| `SSTORE` | `sstoreActionPure` | storage at `slot` becomes that sum |

| Claim | Theorem |
| --- | --- |
| `ADD` pushes `wplus` | `ADD_pushes_wplus` |
| `SWAP1` exchanges the top two words | `SWAP1_exchanges` |
| `SSTORE` of a missing key writes it (gas 20000 in this model) | `SSTORE_fresh` |
| `SSTORE` over a nonzero word overwrites it (gas 5000) | `SSTORE_nonzero` |
| The three-opcode fragment, missing key | `deposit_credit_word_fresh` |
| The three-opcode fragment, nonzero old word | `deposit_credit_word_nonzero` |

Survey P1's storage update is this fragment, for one slot, with the old credit already on the stack. P2–P5 are out of scope: they need `CALL` (`transfer`) or `SHA3` (the Solidity storage slot of `balances[a]`).

## Run

Coq 8.20, `git`, and a network path to GitHub for the first fetch. CI uses `coqorg/coq:8.20`.

```shell
cd verification/evm-coq
make
```

The first run compiles bbv, then `evmModel.v` (it contains `Compute` on 256-bit words), then `SimpleBankEVM.v`.

## Trust

- The interpreter is a 2020 draft. It is not conformance-tested in this repo, and its author marks the development as work in progress.
- `wplus` is mod 2^256. The plain model in `verification/coq` uses unbounded `nat` instead.
- A missing storage key is `None`, not the zero word. `SLOAD` of `None` fails. `SSTORE` of `None` inserts the key.
- The fragment does not include the Solidity dispatcher, ABI, or keccak slot.
