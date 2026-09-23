(* SPDX-License-Identifier: Apache-2.0 *)

(** Coq model of [src/SimpleBank.sol].

    Interactive theorem proving. Abstract vault (credits, reserves, an
    accepting flag), not an EVM interpreter. Wei is [nat]: unbounded, so
    Solidity [uint256] overflow is not modelled. *)

From Coq Require Import List Arith PeanoNat Lia Bool.
Import ListNotations.

Definition Address : Type := nat.
Definition Wei : Type := nat.

Record State : Type := {
  credit : Address -> Wei;
  reserves : Wei;
  accepting : Address -> bool
}.

Definition set_credit (c : Address -> Wei) (sender : Address) (v : Wei)
  : Address -> Wei :=
  fun a => if a =? sender then v else c a.

(** [deposit()]: credit [msg.value] to the caller and take the ETH. *)
Definition deposit (s : State) (sender : Address) (value : Wei) : State :=
  {| credit := set_credit (credit s) sender (credit s sender + value);
     reserves := reserves s + value;
     accepting := accepting s |}.

Inductive Result : Type :=
  | Ok : State -> Result
  | Revert : Result.

(** [withdraw(amount)]: require credit, then [transfer].
    A receiver with [accepting sender = false] reverts. *)
Definition withdraw (s : State) (sender : Address) (amount : Wei) : Result :=
  if credit s sender <? amount then Revert
  else if negb (accepting s sender) then Revert
  else Ok {| credit := set_credit (credit s) sender (credit s sender - amount);
             reserves := reserves s - amount;
             accepting := accepting s |}.

Fixpoint creditSum (c : Address -> Wei) (xs : list Address) : Wei :=
  match xs with
  | [] => 0
  | a :: tl => c a + creditSum c tl
  end.

Lemma withdraw_ok_inv :
  forall s s' sender amount,
    withdraw s sender amount = Ok s' ->
    amount <= credit s sender /\
    accepting s sender = true /\
    s' = {| credit := set_credit (credit s) sender (credit s sender - amount);
            reserves := reserves s - amount;
            accepting := accepting s |}.
Proof.
  intros s s' sender amount H.
  unfold withdraw in H.
  destruct (credit s sender <? amount) eqn:Hlt.
  - discriminate H.
  - apply Nat.ltb_ge in Hlt.
    destruct (accepting s sender) eqn:Hacc.
    + simpl in H. injection H as <-. repeat split; assumption.
    + simpl in H. discriminate H.
Qed.

