/-
  Lean 4 model of `src/SimpleBank.sol`.

  Interactive theorem proving: https://lean-lang.org/
  Abstract vault (credits + reserves), not an EVM interpreter.
  Wei is `Nat` (unbounded). Solidity `uint256` overflow is not modelled.
-/

namespace SimpleBank

abbrev Address := Nat
abbrev Wei := Nat

/-- Vault state. `accepting a = false` means `transfer` to `a` reverts. -/
structure State where
  credit : Address → Wei
  reserves : Wei
  accepting : Address → Bool

/-- `deposit()`: credit `msg.value` to the caller and take the ETH. -/
def deposit (s : State) (sender : Address) (value : Wei) : State :=
  { s with
    credit := fun a => if a = sender then s.credit a + value else s.credit a
    reserves := s.reserves + value }

inductive Result where
  | ok : State → Result
  | revert : Result

/-- `withdraw(amount)`: require credit, then `transfer`. Failed transfer reverts. -/
def withdraw (s : State) (sender : Address) (amount : Wei) : Result :=
  if s.credit sender < amount then
    .revert
  else if s.accepting sender = false then
    .revert
  else
    .ok
      { s with
        credit := fun a => if a = sender then s.credit a - amount else s.credit a
        reserves := s.reserves - amount }

def creditSum (credit : Address → Wei) : List Address → Wei
  | [] => 0
  | a :: as => credit a + creditSum credit as

