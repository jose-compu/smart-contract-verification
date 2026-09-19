# Certora CVL spec of SimpleBank

Rules, invariants, and a credit-sum ghost checked against the *compiled bytecode* of [`src/SimpleBank.sol`](../../src/SimpleBank.sol).

Class: automated deductive / SMT. Language: [Certora CVL](https://docs.certora.com/). The Prover symbolically executes `solc` output. This is not a Lean model and not a hand-written EVM interpreter.

## What is checked

| Solidity | CVL |
| --- | --- |
| `balances[a]` | `balances(a)` |
| `address(this).balance` | `nativeBalances[currentContract]` |
| `deposit()` | `deposit(e)` |
| `withdraw(amount)` | `withdraw(e, amount)` / `@withrevert` |
| failed `transfer` | `msg.sender == rejector` (`receive` reverts) |

`sumCredits` is a ghost updated on every `balances` store. Solidity `uint256` overflow reverts are in scope (0.8 checked arithmetic).

## Properties

| Id | Claim | Rule / invariant |
| --- | --- | --- |
| P1 | Deposit of `v` increases the caller’s credit and vault ETH by `v` | `P1_deposit_credits_caller_and_reserves` |
| P2 | Withdraw reverts when credit is short; success debits the caller | `P2_withdraw_reverts_when_credit_short`, `P2_withdraw_success_debits_caller` |
| P3 | A caller cannot decrease another address’s credit | `P3_deposit_preserves_other`, `P3_withdraw_preserves_other` |
| P4 | Credits never exceed vault ETH on deposit; a reverting withdraw leaves the ghost unchanged | `P4_solvency`, `P4_deposit_preserves_equality`, `P4_withdraw_revert_preserves_credit_sum`, `P4_credit_le_sum` |
| P5 | A reverting withdraw leaves the caller’s credit unchanged | `P5_withdraw_revert_preserves_credit` |

[`harness/Rejector.sol`](harness/Rejector.sol) is in the scene for a rejecting `receive`. The Prover does not execute that `receive` on `transfer`, so P5 is the revert-atomicity claim, not “Rejector implies revert”. Self-calls are excluded from P1/P4: a self-`deposit` would credit without moving ETH.

## Run

Requires [certora-cli](https://docs.certora.com/en/latest/docs/user-guide/install.html) and `solc` 0.8.24 on `PATH`. Full proving needs `CERTORAKEY`.

```shell
python3 -m venv .venv
source .venv/bin/activate
pip install certora-cli solc-select
solc-select install 0.8.24
solc-select use 0.8.24

# syntax + compilation only (no API key)
certoraRun verification/certora/SimpleBank.conf --compilation_steps_only

# cloud Prover (all rules)
export CERTORAKEY=...
certoraRun verification/certora/SimpleBank.conf
```

Run from the repository root.

## Trust

- The Prover reads bytecode, not a separate vault model.
- P4 equality is proved for `deposit` from an EOA. `withdraw` uses `transfer` (an unresolved CALL); the Prover may havoc ETH on that path, so withdraw rules check credit accounting, not a native-balance delta.
- Extra ETH at construction (or `selfdestruct` in older EVM rules) is outside exact equality.
- A green `compilation_steps_only` run is not a proof; a green Prover job is.
