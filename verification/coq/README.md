# Coq model of SimpleBank

Interactive proofs of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) in **Coq 8.20**.

Class: interactive theorem proving. This is an abstract vault (credits + reserves + an `accepting` flag), the same shape as [`verification/lean/`](../lean/). It is not an EVM interpreter. The academic EVM embedding is [`verification/evm-coq/`](../evm-coq/).

## What is modelled

| Solidity | Coq |
| --- | --- |
| `address` | `Address` (`nat`) |
| `balances[a]` | `credit s a` |
| `address(this).balance` | `reserves s` |
| `deposit()` | `deposit s sender value` |
| `withdraw(amount)` | `withdraw s sender amount` (`Ok` / `Revert`) |
| failed `transfer` | `accepting s sender = false` |
| a transaction | `Op` / `step s o` (a reverted withdraw leaves the state untouched) |
| a sequence of transactions | `run s ops` |
| the deployed vault | `init acc` (no credit, no reserves) |

Wei is `nat` (unbounded). Solidity `uint256` overflow is not modelled. There is no `receive`/`fallback`: reserves grow only through `deposit`.

## Properties

Aligned with the survey list in the root README. A `Theorem` here is a kernel-checked proof (unbounded in `nat` and in the list of accounts).

| Id | Claim | Theorem |
| --- | --- | --- |
| P1 | Deposit of `v` increases the caller's credit and reserves by `v` | `P1_deposit_credits_caller_and_reserves` |
| P2 | Withdraw succeeds iff credit covers `amount` and the receiver accepts ETH | `P2_withdraw_succeeds_iff` |
| P3 | A caller cannot decrease another address's credit | `P3_deposit_preserves_other`, `P3_withdraw_ok_preserves_other` |
| P4 | `sum(credits) = reserves` is preserved on a duplicate-free support | `P4_deposit_preserves_solvency`, `P4_withdraw_preserves_solvency` |
| P4 | The deployed vault is solvent, and every reachable state is | `P4_init_solvent`, `P4_run_preserves_solvency`, `P4_reachable_solvent` |
| P5 | Rejecting receiver: withdraw reverts | `P5_rejecting_reverts` |
| P2 | On a reachable state, a successful withdraw is covered by the reserves | `P2_reachable_withdraw_within_reserves` |

`make` rejects the build unless `P4_reachable_solvent` and `P2_reachable_withdraw_within_reserves` are closed (no axioms).

## Run

Coq 8.20. CI uses `coqorg/coq:8.20`.

```shell
cd verification/coq
make
```

## Trust

- Solidity to Coq is a manual translation.
- `nat` is not `uint256`; overflow reverts are absent.
- Failed `transfer` is a boolean `accepting`, not a gas model.
- Solvency is stated on a finite, duplicate-free account list (`NoDup`) that contains every actor. `sender` must be in that list.
- `withdraw` omits the reserve-shortfall revert of `transfer`. The gap is closed by reachability (`P2_reachable_withdraw_within_reserves`).
- Reachability is `run` over `Deposit` and `Withdraw` only.
