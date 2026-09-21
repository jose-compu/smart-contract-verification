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
    (hmem : sender ∈ xs) (hnd : xs.Nodup) :
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
      have hnin : sender ∉ as := (List.nodup_cons.mp hnd).1
      simp [creditSum, creditSum_not_mem credit sender newVal as hnin]
      ac_rfl
    · have hne : a ≠ sender := by
        intro e
        subst e
        exact (List.nodup_cons.mp hnd).1 hmem'
      have hih := ih hmem' (List.nodup_cons.mp hnd).2
      change
        (if a = sender then newVal else credit a) + creditSum (fun b => if b = sender then newVal else credit b) as +
            credit sender =
          credit a + creditSum credit as + newVal
      rw [if_neg hne, Nat.add_assoc, Nat.add_assoc]
      exact congrArg (credit a + ·) hih

/-- P4: deposit preserves solvency on a duplicate-free support that contains the sender. -/
theorem P4_deposit_preserves_solvency
    (s : State) (sender : Address) (value : Wei) (xs : List Address)
    (hmem : sender ∈ xs) (hnd : xs.Nodup)
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
    (hmem : sender ∈ xs) (hnd : xs.Nodup)
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

/-- On a solvent vault a successful withdraw is covered by the reserves. The
    `transfer` reserve shortfall cannot arise and `reserves - amount` is exact. -/
theorem withdraw_ok_amount_le_reserves
    (s : State) (sender : Address) (amount : Wei) (s' : State) (xs : List Address)
    (hok : withdraw s sender amount = .ok s')
    (hmem : sender ∈ xs) (hsol : s.reserves = creditSum s.credit xs) :
    amount ≤ s.reserves := by
  obtain ⟨hle, _, _⟩ := withdraw_ok_inv hok
  rw [hsol]
  exact Nat.le_trans hle (credit_le_sum s.credit sender xs hmem)

/-- A transaction against the vault. -/
inductive Op where
  | deposit (sender : Address) (value : Wei)
  | withdraw (sender : Address) (amount : Wei)

/-- The caller of a transaction. -/
def Op.sender : Op → Address
  | .deposit a _ => a
  | .withdraw a _ => a

/-- One transaction. A reverted `withdraw` leaves the state untouched. -/
def step (s : State) : Op → State
  | .deposit sender value => deposit s sender value
  | .withdraw sender amount =>
    match withdraw s sender amount with
    | .ok s' => s'
    | .revert => s

/-- A sequence of transactions, applied left to right. -/
def run (s : State) : List Op → State
  | [] => s
  | o :: os => run (step s o) os

theorem creditSum_zero (xs : List Address) : creditSum (fun _ => 0) xs = 0 := by
  induction xs with
  | nil => rfl
  | cons a as ih => simp [creditSum, ih]

/-- The deployed vault: no credit, no reserves, arbitrary receivers. -/
def init (accepting : Address → Bool) : State :=
  { credit := fun _ => 0, reserves := 0, accepting := accepting }

/-- P4: the deployed vault is solvent on every support. -/
theorem P4_init_solvent (accepting : Address → Bool) (xs : List Address) :
    (init accepting).reserves = creditSum (init accepting).credit xs := by
  simp [init, creditSum_zero]

/-- P4 over traces: any sequence of transactions whose callers lie in the support
    preserves solvency. -/
theorem P4_run_preserves_solvency (xs : List Address) (hnd : xs.Nodup) :
    ∀ ops : List Op, (∀ o ∈ ops, o.sender ∈ xs) →
      ∀ s : State, s.reserves = creditSum s.credit xs →
        (run s ops).reserves = creditSum (run s ops).credit xs := by
  intro ops
  induction ops with
  | nil =>
    intro _ s hsol
    simpa [run] using hsol
  | cons o os ih =>
    intro hall s hsol
    have hmem : o.sender ∈ xs := hall o (List.mem_cons_self)
    have htl : ∀ p ∈ os, p.sender ∈ xs := fun p hp => hall p (List.mem_cons_of_mem o hp)
    have hstep : (step s o).reserves = creditSum (step s o).credit xs := by
      cases o with
      | deposit sender value =>
        exact P4_deposit_preserves_solvency s sender value xs hmem hnd hsol
      | withdraw sender amount =>
        simp only [step]
        cases hw : withdraw s sender amount with
        | ok s' =>
          exact P4_withdraw_preserves_solvency s sender amount s' xs hw hmem hnd hsol
        | revert => exact hsol
    simpa [run] using ih htl (step s o) hstep

/-- P4: every state reachable from the deployed vault is solvent. Solvency is a
    conclusion here, not a hypothesis. -/
theorem P4_reachable_solvent
    (accepting : Address → Bool) (ops : List Op) (xs : List Address) (hnd : xs.Nodup)
    (hall : ∀ o ∈ ops, o.sender ∈ xs) :
    (run (init accepting) ops).reserves = creditSum (run (init accepting) ops).credit xs :=
  P4_run_preserves_solvency xs hnd ops hall (init accepting) (P4_init_solvent accepting xs)

/-- P2 on reachable states: a successful withdraw never exceeds the reserves, so the
    `transfer` reserve shortfall omitted from `withdraw` is unreachable. -/
theorem P2_reachable_withdraw_within_reserves
    (accepting : Address → Bool) (ops : List Op) (xs : List Address) (hnd : xs.Nodup)
    (hall : ∀ o ∈ ops, o.sender ∈ xs) (sender : Address) (hmem : sender ∈ xs)
    (amount : Wei) (s' : State)
    (hok : withdraw (run (init accepting) ops) sender amount = .ok s') :
    amount ≤ (run (init accepting) ops).reserves :=
  withdraw_ok_amount_le_reserves _ sender amount s' xs hok hmem
    (P4_reachable_solvent accepting ops xs hnd hall)

end SimpleBank
