# Slither on SimpleBank

Static scan of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) with **Slither 0.11.3**.

Class: static analysis. Tool: [crytic/slither](https://github.com/crytic/slither). This is not a proof of the five survey properties. A quiet run means the default detectors did not match a pattern they know.

## Result

Slither 0.11.3, 100 detectors, on the Foundry build of `src/SimpleBank.sol`: **0 results**.

`withdraw` pays `msg.sender` with `transfer` after the debit. The default set does not report reentrancy, and it does not report the 2,300-gas stipend. P1–P5 are out of scope: there is no claim here that deposit credits `msg.value`, that solvency holds, or that a reverting receiver rolls the debit back.

## Run

Python package `slither-analyzer==0.11.3`, and Foundry so Slither can compile the project.

```shell
verification/slither/run.sh
```

The script fails if Slither errors or if any detector fires.

## Trust

- The detector catalogue is a pattern list, not a semantics of the EVM.
- A later Slither release can add a detector that fires on this file. CI pins 0.11.3.
