# EVM Lean model of SimpleBank

[`src/SimpleBank.sol`](../../src/SimpleBank.sol) executed on **EVMYulLean**, an executable Lean 4 formalisation of the EVM ([NethermindEth/EVMYulLean](https://github.com/NethermindEth/EVMYulLean)).

Class: semantic framework. The subject is the *deployed runtime bytecode*, so nothing about the contract is re-modelled by hand. Unlike [`verification/lean/`](../lean/), this folder contains no `theorem`: the checks are concrete executions of the formal machine, not proofs. [What this does not give](#what-this-does-not-give) is the important section.

## What is executed

The 487 bytes that `solc` emits are embedded as `bankRuntimeHex` and handed to `EvmYul.EVM.Θ`, the yellow paper message-call function.

| Solidity | EVM Lean |
| --- | --- |
| the deployed contract | 487 bytes of runtime bytecode in the account map |
| `deposit()` | message call with calldata `0xd0e30db0` and `value` wei |
| `withdraw(amount)` | message call with calldata `0x2e1a7d4d ++ amount` |
| `balances[a]` | storage slot `keccak256(pad32(a) ++ pad32(0))`, read from the account's storage |
| `address(this).balance` | `Account.balance` in the account map |
| `msg.sender` | `Θ`'s sender argument, which becomes `CALLER` |
| a failed `transfer` | a real `CALL` into a receiver whose code reverts or runs out of gas |
| a revert | `Θ` returning `z = false` with the state rolled back, equation (127) |

The function dispatcher, ABI decoding, `uint256` arithmetic and its overflow checks, the storage hashing, gas accounting, and the 2300 wei gas stipend of `transfer` all come from the semantics rather than from anything written here. `require(...)` is whatever `solc` compiled it to, a `REVERT` at some program counter.

## Checks

`lake exe simplebank-evm` runs 15 checks and exits non-zero if any fails. Ids follow the survey list in the root README.

| Id | Claim | Evidence |
| --- | --- | --- |
| — | `balances(address)` agrees with the storage slot the checks read | getter returns `7e18`, slot holds `7e18` |
| P1 | Deposit credits the caller and the reserves | 1 ETH in: credit `1e18`, reserves `1e18`, caller down `1e18` |
| P2 | Withdraw reverts when the credit is short | asking 2 ETH on 1 ETH of credit: no state change |
| P2 | Withdraw of the whole credit succeeds | credit and reserves reach `0`, caller made whole |
| P2 | Partial withdraw debits exactly the amount | 2 ETH credit, 1 ETH out, 1 ETH left in both places |
| P2 | A zero withdraw returns without effect | no credit, no revert |
| P3 | Another account's credit survives a deposit | Bob's `3e18` untouched by Alice |
| P3 | Another account's credit survives a withdraw | Bob's credit and ETH balance untouched |
| P3 | A caller with no credit cannot drain the vault | revert, Bob's `3e18` still in the vault |
| P4 | `sum(credits)` tracks the reserves | across four calls by two accounts |
| P5 | A receiver that reverts cannot withdraw | `PUSH0 PUSH0 REVERT` receiver: credit and reserves intact |
| P5 | A receiver over the 2300 gas stipend cannot withdraw | cold `SSTORE` receiver, 22100 gas, halts out of gas |
| P5 | That receiver does accept ETH when gas is ample | succeeds at 100000 gas, fails at 2300 |
| P5 | The same withdraw succeeds for an EOA | so the two reverts above are about the receiver |

Three of these are controls rather than claims about `SimpleBank`. Without them a receiver that failed for an unrelated reason, a bad opcode or a broken harness, would read as a passing P5; and a wrong `creditSlot` would make every storage read consistently wrong, which is why the contract's own getter is asked for the same number.

The gas stipend pair is the one claim here that the abstract model in [`verification/lean/`](../lean/) cannot state at all: there a failing `transfer` is a boolean `accepting` flag, while here it is the EVM's own gas accounting deciding the outcome.

## What this does not give

**These are executions, not proofs.** Each check fixes the addresses, the amounts, and the order of calls. Fifteen traces pass. Nothing is claimed about the other inputs. P4 in particular is one observation at the end of one four-call trace, not the invariant; the unbounded statement over arbitrary traces is `P4_reachable_solvent` in [`verification/lean/`](../lean/).

**There are no theorems, and this is a property of the tooling.** Keccak-256 reaches Lean through C (`ffi.KEC`, `ffi.ByteArray.zeroes`), so every storage lookup passes through a foreign function. Three consequences, each observed rather than assumed:

- `decide` gets stuck: reduction stops at the `Decidable` instance for `creditSlot alice`, because the kernel cannot unfold an opaque external constant.
- `#eval` fails with `Could not find native implementation of external declaration 'ffi.ByteArray.zeroes'`.
- `native_decide` fails with the same missing symbol.

A compiled `lake exe` binary is therefore the only way to run the semantics, which is also how EVMYulLean runs its own conformance suite. `native_decide` would in principle turn these checks into `theorem`s, but it would rest on `Lean.ofReduceBool` plus the same C keccak, so it would buy the word "theorem" and no additional assurance.

**Message calls, not transactions.** `Θ` is the message-call level. Intrinsic gas, nonce increments, the sender paying for gas, and transaction signature validation belong to `Υ` and are not exercised, so account balances here move only by value transfer. Contract creation is also skipped: the runtime bytecode is placed in the account map directly rather than deployed through `CREATE`.

## Trust

- The semantics are conformance-tested against the Cancun test suite, not proved correct. A bug there is invisible to this folder.
- Keccak-256 and SHA-256 are C libraries compiled through EVMYulLean's FFI.
- `bankRuntimeHex` is a literal, so this project builds without `solc`. It can drift from the Solidity, which is why CI runs `check-bytecode.sh` in the Foundry job.
- `solc` itself is trusted: the bytecode is taken as the meaning of the contract.
- The block header and the accrued substate are `default`, so block number, timestamp, and `prevrandao` are zero. `SimpleBank` reads none of them.

## Run

Requires [elan](https://github.com/leanprover/elan). Lean 4.22.0 is pinned in `lean-toolchain` to match EVMYulLean.

```shell
cd verification/evm-lean
source "$HOME/.elan/env"

# Mathlib is a transitive dependency; fetch its oleans rather than building it.
lake exe cache get

# EVMYulLean's FFI target otherwise runs `git submodule update --init` here,
# cloning several GB of fixtures that only its own Conform target needs.
mkdir -p EthereumTests

lake build
lake exe simplebank-evm
```

A cold run takes about half an hour and just under 6 GB of disk. The olean cache covers Mathlib's `.olean` files but not the native objects, and an executable has to be linked because of the keccak FFI, so the C compilation of Mathlib's import closure dominates. That is why CI keeps this in its own workflow, triggered only when this folder or `src/SimpleBank.sol` changes.

After `src/SimpleBank.sol` changes, `./check-bytecode.sh` reports whether `bankRuntimeHex` needs updating.

## Files

| Path | Role |
| --- | --- |
| `SimpleBankEVM.lean` | bytecode, accounts, calldata builders, storage slot arithmetic, the call wrapper |
| `Main.lean` | the P1-P5 checks and the runner |
| `check-bytecode.sh` | compares `bankRuntimeHex` against `forge build` output |
| `lakefile.toml` | pins EVMYulLean by commit |