theorem withdraw_ok_inv {s s' : State} {sender : Address} {amount : Wei}
    (hok : withdraw s sender amount = .ok s') :
    amount ≤ s.credit sender ∧
      s.accepting sender = true ∧
      s' =
        { s with
          credit := fun a => if a = sender then s.credit a - amount else s.credit a
          reserves := s.reserves - amount } := by
  unfold withdraw at hok
  by_cases hlt : s.credit sender < amount
  · simp [hlt] at hok
  · simp [hlt] at hok
    by_cases hacc : s.accepting sender = false
    · simp [hacc] at hok
    · simp [hacc] at hok
      cases hok
      refine ⟨Nat.not_lt.mp hlt, ?_, rfl⟩
      cases hs : s.accepting sender
      · exact (hacc hs).elim
      · rfl

/-- P1: deposit of `v` increases the caller's credit and the vault reserves by `v`. -/
theorem P1_deposit_credits_caller_and_reserves
    (s : State) (sender : Address) (value : Wei) :
    (deposit s sender value).credit sender = s.credit sender + value ∧
      (deposit s sender value).reserves = s.reserves + value := by
  simp [deposit]

/-- P2: withdraw succeeds iff credit covers `amount` and the receiver accepts ETH. -/
theorem P2_withdraw_succeeds_iff
    (s : State) (sender : Address) (amount : Wei) :
    (∃ s', withdraw s sender amount = .ok s') ↔
      amount ≤ s.credit sender ∧ s.accepting sender = true := by
  constructor
  · intro ⟨_, hok⟩
    exact ⟨(withdraw_ok_inv hok).1, (withdraw_ok_inv hok).2.1⟩
  · intro ⟨hle, hacc⟩
    have hlt : ¬ s.credit sender < amount := Nat.not_lt.mpr hle
    have hf : ¬ s.accepting sender = false := by
      intro h
      simp [h] at hacc
    exact ⟨
      { s with
        credit := fun a => if a = sender then s.credit a - amount else s.credit a
        reserves := s.reserves - amount },
      by simp [withdraw, hlt, hf]⟩

/-- P3 (deposit): another address's credit is unchanged. -/
theorem P3_deposit_preserves_other
    (s : State) (sender other : Address) (value : Wei) (h : sender ≠ other) :
    (deposit s sender value).credit other = s.credit other := by
  simp [deposit, h.symm]

/-- P3 (withdraw): on success, another address's credit is unchanged. -/
theorem P3_withdraw_ok_preserves_other
    (s : State) (sender other : Address) (amount : Wei) (s' : State)
    (hok : withdraw s sender amount = .ok s') (h : sender ≠ other) :
    s'.credit other = s.credit other := by
  have ⟨_, _, hs⟩ := withdraw_ok_inv hok
  simp [hs, h.symm]

/-- P5: a rejecting receiver cannot withdraw. -/
theorem P5_rejecting_reverts
    (s : State) (sender : Address) (amount : Wei)
    (h : s.accepting sender = false) :
    withdraw s sender amount = .revert := by
  unfold withdraw
  by_cases hlt : s.credit sender < amount
  · simp [hlt]
  · simp [hlt, h]

theorem creditSum_not_mem
    (credit : Address → Wei) (sender : Address) (newVal : Wei) (xs : List Address)
    (h : sender ∉ xs) :
    creditSum (fun a => if a = sender then newVal else credit a) xs = creditSum credit xs := by
  induction xs with
  | nil =>
    rfl
  | cons a as ih =>
    have hne : a ≠ sender := by
      intro e
      subst e
      exact h (List.mem_cons_self)
    have htl : sender ∉ as := fun m => h (List.mem_cons_of_mem a m)
    simp [creditSum, hne]
    exact ih htl

theorem pairwise_head_not_mem {a : Address} {as : List Address}
    (h : (a :: as).Pairwise (· ≠ ·)) : a ∉ as := by
  intro m
  cases h with
  | cons hall _ =>
    exact (hall a m) rfl

theorem pairwise_tail {a : Address} {as : List Address}
    (h : (a :: as).Pairwise (· ≠ ·)) : as.Pairwise (· ≠ ·) := by
  cases h with
  | cons _ htail =>
    exact htail

theorem credit_le_sum (credit : Address → Wei) (sender : Address) (xs : List Address)
    (hmem : sender ∈ xs) : credit sender ≤ creditSum credit xs := by
  induction xs with
  | nil =>
    simp at hmem
  | cons b bs ih =>
    simp [creditSum, List.mem_cons] at hmem ⊢
    rcases hmem with h | hm
    · subst h
      exact Nat.le_add_right _ _
    · exact Nat.le_trans (ih hm) (Nat.le_add_left _ _)

theorem add_sub_sub_add {x y a : Nat} (ha_y : a ≤ y) (ha_x : a ≤ x) :
    x + (y - a) = x - a + y := by
  rw [← Nat.add_sub_assoc ha_y, Nat.sub_add_comm ha_x]

theorem creditSum_mem
    (credit : Address → Wei) (sender : Address) (newVal : Wei) (xs : List Address)
    (hmem : sender ∈ xs) (hnd : xs.Pairwise (· ≠ ·)) :
    creditSum (fun a => if a = sender then newVal else credit a) xs + credit sender =
      creditSum credit xs + newVal := by
  revert hmem hnd
  induction xs with
  | nil =>
    intro hmem _hnd
    simp at hmem
  | cons a as ih =>
    intro hmem hnd
    simp [List.mem_cons] at hmem
    rcases hmem with h | hmem'
    · subst h
      have hnin : sender ∉ as := pairwise_head_not_mem hnd
      simp [creditSum, creditSum_not_mem credit sender newVal as hnin]
      ac_rfl
    · have hne : a ≠ sender := by
        intro e
        subst e
        exact pairwise_head_not_mem hnd hmem'
      have hih := ih hmem' (pairwise_tail hnd)
      change
        (if a = sender then newVal else credit a) + creditSum (fun b => if b = sender then newVal else credit b) as +
            credit sender =
          credit a + creditSum credit as + newVal
      rw [if_neg hne, Nat.add_assoc, Nat.add_assoc]
      exact congrArg (credit a + ·) hih

/-- P4: deposit preserves solvency on a duplicate-free support that contains the sender. -/
theorem P4_deposit_preserves_solvency
    (s : State) (sender : Address) (value : Wei) (xs : List Address)
    (hmem : sender ∈ xs) (hnd : xs.Pairwise (· ≠ ·))
    (hsol : s.reserves = creditSum s.credit xs) :
    (deposit s sender value).reserves = creditSum (deposit s sender value).credit xs := by
  have hfun :
      (fun a => if a = sender then s.credit a + value else s.credit a) =
        fun a => if a = sender then s.credit sender + value else s.credit a := by
    funext a
    by_cases h : a = sender
    · simp [h]
    · simp [h]
  have hsum := creditSum_mem s.credit sender (s.credit sender + value) xs hmem hnd
  have hA :
      creditSum (fun a => if a = sender then s.credit sender + value else s.credit a) xs =
        creditSum s.credit xs + value := by
    have h' :
        creditSum (fun a => if a = sender then s.credit sender + value else s.credit a) xs +
            s.credit sender =
          creditSum s.credit xs + value + s.credit sender := by
      rw [Nat.add_assoc]
      simpa [Nat.add_comm, Nat.add_left_comm] using hsum
    exact Nat.add_right_cancel h'
  simp [deposit, hsol, hfun, hA]

/-- P4: a successful withdraw preserves solvency on the same support. -/
theorem P4_withdraw_preserves_solvency
    (s : State) (sender : Address) (amount : Wei) (s' : State) (xs : List Address)
    (hok : withdraw s sender amount = .ok s')
    (hmem : sender ∈ xs) (hnd : xs.Pairwise (· ≠ ·))
    (hsol : s.reserves = creditSum s.credit xs) :
    s'.reserves = creditSum s'.credit xs := by
  obtain ⟨hle, _, hs⟩ := withdraw_ok_inv hok
  have hfun :
      (fun a => if a = sender then s.credit a - amount else s.credit a) =
        fun a => if a = sender then s.credit sender - amount else s.credit a := by
    funext a
    by_cases h : a = sender
    · simp [h]
    · simp [h]
  have hsum := creditSum_mem s.credit sender (s.credit sender - amount) xs hmem hnd
  have hA :
      creditSum (fun a => if a = sender then s.credit sender - amount else s.credit a) xs =
        creditSum s.credit xs - amount := by
    have h' :
        creditSum (fun a => if a = sender then s.credit sender - amount else s.credit a) xs +
            s.credit sender =
          creditSum s.credit xs - amount + s.credit sender := by
      have hid :
          creditSum s.credit xs + (s.credit sender - amount) =
            creditSum s.credit xs - amount + s.credit sender :=
        add_sub_sub_add hle (Nat.le_trans hle (credit_le_sum s.credit sender xs hmem))
      exact hsum.trans hid
    exact Nat.add_right_cancel h'
  subst hs
  simp [hsol, hfun, hA]

end SimpleBank
