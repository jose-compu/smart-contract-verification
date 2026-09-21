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
| a transaction | `Op` / `step s o` (a reverted `withdraw` leaves the state untouched) |
| a sequence of transactions | `run s ops` |
| the deployed vault | `init accepting` (no credit, no reserves) |

Wei is `Nat` (unbounded). Solidity `uint256` overflow is not modelled. There is no `receive`/`fallback`: reserves grow only through `deposit`.

## Properties

Aligned with the survey list in the root README. A `theorem` here is a kernel-checked proof (unbounded in `Nat` and in the list of accounts), not a bounded SAT check.

| Id | Claim | Theorem |
| --- | --- | --- |
| P1 | Deposit of `v` increases the caller’s credit and reserves by `v` | `P1_deposit_credits_caller_and_reserves` |
| P2 | Withdraw succeeds iff credit covers `amount` and the receiver accepts ETH | `P2_withdraw_succeeds_iff` |
| P3 | A caller cannot decrease another address’s credit | `P3_deposit_preserves_other`, `P3_withdraw_ok_preserves_other` |
| P4 | `sum(credits) = reserves` is preserved on a duplicate-free support | `P4_deposit_preserves_solvency`, `P4_withdraw_preserves_solvency` |
| P4 | The deployed vault is solvent, and every reachable state is | `P4_init_solvent`, `P4_run_preserves_solvency`, `P4_reachable_solvent` |
| P5 | Rejecting receiver: withdraw reverts | `P5_rejecting_reverts` |

`P4_reachable_solvent` is the statement that answers “is the vault solvent?”. The per-operation P4 theorems only *preserve* solvency from a hypothesis; `P4_init_solvent` discharges that hypothesis for `init`, and `P4_run_preserves_solvency` carries it along an arbitrary `List Op`. Solvency is therefore a conclusion about reachable states, not an assumption.

### Reserves cover a successful withdraw

`withdraw` has no reserve-shortfall branch: on an arbitrary `State` with `reserves < amount` it returns `.ok` and the `Nat` subtraction floors at `0`, whereas Solidity’s `transfer` would revert. That state is unreachable rather than ignored:

| Claim | Theorem |
| --- | --- |
| On a solvent vault, a successful withdraw satisfies `amount ≤ reserves` | `withdraw_ok_amount_le_reserves` |
| On any state reachable from `init`, likewise | `P2_reachable_withdraw_within_reserves` |

So `reserves - amount` is exact wherever the model is reachable, and the omitted `transfer` failure cannot be triggered.

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
- Failed `transfer` is a boolean `accepting`, not a gas model: a receiver cannot change its mind between calls, and gas is not modelled.
- Solvency is stated on a finite, duplicate-free account list (`List.Nodup`) that contains every actor. The support is fixed in advance, whereas a Solidity mapping grows implicitly; a deposit from an address outside the list would break the equality, which is why `sender ∈ xs` is required.
- `withdraw` omits the reserve-shortfall revert of `transfer`. The gap is closed by reachability (`P2_reachable_withdraw_within_reserves`), not by a branch in the model.
- Reachability is defined by `run` over `Op`, so it covers `deposit` and `withdraw` only. Direct ETH transfers, `selfdestruct`, and coinbase payments are out of scope, matching the “no `receive`/`fallback`” assumption.
