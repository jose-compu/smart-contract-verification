import SimpleBankVerity.Contract
import Verity.Core.Model.MultiContract
import Verity.Proofs.Stdlib.Automation
import Verity.Proofs.Stdlib.ListSum
import Verity.Proofs.Stdlib.Math

/-!
# What is proved about `SimpleBank`

Source-level, about the EDSL term `lake build` checks:

* `creditOf` reads the mapping and changes nothing.
* `deposit` credits `msg.sender` by `msg.value` when that does not overflow,
  and reverts when it does. It does not touch `selfBalance`: crediting the
  contract's ETH is the call frame's job, not the function body's.
* `withdraw` debits the caller iff their credit covers `amount`, changes no
  other credit, and leaves `selfBalance` where it was.

That last fact is the gap. Solidity's `withdraw` then `transfer`s the ETH.
The EDSL has no statement for that send, so a successful withdrawal here
drops the credit sum and leaves the native balance alone. `withdraw_keeps_eth`
is the kernel-checked statement of the missing transfer.

Composing `deposit` with `withCallContext` — the frame Verity installs on an
ETH-valued call, which sets `msgValue` and adds the value to `selfBalance` —
restores the coupling for the incoming direction: the caller's credit and the
contract's native balance rise by the same amount.
-/

namespace SimpleBankVerity

open Verity
open Verity.Stdlib.Math
open Verity.Proofs.Stdlib.Math (safeAdd_some safeAdd_none)
open Verity.Proofs.Stdlib.ListSum (countOcc countOccU map_sum_point_update map_sum_point_decrease)
open Verity.MultiContract
open SimpleBank

private theorem contract_pure_apply (a : Uint256) (st : ContractState) :
    (Pure.pure a : Contract Uint256) st = ContractResult.success a st := rfl

private theorem require_false_bind (f : Unit → Contract Uint256) (st : ContractState) :
    ((require false "Credit overflow" : Contract Unit) >>= f) st =
      ContractResult.revert "Credit overflow" st := by
  simp [Bind.bind, Verity.bind, Verity.require]

/-- Credits recorded for `addr`. Slot 0 is `balances`. -/
def credit (s : ContractState) (addr : Address) : Uint256 :=
  s.storageMap balances.slot addr

/-- Sum of credits over an explicit address list. -/
def creditSum (s : ContractState) (addrs : List Address) : Uint256 :=
  (addrs.map (credit s)).sum

/-! ## The compiler input -/

theorem balances_slot : balances.slot = 0 := rfl

theorem deposit_is_payable :
    (spec.functions.find? (fun f => f.name == "deposit")).map (·.isPayable) = some true := by
  native_decide

theorem withdraw_is_not_payable :
    (spec.functions.find? (fun f => f.name == "withdraw")).map (·.isPayable) = some false := by
  native_decide

theorem spec_has_no_externals : spec.externals = [] := by
  native_decide

/-! ## creditOf -/

private theorem creditOf_run (s : ContractState) (addr : Address) :
    (creditOf addr).run s = ContractResult.success (credit s addr) s := by
  verity_unfold creditOf
  simp [credit, balances]

theorem creditOf_reads (s : ContractState) (addr : Address) :
    ((creditOf addr).run s).fst = credit s addr := by
  rw [creditOf_run]; simp

theorem creditOf_preserves_state (s : ContractState) (addr : Address) :
    ((creditOf addr).run s).snd = s := by
  rw [creditOf_run]; simp

/-! ## deposit -/

private theorem deposit_unfold (s : ContractState)
    (h : (credit s s.sender : Nat) + (s.msgValue : Nat) ≤ MAX_UINT256) :
    deposit.run s = ContractResult.success ()
      { s.writeMap balances.slot s.sender (credit s s.sender + s.msgValue) with
        knownAddresses := fun slotIdx =>
          if slotIdx == balances.slot then (s.knownAddresses slotIdx).insert s.sender
          else s.knownAddresses slotIdx } := by
  have h_safe : safeAdd (s.storageMap balances.slot s.sender) s.msgValue =
      some (credit s s.sender + s.msgValue) := by
    unfold credit
    exact safeAdd_some _ _ h
  verity_unfold deposit
  simp only [msgValue]
  rw [h_safe]
  simp [requireSomeUint, contract_pure_apply, credit]

theorem deposit_succeeds (s : ContractState)
    (h : (credit s s.sender : Nat) + (s.msgValue : Nat) ≤ MAX_UINT256) :
    ∃ post, deposit.run s = ContractResult.success () post := by
  exact ⟨_, deposit_unfold s h⟩

theorem deposit_credits_sender (s : ContractState)
    (h : (credit s s.sender : Nat) + (s.msgValue : Nat) ≤ MAX_UINT256) :
    credit (deposit.run s).snd s.sender = credit s s.sender + s.msgValue := by
  rw [deposit_unfold s h]
  simp [credit, ContractResult.snd, ContractState.writeMap, ContractState.storageMap]

