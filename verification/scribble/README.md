# Scribble annotations for SimpleBank

Runtime annotations on a copy of [`src/SimpleBank.sol`](../../src/SimpleBank.sol), instrumented with **Scribble 0.7.10**.

Class: specification overlay. Tool: [consensys/scribble](https://github.com/consensys/scribble). Scribble compiles annotations into assertions. It is not a prover. `src/SimpleBank.sol` is unchanged.

`totalCredits` is a ghost added so P4 can be stated. The deposit and withdraw updates otherwise match the original contract.

## Properties

| Id | Annotation | In scope |
| --- | --- | --- |
| P1 | After `deposit`, the caller credit is the old credit plus `msg.value`, and the body does not change `address(this).balance` (the value is already in the balance when the function starts) | Yes, as a runtime assertion |
| P2 | After a successful `withdraw`, credit and balance drop by `amount` | Yes. A revert skips `if_succeeds` |
| P3 | A witness address other than the caller keeps its credit | Yes, on `depositWitness` / `withdrawWitness`. Scribble 0.7 has no unbounded `forall`, so the witness is an argument |
| P4 | `totalCredits == address(this).balance` after each successful call | Yes, on the ghost |
| P5 | A receiver that reverts, or that exceeds the stipend, rolls the debit back | No. `transfer` is not given a model |

## Run

Scribble 0.7.10 (`eth-scribble`) and `solc` 0.8.24 on `PATH`.

```shell
verification/scribble/run.sh
```

The script fails if instrumentation fails or if `solc` rejects the instrumented file.

## Trust

- A successful instrumentation is a well-formed spec, not a passing test campaign.
- `old(address(this).balance)` is the balance at entry, which already includes `msg.value` on `deposit`.
- The ghost `totalCredits` is not part of `src/SimpleBank.sol`.
