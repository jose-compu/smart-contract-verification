# SimpleBank in Verity

[Verity](https://veritylang.com/) is a Lean 4 embedded DSL and a compiler from that DSL toward Yul, with the compilation proved for a stated fragment ([lfglabs-dev/verity](https://github.com/lfglabs-dev/verity), MIT). A contract, its specification, and its proofs are one Lean artifact. `lake build` fails if a proof is wrong.

This directory is a **port** of `src/SimpleBank.sol`. It is a new Verity contract. It does not verify the Solidity file, and changing the `.sol` does not change what is proved here.

Pinned compiler: `lfglabs-dev/verity` @ `87aa890400f03cbb1b8122659887e0e3f43363ea`, Lean `v4.31.0`.

## What is proved

`SimpleBankVerity/Proofs.lean`, checked by the kernel on `lake build`:

| Property | Theorem | Holds here? |
| --- | --- | --- |
| P1, credit half | `deposit_credits_sender` | Yes. `deposit` adds `msg.value` to the caller's credit, and reverts on overflow (`deposit_reverts_on_overflow`). |
| P1, ETH half | `deposit_matches_value_received` | Yes, once `deposit` is run in `withCallContext`, the frame Verity installs on a value-bearing call. That frame sets `msg.value` and adds the value to `selfBalance`. The function body itself does not move ETH (`deposit_preserves_selfBalance`). |
| P2, credit half | `withdraw_succeeds`, `withdraw_reverts_when_short`, `withdraw_debits_sender` | Yes. Withdrawal succeeds iff the caller's credit covers `amount`. |
| P2, ETH half | `withdraw_keeps_eth` | **No, and that is proved.** A successful `withdraw` decreases the credit sum and leaves `selfBalance` unchanged. Solidity then `transfer`s; the EDSL has no statement that sends value, so the outgoing ETH is absent rather than abstracted. |
| P3 | `deposit_preserves_other`, `withdraw_preserves_other` | Yes. |
| P4, credits | `deposit_sum_equation`, `withdraw_sum_equation`, `init_creditSum_zero` | The credit sum moves by exactly the deposited or withdrawn amount, over any address list. |
| P4, solvency | — | Not a theorem of `withdraw`. Coupling `sum(credits) = selfBalance` holds for a deposit composed with the call frame, and fails for withdraw by exactly `amount` (`withdraw_keeps_eth`). |
| P5 | — | Out of scope. There is no send, so there is no reverting receiver and no 2300-gas stipend. |

`deposit` is recorded as `payable` and `withdraw` as not (`deposit_is_payable`, `withdraw_is_not_payable`). The spec has no external calls (`spec_has_no_externals`).

## What is compiled

`lake exe simplebank-verity` lowers `SimpleBank.spec` — the `CompilationModel` the `verity_contract` macro generates from the same declaration the proofs unfold — to Yul, and writes `artifacts/`.

Every `deny*` gate is on except local obligations. `deposit` uses checked addition, and Verity records one assumed local obligation for it (`checked_arithmetic_deposit_1_add_no_overflow`, also on the generated `internal_deposit`): the compiler does not prove that the sum cannot overflow, because a large enough `msg.value` does overflow. The source proofs cover both outcomes. The executable accepts that obligation and fails if any other assumption or an `unchecked` entry appears. A later edit that reaches for an unproved construct fails this step.

Yul is not EVM bytecode. `solc` is the remaining trusted step from this artifact to a deployed contract, and it is not run here.

## What this does not give

* A proof about `src/SimpleBank.sol` or about `solc`'s output.
* The outgoing `transfer` in `withdraw`, or property P5.
* A theorem that Verity's whole-compiler proof applies to this contract. Layer 2 is a generic theorem for the supported fragment; this package checks that the contract stays inside the fragment the deny gates accept, and it proves the source-level behaviour above. It does not re-prove the compiler.

## Run

[elan](https://github.com/leanprover/elan) is required. The first build downloads the Mathlib cache; allow several minutes.

```shell
cd verification/verity
lake update
mkdir -p .lake/packages/evmyul/EthereumTests   # skip the conformance-fixture clone
lake exe cache get
lake build                                     # kernel-checks the proofs
lake exe simplebank-verity                     # Yul, under every deny gate
```

The `EthereumTests` directory is a stub. The pinned EVMYulLean fork clones those fixtures unless the directory already exists, and this package does not run them.
