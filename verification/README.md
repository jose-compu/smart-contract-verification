# Verification

Reserved for a survey of software verification methods applied to [`src/SimpleBank.sol`](../src/SimpleBank.sol).

Each method will live in its own subfolder (tooling, specs, proofs or rules, and notes). This directory has no experiments yet.

The Foundry suite in `test/` is executable testing (unit, fuzz, invariant) at 100% line / statement / branch / function coverage. Work here is meant to go further: machine-checked proofs, symbolic execution, or model checking of the same contract.

## Planned subfolders

Names are indicative; a method is added only when its artifact exists.

| Subfolder | Method |
| --- | --- |
| `lean/` | Lean 4 interactive theorem proving |
| `evm-lean/` | EVM / Yul semantics in Lean (EVMYulLean) |
| `verity/` | Verity (Lean 4 EDSL and verified compiler) |
| `certora/` | Certora CVL |
| `smtchecker/` | Solidity SMTChecker |
| `halmos/` | Halmos symbolic tests |
| `kontrol/` | Kontrol / KEVM |
| `hevm/` | hevm symbolic execution |
| `act/` | Act specifications |

## Candidate tools

### Theorem proving (Lean family)

- **Lean 4** — Interactive theorem prover. Specs and proofs are Lean terms; the kernel checks them. A `SimpleBank` model would live in Lean, with theorems such as solvency and “only the owner of a credit can reduce it.”
- **EVM Lean (EVMYulLean)** — Executable Lean 4 model of the EVM and Yul ([NethermindEth/EVMYulLean](https://github.com/NethermindEth/EVMYulLean)), aligned with Cancun tests. Useful as the machine semantics against which bytecode or Yul from `SimpleBank` is reasoned about, rather than a Solidity-level rewrite.
- **Verity Lean (Verity)** — Lean 4 embedded DSL and verified compiler ([veritylang.com](https://veritylang.com/), [lfglabs-dev/verity](https://github.com/lfglabs-dev/verity)). A contract is spec, implementation, and proof together; compilation toward Yul/EVM is itself proved for a supported fragment. A port of `SimpleBank` would not keep the Solidity text; it would re-express the vault in Verity.

### Deductive verification / SMT

- **Certora CVL** — Certora Verification Language: rules, invariants, and ghosts checked against compiled bytecode with SMT solvers. Natural target for `SimpleBank` properties (`deposit` credits exactly `msg.value`; `withdraw` fails when `amount` exceeds credit; sum of credits equals native balance under the “ETH only via `deposit`” assumption).
- **Solidity SMTChecker** — Built-in CHC/SMT backend (`pragma experimental SMTChecker` or `forge` / `solc` model-checker flags). Assertions and `require`s are proved or refuted on the Solidity AST; good as a zero-spec baseline on this small contract.
- **Act** — Ethereum contract spec language (pre/post, storage updates, invariants) with SMT, Coq, and hevm backends.
- **Dafny / F\* / Why3** — General-purpose verifiers. A `SimpleBank` model can be written in their languages; the gap is the trusted link back to EVM bytecode.

### Symbolic execution and EVM semantics

- **Halmos** — Symbolic Foundry tests ([a16z/halmos](https://github.com/a16z/halmos)). Existing `testFuzz_*` / assertion tests are executed over symbolic inputs instead of random ones.
- **hevm** — Symbolic EVM ([hevm.dev](https://hevm.dev/)). Assertion proofs, ds-test / Foundry tests, bytecode equivalence.
- **Kontrol** — Foundry-oriented verifier on **KEVM** (EVM semantics in the K framework, Runtime Verification). Specs stay in Solidity tests; execution is the K EVM model.
- **K / KEVM** — Direct reachability proofs over EVM bytecode without the Foundry frontend.

### Adjacent (not in the first wave, still relevant)

- **Coq / Isabelle/HOL** — Independent ITP embeddings of EVM or of a `SimpleBank` model (historical: Coq EVM models, Isabelle bytecode analyses).
- **Scribble** — Specification annotations compiled to assertions, often paired with fuzzers or Certora.
- **Echidna / Medusa** — Property-based fuzzing, not proofs; useful as a comparison point against Halmos/hevm on the same invariants.
- **Slither / Aderyn** — Static analysis, not formal verification.

## Properties to compare across tools

The same claims should be attempted in each subfolder so methods can be judged on expressiveness, trust base, and effort:

1. Deposit of `v` increases the caller’s credit and the contract’s native balance by `v`.
2. Withdraw of `a` succeeds iff the caller’s credit is at least `a`; then both credit and native balance drop by `a`, and the caller receives `a`.
3. A caller cannot decrease another address’s credit.
4. If ETH only enters through `deposit`, `sum(balances) == address(this).balance`.
5. `withdraw` to a contract that reverts on receive, or that consumes more than the `transfer` stipend, reverts and leaves credits unchanged.

## Convention

When a method is added: put a short README in its subfolder stating the tool version, what was proved or refuted, and which of the properties above are in scope. Do not mix tools in one subfolder.
