# Alloy model of SimpleBank

Bounded relational model of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) in **Alloy 6**.

Class: relational model finding (SAT). Analyzer and language: [alloytools.org](https://alloytools.org/). This is not an EVM interpreter; it is an abstract vault with credits, native reserves, and `deposit` / `withdraw` actions.

## What is modelled

| Solidity | Alloy |
| --- | --- |
| `address` | `Account` |
| `balances[a]` | `Bank.credit[a]` |
| `address(this).balance` | `Bank.reserves` |
| `deposit()` | `deposit[sender, value]` |
| `withdraw(amount)` | `withdraw[sender, amount]` |
| `transfer` revert (rejecting or gas-heavy `receive`) | `Rejecting` accounts; `withdraw` is disabled for them |

ETH is a non-negative Alloy `Int` (finite bitwidth). Overflow of `+=` is treated as a disabled `deposit`, matching Solidity 0.8 revert-on-overflow. There is no `receive`/`fallback`: reserves grow only through `deposit`.

## Properties

Aligned with the survey list in the root README:

| Id | Claim | Command |
| --- | --- | --- |
| P1 | Deposit of `v` increases the caller’s credit and reserves by `v` | `P1_deposit_credits_caller_and_reserves` |
| P2 | Withdraw of `a` succeeds iff credit covers `a` and the receiver can take ETH | `P2_withdraw_requires_credit_and_accepting_receiver` |
| P3 | A caller cannot decrease another address’s credit | `P3_caller_cannot_debit_another_account` |
| P4 | `sum(credits) = reserves` | `P4_solvency` |
| P5 | Rejecting receiver cannot withdraw; their credit never falls | `P5_*` |

A passing `check` means **no counterexample in the given scope** (here: 2 accounts, 4-bit integers, 5 steps). It is not an unbounded proof.

## Run

Alloy 6.2 ([alloytools.org](https://alloytools.org/) or `brew install alloy-analyzer`):

```shell
# Homebrew binary, if installed
alloy exec verification/alloy/SimpleBank.als

# Portable JAR from https://github.com/AlloyTools/org.alloytools.alloy/releases
java -jar org.alloytools.alloy.dist.jar exec verification/alloy/SimpleBank.als
```

GUI: open `SimpleBank.als` in the Alloy Analyzer and Execute the `check` / `run` commands.

## Trust

- Solidity → Alloy is a manual translation.
- `Int` is signed and bounded; wei is not `uint256`.
- Failed `transfer` is a static partition `Rejecting`, not a gas model.
- Stutter is always enabled (idle blocks / reverted transactions).
