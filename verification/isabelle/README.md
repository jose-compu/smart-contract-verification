# Isabelle/HOL model of SimpleBank

Kernel-checked proof of an abstract vault for [`src/SimpleBank.sol`](../../src/SimpleBank.sol) in **Isabelle 2025-2**.

Class: interactive theorem proving. Tool: [Isabelle](https://isabelle.in.tum.de/). The theory is accepted by the HOL kernel or rejected. It does not execute `solc` bytecode.

## What is modelled

| Solidity | Isabelle |
| --- | --- |
| `address` | `addr` (`nat`) |
| `balances[a]` | `credit s a` (0 when unset) |
| `address(this).balance` | `reserves` |
| `deposit()` | `deposit` |
| `withdraw(amount)` | `withdraw` when `withdraw_ok`, otherwise `step` leaves the state |
| failed `transfer` | `sender ∈ rejecting` |
| ETH paid to the caller | `held` |
| a sequence of transactions | `run` |
| the deployed vault | `init` |

Wei is `nat`. Solidity `uint256` overflow is not modelled. Reserves grow only through `deposit`.

`solvent s xs` says `xs` is duplicate-free, every non-zero credit is in `xs`, and `reserves = sum_credits`. The trace lemmas require every sender to be in that list.

## Properties

| Id | Claim | Lemma |
| --- | --- | --- |
| P1 | Deposit of `v` increases the caller's credit and reserves by `v` | `p1_credit`, `p1_reserves` |
| P2 | On a solvent vault, withdraw is allowed iff credit covers `a` and the receiver is not rejecting | `p2_succeeds_iff` |
| P2 | Success debits that credit, drops reserves, and pays the caller | `p2_success_effect` |
| P3 | Another address's credit is unchanged | `p3_deposit`, `p3_withdraw` |
| P4 | Solvency holds of `init` and of every trace whose senders lie in the support | `p4_init`, `p4_run`, `p4_reachable` |
| P5 | A rejecting receiver's withdraw is a no-op | `p5_not_ok`, `p5_step_unchanged` |

## Run

Isabelle 2025-2 on `PATH` (`isabelle`). The distribution's HOL heap is reused.

```shell
verification/isabelle/run.sh
```

## Trust

The artefact is this theory, not `src/SimpleBank.sol`. The step from Solidity or EVM bytecode to these definitions is unchecked. The `transfer` stipend is only the rejecting set: gas accounting is absent.