theorem deposit_preserves_other (s : ContractState)
    (h : (credit s s.sender : Nat) + (s.msgValue : Nat) ≤ MAX_UINT256)
    (addr : Address) (h_ne : addr ≠ s.sender) :
    credit (deposit.run s).snd addr = credit s addr := by
  rw [deposit_unfold s h]
  simp [credit, ContractResult.snd, ContractState.writeMap, ContractState.storageMap, h_ne]

theorem deposit_reverts_on_overflow (s : ContractState)
    (h : (credit s s.sender : Nat) + (s.msgValue : Nat) > MAX_UINT256) :
    ∃ msg, deposit.run s = ContractResult.revert msg s := by
  have h_safe : safeAdd (s.storageMap balances.slot s.sender) s.msgValue = none := by
    unfold credit at h
    exact safeAdd_none _ _ h
  verity_unfold deposit
  simp only [msgValue]
  rw [h_safe]
  simp [requireSomeUint, require_false_bind]

/-- The function body never moves ETH. The credit changes; `selfBalance` does not. -/
theorem deposit_preserves_selfBalance (s : ContractState)
    (h : (credit s s.sender : Nat) + (s.msgValue : Nat) ≤ MAX_UINT256) :
    (deposit.run s).snd.selfBalance = s.selfBalance := by
  rw [deposit_unfold s h]
  simp [ContractResult.snd, ContractState.writeMap]

theorem deposit_sum_equation (s : ContractState)
    (h : (credit s s.sender : Nat) + (s.msgValue : Nat) ≤ MAX_UINT256) :
    ∀ addrs : List Address,
      creditSum (deposit.run s).snd addrs =
        creditSum s addrs + countOccU s.sender addrs * s.msgValue := by
  intro addrs
  unfold creditSum
  have h_inc : credit (deposit.run s).snd s.sender = credit s s.sender + s.msgValue :=
    deposit_credits_sender s h
  have h_other : ∀ addr, addr ≠ s.sender → credit (deposit.run s).snd addr = credit s addr :=
    fun addr h_ne => deposit_preserves_other s h addr h_ne
  exact map_sum_point_update (credit s) (credit (deposit.run s).snd) s.sender s.msgValue h_inc h_other addrs

/-! ## withdraw -/

private theorem withdraw_unfold (s : ContractState) (amount : Uint256)
    (h : credit s s.sender ≥ amount) :
    (withdraw amount).run s = ContractResult.success ()
      { s.writeMap balances.slot s.sender (EVM.Uint256.sub (credit s s.sender) amount) with
        knownAddresses := fun slotIdx =>
          if slotIdx == balances.slot then (s.knownAddresses slotIdx).insert s.sender
          else s.knownAddresses slotIdx } := by
  have h_yes : decide (s.storageMap balances.slot s.sender ≥ amount) = true := by
    unfold credit at h
    exact decide_eq_true h
  verity_unfold withdraw
  rw [h_yes]
  simp [credit]

theorem withdraw_succeeds (s : ContractState) (amount : Uint256)
    (h : credit s s.sender ≥ amount) :
    ∃ post, (withdraw amount).run s = ContractResult.success () post := by
  exact ⟨_, withdraw_unfold s amount h⟩

theorem withdraw_debits_sender (s : ContractState) (amount : Uint256)
    (h : credit s s.sender ≥ amount) :
    credit ((withdraw amount).run s).snd s.sender =
      EVM.Uint256.sub (credit s s.sender) amount := by
  rw [withdraw_unfold s amount h]
  simp [credit, ContractResult.snd, ContractState.writeMap, ContractState.storageMap]

theorem withdraw_preserves_other (s : ContractState) (amount : Uint256)
    (h : credit s s.sender ≥ amount)
    (addr : Address) (h_ne : addr ≠ s.sender) :
    credit ((withdraw amount).run s).snd addr = credit s addr := by
  rw [withdraw_unfold s amount h]
  simp [credit, ContractResult.snd, ContractState.writeMap, ContractState.storageMap, h_ne]

theorem withdraw_reverts_when_short (s : ContractState) (amount : Uint256)
    (h : ¬ credit s s.sender ≥ amount) :
    ∃ msg, (withdraw amount).run s = ContractResult.revert msg s := by
  have h_no : decide (s.storageMap balances.slot s.sender ≥ amount) = false := by
    unfold credit at h
    exact decide_eq_false h
  verity_unfold withdraw
  rw [h_no]
  simp

