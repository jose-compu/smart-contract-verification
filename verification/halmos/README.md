# Halmos symbolic tests for SimpleBank

Symbolic execution of Foundry tests, checked against the *compiled bytecode* of
[`src/SimpleBank.sol`](../../src/SimpleBank.sol) with [Halmos](https://github.com/a16z/halmos).

Class: symbolic execution. Halmos runs ordinary Foundry test contracts, but treats every function
argument (and, via `svm.createAddress`/`createUint*`, any value you ask for) as symbolic: it
explores the tree of path conditions and either proves the assertions hold on the whole explored
space, or returns a concrete counterexample.

## What is checked

[`SimpleBank.t.sol`](SimpleBank.t.sol) defines `check_*` functions (Halmos's default test prefix,
alongside `invariant_`) that mirror the same properties used for the [Certora
spec](../certora/SimpleBank.spec):

| Id | Claim | Halmos test |
| --- | --- | --- |
| P1 | Deposit of `v` credits the caller and the vault's ETH by `v` | `check_Deposit_CreditsCallerAndReserves` |
| P2 | Withdraw reverts when credit is short; a successful withdraw debits the caller and pays them | `check_Withdraw_RevertsWhenCreditShort`, `check_Withdraw_SuccessDebitsCaller` |
| P3 | A caller cannot change another address's credit | `check_Deposit_PreservesOtherCredit`, `check_Withdraw_PreservesOtherCredit` |
| P5 | A withdraw that reverts (short credit, or the receiver rejects ETH) leaves the caller's credit unchanged | `check_Withdraw_RevertsWhenCreditShort`, `check_Withdraw_RevertOnRejectingReceiverLeavesCreditUnchanged` |

`RejectingReceiver` in the same file plays the role Certora's `harness/Rejector.sol` plays there:
a contract whose `receive()` reverts, to exercise the failed-`transfer` path.

P4 (global solvency, `sum(balances) == address(this).balance`) is not attempted here: that needs a
running sum over every possible storage key, which Certora gets from a ghost + storage hook.
Halmos explores concrete paths through a fixed set of symbolic accounts; it has no primitive for
summing an unbounded mapping, so it is not the right tool for that specific claim.

Reverts are observed with `try`/`catch`, not `vm.expectRevert`: Halmos (0.3.3) does not implement
that cheatcode, and calling it does not fail loudly — it just warns `Unsupported cheat code:
expectRevert()` and continues as a no-op, which would silently drop the very check the test is
supposed to make.

### Running Halmos on the existing `testFuzz_*` suite

Halmos's headline feature is running unmodified against tests that were written for concrete
fuzzing — every argument becomes symbolic regardless of what wrote the test. That works out of the
box for functions that only use argument-shaped symbolic values and cheatcodes Halmos supports:

```shell
halmos --contract SimpleBankTest --function testFuzz_IndependentAccounting
```

Two of the four `testFuzz_*` in [`test/SimpleBank.t.sol`](../../test/SimpleBank.t.sol) are not
currently clean under Halmos 0.3.3, for reasons unrelated to `SimpleBank`'s correctness (both are
exercised by thousands of real Foundry fuzz runs in CI, and by the equivalent `check_*` properties
above, which pass):

- `testFuzz_WithdrawAboveCreditReverts` uses `vm.expectRevert()` — unsupported, see above.
- `testFuzz_DepositCreditsExactValue` reports a spurious counterexample (`amount == 0`) once
  `setUp()` funds a *second* `makeAddr` account (`bob`) with `vm.deal`. A reduced repro (one
  `SimpleBank`, two `vm.deal`-funded addresses, one deposit, one `assertEq`) reproduces it outside
  this repo entirely, isolating it to how Halmos 0.3.3 case-splits on multiple concrete addresses
  funded via `vm.deal` in `setUp`, not to anything test- or contract-specific. It disappears with a
  single funded address.

This is why the properties above live in a dedicated `check_*` file instead of only pointing
Halmos at `test/`: it is the only way to get a clean (0 warnings, 0 false positives) run today.

## Run

Requires Python 3.9+. `certora-cli`/`solc` are not needed; Halmos ships its own SMT solvers
(`yices-solver` and `z3-solver` are pulled in as pip dependencies) and needs no API key or account.

```shell
python3 -m venv .venv
source .venv/bin/activate
pip install halmos

# Halmos's own check_* tests (dedicated Foundry profile, see foundry.toml)
FOUNDRY_PROFILE=halmos halmos --contract SimpleBankHalmosTest

# symbolic run of the existing Foundry test suite (default profile)
halmos --contract SimpleBankTest --function testFuzz_IndependentAccounting
```

Run from the repository root. `FOUNDRY_PROFILE=halmos` points Foundry's `test` root at
`verification/halmos/` instead of `test/`, purely so `forge build` (which Halmos calls itself)
compiles this file — it does not affect `src/`.

## Trust

- Halmos symbolically executes the same bytecode `forge test` runs; it is not a separate model.
- `svm.createAddress`/`createUint*` (from [`lib/halmos-cheatcodes`](../../lib/halmos-cheatcodes),
  `a16z/halmos-cheatcodes`) produce values with no prior constraints, unlike a Foundry fuzz
  argument which is still just a concrete sample.
- A "PASS" is exhaustive over the paths Halmos actually explores for that function signature (see
  the printed `paths:` count) — bounded by argument types and any `vm.assume`, not by the SMT
  solver giving up early. `check_Deposit_CreditsCallerAndReserves(uint96)`, for example, explores
  the two paths implied by the type range: PASS means both are proved.
- Sanity-checked before committing: an off-by-one deliberately injected into
  `check_Deposit_CreditsCallerAndReserves` was caught immediately, with a concrete `amount = 0`
  counterexample, confirming the rule fails on a real bug rather than passing vacuously.
