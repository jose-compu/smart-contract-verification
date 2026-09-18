# Smart Contract Verification

Foundry workspace around a minimal `SimpleBank` ETH vault. The contract is the shared example for unit tests, fuzzing, invariant tests, 100% Foundry coverage, and a later survey of software verification methods.

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
| `verification/` | Reserved for formal / symbolic / model-checking methods |
| `.github/workflows/test.yml` | `fmt`, build, tests, 100% coverage gate |

See [`verification/README.md`](verification/README.md) for candidate verification tools (Lean, EVM Lean, Verity, Certora CVL, and others). Each method will occupy its own subfolder.

## License

Apache-2.0. See `LICENSE`.
