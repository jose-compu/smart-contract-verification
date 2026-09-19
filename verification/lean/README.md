# Lean 4 model of SimpleBank

Interactive proofs of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) in **Lean 4**.

Class: interactive theorem proving. Language: [lean-lang.org](https://lean-lang.org/). This is an abstract vault (credits + reserves + an `accepting` flag), not an EVM interpreter and not EVMYulLean.

## What is modelled

| Solidity | Lean |
| --- | --- |
| `address` | `Address` (`Nat`) |
| `balances[a]` | `State.credit a` |
| `address(this).balance` | `State.reserves` |
| `deposit()` | `deposit s sender value` |
| `withdraw(amount)` | `withdraw s sender amount` (`Result.ok` / `Result.revert`) |
| failed `transfer` | `accepting sender = false` → `.revert` |

Wei is `Nat` (unbounded). Solidity `uint256` overflow is not modelled. There is no `receive`/`fallback`: reserves grow only through `deposit`.

## Properties

Aligned with the survey list in the root README. A `theorem` here is a kernel-checked proof (unbounded in `Nat` and in the list of accounts), not a bounded SAT check.

| Id | Claim | Theorem |
| --- | --- | --- |
| P1 | Deposit of `v` increases the caller’s credit and reserves by `v` | `P1_deposit_credits_caller_and_reserves` |
| P2 | Withdraw succeeds iff credit covers `amount` and the receiver accepts ETH | `P2_withdraw_succeeds_iff` |
| P3 | A caller cannot decrease another address’s credit | `P3_deposit_preserves_other`, `P3_withdraw_ok_preserves_other` |
| P4 | `sum(credits) = reserves` is preserved on a duplicate-free support | `P4_deposit_preserves_solvency`, `P4_withdraw_preserves_solvency` |
| P5 | Rejecting receiver: withdraw reverts | `P5_rejecting_reverts` |

## Run

Requires [elan](https://github.com/leanprover/elan) / Lean 4.24 (see `lean-toolchain`).

```shell
cd verification/lean
source "$HOME/.elan/env"
lake build
```

## Trust

- Solidity → Lean is a manual translation.
- `Nat` is not `uint256`; overflow reverts are absent.
- Failed `transfer` is a boolean `accepting`, not a gas model.
- Solvency is stated on a finite, duplicate-free account list that contains the actor.
