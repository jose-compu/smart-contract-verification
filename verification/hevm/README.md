# hevm proofs of SimpleBank

Symbolic execution of [`src/SimpleBank.sol`](../../src/SimpleBank.sol) with **hevm** ([hevm.dev](https://hevm.dev/)).

Class: symbolic execution. hevm is an EVM (opcodes, `transfer` stipend, Solidity panics). This is not Halmos (Solidity-level Foundry tests) and not a Lean model.

`prove_` tests in `SimpleBank.t.sol` are compiled with Foundry (`ast = true`) and discharged by `hevm test`. Function arguments are symbolic. A `[PASS]` means no assertion violation on the explored paths. The suite uses `StdAssertions` and deploys `SimpleBank` in each test (no `setUp`) so the Linux hevm binary does not bail on forge-std `Test` construction.

## Properties

| Id | Claim | Test |
| --- | --- | --- |
| P1 | Deposit of `v` increases the caller’s credit and vault ETH by `v` | `prove_P1_deposit_credits_caller_and_reserves` |
| P2 | Withdraw reverts when credit is short; an EOA with enough credit is paid | `prove_P2_withdraw_reverts_when_credit_short`, `prove_P2_withdraw_success_debits_and_pays` |
| P3 | A caller cannot decrease another address’s credit | `prove_P3_deposit_preserves_other`, `prove_P3_withdraw_preserves_other` |
| P4 | If ETH only enters through `deposit`, `sum(credits) == address(this).balance` | `prove_P4_deposit_preserves_solvency`, `prove_P4_withdraw_preserves_solvency` |
| P5 | Rejecting receiver: withdraw reverts and state is unchanged | `prove_P5_rejecting_receiver_reverts` |

P4 is stated for a single EOA (`alice`) after `deposit`/`withdraw`. P5 uses `Rejector` (`receive` reverts). hevm reports `assert` / Panic(0x01), not a failing `require`.

## Run

Requires [hevm](https://hevm.dev/install.html) 0.58 and [z3](https://github.com/Z3Prover/z3). Foundry must compile with AST (`FOUNDRY_PROFILE=hevm` sets `ast = true`).

```shell
FOUNDRY_PROFILE=hevm forge clean
FOUNDRY_PROFILE=hevm forge build --ast
hevm test --root . --match prove_ --solver z3
```

## Trust

- Starting storage after `setUp` is concrete; calldata is symbolic.
- Loops are bounded (`--max-iterations`, default 5). `SimpleBank` has no loops.
- `deal` on a symbolic address is only sound for already-deployed contracts; callers here are concrete (`alice`, `Rejector`).
- A `[PASS]` is an SMT proof of the assertions on the explored EVM paths, not a Lean kernel check.
