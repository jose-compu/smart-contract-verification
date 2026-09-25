# Echidna campaign for SimpleBank

Assertion fuzzing of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) with **Echidna 2.3.3**.

Class: property-based testing. Tool: [crytic/echidna](https://github.com/crytic/echidna). A finished campaign with no broken `assert` is evidence, not a proof.

## What is exercised

`SimpleBankEchidna` deploys the bank. The harness is the only account that can receive ETH. `Rejector.receive` reverts, so `transfer` to it fails.

| Id | What the asserts check |
| --- | --- |
| P1 | `deposit` of `msg.value` increases the harness credit and the bank balance by that value |
| P2 | `withdraw` of more than the credit reverts and leaves balances unchanged. Otherwise credit and reserves drop by `amount`, and the harness balance rises by `amount` |
| P3 | The other account's credit is unchanged |
| P4 | `totalCredits == address(bank).balance` after every call. ETH enters only through the harness |
| P5 | `Rejector.pull` always reverts, and that credit is unchanged |

`totalCredits` is harness ghost state. It is not storage in `src/SimpleBank.sol`.

## Run

Echidna 2.3.3, `crytic-compile`, and `solc` 0.8.24 on `PATH`. The Linux binary shells out to `crytic-compile`. Config: `echidna.yaml` (10,000 sequences, length 40, assertion mode).

```shell
verification/echidna/run.sh
```

The script fails if any assertion fails.

## Trust

- The search is bounded by `testLimit` and `seqLen`.
- Callers are the fuzzer's senders, all talking to this harness. There is no arbitrary third contract.
- Overflow reverts from Solidity 0.8 abort the transaction; they are not treated as failed assertions.
