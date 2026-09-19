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
| P2 | Withdraw reverts when credit is short; an EOA with enough credit is paid | `P2_withdraw_reverts_when_credit_short`, `P2_withdraw_success_debits_and_pays`, `P2_eoa_withdraw_iff_credit` |
| P3 | A caller cannot decrease another address’s credit | `P3_deposit_preserves_other`, `P3_withdraw_preserves_other` |
| P4 | If ETH only enters through `deposit`, `sum(credits) == address(this).balance` | `P4_solvency`, `P4_credit_le_sum` |
| P5 | Rejecting receiver: withdraw reverts and state is unchanged | `P5_rejecting_receiver_reverts` |

P5 uses [`harness/Rejector.sol`](harness/Rejector.sol). A receiver that exceeds the `transfer` stipend is the same observable (the CALL fails). Self-calls (`msg.sender == currentContract`) are excluded from P1/P2/P4: they are not a reachable entry from an EOA, and a self-`deposit` would credit without moving ETH.

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
- P4 holds for the public ABI when the caller is not the vault itself. Extra ETH (for example `selfdestruct` in older EVM rules) is outside that claim.
- P2’s iff form is for EOAs (`msg.sender == tx.origin`). A rejecting contract is P5.
- A green `compilation_steps_only` run is not a proof; a green Prover job is.
