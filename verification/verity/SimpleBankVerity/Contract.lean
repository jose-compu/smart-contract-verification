import Compiler.CompilationModel
import Verity.Core
import Verity.Core.Semantics
import Verity.EVM.Uint256
import Verity.Macro
import Verity.Stdlib.Math

/-!
# SimpleBank as a Verity contract

A port of `src/SimpleBank.sol` into Verity's Lean 4 EDSL. This is a
re-implementation, not a translation of the Solidity source: the EDSL
declaration below *is* the implementation, and `SimpleBank.spec` is the
compiler input that Verity lowers toward Yul.

The credit ledger is ported exactly. The native ETH movement is not, because
the EDSL has no statement that sends value; see `README.md` for what that
costs. `deposit` is `payable` and reads `msgValue`, so the incoming half of
the ETH accounting is modelled; the outgoing `transfer` of
`SimpleBank.withdraw` has no counterpart here.

Solidity reference:

```solidity
mapping(address => uint256) public balances;

function deposit() external payable {
    balances[msg.sender] += msg.value;
}

function withdraw(uint256 amount) external {
    require(balances[msg.sender] >= amount);
    balances[msg.sender] -= amount;
    payable(msg.sender).transfer(amount);
}
```
-/

namespace SimpleBankVerity

open Verity hiding pure bind
open Verity.EVM.Uint256
open Verity.Stdlib.Math

verity_contract SimpleBank where
  storage
    balances : Address → Uint256 := slot 0

  -- `balances[msg.sender] += msg.value`. Solidity 0.8 checked arithmetic
  -- reverts on overflow, so the `+=` is a `safeAdd` guarded by
  -- `requireSomeUint` rather than a wrapping `add`.
  function payable deposit () : Unit := do
    let sender ← msgSender
    let value ← msgValue
    let credit ← getMapping balances sender
    let credited ← requireSomeUint (safeAdd credit value) "Credit overflow"
    setMapping balances sender credited

  -- `require(balances[msg.sender] >= amount); balances[msg.sender] -= amount;`
  -- The guard makes the debit exact, so the wrapping `sub` cannot underflow.
  -- The `transfer(amount)` that follows in Solidity is not expressible here.
  function withdraw (amount : Uint256) : Unit := do
    let sender ← msgSender
    let credit ← getMapping balances sender
    require (credit >= amount) "Insufficient credit"
    setMapping balances sender (sub credit amount)

  -- The getter Solidity generates for `public balances`.
  function view creditOf (account : Address) : Uint256 := do
    let credit ← getMapping balances account
    return credit

end SimpleBankVerity