/-- Successful withdrawal leaves the contract's ETH where it was. -/
theorem withdraw_preserves_selfBalance (s : ContractState) (amount : Uint256)
    (h : credit s s.sender ≥ amount) :
    ((withdraw amount).run s).snd.selfBalance = s.selfBalance := by
  rw [withdraw_unfold s amount h]
  simp [ContractResult.snd, ContractState.writeMap]

theorem withdraw_sum_equation (s : ContractState) (amount : Uint256)
    (h : credit s s.sender ≥ amount) :
    ∀ addrs : List Address,
      creditSum ((withdraw amount).run s).snd addrs + countOccU s.sender addrs * amount =
        creditSum s addrs := by
  intro addrs
  unfold creditSum
  have h_dec : credit ((withdraw amount).run s).snd s.sender = credit s s.sender - amount := by
    rw [withdraw_debits_sender s amount h]
    unfold EVM.Uint256.sub
    rfl
  have h_other : ∀ addr, addr ≠ s.sender →
      credit ((withdraw amount).run s).snd addr = credit s addr :=
    fun addr h_ne => withdraw_preserves_other s amount h addr h_ne
  exact map_sum_point_decrease (credit s) (credit ((withdraw amount).run s).snd)
    s.sender amount h_dec h_other addrs

/--
  The missing `transfer`. After a successful `withdraw` of `amount` by an
  address that occurs once in `addrs`, the credit sum is `amount` smaller and
  the native balance is unchanged. In Solidity those two move together.
-/
theorem withdraw_keeps_eth (s : ContractState) (amount : Uint256)
    (h : credit s s.sender ≥ amount)
    (addrs : List Address) (h_once : countOcc s.sender addrs = 1) :
    creditSum ((withdraw amount).run s).snd addrs + amount = creditSum s addrs ∧
      ((withdraw amount).run s).snd.selfBalance = s.selfBalance := by
  refine ⟨?_, withdraw_preserves_selfBalance s amount h⟩
  have h_sum := withdraw_sum_equation s amount h addrs
  simp [countOccU, h_once] at h_sum
  simpa [Verity.Core.Uint256.add_comm] using h_sum

/-! ## Deposit composed with an ETH-valued call frame -/

/-- Run `deposit` in the frame Verity installs for a call carrying `value`. -/
def depositFrom (pre : ContractState) (caller : Address) (value : Uint256) : ContractResult Unit :=
  deposit.run (withCallContext pre caller pre.thisAddress value)

theorem deposit_frame_msgValue (pre : ContractState) (caller : Address) (value : Uint256) :
    (withCallContext pre caller pre.thisAddress value).msgValue = value :=
  withCallContext_msgValue pre caller pre.thisAddress value

theorem deposit_frame_balance (pre : ContractState) (caller : Address) (value : Uint256) :
    (withCallContext pre caller pre.thisAddress value).selfBalance = pre.selfBalance + value :=
  withCallContext_selfBalance pre caller pre.thisAddress value

/--
  Incoming ETH, the direction the EDSL can express. Once the call frame has
  credited `value` to the contract, `deposit` credits the caller by the same
  `value`, and the native balance stays at the frame's post-credit value.
-/
theorem deposit_matches_value_received (pre : ContractState) (caller : Address) (value : Uint256)
    (h : (credit pre caller : Nat) + (value : Nat) ≤ MAX_UINT256) :
    let result := depositFrom pre caller value
    credit result.snd caller = credit pre caller + value ∧
      result.snd.selfBalance = pre.selfBalance + value := by
  let entry := withCallContext pre caller pre.thisAddress value
  have h_sender : entry.sender = caller := withCallContext_sender pre caller pre.thisAddress value
  have h_msg : entry.msgValue = value := deposit_frame_msgValue pre caller value
  have h_bal : entry.selfBalance = pre.selfBalance + value := deposit_frame_balance pre caller value
  have h_credit : credit entry caller = credit pre caller := by
    simp [credit, entry, withCallContext, ContractState.storageMap]
  have h_ok : (credit entry entry.sender : Nat) + (entry.msgValue : Nat) ≤ MAX_UINT256 := by
    simpa [h_sender, h_msg, h_credit] using h
  refine ⟨?_, ?_⟩
  · have h_inc := deposit_credits_sender entry h_ok
    simpa [depositFrom, h_sender, h_msg, h_credit] using h_inc
  · unfold depositFrom
    rw [deposit_preserves_selfBalance entry h_ok]
    exact h_bal

/-! ## The deployed contract starts solvent -/

theorem init_credits_zero (addr : Address) : credit defaultState addr = 0 := rfl

theorem init_balance_zero : defaultState.selfBalance = 0 := rfl

theorem init_creditSum_zero (addrs : List Address) : creditSum defaultState addrs = 0 := by
  unfold creditSum
  induction addrs with
  | nil => simp
  | cons a rest ih => simp [init_credits_zero, ih]

end SimpleBankVerity
