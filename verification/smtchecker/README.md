# SMTChecker baseline for SimpleBank

`solc` 0.8.24 CHC engine on [`SimpleBank.sol`](SimpleBank.sol). Assertions are Solidity, not a second spec language. The file is the contract the checker sees: the credit update and `transfer` from [`src/SimpleBank.sol`](../../src/SimpleBank.sol), plus `assert`s. `src/SimpleBank.sol` is left unchanged so the Foundry coverage gate still measures that file.

Class: automated deductive / SMT. Solver: z3, as a Horn solver (Spacer) behind `solc`. Engine: `chc`. Targets: `assert`.

## What is checked

`_credit` and `_debit` are the two state updates. `deposit` and `withdraw` are the functions from `src/SimpleBank.sol`. `specDepositPreservesOther` and `specWithdrawPreservesOther` pass a witness address into the same updates so P3 is a query. The CHC transaction relation may call those witnesses.

| Id | Claim | Result |
| --- | --- | --- |
| P1 | Deposit increases the caller's credit by `msg.value` | Proved, in `deposit` and in the witness |
| P1 | The credit write does not change the native balance: `address(this).balance == reservesBefore + msg.value`, with `reservesBefore` taken as `address(this).balance - msg.value` before the write | Proved, on the path where that subtraction does not revert |
| P2 | After `require(balances[msg.sender] >= amount)`, the debit decreases that credit by `amount` | Proved, on the path before `transfer` |
| P3 | An address other than the caller keeps its credit across the credit update and across the debit | Proved |
| P4 | `sum(balances) == address(this).balance` | Not an assertion. A ghost `totalCredits == address(this).balance` is refuted: constructor, then `deposit` of 0 wei, leaves `totalCredits` at 0 while the balance is not that value |
| P5 | A receiver that reverts, or that exceeds the `transfer` stipend, rolls the debit back | Not a query. `transfer` is unknown code, so a post-call assertion does not see the 2300 stipend or the rollback |

`address(this).balance >= msg.value` is safe on a contract whose only function is a payable `deposit`. The same assertion is refuted once `withdraw` calls `transfer`: constructor, `withdraw`, then `deposit`. The harness does not assert it.

`balances[msg.sender] += msg.value` can still revert on `uint256` overflow. The overflow target is off, so that revert is not a failed check.

`run.sh` fails if any assertion is unproved or has a counterexample, if solc reports an error, or if the number of safe checks is not the number of `assert`s in the file.

## Run

solc 0.8.24 and `z3` on `PATH`. The Linux `solc` binary loads `libz3.so.4.12`, so CI pins z3 4.12.2 and puts that library on `LD_LIBRARY_PATH`. A newer `z3` binary is not a substitute: without `libz3.so.4.12`, CHC is skipped.

```shell
verification/smtchecker/run.sh
```

Foundry can pass the same options through `[profile.smt.model_checker]` during `forge build`. That reports findings as warnings and still exits 0, so CI calls `solc`.
