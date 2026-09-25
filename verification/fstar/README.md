# F* model of SimpleBank

Deductive proof of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) in **F\* 2026.09.20** (Z3 4.15.3).

Class: automated deductive / SMT. Language: [fstar-lang.org](https://www.fstar-lang.org/). Lemmas are SMT obligations. This is an abstract vault, not an EVM interpreter, and not the Solidity compiler.

## What is modelled

| Solidity | F* |
| --- | --- |
| `address` | `address` (`nat`) |
| `balances[a]` | `state.credit a` |
| `address(this).balance` | `state.reserves` |
| `deposit()` | `deposit` |
| `withdraw(amount)` | `withdraw_ok` / `withdraw_state` |
| failed `transfer` | `rejecting sender = true` makes `withdraw_ok` false |
| ETH paid to the caller | `state.held` |
| a sequence of transactions | `op` / `step` / `run` |
| the deployed vault | `init` |

Wei is `nat`. There is no `receive`/`fallback`: reserves grow only through `deposit`.

## Properties

| Id | Claim | Lemma |
| --- | --- | --- |
| P1 | Deposit of `v` increases the caller's credit and reserves by `v` | `p1_deposit_credits_caller_and_reserves` |
| P2 | On a solvent vault, withdraw is allowed iff credit covers `amount` and the receiver is not rejecting | `p2_succeeds_iff_on_solvent` |
| P2 | Success debits that credit, drops reserves, and pays the caller | `p2_withdraw_success_effect` |
| P3 | Another address keeps its credit | `p3_deposit_preserves_other`, `p3_withdraw_preserves_other` |
| P4 | `sum(credits) = reserves` on a duplicate-free support, including every state reachable from `init` | `p4_deposit_preserves_solvency`, `p4_withdraw_preserves_solvency`, `p4_reachable_solvent` |
| P5 | A rejecting receiver cannot withdraw | `p5_rejecting_reverts` |

`withdraw_state` also refuses `amount > reserves`. On a solvent support that check follows from the credit check (`p2_reachable_withdraw_within_reserves`).

## Run

F\* 2026.09.20 with its bundled Z3 4.15.3 on `PATH`.

```shell
verification/fstar/run.sh
```

`fstar.exe` fails if a lemma is not proved.

## Trust

- Solidity → F\* is a manual translation.
- `nat` is not `uint256`. Overflow reverts are absent.
- `rejecting` is not a gas model. A receiver cannot change its mind between calls.
- Solvency is a duplicate-free list that contains every actor. `deposit` from outside that list is outside the lemmas.
- `held` is the ETH the model pays out, not the caller's EVM balance.
- `run` covers `deposit` and `withdraw` only.
