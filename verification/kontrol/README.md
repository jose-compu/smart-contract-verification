# Kontrol proofs of SimpleBank

Symbolic execution of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) on **KEVM**, driven by **Kontrol 1.0.255**.

Class: symbolic execution / KEVM. Image: `runtimeverificationinc/kontrol:ubuntu-jammy-1.0.255`. The claims are Foundry tests in [`test/kontrol/SimpleBank.kontrol.t.sol`](../../test/kontrol/SimpleBank.kontrol.t.sol). Kontrol compiles them and asks the K prover to show that every `assert` holds.

## What is in scope

Symbolic `uint96` amounts are assumed to lie in `(0, 10 ether)`. That is a proof for that range, not for every `uint256`.

| Id | Test | Claim |
| --- | --- | --- |
| P1 | `test_p1_deposit` | Deposit of `value` credits the caller and increases the bank balance by `value` |
| P2 | `test_p2_withdraw` | After that deposit, `withdraw(value)` clears the credit and the reserves and pays the caller |
| P2 | `test_p2_withdraw_short_reverts` | `withdraw(1)` with no credit reverts and leaves both balances at 0 |
| P3 | `test_p3_other_credit_untouched` | A deposit does not credit `address(0xBEEF)` |
| P4 | `test_p4_solvent_after_deposit` | After one deposit, that credit equals `address(bank).balance` |
| P5 | `test_p5_rejector_reverts` | Withdraw to a receiver whose `receive` reverts leaves the credit and the reserves unchanged |

## Run

Docker, and the image above.

```shell
verification/kontrol/run.sh
```

`kontrol build` kompiles the KEVM definition for this Foundry project. `kontrol prove` runs each test. The script fails if a proof does not close.

An 8 GB Docker VM is not enough: the LLVM and Haskell kompiles run together and the kernel kills the compiler (exit 137). The CI runner is the machine this script is written for.

## Trust

The semantics are KEVM, not a custom interpreter. Gas is the schedule Kontrol enables by default. The `transfer` stipend is exercised only by `test_p5_rejector_reverts`. Calls outside these tests are not in the proof.
