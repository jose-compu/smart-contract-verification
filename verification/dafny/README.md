# Dafny model of SimpleBank

Deductive proof of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) in **Dafny 4.11**.

Class: automated deductive / SMT. Language: [dafny.org](https://dafny.org/). Dafny checks preconditions, postconditions, and the solvency invariant, then Boogie sends the proof obligations to Z3. This is an abstract vault (credits, reserves, a rejecting set, a payout purse), not an EVM interpreter.

## What is modelled

| Solidity | Dafny |
| --- | --- |
| `address` | `Address` (`nat`) |
| `balances[a]` | `State.credit[a]` (`CreditOf` is 0 when the key is absent) |
| `address(this).balance` | `State.reserves` |
| `deposit()` | `deposit` / `Vault.Deposit` |
| `withdraw(amount)` | `withdraw` (`Success` / `Revert`) / `Vault.Withdraw` |
| failed `transfer` | `sender in rejecting` → `Revert` |
| ETH paid to the caller | `State.held[sender]` |
| a transaction | `Op` / `Step` (a reverted `withdraw` leaves the state untouched) |
| a sequence of transactions | `Run` |
| the deployed vault | `Init` / `Vault` constructor (no credit, no reserves) |

Wei is `nat` (unbounded). Solidity `uint256` overflow is not modelled. There is no `receive`/`fallback`: reserves grow only through `deposit`.

`Vault` is the same state with an explicit invariant `Inv`: `Solvent` on a fixed, duplicate-free support. The constructor establishes it. `Deposit` and `Withdraw` require it and ensure it. That is the pre/post and invariant layer; the lemmas below are the same claims on the pure functions.

## Properties

Aligned with the survey list in the root README. A lemma or a method postcondition here is a Boogie/Z3 proof, unbounded in `nat` and in the length of the support, not a bounded SAT check.

| Id | Claim | Lemma or postcondition |
| --- | --- | --- |
| P1 | Deposit of `v` increases the caller's credit and reserves by `v` | `P1_deposit_credits_caller_and_reserves`, `Vault.Deposit` |
| P2 | On a solvent vault, withdraw succeeds iff credit covers `amount` and the receiver is not rejecting | `P2_withdraw_succeeds_iff`, `Vault.Withdraw` |
| P2 | Success debits that credit, drops reserves, and pays the caller `amount` | `P2_withdraw_success_effect`, `Vault.Withdraw` |
| P3 | A caller cannot decrease another address's credit | `P3_deposit_preserves_other`, `P3_withdraw_preserves_other` |
| P4 | `sum(credits) = reserves` is preserved on a duplicate-free support | `P4_deposit_preserves_solvency`, `P4_withdraw_preserves_solvency` |
| P4 | The deployed vault is solvent, and every reachable state is | `P4_init_solvent`, `P4_run_preserves_solvency`, `P4_reachable_solvent`, `Vault.Inv` |
| P5 | A rejecting receiver cannot withdraw; the state is unchanged | `P5_rejecting_reverts`, `P5_rejecting_preserves_state` |

`P4_reachable_solvent` is the statement that answers "is the vault solvent?". The per-operation P4 lemmas only preserve solvency from a hypothesis; `P4_init_solvent` discharges that hypothesis for `Init`, and `P4_run_preserves_solvency` carries it along an arbitrary sequence of `Op`. `Vault.Inv` is the same fact at each method boundary.

### Reserves cover a successful withdraw

`withdraw` returns `Revert` when `amount` exceeds `reserves`, because Solidity `transfer` would. On a solvent vault that branch is redundant: `P2_withdraw_succeeds_iff` drops it, and `P2_reachable_withdraw_within_reserves` records that a successful withdraw from `Init` is covered by the reserves.

## Run

Dafny 4.11 ([dafny.org](https://dafny.org/), or `brew install dafny`). Z3 ships with that install.

```shell
verification/dafny/run.sh
```

`dafny verify` fails if any lemma or method is not proved.

## Trust

- Solidity → Dafny is a manual translation.
- `nat` is not `uint256`; overflow reverts are absent.
- Failed `transfer` is membership in `rejecting`, not a gas model: a receiver cannot change its mind between calls, and the 2,300-gas stipend is not modelled.
- Solvency is stated on a finite, duplicate-free support that contains every actor. A deposit from an address outside the support is outside the invariant; `Deposit` and `Withdraw` require `sender in support`.
- `held` records ETH the vault pays out. It is not the caller's EVM balance, and `deposit` does not debit it.
- Reachability is `Run` over `Op`, so it covers `deposit` and `withdraw` only. Direct ETH transfers, `selfdestruct`, and coinbase payments are out of scope, matching the "no `receive`/`fallback`" assumption.
