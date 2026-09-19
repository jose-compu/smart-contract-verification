# Smart Contract Verification

Foundry workspace around a minimal `SimpleBank` ETH vault. The contract is the shared example for unit tests, fuzzing, invariant tests, 100% Foundry coverage, and a survey of software verification methods.

## Contract

`src/SimpleBank.sol` (Solidity `0.8.24`, Cancun EVM):

- `deposit()` — payable; credits `msg.value` to `balances[msg.sender]`
- `withdraw(uint256 amount)` — reverts unless the caller’s credit covers `amount`, then debits and pays with `transfer`

No `receive`/`fallback`. Direct ETH transfers revert. Accounting is a per-address mapping; solvency (`sum(credits) == address(this).balance`) holds only if ETH enters through `deposit`.

## Coverage

The suite is gated at **100%** Foundry source coverage on every metric the summary report exposes:

| Metric | Target |
| --- | --- |
| Lines | 100% |
| Statements | 100% |
| Branches | 100% |
| Functions | 100% |

CI runs `forge coverage` and fails unless the `Total` row is `100.00%` on all four columns. That includes `src/`, `script/`, and instrumented test helpers.

Foundry report types used here:

| Report | Command | Role |
| --- | --- | --- |
| Summary | `forge coverage --report summary` | Line / statement / branch / function table |
| LCOV | `forge coverage --report lcov --report-file lcov.info` | Interoperable tracefile (Coverage Gutters, `genhtml`) |
| Debug | `forge coverage --report debug` | Per-item hit counts |
| Bytecode | `forge coverage --report bytecode` | Opcode-level map (Foundry 1.5 may fail to disassemble large artifacts) |

HTML from LCOV:

```shell
genhtml lcov.info --branch-coverage --output-dir coverage
```

`--ir-minimum` is not the baseline: IR source maps under-count `require` branches. `--report attribution` is not available on Foundry 1.5.0.

## Tests

| Kind | Location |
| --- | --- |
| Unit and fuzz | `test/SimpleBank.t.sol` |
| Invariants (solvency, credit sum, per-actor bound) | `test/SimpleBank.invariant.t.sol` |
| Handler | `test/handlers/SimpleBankHandler.sol` |
| Deploy script | `test/Deploy.t.sol` |

Properties covered include independent user credits, insufficient-balance reverts, zero deposit/withdraw, `transfer` failure on reverting or gas-heavy receivers, and dispatcher paths (empty calldata, unknown selector, `withdraw` with value).

## Setup

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation).

```shell
git submodule update --init --recursive
forge install
```

## Commands

```shell
forge build
forge test -vvv
forge test --match-contract SimpleBankInvariantTest -vvv
forge coverage --report summary
forge coverage --report lcov --report-file lcov.info
forge coverage --report debug
forge coverage --report bytecode
genhtml lcov.info --branch-coverage --output-dir coverage
forge fmt
```

Deploy locally:

```shell
forge script script/Deploy.s.sol:DeploySimpleBank --broadcast --rpc-url http://127.0.0.1:8545
```

## Layout

| Path | Role |
| --- | --- |
| `src/SimpleBank.sol` | Example contract |
| `test/` | Unit, fuzz, invariant, handler, and script tests |
| `script/Deploy.s.sol` | Deployment |
| `verification/` | Formal / symbolic / model-checking experiments |
| `verification/hevm/` | hevm symbolic proofs for `SimpleBank` |
| `.github/workflows/test.yml` | `fmt`, build, tests, 100% coverage gate, hevm proofs |

## Verification

`verification/` holds one experiment per tool. Foundry tests are executable checking; work here is meant to go further: machine-checked proofs, symbolic execution, or model checking of the same contract.