(** P1: deposit of [v] increases the caller's credit and the reserves by [v]. *)
Theorem P1_deposit_credits_caller_and_reserves :
  forall s sender value,
    credit (deposit s sender value) sender = credit s sender + value /\
    reserves (deposit s sender value) = reserves s + value.
Proof.
  intros s sender value.
  unfold deposit, set_credit. simpl.
  rewrite Nat.eqb_refl.
  split; reflexivity.
Qed.

(** P2: withdraw succeeds iff credit covers [amount] and the receiver accepts. *)
Theorem P2_withdraw_succeeds_iff :
  forall s sender amount,
    (exists s', withdraw s sender amount = Ok s') <->
    (amount <= credit s sender /\ accepting s sender = true).
Proof.
  intros s sender amount. split.
  - intros [s' Hok].
    destruct (withdraw_ok_inv s s' sender amount Hok) as [Hle [Hacc _]].
    split; assumption.
  - intros [Hle Hacc].
    exists {| credit := set_credit (credit s) sender (credit s sender - amount);
              reserves := reserves s - amount;
              accepting := accepting s |}.
    unfold withdraw.
    destruct (credit s sender <? amount) eqn:Hlt.
    + apply Nat.ltb_lt in Hlt. lia.
    + rewrite Hacc. simpl. reflexivity.
Qed.

(** P3 (deposit): another address's credit is unchanged. *)
Theorem P3_deposit_preserves_other :
  forall s sender other value,
    sender <> other ->
    credit (deposit s sender value) other = credit s other.
Proof.
  intros s sender other value Hneq.
  unfold deposit, set_credit. simpl.
  rewrite (proj2 (Nat.eqb_neq other sender)).
  - reflexivity.
  - intros Heq. apply Hneq. symmetry. assumption.
Qed.

(** P3 (withdraw): on success, another address's credit is unchanged. *)
Theorem P3_withdraw_ok_preserves_other :
  forall s sender other amount s',
    withdraw s sender amount = Ok s' ->
    sender <> other ->
    credit s' other = credit s other.
Proof.
  intros s sender other amount s' Hok Hneq.
  destruct (withdraw_ok_inv s s' sender amount Hok) as [_ [_ ->]].
  simpl. unfold set_credit.
  rewrite (proj2 (Nat.eqb_neq other sender)).
  - reflexivity.
  - intros Heq. apply Hneq. symmetry. assumption.
Qed.

(** P5: a rejecting receiver cannot withdraw. *)
Theorem P5_rejecting_reverts :
  forall s sender amount,
    accepting s sender = false ->
    withdraw s sender amount = Revert.
Proof.
  intros s sender amount Hrej.
  unfold withdraw.
  destruct (credit s sender <? amount).
  - reflexivity.
  - rewrite Hrej. simpl. reflexivity.
Qed.

Lemma creditSum_not_mem :
  forall c sender newVal xs,
    ~ In sender xs ->
    creditSum (set_credit c sender newVal) xs = creditSum c xs.
Proof.
  intros c sender newVal xs. induction xs as [|a tl IH]; intros Hnin.
  - reflexivity.
  - simpl.
    assert (Hneq : a <> sender).
    { intros Heq. apply Hnin. subst a. left. reflexivity. }
    assert (Htl : ~ In sender tl).
    { intros Hin. apply Hnin. right. assumption. }
    unfold set_credit at 1.
    rewrite (proj2 (Nat.eqb_neq a sender) Hneq).
    f_equal. apply IH. assumption.
Qed.

Lemma credit_le_sum :
  forall c sender xs,
    In sender xs ->
    c sender <= creditSum c xs.
Proof.
  intros c sender xs. induction xs as [|b tl IH]; simpl; intros Hin.
  - contradiction.
  - destruct Hin as [->|Hin].
    + lia.
    + specialize (IH Hin). lia.
Qed.

Lemma creditSum_set_plus :
  forall c sender newVal xs,
    In sender xs ->
    NoDup xs ->
    creditSum (set_credit c sender newVal) xs + c sender =
    creditSum c xs + newVal.
Proof.
  intros c sender newVal xs.
  induction xs as [|a tl IH]; intros Hin Hnd.
  - contradiction.
  - apply NoDup_cons_iff in Hnd. destruct Hnd as [Hnin Hnd].
    simpl.
    destruct Hin as [Ha|Hin].
    + subst a.
      replace (set_credit c sender newVal sender) with newVal.
      2: { unfold set_credit. rewrite Nat.eqb_refl. reflexivity. }
      rewrite (creditSum_not_mem c sender newVal tl Hnin).
      lia.
    + assert (Hneq : a <> sender).
      { intros Heq. apply Hnin. subst a. exact Hin. }
      replace (set_credit c sender newVal a) with (c a).
      2: {
        unfold set_credit.
        rewrite (proj2 (Nat.eqb_neq a sender) Hneq).
        reflexivity.
      }
      specialize (IH Hin Hnd).
      lia.
Qed.

(** P4: deposit preserves solvency on a duplicate-free support that contains the sender. *)
Theorem P4_deposit_preserves_solvency :
  forall s sender value xs,
    In sender xs ->
    NoDup xs ->
    reserves s = creditSum (credit s) xs ->
    reserves (deposit s sender value) =
    creditSum (credit (deposit s sender value)) xs.
Proof.
  intros s sender value xs Hin Hnd Hsol.
  unfold deposit. simpl.
  assert (Hsum :=
    creditSum_set_plus (credit s) sender (credit s sender + value) xs Hin Hnd).
  assert (Hcut :
    creditSum (set_credit (credit s) sender (credit s sender + value)) xs =
    creditSum (credit s) xs + value) by lia.
  rewrite Hcut, Hsol. reflexivity.
Qed.

(** P4: a successful withdraw preserves solvency on the same support. *)
Theorem P4_withdraw_preserves_solvency :
  forall s sender amount s' xs,
    withdraw s sender amount = Ok s' ->
    In sender xs ->
    NoDup xs ->
    reserves s = creditSum (credit s) xs ->
    reserves s' = creditSum (credit s') xs.
Proof.
  intros s sender amount s' xs Hok Hin Hnd Hsol.
  destruct (withdraw_ok_inv s s' sender amount Hok) as [Hle [_ ->]].
  simpl.
  assert (Hsum :=
    creditSum_set_plus (credit s) sender (credit s sender - amount) xs Hin Hnd).
  assert (Hle_sum : amount <= creditSum (credit s) xs).
  { apply Nat.le_trans with (m := credit s sender).
    - exact Hle.
    - apply credit_le_sum. exact Hin. }
  assert (Hcut :
    creditSum (set_credit (credit s) sender (credit s sender - amount)) xs =
    creditSum (credit s) xs - amount) by lia.
  rewrite Hcut, Hsol. reflexivity.
Qed.

(** On a solvent vault a successful withdraw is covered by the reserves. *)
Theorem withdraw_ok_amount_le_reserves :
  forall s sender amount s' xs,
    withdraw s sender amount = Ok s' ->
    In sender xs ->
    reserves s = creditSum (credit s) xs ->
    amount <= reserves s.
Proof.
  intros s sender amount s' xs Hok Hin Hsol.
  destruct (withdraw_ok_inv s s' sender amount Hok) as [Hle _].
  rewrite Hsol.
  apply Nat.le_trans with (m := credit s sender).
  - exact Hle.
  - apply credit_le_sum. exact Hin.
Qed.

Inductive Op : Type :=
  | Deposit (sender : Address) (value : Wei)
  | Withdraw (sender : Address) (amount : Wei).

Definition op_sender (o : Op) : Address :=
  match o with
  | Deposit a _ => a
  | Withdraw a _ => a
  end.

(** One transaction. A reverted withdraw leaves the state untouched. *)
Definition step (s : State) (o : Op) : State :=
  match o with
  | Deposit sender value => deposit s sender value
  | Withdraw sender amount =>
      match withdraw s sender amount with
      | Ok s' => s'
      | Revert => s
      end
  end.

Fixpoint run (s : State) (ops : list Op) : State :=
  match ops with
  | [] => s
  | o :: tl => run (step s o) tl
  end.

Lemma creditSum_zero : forall xs, creditSum (fun _ => 0) xs = 0.
Proof.
  induction xs as [|a tl IH]; simpl.
  - reflexivity.
  - rewrite IH. reflexivity.
Qed.

(** The deployed vault: no credit, no reserves, arbitrary receivers. *)
Definition init (acc : Address -> bool) : State :=
  {| credit := fun _ => 0; reserves := 0; accepting := acc |}.

(** P4: the deployed vault is solvent on every support. *)
Theorem P4_init_solvent :
  forall acc xs,
    reserves (init acc) = creditSum (credit (init acc)) xs.
Proof.
  intros acc xs. simpl. rewrite creditSum_zero. reflexivity.
Qed.

(** P4 over traces: any sequence whose callers lie in the support preserves solvency. *)
Theorem P4_run_preserves_solvency :
  forall xs,
    NoDup xs ->
    forall ops,
      (forall o, In o ops -> In (op_sender o) xs) ->
      forall s,
        reserves s = creditSum (credit s) xs ->
        reserves (run s ops) = creditSum (credit (run s ops)) xs.
Proof.
  intros xs Hnd ops.
  induction ops as [|o tl IH]; intros Hall s Hsol.
  - simpl. exact Hsol.
  - assert (Hin : In (op_sender o) xs) by (apply Hall; left; reflexivity).
    assert (Htl : forall p, In p tl -> In (op_sender p) xs).
    { intros p Hp. apply Hall. right. exact Hp. }
    assert (Hstep : reserves (step s o) = creditSum (credit (step s o)) xs).
    { destruct o as [sender value|sender amount].
      - simpl in Hin. apply P4_deposit_preserves_solvency; assumption.
      - simpl in Hin. unfold step.
        destruct (withdraw s sender amount) eqn:Hw.
        + apply (P4_withdraw_preserves_solvency s sender amount s0 xs Hw Hin Hnd Hsol).
        + exact Hsol. }
    simpl. apply IH; assumption.
Qed.

(** P4: every state reachable from the deployed vault is solvent. *)
Theorem P4_reachable_solvent :
  forall acc ops xs,
    NoDup xs ->
    (forall o, In o ops -> In (op_sender o) xs) ->
    reserves (run (init acc) ops) = creditSum (credit (run (init acc) ops)) xs.
Proof.
  intros acc ops xs Hnd Hall.
  apply P4_run_preserves_solvency.
  - exact Hnd.
  - exact Hall.
  - apply P4_init_solvent.
Qed.

(** P2 on reachable states: a successful withdraw never exceeds the reserves. *)
Theorem P2_reachable_withdraw_within_reserves :
  forall acc ops xs,
    NoDup xs ->
    (forall o, In o ops -> In (op_sender o) xs) ->
    forall sender amount s',
      In sender xs ->
      withdraw (run (init acc) ops) sender amount = Ok s' ->
      amount <= reserves (run (init acc) ops).
Proof.
  intros acc ops xs Hnd Hall sender amount s' Hin Hok.
  apply (withdraw_ok_amount_le_reserves (run (init acc) ops) sender amount s' xs Hok Hin).
  apply P4_reachable_solvent; assumption.
Qed.

Redirect "assumptions-P4.txt" Print Assumptions P4_reachable_solvent.
Redirect "assumptions-P2.txt" Print Assumptions P2_reachable_withdraw_within_reserves.
