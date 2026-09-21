/-
  `src/SimpleBank.sol` on the EVMYulLean semantics.

  Executable Lean 4 model of the EVM: https://github.com/NethermindEth/EVMYulLean
  The subject is the deployed runtime bytecode, not a rewrite of the Solidity.
  Message calls go through `EvmYul.EVM.Θ`, the yellow paper message-call function.
-/

import EvmYul.EVM.Semantics

namespace SimpleBankEVM

open EvmYul EvmYul.EVM

/-! ## Accounts -/

/-- The vault. Holds the `SimpleBank` runtime bytecode. -/
def bank : AccountAddress := 0x00000000000000000000000000000000000000bb

/-- An externally owned account. -/
def alice : AccountAddress := 0x000000000000000000000000000000000000a11c

/-- A second externally owned account, used for the no-interference checks. -/
def bob : AccountAddress := 0x0000000000000000000000000000000000000b0b

/-- A contract that reverts on any incoming call, so `transfer` to it fails. -/
def rejector : AccountAddress := 0x00000000000000000000000000000000000dead0

/-- A contract that does not revert but cannot run within `transfer`'s 2300 gas stipend. -/
def gasHog : AccountAddress := 0x000000000000000000000000000000000000f00d

/-! ## Code -/

/--
  Runtime bytecode of `src/SimpleBank.sol`.

  solc 0.8.24, Cancun, optimizer enabled (200 runs), as produced by `forge build`.
  A literal, so this project builds without solc; CI guards the drift with
  `verification/evm-lean/check-bytecode.sh`.
-/
def bankRuntimeHex : String :=
  "0x608060405260043610610033575f3560e01c806327e235e3146100375780632e1a7d4d14610074578063d0e30db014610095575b5f80fd5b348015610042575f80fd5b5061006261005136600461012d565b5f6020819052908152604090205481565b60405190815260200160405180910390f35b34801561007f575f80fd5b5061009361008e36600461015a565b61009d565b005b610093610108565b335f908152602081905260409020548111156100b7575f80fd5b335f90815260208190526040812080548392906100d5908490610185565b9091555050604051339082156108fc029083905f818181858888f19350505050158015610104573d5f803e3d5ffd5b5050565b335f908152602081905260408120805434929061012690849061019e565b9091555050565b5f6020828403121561013d575f80fd5b81356001600160a01b0381168114610153575f80fd5b9392505050565b5f6020828403121561016a575f80fd5b5035919050565b634e487b7160e01b5f52601160045260245ffd5b8181038181111561019857610198610171565b92915050565b808201808211156101985761019861017156fea2646970667358221220e49f86769926289dbba60fc635d8e6790abf916505aef43586b781a00627472d64736f6c63430008180033"

/-- `PUSH0 PUSH0 REVERT`: refuses every incoming call, including a plain ETH send. -/
def rejectorCodeHex : String := "0x5f5ffd"

/--
  `PUSH1 1 PUSH1 0 SSTORE`: accepts the call but spends more than it is given.

  A cold zero-to-nonzero `SSTORE` costs 22100 gas, and `transfer` forwards 2300,
  so this halts out of gas rather than reverting deliberately.
-/
def gasHogCodeHex : String := "0x6001600055"

/-- Decode a `0x`-prefixed hex literal. Panics on malformed input, which is a bug in this file. -/
def bytesOfHex (s : String) : ByteArray :=
  match ByteArray.ofBlob (getBlob! s) with
    | .ok bytes => bytes
    | .error e => panic! s!"malformed hex literal: {e}"

def bankRuntime : ByteArray := bytesOfHex bankRuntimeHex

def rejectorCode : ByteArray := bytesOfHex rejectorCodeHex

def gasHogCode : ByteArray := bytesOfHex gasHogCodeHex

/-! ## Calldata -/

/-- `deposit()` -/
def depositData : ByteArray := bytesOfHex "0xd0e30db0"

/-- `withdraw(uint256)` -/
def withdrawData (amount : UInt256) : ByteArray :=
  bytesOfHex "0x2e1a7d4d" ++ amount.toByteArray

/-- `balances(address)` -/
def balancesData (a : AccountAddress) : ByteArray :=
  bytesOfHex "0x27e235e3" ++ (UInt256.ofNat a.val).toByteArray

/-! ## State -/

def wei (n : ℕ) : UInt256 := UInt256.ofNat n

def ether : ℕ := 1000000000000000000

def mkAccount (balance : UInt256) (code : ByteArray) : Account .EVM :=
  { nonce := wei 0
    balance := balance
    storage := ∅
    code := code
    tstorage := ∅ }