The hevm experiment is [`verification/hevm/`](verification/hevm/): symbolic EVM proofs of `SimpleBank` ([hevm.dev](https://hevm.dev/)).

### Classification

Tools are grouped by *how they argue*, not by vendor. The guarantee column is the usual ceiling, not a promise on `SimpleBank`.

| Class | Question | Typical artifact | Usual guarantee |
| --- | --- | --- | --- |
| Interactive theorem proving | Does a proof of this theorem exist? | Lean / Coq / Isabelle model, or a verified compiler | Unbounded, kernel-checked (human-written proofs) |
| Automated deductive / SMT | Do these rules or assertions hold on all paths the solver can see? | Solidity, bytecode, or a spec language | Unbounded in intent; solvers may time out or need bounds |
| Relational model finding | Is there a counterexample in this finite scope? | Alloy / DynAlloy model | Bounded SAT; a pass is not an unbounded proof |
| Symbolic execution | Can any input violate this assertion? | Foundry tests or EVM bytecode | All paths in the explored fragment; loops often bounded |
| Semantic frameworks | Does this claim hold in a formal EVM? | Bytecode + K / KEVM rules | As strong as the semantics and the proof backend |
| Spec overlays | What should the contract do, in a machine-readable way? | Annotations or Act specs | Not a verifier by itself; feeds other tools |
| Property-based testing | Can random (or coverage-guided) inputs break this invariant? | Invariant tests | No proof; only counterexamples |
| Static analysis | Does the source match known bug patterns? | Solidity AST | Heuristic; neither proof nor exhaustive search |

### Tools

#### Interactive theorem proving

Kernel-checked mathematics. High assurance, high effort. The Solidity text is usually *modelled*, not executed.

- **Lean 4** — Interactive theorem prover and programming language. You write a `SimpleBank` state and theorems (solvency, no cross-account debit); the kernel accepts a proof or rejects it. Nothing here talks to `solc` unless you add that link yourself.
- **EVM Lean (EVMYulLean)** — Executable Lean 4 semantics of the EVM and Yul ([NethermindEth/EVMYulLean](https://github.com/NethermindEth/EVMYulLean)), checked against Cancun tests. Use it as the *machine* on which bytecode or Yul is proved, rather than as a Solidity rewrite.
- **Verity** — Lean 4 EDSL and verified compiler ([veritylang.com](https://veritylang.com/)). Spec, implementation, and proof are one artifact; compilation toward Yul/EVM is proved for a supported fragment. A `SimpleBank` port is a new Verity contract, not the current `.sol` file.
- **Coq** — Independent ITP. Same role as Lean: embed a vault model (or an EVM fragment) and prove theorems. Several academic EVM embeddings exist; none are wired to this repo yet.
- **Isabelle/HOL** — Another ITP, historically used for bytecode and protocol proofs. A `SimpleBank` theory would be a HOL model plus lemmas, with a trusted step back to EVM if desired.

#### Automated deductive verification (SMT)

You state properties; an SMT or CHC solver tries to prove them or return a counterexample. Little or no interactive proof.

- **Certora CVL** — Certora Verification Language: rules, invariants, and ghosts checked against *compiled bytecode*. Fits `SimpleBank` directly (`deposit` credits `msg.value`; `withdraw` reverts when credit is short; sum of credits equals native balance if ETH only enters via `deposit`).
- **Solidity SMTChecker** — `solc` built-in CHC/SMT checker. Assertions and `require`s are proved or refuted on the Solidity AST. Zero extra spec language; a good baseline on this small contract.
- **Dafny** — Verification-aware language (pre/post, invariants) compiled to Boogie/SMT. Model `SimpleBank` in Dafny; the EVM gap is trusted.
- **F\*** — Effectful functional language with SMT and tactic proofs. Same pattern: a verified model, not the on-chain compiler.
- **Why3** — Deductive platform with pluggable solvers. Useful as a backend for a hand-written vault spec.

#### Relational model finding (bounded SAT)

Abstract relational state + SAT. Excellent at finding design bugs; a passing `check` only holds inside the chosen scope (number of addresses, trace length, bitwidth).

- **Alloy** — Lightweight relational language and analyzer ([alloytools.org](https://alloytools.org/)). Encode addresses, credits, and balance as relations; `deposit` / `withdraw` as predicates; `check` solvency and authorization. Counterexamples are concrete instances.
- **DynAlloy** — Alloy plus *actions*, sequencing, choice, and bounded loops, via partial-correctness assertions (WLP) compiled to Alloy/SAT. Write traces of `deposit` and `withdraw` as programs instead of stitching state predicates by hand.

#### Symbolic execution

Replace concrete fuzz inputs with symbols; the tool explores a tree of path conditions.

- **Halmos** — Symbolic runner for Foundry tests ([a16z/halmos](https://github.com/a16z/halmos)). Existing `testFuzz_*` / `assert` tests are checked for *all* inputs in the explored space, or a counterexample is returned.
- **hevm** — Symbolic EVM ([hevm.dev](https://hevm.dev/)). Assertion proofs, Foundry/ds-test execution, and bytecode equivalence. Closer to opcodes than Halmos’s Solidity-level view.
- **Kontrol** — Foundry frontend on KEVM (Runtime Verification). Specs stay in Solidity tests; execution uses the K EVM model, so the trust base is the published semantics rather than a custom interpreter.

#### Semantic frameworks

A formal operational model of the chain, then prove reachability claims on it.

- **K / KEVM** — EVM rewritten in the K framework. Direct bytecode reachability proofs without Foundry. Kontrol is the ergonomic layer over the same semantics.

#### Specification overlays

These *describe* behaviour. A separate engine checks it.

- **Act** — Ethereum spec language (pre/post, storage updates, invariants) with SMT, Coq, and hevm backends. A `SimpleBank` Act spec can be discharged by more than one tool.
- **Scribble** — In-source annotations compiled to assertions. Feeds fuzzers or Certora; it is not a prover.

#### Property-based testing (not proofs)

Same invariants as verification, weaker conclusion.

- **Echidna** — Coverage-guided fuzzer (Trail of Bits). Random and guided sequences of `deposit` / `withdraw` try to break invariants; a long green run is evidence, not a proof.
- **Medusa** — Parallel EVM fuzzer with similar goals. Useful as a second fuzzer on the same properties.

#### Static analysis (not verification)

- **Slither** — AST detectors (reentrancy, dead code, `transfer` stipend, and so on). Fast triage; does not prove the five properties below.
- **Aderyn** — Rust-based Solidity detector, same niche as Slither: pattern matching, not exhaustive reasoning.

### Planned `verification/` subfolders

Created only when an experiment exists.

| Subfolder | Class | Tool |
| --- | --- | --- |
| `verification/lean/` | Interactive theorem proving | Lean 4 |
| `verification/evm-lean/` | Interactive theorem proving | EVMYulLean |
| `verification/verity/` | Interactive theorem proving | Verity |
| `verification/certora/` | Automated deductive / SMT | Certora CVL |
| `verification/smtchecker/` | Automated deductive / SMT | Solidity SMTChecker |
| `verification/alloy/` | Relational model finding | Alloy |
| `verification/dynalloy/` | Relational model finding | DynAlloy |
| `verification/halmos/` | Symbolic execution | Halmos |
| `verification/kontrol/` | Symbolic execution / KEVM | Kontrol |
| `verification/hevm/` | Symbolic execution | hevm |
| `verification/act/` | Spec overlay | Act |

### Properties to compare across tools

Attempt the same claims in each subfolder so methods can be judged on expressiveness, trust base, and effort:

1. Deposit of `v` increases the caller’s credit and the contract’s native balance by `v`.
2. Withdraw of `a` succeeds iff the caller’s credit is at least `a`; then both credit and native balance drop by `a`, and the caller receives `a`.
3. A caller cannot decrease another address’s credit.
4. If ETH only enters through `deposit`, `sum(balances) == address(this).balance`.
5. `withdraw` to a contract that reverts on receive, or that consumes more than the `transfer` stipend, reverts and leaves credits unchanged.

When a method is added, put a short note in its subfolder stating the tool version, class from the table above, what was proved or refuted, and which of the properties are in scope. Do not mix tools in one subfolder.

## License

Apache-2.0. See `LICENSE`.
