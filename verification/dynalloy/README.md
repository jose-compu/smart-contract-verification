# DynAlloy model of SimpleBank

Bounded analysis of a DynAlloy model of the vault, with **DynAlloy 1.0.0** (the `gregistecco/dynalloy` release). The analyzer is Alloy's SAT engine. `SimpleCLI` does not translate DynAlloy programs, so [`run.sh`](run.sh) calls `CompModule.translateCommandDynAlloy` and then SAT4J.

Class: relational model finding. A passing `check` means no counterexample inside the scope below. It is not an unbounded proof, and it is not a proof about `src/SimpleBank.sol`.

## Scope

Two addresses. Integers use bitwidth 4, so values are -8..7, and overflow is forbidden (`noOverflow`). Single actions are unrolled once. The trace check allows at most two steps (`lurs 2`).

## What is in scope

Actions `deposit`, `withdrawOk`, and `withdrawShort` are the model. The checks are consequences of those actions.

| Id | Command | Claim |
| --- | --- | --- |
| P1 | `check p1_deposit` | From a non-negative solvent state, one deposit stays non-negative and solvent, raises some credit, and raises reserves by that same amount. No credit falls. |
| P2 | `check p2_withdraw` | From a non-negative solvent state with some positive credit, one successful withdraw stays non-negative and solvent, lowers exactly one credit, and lowers reserves by that same amount. |
| P2 | `check p2_short` | A withdraw whose amount exceeds every credit leaves credits, reserves, and solvency unchanged. |
| P3 | `check p3_deposit` | A deposit does not decrease any credit. |
| P4 | `check p4_trace` | A trace of at most two deposits or withdraws, from a non-negative solvent state, is still non-negative and solvent. |

`run oneDeposit`, `run oneWithdraw`, and `run trace` must each return an instance, so the scope is not empty.

P5, a revert from the receiver of `transfer`, is not in the model. There is no CALL and no gas stipend.

## Run

Java 21 and the DynAlloy 1.0.0 jar. The script uses `$HOME/.local/verifiers/dynalloy/dynalloy.jar` when that file exists, and otherwise downloads the release.

```shell
verification/dynalloy/run.sh
```

The script fails if a `check` is satisfiable or a `run` is not.

## Trust

The state is a relation `credit` plus an integer `reserves`. The EVM, `transfer`, and storage layout are not in the model. Integer overflow is excluded rather than proved absent for every `uint256`. Traces longer than two steps, and more than two addresses, are outside the scope.