/-- Genesis: the vault deployed and empty, every other account holding 10 ETH. -/
def genesis : AccountMap .EVM :=
  (∅ : AccountMap .EVM)
    |>.insert bank (mkAccount (wei 0) bankRuntime)
    |>.insert alice (mkAccount (wei (10 * ether)) .empty)
    |>.insert bob (mkAccount (wei (10 * ether)) .empty)
    |>.insert rejector (mkAccount (wei (10 * ether)) rejectorCode)
    |>.insert gasHog (mkAccount (wei (10 * ether)) gasHogCode)

/-! ## Observables -/

/-- Storage slot of `balances[a]`, i.e. `keccak256(pad32(a) ++ pad32(0))`. -/
def creditSlot (a : AccountAddress) : UInt256 :=
  let preimage := (UInt256.ofNat a.val).toByteArray ++ (wei 0).toByteArray
  UInt256.ofNat (fromByteArrayBigEndian (ffi.KEC preimage))

/-- `balances[a]` read straight out of the vault's storage trie. -/
def creditOf (σ : AccountMap .EVM) (a : AccountAddress) : ℕ :=
  match σ.find? bank with
    | some acc => ((acc.storage.find? (creditSlot a)).getD (wei 0)).toNat
    | none => 0

/-- Native ETH balance of an account. -/
def balanceOf (σ : AccountMap .EVM) (a : AccountAddress) : ℕ :=
  match σ.find? a with
    | some acc => acc.balance.toNat
    | none => 0

/-! ## Execution -/

/-- Recursion budget for the interpreter. `.OutOfFuel` is reported, never silently ignored. -/
def fuel : ℕ := 2 ^ 14

/-- Outcome of a message call: the post state and whether the call returned rather than reverted. -/
structure Outcome where
  post : AccountMap .EVM
  succeeded : Bool
  output : ByteArray

/--
  `sender` calls `recipient`, running `code` with `value` wei and `calldata`.

  A `REVERT` or an exceptional halt comes back as `succeeded := false` with `post`
  rolled back to the pre-call state, per equation (127). Only exhausting `fuel`
  is an error, so a failing budget can never be mistaken for a contract revert.
-/
def callCode
    (σ : AccountMap .EVM) (sender recipient : AccountAddress) (code : ByteArray)
    (value : UInt256) (calldata : ByteArray) (gas : UInt256) :
    Except EVM.ExecutionException Outcome :=
  match
    EVM.Θ fuel
      []                -- blobVersionedHashes
      ∅                 -- createdAccounts
      default           -- genesisBlockHeader
      #[]               -- blocks
      σ                 -- σ
      σ                 -- σ₀
      default           -- A, the accrued substate
      sender            -- s, becomes CALLER
      sender            -- o, becomes ORIGIN
      recipient         -- r
      (.Code code)
      gas
      (wei 1)           -- p, gas price
      value             -- v
      value             -- v', the apparent value
      calldata
      0                 -- e, call depth
      default           -- H, the block header
      true              -- w, write permission
  with
    | .ok (_, post, _, _, succeeded, output) => .ok { post, succeeded, output }
    | .error e => .error e

/-- `sender` calls the vault with `value` wei and `calldata`. -/
def callBank
    (σ : AccountMap .EVM) (sender : AccountAddress)
    (value : UInt256) (calldata : ByteArray)
    (gas : UInt256 := wei 1000000) :
    Except EVM.ExecutionException Outcome :=
  callCode σ sender bank bankRuntime value calldata gas

/-- `deposit()` carrying `value` wei. -/
def deposit (σ : AccountMap .EVM) (sender : AccountAddress) (value : UInt256) :
    Except EVM.ExecutionException Outcome :=
  callBank σ sender value depositData

/-- `withdraw(amount)`. -/
def withdraw (σ : AccountMap .EVM) (sender : AccountAddress) (amount : UInt256) :
    Except EVM.ExecutionException Outcome :=
  callBank σ sender (wei 0) (withdrawData amount)

/-- The `balances(address)` getter, so the slot arithmetic above can be cross-checked. -/
def balancesGetter (σ : AccountMap .EVM) (caller a : AccountAddress) :
    Except EVM.ExecutionException Outcome :=
  callBank σ caller (wei 0) (balancesData a)

/-- Decode a single ABI word of return data. -/
def decodeWord (output : ByteArray) : ℕ := fromByteArrayBigEndian output

end SimpleBankEVM
