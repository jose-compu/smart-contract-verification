# Medusa campaign for SimpleBank

Assertion and property fuzzing of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) with **Medusa 1.5.1**.

Class: property-based testing. Tool: [crytic/medusa](https://github.com/crytic/medusa). A finished campaign is evidence, not a proof. The asserts match the Echidna harness; the fuzzer and the corpus do not.

## What is exercised

`SimpleBankMedusa` deploys the bank. The harness receives ETH. `Rejector.receive` reverts.

| Id | Check |
| --- | --- |
| P1 | Deposit increases the harness credit and the bank balance by `msg.value` |
| P2 | A withdraw above credit reverts. Otherwise credit, reserves, and the harness balance move by `amount` |
| P3 | The other account's credit is unchanged |
| P4 | `property_solvency`: `totalCredits == address(bank).balance` |
| P5 | `Rejector.pull` reverts and leaves that credit unchanged |

`failOnAssertion` is on. Compiler-inserted arithmetic panics are not failures, so a Solidity 0.8 overflow revert does not end the campaign.

## Run

Medusa 1.5.1, `crytic-compile`, and `solc` 0.8.24 on `PATH`. The campaign is 10,000 transactions, sequence length 40, 180 second timeout. `run.sh` uses one worker and turns coverage on: Medusa 1.5.1 crashes in `CoverageTracer` if coverage is disabled. The corpus stays in a temporary directory.

```shell
verification/medusa/run.sh
```

## Trust

- The search stops at `testLimit` or `timeout`.
- Senders are the three addresses in `medusa.json`.
- `totalCredits` lives in the harness, not in `src/SimpleBank.sol`.
