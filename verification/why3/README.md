# Why3 model of SimpleBank

Deductive proof of an abstract vault for [`src/SimpleBank.sol`](../../src/SimpleBank.sol) in **Why3 1.8.2**, discharged by **Alt-Ergo 2.6.4**.

Class: automated deductive / SMT. Tool: [why3.lri.fr](https://www.why3.org/). Why3 generates proof obligations; the solver says valid or it does not. This is not a check of `solc` bytecode.

## What is modelled

| Solidity | Why3 |
| --- | --- |
| `address` | `address` (`int`) |
| `balances[a]` | `credit` (0 when unset) |
| `address(this).balance` | `reserves` |
| `deposit()` | `deposit` |
| `withdraw(amount)` | `withdraw` (`Success` / `Revert`) |
| failed `transfer` | `rejecting` map |
| ETH paid to the caller | `held` |
| a sequence of transactions | `run` |
| the deployed vault | `init` |

Wei is mathematical `int`. Deposit amounts on a trace are constrained by `deposits_nonneg`. Solidity `uint256` overflow is not modelled.

`solvent` is duplicate-free support, every non-zero credit in that support, non-negative credits, and `reserves = sum`.

## Properties

| Id | Claim | Goal or lemma |
| --- | --- | --- |
| P1 | Deposit of `v` increases the caller's credit and reserves by `v` | `p1_credit`, `p1_reserves` |
| P2 | On a solvent vault, withdraw is allowed iff credit covers the amount and the receiver is not rejecting | `p2_succeeds_iff` |
| P2 | Success debits that credit, drops reserves, and pays the caller | `p2_success_effect` |
| P3 | Another address's credit is unchanged | `p3_deposit`, `p3_withdraw` |
| P4 | Solvency of `init`, of one step, and of a trace whose senders lie in the support | `p4_init`, `p4_deposit`, `p4_withdraw`, `p4_run`, `p4_reachable` |
| P5 | A rejecting receiver's withdraw reverts and `step` is a no-op | `p5_rejecting`, `p5_step_unchanged` |

## Run

Why3 1.8.2 and Alt-Ergo 2.6.4 on `PATH`. Ubuntu 24.04 has no `alt-ergo` package, so CI builds these two versions with opam.

```shell
verification/why3/run.sh
```

The script fails unless every obligation is valid.

## Trust

The artefact is `simple_bank.mlw`, not `src/SimpleBank.sol`. The translation into these definitions is unchecked. The `transfer` stipend is only the rejecting flag.
